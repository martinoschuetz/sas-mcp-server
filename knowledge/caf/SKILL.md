---
name: sas-caf
description: Custom Analysis Framework (CAF) for SAS AIoT rules and concepts. Use when analyzing IoT data or building custom analytical pipelines in AIoT.
---
# Custom Analysis Framework (CAF) Authoring Rules

Rules for authoring SAS Analytics for IoT **analysis types** through the Tier 13 tools
(`src/sas_mcp_server/tools/caf.py`). A CAF package is unforgiving in a specific way: almost
everything that is wrong with one is **invisible until a user runs it**, and then it fails
silently — a blank report page, an empty picker, no error anywhere. These rules exist because
each of them was learned from a package that imported cleanly and did the wrong thing.

The full format reference lives outside this repo, in
`C:\Git\martinoschuetz\AIoT\custom_analysis\CAF_documentation.md`. What follows is only the
part an agent must hold while writing.

## 1. Read before you write

Call `describe_caf_schema()` for the index, then the topic you are about to write. The
vocabularies (`displayControl`, `dataType`, `KeyGroup`, `#ctx.*` methods, `<Property>` keys) are
frozen in `helpers/caf_registry.py`, extracted from 34 shipped packages. An unknown value does
not error on import; it degrades at runtime. So when authoring, stay inside them.

When *reading* a deployed type, treat them as a lower bound instead. Sweeping the 37 types on a
live deployment turned up one `KeyGroup` (`BATCH`) and three `displayControl` values
(`PQOPTIMIZATION`, `PQLINERCONSTRAINT`, `STABLEPERIODGRAPH`) that appear in no example package;
until they were added, the validator rejected types the platform itself ships. If
`validate_analysis_type_spec` rejects a value you took from an exported package, the registry is
likelier to be incomplete than the package wrong — say so rather than editing the package to fit.

When a format question can be answered by an example, answer it that way:
`export_analysis_type("<a SAS-shipped type>")` returns real `input.xml`. Copying a working
construct beats deriving one.

## 2. Token/producer symmetry is the whole name mapping

A report template reads `{{.TOKEN}}`. A token resolves from exactly one of:

1. an **output param** published by this step or an earlier one — `%let g_output_table_N` +
   `%afi_caf_postprocess`, or an explicit POST to `…/steps/{stepId}/outputParams`;
2. an **input parameter name** declared on the step;
3. an **ambient framework token** (`CASSERVERNAME`, `LOCALE`, `REPORT_THEME`, `REPORTVAR`,
   `__ANALYSISNAME__`, `USERTITLE`/`USERSUBTITLE`/`USERFOOTNOTE` — see
   `caf_registry.AMBIENT_TOKENS`);
4. a **companion suffix** on any of the above: `_DESC`, `_LABEL`, `_FORMAT`;
5. the positional aliases `OUTPUTTABLENAME1`…`OUTPUTTABLENAME29` (STANDARD types).

Anything else renders empty. Never hand-write the SAS tail — call `build_output_contract`,
which writes it and names the tokens it creates, then run `validate_analysis_type_spec` to
confirm both sides agree. The validator's "template token has no producer" is a blocking
error for a reason; do not pass `skip_validation=true` to get past it.

**The token is the bare member name, uppercased.** `%let g_output_table_1 = work.Filtered;`
publishes `{{.FILTERED}}`, not `{{.work.Filtered}}`. The libref says where the table is read
from, not what it is called downstream.

## 3. A table name lives in two attributes, not one

In BIRD XML every output table appears twice:

```xml
<DataSource ... label="{{.SAMPLE}}">
  <CasResource server="{{.CASSERVERNAME}}" library="QASANLOUT" table="{{.SAMPLE}}"/>
```

Tokenize **both**. Rewriting only `CasResource/@table` is the single most common hand-editing
mistake, and the report still loads — it just binds nothing. `templatize_va_report` does both;
prefer it over editing XML.

## 4. Build the output layer from a report that already works

