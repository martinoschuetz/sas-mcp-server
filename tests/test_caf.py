# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Tests for Tier 13 — Custom Analysis Framework (AIoT analysis types).

Two halves, because the tier has two kinds of risk.

The pure half (``helpers/caf_helpers.py``) renders a file format whose mistakes
fail *silently at runtime* — a report token with no producer paints a blank page
and raises nothing. So the tests here check the rules that catch those, and check
them in the direction that matters: a spec that should validate must not produce
noise, and one that should not must name the specific fault.

The wired half talks to ``/iotAnalysisModels``, which transports zips rather than
JSON. That makes the request itself the thing worth asserting — the ``Accept``
on the export, the multipart-then-raw fallback on the upload, and the fact that
a failed validation sends nothing at all — so it runs against a routed fake on
:class:`httpx.MockTransport` rather than an ``AsyncMock`` that would answer every
call identically.
"""

import io
import json
import zipfile
from contextlib import asynccontextmanager
from typing import Any

import httpx
import pytest
from fastmcp import Client, FastMCP

from sas_mcp_server.helpers import caf_helpers as caf
from sas_mcp_server.helpers.caf_registry import (
    AMBIENT_TOKENS,
    CTX_METHODS,
    DISPLAY_CONTROLS,
    MINIMAL_TEMPLATE,
    TEMPLATE_SUFFIX,
)
from sas_mcp_server.tools import caf as caf_tools

pytestmark = pytest.mark.asyncio

VIYA = "https://test.viya.com"

# --- fixture data ------------------------------------------------------------

# A spec that is correct on every axis the validator checks: the template's one
# token is published by the step's own code, the form item points at a real
# parameter, and the cascade guards itself with getChangedParamName.
GOOD_SPEC: dict[str, Any] = {
    "name": "DEMO_PROFILE",
    "display_name": "Demo Profile",
    "description": "A minimal well-formed analysis type.",
    "type": "CUSTOM",
    "key_group": "ASSET",
    "steps": [
        {
            "id": "DEMO_PROFILE_STP_1",
            "display_name": "Profile",
            "order": 1,
            "parameters": [
                {
                    "name": "p_caslib",
                    "display_text": "Library",
                    "data_type": "String",
                    "display_control": "DROPDOWN",
                    "order": 1,
                },
                {
                    "name": "p_table",
                    "display_text": "Table",
                    "data_type": "String",
                    "display_control": "DROPDOWN",
                    "order": 2,
                    # RESOLVEONUI belongs to the lookup, not the parameter: every
                    # one of the nine shipped uses of it sits under
                    # LookupMetadata/Properties.
                    "lookup": {
                        "type": "RESTAPI",
                        "name": "tables",
                        "properties": {"RESOLVEONUI": "true"},
                        "rest": {
                            "uri": '/casManagement/servers/cas-shared-default/caslibs/'
                            '{{getCurrentValue $.values "p_caslib"}}/tables',
                            "method": "GET",
                        },
                    },
                },
            ],
            "containers": [
                {
                    "type": "TAB",
                    "name": "BASIC",
                    "forms": [{"type": "FORM", "items": ["p_caslib", "p_table"]}],
                }
            ],
            "code": (
                "%afi_caf_preprocess(?g_cas, ?analysisID);\n"
                "data work.PROFILE; set &g_p_caslib..&g_p_table; run;\n"
                "%let g_num_output_tables = 1;\n"
                "%let g_output_table_1 = work.PROFILE;\n"
                "%afi_caf_postprocess;\n"
            ),
            "vaoutput_template": (
                '<SASReport><DataSources><DataSource label="{{.PROFILE}}">'
                '<CasResource server="{{.CASSERVERNAME}}" library="QASANLOUT" '
                'table="{{.PROFILE}}"/></DataSource></DataSources></SASReport>'
            ),
        }
    ],
    "interactions": [
        {
            "name": "cascade_table",
            "source_param": "p_caslib",
            "combinator": "AND",
            "order": 1,
            "condition": "#ctx.getChangedParamName() != 'p_table'",
            "actions": [{"order": 1, "expression": "#ctx.fetchPossibleValues('p_table')"}],
        }
    ],
}

# The collection's real field names, captured from a live deployment. They are
# NOT the ones the OpenAPI spec implies: the type is 'analysisType', the key
# group is 'domainGroup', and active is 'activeFlag'. A fixture using the
# documented spellings passes while the tool returns None for all three.
MODELS = {
    "items": [
        {
            "name": "DEMO_PROFILE",
            "displayName": "Demo Profile",
            "analysisType": "CUSTOM",
            "domainGroup": "ASSET",
            "activeFlag": True,
            "description": "A minimal well-formed analysis type.",
            "stepCount": 1,
            "modifiedTimeStamp": "2026-09-01T10:48:43.108579Z",
        },
        {
            "name": "PARETO_PRODUCT",
            "displayName": "Pareto",
            "analysisType": "STANDARD",
            "domainGroup": "PRODUCT",
            "activeFlag": True,
            "description": "Shipped.",
            "stepCount": 3,
            "modifiedTimeStamp": "2026-09-02T10:48:43.108579Z",
        },
    ],
    "count": 2,
}

# A report as Viya returns it: the table name sits in two attributes, and only
# tokenizing both makes the template bind at run time.
REPORT_XML = (
    '<SASReport xmlns="http://www.sas.com/sasreportmodel/bird-4.53.0">'
    '<DataSources><DataSource name="ds1" label="DEMO_PROFILE_PROFILE_9F2A1B">'
    '<CasResource server="cas-shared-default" library="QASANLOUT" '
    'table="DEMO_PROFILE_PROFILE_9F2A1B"/>'
    '<BusinessItemFolder><DataItem name="bi1" xref="ASSET_ID"/></BusinessItemFolder>'
    "</DataSource></DataSources></SASReport>"
)


def package_bytes(spec: dict[str, Any] = GOOD_SPEC) -> bytes:
    data, _ = caf.build_package(spec)
    return data


# --- the routed fake ----------------------------------------------------------


class FakeViya:
    """A stand-in /iotAnalysisModels that records what it was asked for."""

    def __init__(self, **overrides: Any) -> None:
        self.requests: list[httpx.Request] = []
        self.overrides = overrides
        self.reject_multipart = overrides.get("reject_multipart", False)

    def handler(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        path, method = request.url.path, request.method

        if method == "GET" and path == "/iotAnalysisModels/models":
            return httpx.Response(200, json=MODELS)
        if method == "GET" and path.startswith("/iotAnalysisModels/models/"):
            if path.endswith("/steps"):
                return httpx.Response(200, json={"items": [{"id": "DEMO_PROFILE_STP_1", "order": 1}]})
            if request.headers.get("Accept") == "application/zip":
                return httpx.Response(200, content=package_bytes())
            return httpx.Response(200, json=MODELS["items"][0])
        if method == "GET" and path == "/iotAnalysisModels/lookups":
            return httpx.Response(
                200, json={"items": [{"id": "DOMAIN", "name": "Domain", "type": "RESTAPI"}]}
            )
        if method == "POST" and path == "/iotAnalysisModels/models":
            if self.overrides.get("forbid_post"):
                # The live deployment's wording, verbatim.
                return httpx.Response(
                    403,
                    json={
                        "message": "Forbidden you are not authorized to execute this api "
                        "upsert embeded models"
                    },
                )
            if self.reject_multipart and "multipart/form-data" in request.headers.get("content-type", ""):
                return httpx.Response(415, json={"message": "unsupported"})
            return httpx.Response(201, json={"name": "DEMO_PROFILE"})
        if method == "PUT" and path.startswith("/iotAnalysisModels/models/"):
            return httpx.Response(200, json={"name": "DEMO_PROFILE"})
        if method == "PATCH" and path.startswith("/iotAnalysisModels/models/"):
            return httpx.Response(200, json={"state": request.url.params.get("state")})
        if method == "DELETE" and path.startswith("/iotAnalysisModels/models/"):
            return httpx.Response(204)
        if method == "GET" and path.startswith("/reports/reports/"):
            return httpx.Response(
                200,
                text=REPORT_XML,
                headers={"Content-Type": "application/vnd.sas.report.content+xml"},
            )
        return httpx.Response(404, json={"message": f"unrouted {method} {path}"})


@asynccontextmanager
async def caf_client(fake: FakeViya):
    """An MCP client whose Tier 13 tools talk to *fake* instead of Viya."""
    transport = httpx.MockTransport(fake.handler)

    def make_client(token: str | None):  # noqa: ARG001 - signature parity
        return httpx.AsyncClient(transport=transport, base_url=VIYA)

    mcp = FastMCP("caf-test")

    async def get_token(ctx):  # noqa: ARG001
        return "test-token"

    import sas_mcp_server.tools._common as common

    original = common.make_client
    common.make_client = make_client
    try:
        caf_tools.register(mcp, get_token)
        async with Client(mcp) as client:
            yield client
    finally:
        common.make_client = original


def result_of(call) -> dict[str, Any]:
    """The structured payload of a FastMCP tool result."""
    return call.data if call.data is not None else json.loads(call.content[0].text)


@pytest.fixture(autouse=True)
def _pin_endpoint(monkeypatch):
    """Pin VIYA_ENDPOINT so request URLs are predictable regardless of .env."""
    monkeypatch.setattr(caf_tools, "VIYA_ENDPOINT", VIYA)
    import sas_mcp_server.viya_client as viya_client

    monkeypatch.setattr(viya_client, "VIYA_ENDPOINT", VIYA)


# --- rendering ----------------------------------------------------------------


def test_xml_escaping_matches_the_corpus_spelling():
    """Quotes and newlines go out as numeric entities — what shipped packages use
    and what the importer's parser was verified against."""
    assert caf.esc('a "b" c') == "a &#34;b&#34; c"
    assert caf.esc("it's") == "it&#39;s"
    assert caf.esc("a\nb") == "a&#xA;b"
    assert caf.esc("<x> & y") == "&lt;x&gt; &amp; y"


