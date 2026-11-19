---
name: sas-caf
description: >-
  Domain playbook for authoring, validating, deploying, testing, and troubleshooting SAS Analytics for IoT (AIoT) Custom Analysis Framework (CAF) analysis types via the sas-viya-mcp server. Use whenever building or editing CAF packages (spec.json, input.xml, steps/*.sas, *_vaoutput.template, .zip), configuring UI controls and dynamic lookups (DROPDOWN, SINGLESELECT, MULTISELECT, STABLEPERIOD, NUMERICSTEPPER, RESTAPI, CASTABLE, RESOLVEONUI), writing SpEL #ctx <Interactions>, promoting CAS output tables in QASAnlOut, tokenizing Visual Analytics BIRD XML reports ({{.TOKEN}}), injecting analysis types into AIoT Analysis Types, or debugging blank UI parameters, empty pickers, or silent VA report failures.
metadata:
  version: "2.1.0"
  source: >-
    Tier 15 CAF MCP tools (caf.py, caf_helpers.py, caf_registry.py), sas-mcp-server v1.20.2 AIoT/Launcher/Folder tools, 38 deployed AIoT models (14 STANDARD + 3 ALERTS + CUSTOM corpus including SVDD_ASSET, ISOLATION_FOREST, MTS), AIoT React UI client bundle analysis (app.js & 4983.bundle.js), and live SAS Viya 2026 execution verification.
  mcp_server: sas-viya-mcp
---

# SAS Analytics for IoT — Custom Analysis Framework (CAF)

CAF packages define the **Analysis Types** users pick in SAS Analytics for IoT (`PRODUCT`, `ASSET`, `PRD_ASSET`, `ENTERPRISE`, `BATCH`). Each package bundles:
1. **Input Layer (`input.xml`):** Registration metadata, step definitions, form containers, parameter lookups (`RESTAPI`, `CASTABLE`, shared platform lookups, static values), embedded SAS compute code per step, and model-level SpEL `<Interactions>`.
2. **Output Layer (`<STEP_ID>_vaoutput.template`):** Go `text/template`-tokenized SAS Visual Analytics BIRD XML reports bound to CAS tables and scalar outputs published by each step.

Start by reading [`mcp_execution_rules.md`](mcp_execution_rules.md) — almost every CAF bug imports with HTTP `200`/`202` and fails **silently** at runtime (wiped UI parameters on step open, blank `STABLEPERIOD` charts, or empty Visual Analytics containers).

---

## Non-Negotiable CAF Rules (Summary)

1. **One Self-Contained Folder per CAF:** Author in `spec.json` + `steps/<STEP_ID>.sas` + `output/<STEP_ID>_vaoutput.template` + `build_package.py` (`templates/build_package.py`) — never hand-patch 3,500-line `input.xml` CDATA blobs.
2. **ZIP Internal Folder Must Equal `<Registration><Name>`:** `<Name>ISOLATION_FOREST</Name>` requires `ISOLATION_FOREST/input.xml` and `ISOLATION_FOREST/<STEP_ID>_vaoutput.template` inside the `.zip`.
3. **Token/Producer Symmetry (`{{.TOKEN}}`):** Every `{{.TOKEN}}` in `<STEP_ID>_vaoutput.template` must be published by that step (or an earlier step) via `%afi_caf_postprocess` (`build_output_contract`) or `POST .../steps/{stepId}/outputParams`, and **both** `DataSource/@label` and `CasResource/@table` must be tokenized (`templatize_va_report`).
4. **CAS Output Table Naming (`<= 32` Chars, `_&g_instance_nm` Strictly Last):** Every table promoted/saved in `QASAnlOut` must be uppercase, `<= 32` characters total, and end strictly with `_&g_instance_nm` (use deterministic `<= 8`-char CRC32 asset keys for per-asset ASTOREs).
5. **Self-Healing CAS Pre-Cleanup on Step 1:** Multi-step CAFs that write custom tables/`.sashdat` files in Steps 2+ must drop stale `*_${g_instance_nm}` tables (`remACs=true`) and `.sashdat` sources at the top of Step 1 while preserving `options sessref`.
6. **`RESOLVEONUI=true` Strictly on `STABLEPERIOD` (and `MULTIINPCHKTABLE`) Lookups Only:** **Never** set `RESOLVEONUI=true` on `DROPDOWN`, `SINGLESELECT`, or `MULTISELECT` lookups — in `app.js` (`fetchPossibleValues`), every control except `STABLEPERIOD` and `MULTIINPCHKTABLE` intersects `currentValues` with `/possibleValues` keys, so returning metadata rows wipes saved user selections on step open and renders raw metadata keys in `DROPDOWN`s!
7. **Never Guard Step-Open Cascades with `#ctx.getCurrentStep()`:** During initial step load (`_paramChanged == false`), `#ctx.getCurrentStep()` returns `""` in `app.js`, silently blocking `fetchPossibleValues(...)`. Keep `<Condition></Condition>` empty whenever `sourceParamName` is unique to its step.
8. **Lookup IDs `<= 36` Characters & Contiguous Step `order` (`1..N`):** `LookupMetadata/@id` and `@name` > 36 chars fail import with `HTTP 400 errorCode 124206`. Step `order` must be `1, 2, 3, ...` with no gaps.
9. **Defensive SAS Macro Quoting (`%superq` / `%nrbquote`) on Multi-Select & `STABLEPERIOD`:** Multi-select tags and multi-window `STABLEPERIOD` values arrive as comma-separated lists (`W1,W2,W3`). Always scan with `%scan(%superq(G_PARAM), &i., %str(,))` and read long `STABLE_PERIOD` / `SCORE_PERIOD` strings from `mfgapp.analysis_ins_step_input` to avoid truncation.
10. **`?token` First-Occurrence Substitution Trap:** `?g_cas`, `?analysisID`, `?g_metadata`, `?limit`, `?append`, and `?filter` are replaced **once** at their very first occurrence in `<Code>` — **including inside `/* comments */`**. Never mention them in header comments.
11. **Deploying & Updating Analysis Types:** `create_analysis_type` (`POST`) creates an inactive type; call `set_analysis_type_state(name, 'active')` to expose it in AIoT Analysis Types. Models with existing instances return `HTTP 423 Locked` on `DELETE`; update in-place via `update_analysis_type` (`PUT` with `If-Match: <ETag>`) and increment `revision_no` when adding/removing steps.
12. **Visual Analytics BIRD XML Hardening (Rule 11):** Omit `autoInteractionMode="oneWayFilter"` on `graphType="custom"` objects (wire explicit `<Interaction type="filter">` rules + dynamic `first` `<Prompt>` defaults), reset `<SASReportState><View/></SASReportState>`, use continuous `<SeriesPlot>` + `<TimeOpts>` instead of discrete `<LineChart>`, stay under the `250,000`-cell `sas-report-data` limit (`maxRows="250000" maxRowsBehavior="truncate"`, `detail="false"`), and drive high-frequency score charts from a 1-row/timestamp series table rather than $p\times$ transposed rows.
13. **Mandatory Live Smoke Test Before Done:** Create a test instance (`create_iot_analysis_tool`), set step parameters (`update_analysis_step_parameters_tool` — sends target step as `steps[0]`), run every step (`run_analysis_step_and_wait_tool`), verify **`0` `ERROR:` lines** (`get_iot_analysis_step_log_tool`), check CAS tables (`get_castable_data`), and verify `/possibleValues` UI retention.

---

## MCP Tool Routing

| Task | MCP Tools (`sas-viya-mcp`) |
| :--- | :--- |
| Learn CAF XML / JSON schema & controls | `describe_caf_schema` (`topic='overview'\|'parameters'\|'lookups'\|'interactions'\|'tokens'\|'gotchas'`, `control='STABLEPERIOD'`) |
| Inspect deployed or local `.zip` CAF models | `list_analysis_types`, `get_analysis_type`, `export_analysis_type`, `read_local_analysis_type_package`, `list_analysis_type_lookups`, `get_analysis_type_steps` |
| Author & statically validate CAF contracts | `build_output_contract`, `templatize_va_report`, `validate_analysis_type_spec` |
| Deploy, update, activate, or retire a type | `create_analysis_type`, `update_analysis_type`, `set_analysis_type_state`, `delete_analysis_type` |
| End-to-end live execution & log verification | `create_iot_analysis_tool`, `update_analysis_step_parameters_tool`, `run_analysis_step_and_wait_tool`, `get_iot_analysis_step_log_tool`, `get_castable_data`, `delete_iot_analysis_tool` |
| Search CAF knowledge topics & templates | `list_knowledge_domains`, `read_knowledge_topic(domain="caf", ...)`, `search_knowledge(domain="caf", ...)` |

---

## Topic References & Templates (Load on Demand)

- [`mcp_execution_rules.md`](mcp_execution_rules.md): Full 12-section authoring, deployment, UI, and runtime execution rules (`[VERIFIED]` / `[DOC]`).
- [`references/aiot_platform_and_etl.md`](references/aiot_platform_and_etl.md): AIoT platform architecture ("3 Ds" & Common Attribute mapping), `QASMartStore` star schema, batch `%afi_dataload` guardrails & parameter reference, Data Selection domain metadata & REST lifecycle, Launchers (`%qas_makelauncher` & `v1.20.2+` MCP guardrails), `IoTProjects` vs. `@myFolder` folder ACL rules, `Stability Monitoring`, and 4-layer Predictive Maintenance + Survival RUL workflow.
- [`references/anomaly_caf_design_and_patterns.md`](references/anomaly_caf_design_and_patterns.md): Production anomaly CAF design (`SVDD_ASSET`, `ISOLATION_FOREST`, `MTS_SIMPLE`, `MTS`), `VARSCREEN` elapsed-time/constant filtering, frozen `STDSTAT` & `THRESH_*`/`DMAX_*` graded severity, ridge-stabilized MTS, Wenig `MAX_AFTER` vs. `CoMuT`, and live-profiled SAS/CAS + VA performance patterns.
- [`references/ui_lookups_and_interactions.md`](references/ui_lookups_and_interactions.md): Browser client mechanics (`app.js` & `4983.bundle.js`), `RESOLVEONUI` behavior per control type, Go templates in lookups, and SpEL `#ctx` cascade & `Standard/`/`Alerts/` patterns.
- [`references/sas_cas_plumbing.md`](references/sas_cas_plumbing.md): Generation 1, 2, and 3 (`%anl_driver`) SAS compute plumbing, Step 1 CAS pre-cleanup (`remACs=true`), `.sashdat` auto-reload, `<= 32`-char CRC32 asset keys, and multi-window `STABLEPERIOD` parsing.
- [`references/va_output_templates.md`](references/va_output_templates.md): Visual Analytics BIRD XML templatization, dual-attribute `DataSource`/`CasResource` binding, TreeSHAP column alignment, Rule 11 hardening, and high-frequency rendering performance.
- [`references/troubleshooting.md`](references/troubleshooting.md): Symptom → Root Cause → Fix diagnostic matrix for import errors, UI bugs, SAS compute errors, VA BIRD XML / anomaly runtime failures, and AIoT Data Selection / Launcher / Folder / `423` REST errors.
- [`references/case_study_isolation_forest.md`](references/case_study_isolation_forest.md): Complete production walkthrough of `ISOLATION_FOREST` (plus `VARSCREEN`, frozen `THRESH_IF` severity, and companion `SVDD_ASSET`/`MTS_SIMPLE`/`MTS` notes).
- [`templates/build_package.py`](templates/build_package.py): Deterministic single-folder CAF builder and `--check` zero-drift validator.
- [`templates/gen2_single_step_skeleton.sas`](templates/gen2_single_step_skeleton.sas): Declarative Generation 2 (`%afi_caf_preprocess` / `%afi_caf_postprocess`) step template.
- [`templates/multistep_stableperiod_time_filter.sas`](templates/multistep_stableperiod_time_filter.sas): Reusable SAS macros for Step 1 pre-cleanup, `.sashdat` reload, 8-char asset keys, and multi-period `STABLEPERIOD` filtering.
