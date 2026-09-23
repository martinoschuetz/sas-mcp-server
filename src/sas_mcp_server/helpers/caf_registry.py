# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Static vocabularies for the SAS Analytics for IoT Custom Analysis Framework.

The frozen data that drives ``caf_helpers.py``, kept apart from the functions so
each table can be read, audited and extended on its own:

* :data:`MODELS_PATH` and friends — the ``/iotAnalysisModels`` endpoints an
  analysis *type* (as opposed to an analysis *instance*) is managed through;
* the enumerations the input layer accepts — :data:`ANALYSIS_TYPES`,
  :data:`KEY_GROUPS`, :data:`DISPLAY_CONTROLS`, :data:`DATA_TYPES`,
  :data:`LOOKUP_TYPES`, :data:`PROPERTY_KEYS`;
* :data:`CTX_METHODS` — the ``#ctx.*`` surface interactions may call, and
  :data:`TEMPLATE_FUNCTIONS` — the Go ``text/template`` functions the lookup and
  output layers may call. Both are allowlists: a name outside them is a typo or
  an invention, and either way the UI silently does nothing at runtime.
* :data:`MINIMAL_TEMPLATE` — the smallest BIRD report the output layer accepts,
  and :data:`OUTPUT_CONTRACT` / :data:`CODE_SKELETON` — the SAS bookends that
  publish tables under the names a template references.

Every enumeration here was derived by aggregating the 34 shipped analysis-type
packages, not from a specification: the framework's importer is permissive and
its documentation covers the UI, not the artifact. Where a value is inferred
rather than observed it says so.