def test_template_filename_strips_default_from_the_step_id():
    """The filename comes from the step id, not TemplateID, and a trailing
    _DEFAULT is dropped — a rule with no hint in the format itself."""
    assert caf.template_filename("SVDD_ASSET_1_DEFAULT") == "SVDD_ASSET_1_vaoutput.template"
    assert caf.template_filename("DEMO_STP_1") == "DEMO_STP_1_vaoutput.template"


def test_input_xml_keeps_the_fixed_element_order():
    xml = caf.render_input_xml(GOOD_SPEC)
    order = [
        xml.index(tag)
        for tag in ("<Registration", "<Name>", "<KeyGroup>", "<Steps>", "<Interactions>", "<ZipModifiedAt>")
    ]
    assert order == sorted(order)
    # No shipped input.xml carries an XML declaration — all 34 open on the root
    # element — so emitting one would be the odd package out.
    assert xml.startswith("<AnalysisModel>")


def test_parameters_always_carry_properties_and_uigroup():
    """Both are mandatory even when empty; omitting them imports and then
    misbehaves in the form builder."""
    xml = caf.render_input_xml(GOOD_SPEC)
    assert xml.count("<UIGroup>") == 2
    # One <Properties> per parameter, plus the lookup's own.
    assert xml.count("<Properties") == 3


