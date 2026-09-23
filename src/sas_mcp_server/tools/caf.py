# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Tier 13 — Custom Analysis Framework (authoring AIoT analysis types).

Tier 10 runs the analyses a Viya deployment already offers. This tier builds the
*types* those analyses are instances of: the input form, the SAS code, and the
Visual Analytics report the results render into, packaged as the zip
``/iotAnalysisModels`` transports.

The format is unforgiving in ways that fail silently — a report token with no
producer renders an empty page and raises nothing — so the write tools validate
before they upload and say what is wrong in terms of the fix. Two tools exist
specifically to keep a model off the two hardest paths:

* :func:`describe_caf_schema` discloses the format a layer at a time, so the
  vocabularies do not have to be in context to author against them;
* ``templatize_va_report`` converts a report that already works in Visual
  Analytics into a step template, instead of generating BIRD XML blind.
"""

from collections.abc import Awaitable, Callable
from typing import Annotated, Any

from fastmcp import Context, FastMCP
from pydantic import BeforeValidator, Field

from ..config import VIYA_ENDPOINT
from ..helpers import caf_helpers as caf
from ..helpers.caf_registry import (
    COLLECTION_ACCEPT,
    LOOKUPS_PATH,
    MODEL_PATH,
    MODEL_STEPS_PATH,
    MODELS_PATH,
    REPORT_CONTENT_PATH,
    REPORT_CONTENT_XML_ACCEPT,
    ZIP_MEDIA_TYPE,
)
from ..viya_client import delete_resource, get_json, get_paged_items, raise_for_viya_status
from ._common import coerce_json_dict, make_session_helpers

JsonDict = Annotated[dict[str, Any], BeforeValidator(coerce_json_dict)]


async def _fetch_package(client: Any, name: str) -> dict[str, Any]:
    """GET an analysis type as its zip and unpack it."""
    resp = await client.get(
        f"{VIYA_ENDPOINT}{MODEL_PATH.format(name=name)}",
        headers={"Accept": ZIP_MEDIA_TYPE},
    )
    raise_for_viya_status(resp)
    return caf.read_package(resp.content)


def register(mcp: FastMCP, get_token: Callable[[Context], Awaitable[str]]) -> None:
    """Register Tier 13 (Custom Analysis Framework) tools on *mcp*."""

    viya_session, _ = make_session_helpers(get_token)

    # --- learning the format -------------------------------------------------

    @mcp.tool()
    async def describe_caf_schema(
        ctx: Context,
        topic: Annotated[
            str | None,
            Field(
                default=None,
                description="One of: overview, package, registration, parameters, lookups, "
                "containers, interactions, code, output, tokens, gotchas.",
            ),
        ] = None,
        control: Annotated[
            str | None,
            Field(default=None, description="Document one display control, e.g. 'STABLEPERIOD'."),
        ] = None,
    ) -> dict[str, Any]:
        """Explains the Custom Analysis Framework package format, one layer at a time.

        Call with no arguments for the index, then drill into the layer you are
        writing. Read `topic='tokens'` before writing any step that produces a
        report: the rule that an output param named X is read as `{{.X}}` is the
        whole name mapping, and getting it wrong fails silently at runtime.

        Args:
            topic: Which layer of the format to describe.
            control: A display control name to document on its own.
        """
        return caf.describe(topic=topic, control=control)

    # --- reading what is deployed --------------------------------------------

    @mcp.tool()
    async def list_analysis_types(
        ctx: Context,
        analysis_type: Annotated[
            str | None, Field(default=None, description="Filter to CUSTOM, STANDARD or ALERTS.")
        ] = None,
        key_group: Annotated[
            str | None, Field(default=None, description="Filter to PRODUCT, ASSET or PRD_ASSET.")
        ] = None,
        limit: Annotated[int, Field(default=100, ge=1, le=1000)] = 100,
    ) -> dict[str, Any]:
        """Lists the AIoT analysis types installed in this deployment.

        These are the templates users create analyses from — the shipped standard
        ones and any custom ones. Use get_analysis_type or export_analysis_type
        to read one, including a SAS-shipped one, as a worked example.

        Args:
            analysis_type: Restrict to one registration type.
            key_group: Restrict to one key group.
            limit: Maximum number of types to return.
        """
        async with viya_session("list_analysis_types", ctx) as client:
            items, total = await get_paged_items(MODELS_PATH, client, limit=limit)
            # The collection spells three of these differently from the package
            # and from the OpenAPI spec: analysisType, domainGroup, activeFlag.
            # Verified against a live deployment — reading 'type'/'keyGroup'/
            # 'active' here returns None for every row and silently empties the
            # filters below. The documented names are kept as fallbacks.
            rows = [
                {
                    "name": i.get("name"),
                    "display_name": i.get("displayName"),
                    "type": i.get("analysisType", i.get("type")),
                    "key_group": i.get("domainGroup", i.get("keyGroup")),
                    "active": i.get("activeFlag", i.get("active")),
                    "description": i.get("description"),
                    "step_count": i.get("stepCount"),
                    "modified": i.get("modifiedTimeStamp"),
                }
                for i in items
            ]
            if analysis_type:
                rows = [r for r in rows if str(r.get("type", "")).upper() == analysis_type.upper()]
            if key_group:
                rows = [r for r in rows if str(r.get("key_group", "")).upper() == key_group.upper()]
            return {"count": len(rows), "total_available": total, "analysis_types": rows}

    @mcp.tool()
    async def get_analysis_type(
        name: Annotated[str, Field(description="The analysis type's name, e.g. 'PARETO_PRODUCT'.")],
        ctx: Context,
    ) -> dict[str, Any]:
        """Summarizes one analysis type: its steps, parameters, outputs and interactions.

        Reads the deployed package and reports its shape — what each step
        publishes and which tokens its report template reads — without returning
        the XML, which runs to hundreds of kilobytes.

        Args:
            name: The analysis type to describe.
        """
        async with viya_session("get_analysis_type", ctx) as client:
            package = await _fetch_package(client, name)
            summary = caf.summarize_package(package)
            summary["hint"] = (
                "export_analysis_type returns the same package's input.xml and templates as text "
                "when you need to copy a working construct verbatim."
            )
            return summary

    @mcp.tool()
    async def export_analysis_type(
        name: Annotated[str, Field(description="The analysis type to export.")],
        ctx: Context,
        include_templates: Annotated[
            bool,
            Field(default=False, description="Include the full report templates. These are large."),
        ] = False,
        step_id: Annotated[
            str | None,
            Field(default=None, description="With include_templates, return only this step's template."),
        ] = None,
    ) -> dict[str, Any]:
        """Exports an analysis type's source: input.xml, and optionally its report templates.

        The fastest way to answer a format question is to read a type that
        already works. Templates are withheld by default because a single one
        can exceed 800KB; ask for one step's at a time.

        Args:
            name: The analysis type to export.
            include_templates: Return the Go/BIRD report templates too.
            step_id: Limit the returned template to this step.
        """
        async with viya_session("export_analysis_type", ctx) as client:
            package = await _fetch_package(client, name)
            result: dict[str, Any] = {
                "name": name,
                "folder": package["folder"],
                "input_xml": package["input_xml"],
                "template_files": sorted(f"{k}{caf.TEMPLATE_SUFFIX}" for k in package["templates"]),
            }
            if include_templates:
                templates = package["templates"]
                if step_id:
                    key = caf.template_filename(step_id)[: -len(caf.TEMPLATE_SUFFIX)]
                    templates = {k: v for k, v in templates.items() if k == key}
                    if not templates:
                        result["note"] = f"No template for step '{step_id}'. Available: {result['template_files']}"
                result["templates"] = templates
            else:
                result["sizes"] = {k: len(v) for k, v in package["templates"].items()}
                result["hint"] = "Pass include_templates=true with a step_id to read one template."
            return result

    @mcp.tool()
    async def list_analysis_type_lookups(
        ctx: Context,
        limit: Annotated[int, Field(default=100, ge=1, le=1000)] = 100,
    ) -> dict[str, Any]:
        """Lists the shared platform lookups an analysis type's parameters can reference.

        A parameter can carry its own inline lookup, or reference one of these by
        id — which is what most shipped parameters do, since the platform already
        knows how to resolve domains, usage types and the like.

        Args:
            limit: Maximum number of lookups to return.
        """
        async with viya_session("list_analysis_type_lookups", ctx) as client:
            data = await get_json(LOOKUPS_PATH, client, params={"limit": limit}, accept=COLLECTION_ACCEPT)
            items = data.get("items", data if isinstance(data, list) else [])
            return {
                "count": len(items),
                "lookups": [
                    {
                        "id": i.get("id"),
                        "name": i.get("name"),
                        "type": i.get("type"),
                        "description": i.get("description"),
                    }
                    for i in items
                ],
            }

    @mcp.tool()
    async def get_analysis_type_steps(
        name: Annotated[str, Field(description="The analysis type's name.")],
        ctx: Context,
    ) -> dict[str, Any]:
        """Lists an analysis type's steps as the service itself reports them.

        The service's own view of the steps, which is what the runtime uses to
        chain them — useful when a package's step order and the deployed order
        appear to disagree.

        Args:
            name: The analysis type whose steps to list.
        """
        async with viya_session("get_analysis_type_steps", ctx) as client:
            data = await get_json(MODEL_STEPS_PATH.format(name=name), client, accept=COLLECTION_ACCEPT)
            items = data.get("items", data if isinstance(data, list) else [])
            return {"name": name, "count": len(items), "steps": items}

    # --- authoring, offline --------------------------------------------------

    @mcp.tool()
    async def validate_analysis_type_spec(
        spec: Annotated[JsonDict, Field(description="The analysis type spec to check.")],
        ctx: Context,
    ) -> dict[str, Any]:
        """Checks an analysis type spec for the mistakes that fail silently at runtime.

        Run this before create_analysis_type — it is the same check the create
        tool runs, exposed on its own so a spec can be fixed without a round trip.
        It catches unknown display controls and #ctx methods, lookups that
        interpolate a live value without RESOLVEONUI, self-retriggering cascades,
        form items pointing at parameters that do not exist, and above all report
        tokens with no producer, which render a blank page and raise nothing.

        Args:
            spec: The analysis type spec (see describe_caf_schema for its shape).
        """
        issues = caf.validate_spec(spec)
        errors = caf.blocking(issues)
        xml = caf.render_input_xml(spec)
        return {
            "valid": not errors,
            "errors": errors,
            "warnings": [i for i in issues if i.get("severity") == "warning"],
            "info": [i for i in issues if i.get("severity") == "info"],
            "input_xml_lines": len(xml.splitlines()),
            "steps": [
                {
                    "id": s.get("id"),
                    "template_file": caf.template_filename(str(s.get("id", ""))),
                    "publishes": sorted(
                        set().union(*caf.code_tokens(s.get("code", "")).values())  # type: ignore[arg-type]
                    ),
                    "template_tokens": sorted(
                        caf.template_tokens(s.get("vaoutput_template") or s.get("template") or "")
                    ),
                }
                for s in spec.get("steps", [])
            ],
        }

    @mcp.tool()
    async def build_output_contract(
        tables: Annotated[
            list[str],
            Field(description="Tables to publish, as lib.MEMBER — e.g. ['work.SAMPLE', 'casuser.SCORED']."),
        ],
        ctx: Context,
        output_variables: Annotated[
            list[str] | None,
            Field(default=None, description="Scalar macro variables to publish alongside them."),
        ] = None,
    ) -> dict[str, Any]:
        """Writes the SAS tail that publishes a step's outputs, and names the tokens it creates.

        This is the half of the name mapping that lives in SAS. Paste the result
        at the end of the step's code; the tokens it reports are exactly what the
        step's report template may read as `{{.TOKEN}}`.

        Args:
            tables: The tables to promote, qualified as lib.MEMBER.
            output_variables: Macro variable names to publish as scalar outputs.
        """
        code = caf.output_contract(tables, output_variables or [])
        tokens = [t.strip().rsplit(".", 1)[-1].upper() for t in tables]
        return {
            "sas_code": code + "%afi_caf_postprocess;",
            "tokens": tokens + [v.upper() for v in (output_variables or [])],
            "promoted_as": [f"<ANALYSIS_TYPE>_{t}_<SHORT_ID> in QASANLOUT" for t in tokens],
            "note": (
                "The token is the BARE MEMBER NAME, uppercase — the libref says where the table is "
                "read from, not what it is called downstream. Reference each token in the report "
                "template on both CasResource/@table and the enclosing DataSource/@label."
            ),
        }

    @mcp.tool()
    async def templatize_va_report(
        report_id: Annotated[str, Field(description="Id of a Visual Analytics report that already works.")],
        table_tokens: Annotated[
            JsonDict,
            Field(description='Runtime table name to token, e.g. {"DEMO_SAMPLE_9F2A1B": "SAMPLE"}.'),
        ],
        ctx: Context,
        column_tokens: Annotated[
            JsonDict | None,
            Field(default=None, description="Column name to token, when the run's columns vary."),
        ] = None,
    ) -> dict[str, Any]:
        """Converts a working VA report into a step's output template.

        The reliable way to build the output layer: design the report in Visual
        Analytics against a real run's output tables, then run it through here to
        swap those live table names for `{{.TOKEN}}` slots. Both attributes that
        carry a table name are rewritten — CasResource/@table and the enclosing
        DataSource/@label — which is the step most often missed when doing it by
        hand. Writing BIRD XML from scratch instead is how reports end up blank.

        Args:
            report_id: The report to read back as BIRD XML.
            table_tokens: Map each runtime CAS table name to the token to put in its place.
            column_tokens: Map column names to tokens, if the columns vary per run.
        """
        async with viya_session("templatize_va_report", ctx) as client:
            resp = await client.get(
                f"{VIYA_ENDPOINT}{REPORT_CONTENT_PATH.format(report_id=report_id)}",
                headers={"Accept": REPORT_CONTENT_XML_ACCEPT},
            )
            raise_for_viya_status(resp)
            template, report = caf.tokenize_report_xml(resp.text, table_tokens, column_tokens)
            return {
                "template": template,
                "chars": len(template),
                **report,
                "next": (
                    "Put this in the step's `vaoutput_template`, and make the step's SAS code "
                    "publish every token listed — build_output_contract writes that tail. "
                    "validate_analysis_type_spec then confirms the two sides agree."
                ),
            }

    # --- writing to the deployment -------------------------------------------

    @mcp.tool()
    async def create_analysis_type(
        spec: Annotated[
            JsonDict,
            Field(
                description="The analysis type spec: name, display_name, type, key_group and a "
                "steps list. Call describe_caf_schema() first for the shape."
            ),
        ],
        ctx: Context,
        skip_validation: Annotated[
            bool,
            Field(default=False, description="Upload even if validation reports errors."),
        ] = False,
    ) -> dict[str, Any]:
        """Creates a new AIoT analysis type from a spec, packaged and uploaded.

        Renders input.xml and a report template per step, zips them under a
        folder named after the type, and POSTs the result. Validation runs first
        and blocks the upload on errors, because most of what is wrong with a CAF
        package is invisible until a user runs it.

        A step given no `vaoutput_template` gets the minimal legal report, which
        is the right default for a step that computes without visualizing.

        Args:
            spec: The analysis type to create.
            skip_validation: Upload despite validation errors. Rarely the right call.
        """
        issues = caf.validate_spec(spec)
        errors = caf.blocking(issues)
        if errors and not skip_validation:
            return {
                "status": "validation_failed",
                "errors": errors,
                "warnings": [i for i in issues if i.get("severity") == "warning"],
                "message": "Nothing was uploaded. Fix these, or pass skip_validation=true.",
            }

        data, manifest = caf.build_package(spec)
        name = spec.get("name", "")
        async with viya_session("create_analysis_type", ctx) as client:
            result = await caf.upload_package(client, MODELS_PATH, data, f"{name}.zip")
        return {
            **result,
            "name": name,
            "package": manifest,
            "bytes": len(data),
            "warnings": [i for i in issues if i.get("severity") == "warning"],
            "next": (
                "New types are inactive until set_analysis_type_state(name, 'active') — which "
                "needs an administrator."
                if result.get("status") == "ok"
                else None
            ),
        }

    @mcp.tool()
    async def update_analysis_type(
        name: Annotated[str, Field(description="The existing analysis type to replace.")],
        spec: Annotated[JsonDict, Field(description="The full replacement spec.")],
        ctx: Context,
        skip_validation: Annotated[bool, Field(default=False)] = False,
    ) -> dict[str, Any]:
        """Replaces an existing analysis type with a new package.

        This is a whole-package replacement, not a merge: the spec you pass
        becomes the type. Export the current one first if you mean to change part
        of it. Analyses already created from this type keep running against the
        new definition, so a change to a step's outputs can break their reports.

        Args:
            name: The analysis type to replace.
            spec: The complete replacement spec.
            skip_validation: Upload despite validation errors.
        """
        issues = caf.validate_spec(spec)
        errors = caf.blocking(issues)
        if errors and not skip_validation:
            return {
                "status": "validation_failed",
                "errors": errors,
                "message": "Nothing was uploaded. Fix these, or pass skip_validation=true.",
            }
        if spec.get("name") and spec["name"] != name:
            return {
                "status": "name_mismatch",
                "message": (
                    f"spec.name is '{spec['name']}' but the target is '{name}'. The package folder "
                    "is named from spec.name and the service keys on the path, so these must agree."
                ),
            }

        data, manifest = caf.build_package(spec)
        async with viya_session("update_analysis_type", ctx) as client:
            result = await caf.upload_package(
                client, MODEL_PATH.format(name=name), data, f"{name}.zip", method="PUT"
            )
        return {**result, "name": name, "package": manifest, "bytes": len(data)}

    @mcp.tool()
    async def set_analysis_type_state(
        name: Annotated[str, Field(description="The analysis type to activate or deactivate.")],
        state: Annotated[str, Field(description="'active' or 'inactive'.")],
        ctx: Context,
    ) -> dict[str, Any]:
        """Activates or deactivates an analysis type.

        An inactive type is hidden from users without being deleted, which is how
        a type is withdrawn without breaking the analyses already created from
        it. Requires an administrator.

        Args:
            name: The analysis type to change.
            state: 'active' or 'inactive'.
        """
        if state not in ("active", "inactive"):
            return {"status": "invalid_state", "message": "state must be 'active' or 'inactive'."}
        async with viya_session("set_analysis_type_state", ctx) as client:
            resp = await client.patch(
                f"{VIYA_ENDPOINT}{MODEL_PATH.format(name=name)}",
                params={"state": state},
                headers={"Accept": "application/json"},
            )
            raise_for_viya_status(resp)
            return {"status": "ok", "name": name, "state": state, "http_status": resp.status_code}

    @mcp.tool()
    async def delete_analysis_type(
        name: Annotated[str, Field(description="The analysis type to delete.")],
        ctx: Context,
    ) -> dict[str, Any]:
        """Deletes an analysis type.

        Removes the type itself. Analyses users already created from it depend on
        this definition — deactivating with set_analysis_type_state is the
        reversible way to withdraw a type.

        Args:
            name: The analysis type to delete.
        """
        async with viya_session("delete_analysis_type", ctx) as client:
            await delete_resource(MODEL_PATH.format(name=name), client)
            return {"status": "deleted", "name": name}