Data only — anything that executes lives in ``caf_helpers.py``.
"""

from __future__ import annotations

import re
from typing import Any

# --- endpoints ---------------------------------------------------------------
# /iotAnalysisModels manages analysis TYPES; /iotAnalysis manages the instances
# a user creates from them (Tier 10). The two are routinely confused.

MODELS_PATH = "/iotAnalysisModels/models"
MODEL_PATH = "/iotAnalysisModels/models/{name}"
MODEL_STEPS_PATH = "/iotAnalysisModels/models/{name}/steps"
MODEL_STEP_TEMPLATES_PATH = "/iotAnalysisModels/models/{name}/steps/{step_id}/templates"
MODEL_PARAMETERS_PATH = "/iotAnalysisModels/models/{name}/parameters"
LOOKUPS_PATH = "/iotAnalysisModels/lookups"

# Two relations a live deployment advertises that the OpenAPI spec does not
# mention. `copy` is the cheapest way to fork a shipped type into your own.
MODEL_COPY_PATH = "/iotAnalysisModels/models/{name}/copy"
MODEL_REFERENCES_PATH = "/iotAnalysisModels/models/{name}/references"

# The zip is what the service actually transports: GET with this Accept returns
# the same layout that CAF_Examples/*.zip holds, and POST/PUT take it back.
ZIP_MEDIA_TYPE = "application/zip"
COLLECTION_ACCEPT = "application/vnd.sas.collection+json"

# GET the same URL with this instead and you get input.xml on its own, without
# the zip or its templates — the cheap read when only the input layer matters.
# (The service's 406 body is what enumerates these; `application/xml` is NOT
# among them.)
MODEL_UI_XML_ACCEPT = "application/vnd.sas.iot.analysis.model.ui+xml"
MODEL_DETAIL_MEDIA_TYPE = "application/vnd.sas.iot.analysis.model.detail"

# The published OpenAPI spec documents no requestBody media type for POST /models
# or PUT /models/{name}, so the upload encoding is not knowable from the contract.
# Both forms are attempted in order; see caf_helpers.upload_package.
UPLOAD_STRATEGIES: tuple[str, ...] = ("multipart", "raw")

# Read back a VA report as BIRD XML — the shape a *_vaoutput.template is in.
REPORT_CONTENT_PATH = "/reports/reports/{report_id}/content"
REPORT_CONTENT_XML_ACCEPT = "application/vnd.sas.report.content+xml"


# --- input layer enumerations ------------------------------------------------

ANALYSIS_TYPES: frozenset[str] = frozenset({"CUSTOM", "STANDARD", "ALERTS"})

# Which key the analysis is grouped and reported by. PRD_ASSET is used by
# exactly one shipped type (EXPLORATION_PRD_ASSET) and means both.
#
# BATCH is in no package in the example corpus — it was found on a live
# deployment, where PREDICTIVE_BATCH ("Predictive Quality", STANDARD) uses it.
# 34 packages are a lower bound on the vocabulary, not the whole of it; leaving
# BATCH out made the validator reject a key group the platform itself ships.
KEY_GROUPS: frozenset[str] = frozenset({"PRODUCT", "ASSET", "PRD_ASSET", "BATCH"})

# displayControl -> what the UI renders. The empty string is legal and means a
# hidden constant: a parameter that reaches the SAS code but has no widget.
DISPLAY_CONTROLS: dict[str, str] = {
    "DROPDOWN": "Single-value picker, values from a lookup or PossibleValues.",
    "SINGLESELECT": "Single-value list; like DROPDOWN but rendered expanded.",
    "MULTISELECT": "Multi-value list. Pair with dataType='Array'.",
    "SELECTNINPUT": "Select-or-type combo: a listed value or a free one.",
    "TEXTINPUT": "Free text.",
    "NUMERICSTEPPER": "Number spinner. Bound by the 'min'/'max' properties.",
    "MULTINUMERICSTEPPER": "Several number spinners in one row.",
    "CHECKBOX": "Boolean. Reaches the code as the string 'true'/'false'.",
    "DATE": "Date picker.",
    "DATETIME": "Date-and-time picker.",
    "STABLEPERIOD": "Interval picker over a CAS time series; needs a CASTABLE "
    "lookup naming the key (time) and value (measure) columns.",
    "LABEL": "Static text, not an input. The text is the DefaultValues entry.",
    "": "Hidden constant — no widget; the DefaultValues entry reaches the code.",
    # Bespoke widgets shipped with particular SAS STANDARD types. None appears in
    # the example corpus; all three were found on a live deployment. They are
    # listed so the validator does not reject a package the platform itself
    # ships — not as a recommendation to author against them.
    "PQOPTIMIZATION": "Predictive Quality's input-variable picker (PREDICTIVE_BATCH, "
    "PREDICTIVE_PRD_ASSET): a multi-select over the target-variable lookup that "
    "also carries each variable's optimization setting.",
    "PQLINERCONSTRAINT": "Predictive Quality's linear-constraint editor. The value "
    "is a CSV of NAME:number pairs, with UB:/LB: for the bounds — e.g. "
    "'UB:10000,LB:1,CBLABSORB:5'. (The misspelling is the platform's.)",
    "STABLEPERIODGRAPH": "The graphical form of STABLEPERIOD (STABILITY_ASSET): "
    "pick stable periods off a plotted series rather than by typing an interval. "
    "Defaults to 'NONE'.",
}

# Declared type. Note the corpus overwhelmingly declares numbers as 'String'
# with a NUMERICSTEPPER control and min/max properties: only three parameters
# across all 34 packages use Integer or Float. Follow the corpus — the value
# arrives in SAS as text either way.
DATA_TYPES: frozenset[str] = frozenset({"String", "Array", "Date", "Float", "Integer", ""})

# Multi-value controls need Array or the UI keeps only the last selection.
ARRAY_CONTROLS: frozenset[str] = frozenset({"MULTISELECT", "MULTINUMERICSTEPPER"})

# An inline lookup carries its own definition. Omitting @type entirely means the
# element is a REFERENCE to a shared platform lookup by id — ~70% of the corpus.
LOOKUP_TYPES: frozenset[str] = frozenset({"RESTAPI", "CASTABLE"})

PROPERTY_KEYS: dict[str, str] = {
    "min": "Lower bound for NUMERICSTEPPER.",
    "max": "Upper bound for NUMERICSTEPPER.",
    "RESOLVEONUI": "'true' — resolve this lookup in the browser, not server-side. "
    "REQUIRED on any lookup whose URI or WhereCondition interpolates another "
    "live form value, or it resolves against a stale one.",
    "SKIP_VALIDATION": "'true' — do not require a value before the step can run.",
    "RERUN_REQUIRED": "'true' — changing this parameter invalidates prior results.",
    "table_columns": "CSV of column names to show for a table-valued parameter.",
    "table_columns_headers": "CSV of headers for those columns, positionally paired "
    "with table_columns.",
    "group_search": "'true' — add a search box to a grouped picker.",
    "sort": "'asc'/'desc' — order the lookup's values.",
    "fraction": "Decimal places for a numeric control.",
    "max_selection": "Cap on how many values a multi-select accepts.",
    "min_selection": "Floor on how many a multi-select requires.",
    "show_key": "'true' — display the lookup key beside its value.",
}

CONTAINER_TYPES: frozenset[str] = frozenset({"TAB", "FORM"})
FORM_ITEM_TYPES: frozenset[str] = frozenset({"INLINE"})
UI_TABS: frozenset[str] = frozenset({"BASIC", "ADVANCED"})
COMBINATORS: frozenset[str] = frozenset({"AND", "OR"})

# Parameter names the framework fills in itself. Declaring one means "give me
# this", not "let the user type it".
RESERVED_PARAMETERS: dict[str, str] = {
    "__DATASELECTIONID__": "Id of the data selection the analysis runs against.",
    "__DATASELCREATIONTYPE__": "How that data selection was created.",
    "__ANALYSISNAME__": "The analysis instance's display name.",
    "__VECHILDANALYSIS__": "Set when the run is a drill-down child analysis.",
}


# --- interaction layer: the #ctx surface -------------------------------------
# SpEL, evaluated against a #ctx root object. Only a small subset of SpEL's
# grammar appears in practice: method calls on #ctx, == / !=, && / ||, and the
# ternary. There are no #{...} templates anywhere in the corpus.

# Exactly the methods the 34 shipped packages call, with their call counts as a
# rough guide to how load-bearing each one is. This is an allowlist, not a
# summary: the evaluator silently does nothing for a name it does not know, so a
# plausible-sounding invention (clearValidationErrors, setDisplayText) produces
# an interaction that appears to be wired up and never fires.
CTX_METHODS: dict[str, str] = {
    "getChangedParamName": "() -> str. Which parameter fired this interaction. The "
    "guard every cascade needs: re-fetching the parameter that just changed "
    "re-triggers the interaction and loops.",
    "currentValue": "(param) -> str. The parameter's current value.",
    "currentValues": "(param) -> list. All current values of a multi-value parameter.",
    "currentValueObject": "(param) -> obj. The current value as a key/value object.",
    "currentValueObjects": "(param) -> list. Current values as key/value objects.",
    "currentValueByDataType": "(param) -> typed. The current value coerced to the "
    "parameter's declared dataType.",
    "currentValueCsv": "(param) -> str. Current values as a comma-separated string.",
    "fetchPossibleValues": "(param). Re-run that parameter's lookup. The engine of "
    "every cascading picker.",
    "possibleValues": "(param) -> list. The values currently offered.",
    "getPossibleValues": "(param) -> list. As above.",
    "setCurrentValue": "(param, value). Set a value programmatically.",
    "resetCurrentValues": "(param). Clear the selection.",
    "enable": "(param).",
    "disable": "(param).",
    "show": "(param). Reveal a hidden parameter.",
    "hide": "(param). Hide it.",
    "setRequired": "(param, bool). Make a parameter mandatory at runtime.",
    "updateParamPropValue": "(param, key, value). Change a <Property> at runtime "
    "(e.g. raise a NUMERICSTEPPER's max once another value is known).",
    "hideLookupValues": "(param, csv). Hide specific values from a picker without "
    "re-running its lookup.",
    "addValidationError": "(param, message). The ONLY validation mechanism — there "
    "is no <Validations> element.",
    "removeValidationError": "(param). Clear one previously added.",
    "getCurrentStep": "() -> str. The step id. <Interactions> is MODEL-level, so "
    "this is how an interaction is scoped to one step.",
    "getStepStatus": "(stepId) -> str. Has an earlier step run?",
    "getOutputParamValueByModelStepId": "(stepId, name) -> str. Read an earlier "
    "step's published output param from the UI.",
    "isChildAnalysis": "() -> bool. True when the run is a drill-down child analysis.",
    "showUsageType": "(param, usageType). Reveal a parameter for one usage type.",
    "hideUsageType": "(param, usageType). Hide it for one usage type.",
    "usageTypeInteraction": "(param). Wire a parameter to the usage-type selector.",
    "endsWith": "(value, suffix) -> bool. String test, used in conditions.",
}

# Two statement separators appear inside one <Action>; both are legal.
#   '|'      — used by the shipped STANDARD types
#   newline  — used by the CUSTOM types (encoded &#xA; in the XML)
ACTION_SEPARATORS: tuple[str, ...] = ("\n", "|")


# --- template layer: Go text/template ----------------------------------------
# Two different templates, same language. Lookup URIs/bodies/WhereConditions are
# rendered against a values map; *_vaoutput.template is rendered against the
# step's published output params.

TEMPLATE_FUNCTIONS: dict[str, str] = {
    "getCurrentValue": '{{getCurrentValue $.values "p_x"}} — another parameter\'s '
    "value. Needs RESOLVEONUI=true on the lookup that uses it.",
    "hasCurrentValue": '{{if hasCurrentValue $.values "p_x"}}...{{end}}',
    "toCSV": "{{toCSV $cv}} — a multi-value selection as a comma-separated list.",
    "localizeValue": "{{localizeValue .X}} — resolve a value through the bundles.",
    "getColumnLabel": "{{getColumnLabel .TABLE .COLUMN}} — a column's label.",
    "getColumnFormat": "{{getColumnFormat .TABLE .COLUMN}}",
    "showColumn": "{{if showColumn .X}}...{{end}} — suppress a column the run "
    "did not produce.",
    "resolveSelectAndInputControlValue": "Resolve a select-or-input value.",
    "add": "{{add 1 2}} — arithmetic, for generated element indices.",
    "eq": "{{if eq .X \"1\"}}...{{end}}",
    "or": "{{if or (eq .X \"1\") (eq .X \"2\")}}...{{end}}",
    "and": "{{if and ...}}",
    "not": "{{if not ...}}",
}

# {{.TOKEN}}, and .TOKEN inside a pipeline such as {{if eq .TOKEN "1"}}.
TOKEN_RE = re.compile(r"\{\{[^}]*?\.([A-Za-z_][A-Za-z0-9_]*)[^}]*?\}\}")
TOKEN_IN_ACTION_RE = re.compile(r"\.([A-Za-z_][A-Za-z0-9_]*)")

# localize('KEY','BUNDLE','Default text') wraps display strings for i18n.
# Bundles seen: MODEL_DEF, template_param_lookup, REPORT_COMMON, <ANALYSIS_NAME>.
LOCALIZE_RE = re.compile(r"localize\(\s*'([^']*)'\s*,\s*'([^']*)'\s*,\s*'([^']*)'\s*\)")


# --- SAS code layer ----------------------------------------------------------

# Mid-tier substitutions performed on <Code> before it reaches SAS. Each is
# replaced ONCE, case-sensitively, at its FIRST occurrence — including inside a
# comment. Naming one in a comment silently breaks the real call below it.
CODE_TOKENS: dict[str, str] = {
    "?g_cas": "CAS session connection options.",
    "?analysisID": "The analysis instance id.",
    "?g_metadata": "Analysis metadata JSON.",
    "?limit": "Paging limit for a generated REST call.",
    "?append": "Append-vs-replace flag for outputParams (?append=false replaces).",
    "?filter": "Filter for a generated REST call.",
}

# Macro variables the framework sets before <Code> runs. A declared parameter
# named p_x additionally arrives as &g_p_x — 'g_' prefix, name verbatim.
FRAMEWORK_MACROS: dict[str, str] = {
    "g_caslib": "Caslib the analysis reads from.",
    "g_analysis_id": "Analysis instance id.",
    "g_analysis_short_id": "Short id — the suffix in promoted output table names.",
    "g_analysis_type": "Analysis type name — the prefix in those names.",
    "g_step_id": "Current step id.",
    "g_output_caslib": "Where outputs are promoted to. Normally QASANLOUT.",
    "g_dataselection_id": "Data selection id, when one is required.",
}

OUTPUT_CASLIB = "QASANLOUT"

# The bookends every CUSTOM step's code sits between.
CODE_SKELETON = """%afi_caf_loadmacros(/Products/SAS Analytics For IoT/CustomAnalyses/macros);
%afi_caf_preprocess(?g_cas, ?analysisID);