def test_spec_round_trips_through_render_and_parse():
    spec = caf.parse_input_xml(caf.render_input_xml(GOOD_SPEC))
    assert spec["name"] == GOOD_SPEC["name"]
    assert spec["type"] == GOOD_SPEC["type"]
    assert spec["key_group"] == GOOD_SPEC["key_group"]
    assert [s["id"] for s in spec["steps"]] == [s["id"] for s in GOOD_SPEC["steps"]]
    assert [p["name"] for p in spec["steps"][0]["parameters"]] == ["p_caslib", "p_table"]
    assert spec["steps"][0]["code"].strip() == GOOD_SPEC["steps"][0]["code"].strip()
    assert spec["interactions"][0]["source_param"] == "p_caslib"
    assert spec["interactions"][0]["actions"][0]["expression"] == "#ctx.fetchPossibleValues('p_table')"


def test_round_trip_preserves_a_lookups_rest_body():
    spec = caf.parse_input_xml(caf.render_input_xml(GOOD_SPEC))
    lookup = spec["steps"][0]["parameters"][1]["lookup"]
    assert lookup["type"] == "RESTAPI"
    assert 'getCurrentValue $.values "p_caslib"' in lookup["rest"]["uri"]


# --- the zip ------------------------------------------------------------------


def test_package_folder_is_named_after_the_registration_name():
    """The importer keys on the folder name; a mismatch is rejected with an
    unhelpful error, so the packer must never let them diverge."""
    data, manifest = caf.build_package(GOOD_SPEC)
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        names = zf.namelist()
    assert "DEMO_PROFILE/input.xml" in names
    assert "DEMO_PROFILE/DEMO_PROFILE_STP_1_vaoutput.template" in names
    assert manifest["folder"] == "DEMO_PROFILE"