Do not generate BIRD XML from scratch. The supported path, and the one the tools are shaped
around: build the report in Visual Analytics (or with Tier 3's `create_report`) against a real
run's output tables → `templatize_va_report(report_id, table_tokens=…)` → paste the result into
the step's `vaoutput_template`. A step that computes without visualizing gets the minimal legal
template automatically; leave `vaoutput_template` unset rather than inventing one.

## 5. Never invent a `#ctx` method

`<Interaction>` conditions and actions are Spring Expression Language against a `#ctx` root
object. `caf_registry.CTX_METHODS` holds the 29 methods observed across the corpus, with
counts. That list is the API. A misspelled method silently does nothing — the interaction just
never fires, and the form looks merely unhelpful rather than broken.

Two interaction hazards the validator warns about:

- **Self-retriggering cascade.** An interaction that fires on `P` and calls
  `fetchPossibleValues('P')` loops. The guard is
  `#ctx.getChangedParamName() != 'P'` in the condition — every shipped cascade has it.
- **Dangling `sourceParamName`.** Firing on a parameter that no longer exists is dead code, not
  an error; several shipped packages carry one. Clean it up in anything you author.

## 6. `RESOLVEONUI` and the one-selection-behind picker

A lookup whose URI or CAS filter interpolates another parameter's live value
(`{{getCurrentValue $.values "p_x"}}`) needs `<Property key="RESOLVEONUI">true</Property>`
inside **the lookup's** `<Properties>` — `LookupMetadata/Properties`, not the parameter's own.
All nine shipped uses of it sit there, and the validator only looks there. Without it the value is bound once, at form load, and the picker shows options
for the **previous** selection. Shipped packages get this wrong, which is why the validator
warns rather than blocks — but in new work, set it.

## 7. The `?token` substitution is a one-shot, comments included

The mid-tier replaces `?g_cas`, `?analysisID`, `?g_metadata`, `?limit`, `?append` and `?filter`
in the step's SAS code **once each, case-sensitively, at the first occurrence — including inside
a comment**. A `/* pass ?g_cas here */` above the real call consumes the substitution and the
actual code gets nothing. Do not mention these tokens in comments.

## 8. Package invariants

- The zip's top-level folder name **must** equal `<Registration><Name>`. `build_package`
  enforces it; do not construct the zip by hand.
- The template filename comes from the **step id**, not `<TemplateID>`: strip a trailing
  `_DEFAULT`, append `_vaoutput.template` (`caf.template_filename`).
- `<Properties>` and `<UIGroup>` are mandatory on every parameter even when empty.
- `input.xml` element order is fixed. Render it with `caf.render_input_xml`, never by string
  assembly.

## 9. Writes

`create_analysis_type` and `update_analysis_type` validate first and refuse to upload on
errors. `update_analysis_type` is a **whole-package replacement, not a merge** — export the
current package first if you mean to change part of it, and remember that analyses users
already created keep running against the new definition, so changing a step's outputs can break
their reports.

To withdraw a type, prefer `set_analysis_type_state(name, 'inactive')` (reversible, hides it
from users) over `delete_analysis_type`. Both activation and deactivation need an administrator.

**`create_analysis_type` may be refused whatever your permissions are.** On the reference
deployment, `POST /iotAnalysisModels/models` answers `403 "not authorized to execute this api
upsert embeded models"` for an identity that `POST /iotAnalysisModels/lookups` accepts (it
reaches validation, 400) — so the endpoint enforces something of its own beyond the
`/iotAnalysisModels/**` rules, which do grant writes. A refusal comes back as
`status: "forbidden"`. Report it; do not rebuild the spec, do not retry the other encoding, and
do not tell the user to go request a group until you have checked whether other writes to the
same service succeed for them.

## 10. References

- Format reference: `custom_analysis/CAF_documentation.md` (external to this repo)
- SAS docs: [Working with Custom Analysis Types](https://go.documentation.sas.com/doc/en/aniotcdc/default/aniotcat/titlepage.htm)
- SpEL: [Spring Expression Language](https://docs.spring.io/spring-framework/reference/core/expressions.html)
- Template language: [Go `text/template`](https://pkg.go.dev/text/template)