/* ---- analysis logic ---- */

{contract}
%afi_caf_postprocess;
"""

# Declaring the outputs is what makes {{.TOKEN}} resolve in the template:
# %afi_caf_postprocess promotes each table into QASANLOUT as
# <ANALYSIS_TYPE>_<member>_<SHORT_ID> and publishes the BARE MEMBER NAME as the
# step output param. So `%let g_output_table_1 = work.SAMPLE;` is what makes
# `{{.SAMPLE}}` render.
OUTPUT_CONTRACT = """%let g_num_output_tables = {n_tables};
{tables}
%let g_num_output_vars = {n_vars};
{vars}
"""

OUTPUT_TABLE_RE = re.compile(
    r"^\s*%let\s+g_output_table_(\d+)\s*=\s*([^;]+);", re.IGNORECASE | re.MULTILINE
)
OUTPUT_VAR_RE = re.compile(
    r"^\s*%let\s+g_output_var_(\d+)\s*=\s*([^;]+);", re.IGNORECASE | re.MULTILINE
)
# The explicit alternative: POST a name map to the step's outputParams endpoint.
# outputname -> {{.outputname}} is the whole mapping rule.
OUTPUT_PARAM_RE = re.compile(r'"outputname"\s*:\s*"([^"]+)"')


# --- output layer: BIRD XML --------------------------------------------------

# The smallest report the output layer accepts, verbatim from AUTOML. Use it as
# the placeholder for a step that computes but does not visualize: a step with
# no template at all is a different thing (no output tab), and an empty file
# fails to parse.
MINIMAL_TEMPLATE = """<?xml version="1.0" encoding="UTF-8"?>
<SASReport xmlns="http://www.sas.com/sasreportmodel/bird-4.53.0" label="Report 1"\
 features="promptModelV2" implicitInteractions="reportPrompt sectionPrompt sectionLink"\
 createdLocale="en_US" createdVersion="4.53.0" dateCreated="2025-07-15T19:18:44Z"\
 dateModified="2025-07-15T19:18:44Z" createdApplication="SAS Visual Analytics 2020"\
 nextUniqueNameIndex="7">