def test_a_step_without_a_template_gets_the_minimal_legal_report():
    """A missing template and an empty one fail differently, and both fail later
    than packing time."""
    spec = json.loads(json.dumps(GOOD_SPEC))
    del spec["steps"][0]["vaoutput_template"]
    data, manifest = caf.build_package(spec)
    package = caf.read_package(data)
    assert package["templates"]["DEMO_PROFILE_STP_1"] == MINIMAL_TEMPLATE
    assert manifest["templates"]["DEMO_PROFILE_STP_1"] == "minimal placeholder"


def test_read_package_recovers_the_spec_and_templates():
    package = caf.read_package(package_bytes())
    assert package["folder"] == "DEMO_PROFILE"
    assert package["spec"]["name"] == "DEMO_PROFILE"
    assert set(package["templates"]) == {"DEMO_PROFILE_STP_1"}


def test_read_package_says_what_it_found_when_there_is_no_input_xml():
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as zf:
        zf.writestr("X/readme.txt", "nope")
    with pytest.raises(ValueError, match="readme.txt"):
        caf.read_package(buffer.getvalue())


# --- the name mapping ---------------------------------------------------------


def test_output_token_is_the_bare_member_name_uppercased():
    """The libref says where a table is read from, not what it is called
    downstream — the single most misread rule in the format."""
    published = caf.code_tokens("%let g_output_table_1 = work.Filtered;\n%let g_output_var_1 = n_rows;")
    assert published["tables"] == {"FILTERED"}
    assert published["variables"] == {"N_ROWS"}


def test_explicit_output_params_are_published_verbatim():
    code = '{"analysisStepOutputParams":[{"outputname":"TS_TRANS_TABLE","outputvalue":"X"}]}'
    assert caf.code_tokens(code)["explicit"] == {"TS_TRANS_TABLE"}


def test_a_macro_built_output_name_is_recognised_as_dynamic():
    """MTS writes its outputParams body from a macro loop, so the names only
    exist once SAS has run. Enumerating them statically is impossible, and
    pretending otherwise reports every token of the step as missing."""
    looped = 'put \' { "outputname":"\' "ANALYSISVAR&l_c" \'", \';'
    assert caf.publishes_dynamically(looped) is True
    assert caf.publishes_dynamically('{"outputname":"TS_TRANS_TABLE"}') is False
    assert caf.publishes_dynamically("%afi_caf_postprocess;") is False


def test_output_contract_declares_the_count_alongside_the_tables():
    code = caf.output_contract(["work.SAMPLE", "qasout.SCORED"], ["ROW_COUNT"])
    assert "%let g_num_output_tables = 2;" in code
    assert "%let g_output_table_2 = qasout.SCORED;" in code
    assert "%let g_output_var_1 = ROW_COUNT;" in code


def test_tokenizing_a_report_rewrites_both_attributes_that_carry_a_table_name():
    """CasResource/@table and DataSource/@label. Rewriting only the first leaves
    a report that still loads and binds nothing."""
    out, report = caf.tokenize_report_xml(REPORT_XML, {"DEMO_PROFILE_PROFILE_9F2A1B": "PROFILE"})
    assert 'table="{{.PROFILE}}"' in out
    assert 'label="{{.PROFILE}}"' in out
    assert report["substitutions"]["DEMO_PROFILE_PROFILE_9F2A1B"] == 2
    assert "unmatched" not in report


def test_tokenizing_reports_a_mapping_entry_that_matched_nothing():
    _, report = caf.tokenize_report_xml(REPORT_XML, {"TYPO_TABLE": "PROFILE"})
    assert report["unmatched"] == ["TYPO_TABLE"]
    assert "CasResource/@table" in report["warning"]


def test_columns_are_only_tokenized_when_asked():
    out, _ = caf.tokenize_report_xml(REPORT_XML, {}, {"ASSET_ID": "KEYVAR"})
    assert 'xref="{{.KEYVAR}}"' in out


# --- validation ---------------------------------------------------------------


def test_a_correct_spec_validates_without_errors_or_noise():
    issues = caf.validate_spec(GOOD_SPEC)
    assert caf.blocking(issues) == []
    assert [i for i in issues if i["severity"] == "warning"] == []


def test_a_token_with_no_producer_is_a_blocking_error():
    """The check worth having: this renders an empty page and raises nothing."""
    spec = json.loads(json.dumps(GOOD_SPEC))
    spec["steps"][0]["vaoutput_template"] = '<X table="{{.NOT_PUBLISHED}}"/>'
    errors = caf.blocking(caf.validate_spec(spec))
    assert [e["message"] for e in errors if e.get("token") == "NOT_PUBLISHED"]


def test_a_parameter_name_resolves_as_a_token():
    """Shipped packages read an input parameter straight out of the template
    (Cars reads {{.REPORTING_VAR}}); treating only outputs as producers is what
    made the first version of this check unusable."""
    spec = json.loads(json.dumps(GOOD_SPEC))
    spec["steps"][0]["vaoutput_template"] = '<X label="{{.p_table}}"/>'
    assert caf.blocking(caf.validate_spec(spec)) == []


@pytest.mark.parametrize("token", ["CASSERVERNAME", "REPORT_THEME", "LOCALE"])
def test_ambient_framework_tokens_need_no_producer(token):
    assert token in AMBIENT_TOKENS
    spec = json.loads(json.dumps(GOOD_SPEC))
    spec["steps"][0]["vaoutput_template"] = f'<X label="{{{{.{token}}}}}"/>'
    assert caf.blocking(caf.validate_spec(spec)) == []


def test_a_desc_companion_resolves_from_its_base_token():
    spec = json.loads(json.dumps(GOOD_SPEC))
    spec["steps"][0]["vaoutput_template"] = '<X label="{{.PROFILE_DESC}}" table="{{.PROFILE}}"/>'
    assert caf.blocking(caf.validate_spec(spec)) == []


def test_a_later_step_may_read_an_earlier_steps_output():
    spec = json.loads(json.dumps(GOOD_SPEC))
    spec["steps"].append(
        {
            "id": "DEMO_PROFILE_STP_2",
            "display_name": "Visualize",
            "order": 2,
            "code": "%afi_caf_postprocess;",
            "vaoutput_template": '<X table="{{.PROFILE}}"/>',
        }
    )
    assert caf.blocking(caf.validate_spec(spec)) == []


def test_an_unknown_display_control_errors_with_a_suggestion():
    spec = json.loads(json.dumps(GOOD_SPEC))
    spec["steps"][0]["parameters"][0]["display_control"] = "DROPDWN"
    errors = caf.blocking(caf.validate_spec(spec))
    assert any("DROPDWN" in e["message"] for e in errors)
    assert any("DROPDOWN" in (e.get("did_you_mean") or []) for e in errors)


def test_the_batch_key_group_validates():
    """BATCH is in none of the 34 shipped packages, so the corpus-derived
    vocabulary missed it and the validator rejected PREDICTIVE_BATCH — a type the
    platform itself ships. Found on a live deployment; pinned here so a future
    re-derivation from the corpus alone does not drop it again."""
    spec = json.loads(json.dumps(GOOD_SPEC))
    spec["key_group"] = "BATCH"
    assert caf.blocking(caf.validate_spec(spec)) == []


@pytest.mark.parametrize("control", ["PQOPTIMIZATION", "PQLINERCONSTRAINT", "STABLEPERIODGRAPH"])
def test_display_controls_only_a_live_deployment_shows(control):
    """Same lesson as BATCH: these three are bespoke widgets shipped with
    PREDICTIVE_* and STABILITY_ASSET, absent from every example package. The
    corpus is a lower bound on the vocabulary."""
    spec = json.loads(json.dumps(GOOD_SPEC))
    spec["steps"][0]["parameters"][0]["display_control"] = control
    assert caf.blocking(caf.validate_spec(spec)) == []


def test_an_invented_ctx_method_is_an_error():
    """A misspelled method silently does nothing: the interaction never fires and
    the form merely looks unhelpful."""
    spec = json.loads(json.dumps(GOOD_SPEC))
    spec["interactions"][0]["actions"][0]["expression"] = "#ctx.setVisible('p_table', false)"
    errors = caf.blocking(caf.validate_spec(spec))
    assert any("setVisible" in e["message"] for e in errors)
    assert "setVisible" not in CTX_METHODS


def test_a_form_item_pointing_at_a_missing_parameter_is_an_error():
    spec = json.loads(json.dumps(GOOD_SPEC))
    spec["steps"][0]["containers"][0]["forms"][0]["items"] = ["p_caslib", "p_typo"]
    errors = caf.blocking(caf.validate_spec(spec))
    assert any("p_typo" in e["message"] for e in errors)


def test_a_self_retriggering_cascade_is_warned_about():
    spec = json.loads(json.dumps(GOOD_SPEC))
    spec["interactions"][0]["actions"][0]["expression"] = "#ctx.fetchPossibleValues('p_caslib')"
    warnings = [i for i in caf.validate_spec(spec) if i["severity"] == "warning"]
    assert any("re-triggers" in w["message"] for w in warnings)