\t<View>
\t\t<Section name="vi6" label="Page 1">
\t\t\t<Body>
\t\t\t\t<MediaContainer target="mt2">
\t\t\t\t\t<ResponsiveLayout orientation="vertical" overflow="fit">
\t\t\t\t\t\t<Weights mediaTarget="mt5" unit="percent">
\t\t\t\t\t\t\t<Weight value="100%"/>
\t\t\t\t\t\t</Weights>
\t\t\t\t\t\t<Weights mediaTarget="mt4" unit="percent">
\t\t\t\t\t\t\t<Weight value="100%"/>
\t\t\t\t\t\t</Weights>
\t\t\t\t\t\t<Weights mediaTarget="mt3" unit="percent">
\t\t\t\t\t\t\t<Weight value="100%"/>
\t\t\t\t\t\t</Weights>
\t\t\t\t\t</ResponsiveLayout>
\t\t\t\t</MediaContainer>
\t\t\t</Body>
\t\t</Section>
\t</View>
\t<MediaSchemes>
\t\t<MediaScheme name="ms1">
\t\t\t<BaseStylesheetResource theme="light2025"/>
\t\t\t<Stylesheet><![CDATA[]]></Stylesheet>
\t\t</MediaScheme>
\t</MediaSchemes>
\t<MediaTargets>
\t\t<MediaTarget windowSize="default" scheme="ms1" name="mt2"/>
\t\t<MediaTarget windowSize="small" scheme="ms1" name="mt3"/>
\t\t<MediaTarget windowSize="medium" scheme="ms1" name="mt4"/>
\t\t<MediaTarget windowSize="large" scheme="ms1" name="mt5"/>
\t</MediaTargets>
\t<ExportProperties>
\t\t<Export destination="pdf">
\t\t\t<Property key="showCoverPage" value="true"></Property>
\t\t\t<Property key="showPageNumbers" value="true"></Property>
\t\t</Export>
\t</ExportProperties>
\t<History>
\t\t<Versions>
\t\t\t<Version key="4.53.0" lastDate="2025-07-15T19:18:44Z"/>
\t\t</Versions>
\t</History>
\t<SASReportState>
\t\t<View/>
\t</SASReportState>
</SASReport>"""

# The two attributes that carry a design-time table name, and the one that
# carries a column name. Tokenizing a report means rewriting these.
TABLE_SLOT_ATTRS: tuple[str, ...] = ("table", "label")
COLUMN_SLOT_ATTR = "xref"

# STANDARD types address their outputs positionally instead of by name.
POSITIONAL_TOKEN_RE = re.compile(r"^OUTPUTTABLENAME(\d+)$")

# Tokens the framework supplies to every template, whatever the analysis does.
# Identified by appearing across unrelated packages (CASSERVERNAME in 19 of the
# 34, LOCALE in 17) with nothing in any of their code publishing them.
AMBIENT_TOKENS: frozenset[str] = frozenset(
    {
        "CASSERVERNAME",
        "LOCALE",
        "REPORT_THEME",
        "ANALYSISNAME",
        "__ANALYSISNAME__",
        "ANALYSISID",
        "SHORTID",
        "USERTITLE",
        "USERSUBTITLE",
        "USERFOOTNOTE",
        "REPORTVAR",
    }
)

# For any token X the framework also offers these companions, derived from the
# column X names: its label, its SAS format, its description. 91 of the corpus's
# _DESC tokens have no declared base of their own, so the suffix is the rule.
COMPANION_SUFFIXES: tuple[str, ...] = ("_DESC", "_LABEL", "_FORMAT")

TEMPLATE_SUFFIX = "_vaoutput.template"


# --- guidance ----------------------------------------------------------------

GOTCHAS: tuple[str, ...] = (
    "A ?token in <Code> is substituted ONCE, case-sensitively, at its first "
    "occurrence — including inside a comment. Never name one in a comment.",
    "A {{.TOKEN}} with no producer renders a BLANK report and reports no error. "
    "Every token must come from a g_output_table_N/g_output_var_N declaration or "
    "an explicit outputParams POST.",
    "Token case must match between the SAS side and the template exactly.",
    "In BIRD XML, every <Weights> block's <Weight> count must equal its "
    "container's child count, for every media target. A mismatch renders blank.",
    "RESOLVEONUI=true is required on any lookup that interpolates another live "
    "form value; without it the lookup resolves server-side against a stale one.",
    "A cascading fetchPossibleValues needs a getChangedParamName() guard or it "
    "re-triggers itself.",
    "<Interactions> is model-level, not per-step. Scope with #ctx.getCurrentStep().",
    "The zip's top-level folder name must equal <Registration><Name>.",
    "The template filename comes from the STEP ID, not <TemplateID>: strip a "
    "trailing _DEFAULT and append _vaoutput.template.",
    "*.template files are Go templates, not XML — do not parse them as XML.",
    "Comparison operators inside a WhereCondition must be XML-escaped (&lt;&gt;).",
    "<Properties> and <UIGroup> are mandatory on every parameter, even empty.",
    "A macro variable caps at 64KB; write longer payloads to a file and %include.",
    "nextUniqueNameIndex must exceed every generated symbol number in the report.",
    "Step @order need not be contiguous, and steps do not chain declaratively — "
    "they chain at runtime through published output params.",
)

TOPICS: tuple[str, ...] = (
    "overview",
    "package",
    "registration",
    "parameters",
    "lookups",
    "containers",
    "interactions",
    "code",
    "output",
    "tokens",
    "gotchas",
)


def topic_index() -> dict[str, Any]:
    """The table of contents ``describe_caf_schema()`` returns with no arguments."""
    return {
        "topics": list(TOPICS),
        "analysis_types": sorted(ANALYSIS_TYPES),
        "key_groups": sorted(KEY_GROUPS),
        "display_controls": sorted(DISPLAY_CONTROLS),
        "hint": (
            "describe_caf_schema(topic='parameters') for the input layer, "
            "topic='tokens' for how a SAS output name becomes a {{.TOKEN}} in the "
            "report template (the part most often got wrong), topic='gotchas' for "
            "the silent-failure list. describe_caf_schema(control='STABLEPERIOD') "
            "documents one display control."
        ),
    }