def test_a_lookup_interpolating_a_live_value_without_resolveonui_is_warned_about():
    """Without it the value binds once at form load, so the picker shows options
    for the previous selection."""
    spec = json.loads(json.dumps(GOOD_SPEC))
    del spec["steps"][0]["parameters"][1]["lookup"]["properties"]
    warnings = [i for i in caf.validate_spec(spec) if i["severity"] == "warning"]
    assert any("RESOLVEONUI" in w["message"] for w in warnings)


def test_a_dangling_interaction_source_warns_rather_than_blocks():
    """Several shipped packages carry an interaction left behind by a renamed
    parameter. They are dead, not broken."""
    spec = json.loads(json.dumps(GOOD_SPEC))
    spec["interactions"][0]["source_param"] = "p_gone"
    issues = caf.validate_spec(spec)
    assert caf.blocking(issues) == []
    assert any("p_gone" in i["message"] for i in issues if i["severity"] == "warning")


def test_a_lowercase_data_type_warns_rather_than_blocks():
    """One shipped package declares dataType='string' and imports fine, so this
    is a spelling point rather than a fault."""
    spec = json.loads(json.dumps(GOOD_SPEC))
    spec["steps"][0]["parameters"][0]["data_type"] = "string"
    issues = caf.validate_spec(spec)
    assert caf.blocking(issues) == []
    assert any("should be spelled 'String'" in i["message"] for i in issues)


def test_missing_name_and_type_are_both_reported():
    errors = caf.blocking(caf.validate_spec({"type": "MADE_UP", "steps": []}))
    messages = " ".join(e["message"] for e in errors)
    assert "name is required" in messages
    assert "MADE_UP" in messages
    assert "at least one step" in messages


# --- the corpus as an oracle --------------------------------------------------

CORPUS = "C:/Git/martinoschuetz/AIoT/custom_analysis"


def _corpus_packages():
    import pathlib

    root = pathlib.Path(CORPUS)
    return sorted(root.rglob("*.zip")) if root.is_dir() else []


@pytest.mark.skipif(not _corpus_packages(), reason="the shipped-package corpus is not present")
def test_every_shipped_package_round_trips_and_validates():
    """The renderer and the validator were both derived from these 34 packages;
    this is the check that keeps them honest. A package that fails to round-trip
    is a hole in the format model, and a blocking error on one that demonstrably
    works means the validator is wrong, not the package."""
    failures: list[str] = []
    for path in _corpus_packages():
        package = caf.read_package(path.read_bytes())
        spec = package["spec"]
        reparsed = caf.parse_input_xml(caf.render_input_xml(spec))
        if [s["id"] for s in reparsed["steps"]] != [s["id"] for s in spec["steps"]]:
            failures.append(f"{path.name}: steps changed through render/parse")
        for step in spec["steps"]:
            key = caf.template_filename(step["id"])[: -len(TEMPLATE_SUFFIX)]
            step["vaoutput_template"] = package["templates"].get(key, "")
        for error in caf.blocking(caf.validate_spec(spec)):
            failures.append(f"{path.name}: {error['where']} | {error['message']}")
    assert failures == []


# --- reading, over the wire ---------------------------------------------------


async def test_list_analysis_types_filters_client_side():
    fake = FakeViya()
    async with caf_client(fake) as client:
        every = result_of(await client.call_tool("list_analysis_types", {}))
        custom = result_of(await client.call_tool("list_analysis_types", {"analysis_type": "custom"}))
        product = result_of(await client.call_tool("list_analysis_types", {"key_group": "PRODUCT"}))
    assert every["count"] == 2
    assert [t["name"] for t in custom["analysis_types"]] == ["DEMO_PROFILE"]
    assert [t["name"] for t in product["analysis_types"]] == ["PARETO_PRODUCT"]


async def test_list_reads_the_collections_own_field_spellings():
    """The filters above are only meaningful if the fields they read are
    populated — and the collection does not spell them the way the spec does."""
    fake = FakeViya()
    async with caf_client(fake) as client:
        rows = result_of(await client.call_tool("list_analysis_types", {}))["analysis_types"]
    first = rows[0]
    assert first["type"] == "CUSTOM"  # from analysisType
    assert first["key_group"] == "ASSET"  # from domainGroup
    assert first["active"] is True  # from activeFlag
    assert first["step_count"] == 1
    assert not [r for r in rows if r["type"] is None or r["key_group"] is None]


async def test_export_asks_for_the_zip_representation():
    """The package only comes back as a zip; the JSON representation is metadata."""
    fake = FakeViya()
    async with caf_client(fake) as client:
        result = result_of(await client.call_tool("export_analysis_type", {"name": "DEMO_PROFILE"}))
    assert fake.requests[-1].headers["Accept"] == "application/zip"
    assert "<Registration" in result["input_xml"]
    assert result["template_files"] == ["DEMO_PROFILE_STP_1_vaoutput.template"]
    assert "templates" not in result  # withheld until asked for


async def test_export_returns_one_steps_template_on_request():
    fake = FakeViya()
    async with caf_client(fake) as client:
        result = result_of(
            await client.call_tool(
                "export_analysis_type",
                {"name": "DEMO_PROFILE", "include_templates": True, "step_id": "DEMO_PROFILE_STP_1"},
            )
        )
    assert "{{.PROFILE}}" in result["templates"]["DEMO_PROFILE_STP_1"]


async def test_get_analysis_type_summarizes_without_returning_xml():
    fake = FakeViya()
    async with caf_client(fake) as client:
        result = result_of(await client.call_tool("get_analysis_type", {"name": "DEMO_PROFILE"}))
    assert "input_xml" not in result
    assert result["name"] == "DEMO_PROFILE"


async def test_describe_caf_schema_indexes_then_drills_in():
    fake = FakeViya()
    async with caf_client(fake) as client:
        index = result_of(await client.call_tool("describe_caf_schema", {}))
        tokens = result_of(await client.call_tool("describe_caf_schema", {"topic": "tokens"}))
        control = result_of(await client.call_tool("describe_caf_schema", {"control": "STABLEPERIOD"}))
    assert "tokens" in json.dumps(index)
    assert "{{." in json.dumps(tokens)
    assert "STABLEPERIOD" in json.dumps(control)


async def test_describe_covers_every_display_control():
    """The registry is the authoring surface; a control it cannot describe is one
    a model would have to guess at."""
    fake = FakeViya()
    async with caf_client(fake) as client:
        for name in sorted(c for c in DISPLAY_CONTROLS if c):
            result = result_of(await client.call_tool("describe_caf_schema", {"control": name}))
            assert name in json.dumps(result), name


# --- authoring, offline -------------------------------------------------------


async def test_validate_reports_each_steps_producers_and_consumers():
    fake = FakeViya()
    async with caf_client(fake) as client:
        result = result_of(await client.call_tool("validate_analysis_type_spec", {"spec": GOOD_SPEC}))
    assert result["valid"] is True
    step = result["steps"][0]
    assert step["template_file"] == "DEMO_PROFILE_STP_1_vaoutput.template"
    assert "PROFILE" in step["publishes"]
    assert "PROFILE" in step["template_tokens"]


async def test_build_output_contract_names_the_tokens_it_creates():
    fake = FakeViya()
    async with caf_client(fake) as client:
        result = result_of(
            await client.call_tool("build_output_contract", {"tables": ["work.SAMPLE", "casuser.Scored"]})
        )
    assert result["tokens"] == ["SAMPLE", "SCORED"]
    assert result["sas_code"].rstrip().endswith("%afi_caf_postprocess;")


async def test_templatize_va_report_reads_bird_xml_and_swaps_both_slots():
    fake = FakeViya()
    async with caf_client(fake) as client:
        result = result_of(
            await client.call_tool(
                "templatize_va_report",
                {"report_id": "r-1", "table_tokens": {"DEMO_PROFILE_PROFILE_9F2A1B": "PROFILE"}},
            )
        )
    assert fake.requests[-1].headers["Accept"] == "application/vnd.sas.report.content+xml"
    assert 'table="{{.PROFILE}}"' in result["template"]
    assert 'label="{{.PROFILE}}"' in result["template"]
    assert result["tokens"] == ["PROFILE"]


# --- writing ------------------------------------------------------------------


async def test_create_uploads_the_package_and_reports_the_manifest():
    fake = FakeViya()
    async with caf_client(fake) as client:
        result = result_of(await client.call_tool("create_analysis_type", {"spec": GOOD_SPEC}))
    assert result["status"] == "ok"
    assert result["package"]["folder"] == "DEMO_PROFILE"
    assert result["bytes"] > 0
    posts = [r for r in fake.requests if r.method == "POST"]
    assert len(posts) == 1


async def test_create_falls_back_to_a_raw_zip_body_when_multipart_is_refused():
    """The API spec documents no request body for this endpoint, so the upload
    tries the two plausible encodings rather than guessing one."""
    fake = FakeViya(reject_multipart=True)
    async with caf_client(fake) as client:
        result = result_of(await client.call_tool("create_analysis_type", {"spec": GOOD_SPEC}))
    assert result["status"] == "ok"
    content_types = [r.headers.get("content-type", "") for r in fake.requests if r.method == "POST"]
    assert len(content_types) == 2
    assert "multipart/form-data" in content_types[0]
    assert content_types[1] == "application/zip"


async def test_a_refused_write_reports_the_refusal_and_stops():
    """Observed live: POST /models answers 'not authorized to execute this api
    upsert embeded models' for an identity that POST /lookups accepts, so the
    refusal is the endpoint's own and not a missing group. Either way it is not
    an encoding problem, so the fallback must not fire — retrying as a raw zip
    would only produce a second 403 and bury the first."""
    fake = FakeViya(forbid_post=True)
    async with caf_client(fake) as client:
        result = result_of(await client.call_tool("create_analysis_type", {"spec": GOOD_SPEC}))
    assert result["status"] == "forbidden"
    assert "nothing was created" in result["message"]
    assert len([r for r in fake.requests if r.method == "POST"]) == 1


async def test_create_uploads_nothing_when_validation_fails():
    """The point of validating first: most of what is wrong with a package is
    invisible until a user runs it."""
    spec = json.loads(json.dumps(GOOD_SPEC))
    spec["steps"][0]["vaoutput_template"] = '<X table="{{.GHOST}}"/>'
    fake = FakeViya()
    async with caf_client(fake) as client:
        result = result_of(await client.call_tool("create_analysis_type", {"spec": spec}))
    assert result["status"] == "validation_failed"
    assert any(e.get("token") == "GHOST" for e in result["errors"])
    assert [r for r in fake.requests if r.method == "POST"] == []


async def test_skip_validation_uploads_anyway():
    spec = json.loads(json.dumps(GOOD_SPEC))
    spec["steps"][0]["vaoutput_template"] = '<X table="{{.GHOST}}"/>'
    fake = FakeViya()
    async with caf_client(fake) as client:
        result = result_of(
            await client.call_tool("create_analysis_type", {"spec": spec, "skip_validation": True})
        )
    assert result["status"] == "ok"
    assert len([r for r in fake.requests if r.method == "POST"]) == 1


async def test_update_refuses_a_spec_whose_name_disagrees_with_the_target():
    """The zip folder is named from spec.name and the service keys on the path,
    so a mismatch would import under one name and be addressed by another."""
    fake = FakeViya()
    async with caf_client(fake) as client:
        result = result_of(
            await client.call_tool("update_analysis_type", {"name": "OTHER_TYPE", "spec": GOOD_SPEC})
        )
    assert result["status"] == "name_mismatch"
    assert [r for r in fake.requests if r.method == "PUT"] == []


async def test_update_puts_to_the_named_model():
    fake = FakeViya()
    async with caf_client(fake) as client:
        result = result_of(
            await client.call_tool("update_analysis_type", {"name": "DEMO_PROFILE", "spec": GOOD_SPEC})
        )
    assert result["status"] == "ok"
    puts = [r for r in fake.requests if r.method == "PUT"]
    assert puts[0].url.path == "/iotAnalysisModels/models/DEMO_PROFILE"


async def test_set_state_rejects_anything_but_active_or_inactive():
    fake = FakeViya()
    async with caf_client(fake) as client:
        bad = result_of(
            await client.call_tool("set_analysis_type_state", {"name": "DEMO_PROFILE", "state": "on"})
        )
        good = result_of(
            await client.call_tool("set_analysis_type_state", {"name": "DEMO_PROFILE", "state": "active"})
        )
    assert bad["status"] == "invalid_state"
    assert good["state"] == "active"
    patches = [r for r in fake.requests if r.method == "PATCH"]
    assert len(patches) == 1
    assert patches[0].url.params.get("state") == "active"


async def test_delete_removes_the_named_type():
    fake = FakeViya()
    async with caf_client(fake) as client:
        result = result_of(await client.call_tool("delete_analysis_type", {"name": "DEMO_PROFILE"}))
    assert result == {"status": "deleted", "name": "DEMO_PROFILE"}
    assert fake.requests[-1].method == "DELETE"
