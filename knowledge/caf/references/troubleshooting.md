# CAF Troubleshooting Playbook (Symptom → Cause → Fix)

Diagnostic matrix for SAS Analytics for IoT Custom Analysis Framework (CAF) packages (`[VERIFIED]` on SAS Viya 2026).

---

## 1. Package Import & Model API Errors (`/iotAnalysisModels/models`)

| Symptom | Root Cause | Exact Fix |
| :--- | :--- | :--- |
| `HTTP 400 errorCode 124206` during `POST` / `PUT` upload | A `<LookupMetadata id="..." name="..."/>` identifier exceeds **36 characters**. | Shorten every `lookup.id` and `lookup.name` in `spec.json` to `<= 36` chars (e.g., `IF_STABLE_PERIOD_LKP`). |
| `HTTP 403 "not authorized to execute this api upsert embeded models"` | Caller lacks administrative / `SAS Solutions` authorization required by `/iotAnalysisModels/models`. | Report `status: "forbidden"` to the user; do not mutate the spec or retry alternate encodings. |
| `HTTP 406 Not Acceptable` or `412`/`428 Precondition` on `PUT /iotAnalysisModels/models/{name}` | Missing vendor `Accept` header or stale/missing `If-Match` `ETag` header. | Use `update_analysis_type` (or `GET` model first with `Accept: application/vnd.sas.iot.analysis.model+json, application/json, */*`, extract `ETag`, and send `If-Match: <ETag>` on `PUT`). |
| `HTTP 423 Locked` on `DELETE /iotAnalysisModels/models/{name}` | At least one analysis instance created from this model exists in PostgreSQL. | Never delete models with live instances; update in-place via `update_analysis_type` (`PUT`) or hide from users via `set_analysis_type_state(name, "inactive")`. |
| Analysis Type uploaded (`201`/`202`) but missing from AIoT "New Analysis" dialog | Newly created types default to `inactive` (`activeFlag = false`), or user is filtering a different `KeyGroup`. | Call `set_analysis_type_state(name, "active")` (`PATCH .../models/{name}?state=active`) and verify `<KeyGroup>` (`ASSET` vs. `PRODUCT` vs. `PRD_ASSET`). |
| Added/removed steps via `PUT` but existing or new instances show old step structure | `<RevisionNo>` (`revision_no` in `spec.json`) was not incremented. | Increment `"revision_no"` in `spec.json`, rebuild, and `PUT` again. |

---

## 2. Browser UI Form, Picker & `STABLEPERIOD` Bugs

| Symptom | Root Cause | Exact Fix |
| :--- | :--- | :--- |
| **Step 2 or Step 3 saved parameters appear blank/unset when opening the step in the UI** (even though `GET /iotAnalysis/analyses/{id}` shows values saved in PostgreSQL!) | `"RESOLVEONUI": "true"` was set on a `SINGLESELECT`, `MULTISELECT`, or `DROPDOWN` lookup (`SM_ASSET_VARIABLE`, `INPUTVARS`, `TARGETVAR`). In `app.js` (`fetchPossibleValues`), all controls except `STABLEPERIOD` and `MULTIINPCHKTABLE` intersect `currentValues` with `/possibleValues` keys — returning the 6 metadata keys wipes `currentValues` to `[]`! | Remove `"RESOLVEONUI": "true"` (`"properties": {}`) from every `DROPDOWN`, `SINGLESELECT`, and `MULTISELECT` lookup. Keep `"RESOLVEONUI": "true"` **strictly** on `STABLEPERIOD` (and `MULTIINPCHKTABLE`) lookups. |
| **`DROPDOWN` shows literal options `RESOLVEONUI`, `LibraryName`, `TableName`, `KeyColumnName`, `ValueColumnName`, `WhereCondition`** (or `Method`, `URI`, `Headers`) | `"RESOLVEONUI": "true"` was set on a `DROPDOWN` lookup (`CASTABLE` or `RESTAPI`). | Set `"properties": {}` on the `DROPDOWN`'s `lookup` and refresh it via `#ctx.fetchPossibleValues('<PARAM>')` in `<Interactions>`. |
| **`STABLEPERIOD` interactive time-series plot is blank on step open** (or child `SINGLESELECT`/`DROPDOWN` fails to load on step open) | `<Interaction>` has `<Condition>#ctx.getCurrentStep() == '...'</Condition>`, OR `STABLEPERIOD` lookup is missing `"RESOLVEONUI": "true"`. On initial step open (`_paramChanged == false`), `#ctx.getCurrentStep()` returns `""`, blocking the interaction! | Set `"condition": ""` on step-unique lookup cascades (`SM_ASSET_VARIABLE`, `TARGETVAR`, `SCORE_ASSET_VARIABLE`, `SCORE_TARGET_VARIABLE`, `SEL_CASLIB`), and ensure `"RESOLVEONUI": "true"` is set on `STABLEPERIOD` lookups. |
| Browser tab freezes / infinite `/possibleValues` network loop on changing `SM_ASSET_VARIABLE` | Self-retriggering `<Interaction>`: `sourceParamName="SM_ASSET_VARIABLE"` unconditionally calls `#ctx.fetchPossibleValues('SM_ASSET_VARIABLE')`. | Guard the self-fetch inside the expression: `#ctx.getChangedParamName() != 'SM_ASSET_VARIABLE' ? #ctx.fetchPossibleValues('SM_ASSET_VARIABLE') : #ctx.getChangedParamName()`. |
| Programmatic `PUT /iotAnalysis/analyses/{id}` updates Step 1 but silently ignores Step 2 & Step 3 parameter changes | `sas-iot-analysis` only persists `inputParameters` on `steps[0]` of the `PUT` payload! | Use `update_analysis_step_parameters_tool` (which sends `{"steps": [matched_step]}` as `steps[0]`). |

---

## 3. SAS Compute & CAS Runtime Errors

| Symptom | Root Cause | Exact Fix |
| :--- | :--- | :--- |
| `%qas_getconnections` or `%anl_getanalysisattributes` fails with syntax error / literal `?g_cas` or `?analysisID` | `?g_cas` or `?analysisID` appeared earlier inside a `/* comment */`, consuming the single-shot mid-tier substitution. | Remove all literal `?g_cas`, `?analysisID`, `?g_metadata`, `?limit`, `?append`, `?filter` tokens from comments. |
| `ERROR: Invalid data set name` when promoting/saving per-asset ASTORE or output table | Table name in `QASAnlOut` exceeds SAS's **32-character** limit (e.g., `ISOLATION_IDCP_CH18B_AST2_A995BD6E` = 34 chars). | Shorten middle token and hash asset IDs > 8 chars to an 8-char CRC32 key (`ISOLATION_<KEY8>_M1_<shortId>` = 30 chars). |
| Step 1 re-run fails inside `%qas_cas_output_lifetime` / `accessControl.updSomeAcsTable` | Custom Step 2/3 tables in `QASAnlOut` either did not end strictly with `_&g_instance_nm` or left custom ACS rules / `.sashdat` files behind. | Ensure all `QASAnlOut` tables end with `_&g_instance_nm` and run the isolated `PROC CAS` pre-cleanup (`remACs=true` + `deleteSource`) at the top of Step 1. |
| `ERROR: Macro function %SCAN has too many arguments` on `INPUTVARS` or multi-window `STABLE_PERIOD` | Unquoted `&G_INPUTVARS.` or `&G_STABLE_PERIOD.` contains commas that SAS treats as `%scan` argument separators. | Always quote with `%superq`: `%scan(%superq(G_STABLE_PERIOD), &i., %str(,))`. |
| 3rd or 4th window in `STABLE_PERIOD` is truncated in Step 2 | Helper table truncated `param_value_txt` at `$100`. | Query `mfgapp.analysis_ins_step_input` directly via `PROC SQL`: `select coalesce(param_value_txt, '') into :G_STABLE_PERIOD trimmed`. |
| `ERROR: The function STRIP referenced by the %SYSFUNC ... has too few arguments` | Parameter is empty (e.g., optional `STABLE_PERIOD = ""`) or missing from `input.xml` parameter definitions. | Guard with `%length(%superq(G_STABLE_PERIOD)) = 0` (`%sysfunc(strip(%superq(VAR)))` only when non-empty, or check length after `%superq`). |

---

## 4. Visual Analytics Output Report Bugs

| Symptom | Root Cause | Exact Fix |
| :--- | :--- | :--- |
| Step status is `COMPLETED` (`0` SAS errors), but VA report shows "Data is not available" or blank charts | 1) Missing `outputParams` producer for a `{{.TOKEN}}`; 2) `DataSource/@label` was left hardcoded while only `CasResource/@table` was tokenized; or 3) CAS table was not `promote`d to global scope in `QASAnlOut`. | Run `validate_analysis_type_spec` (`0` blocking errors), verify both `DataSource/@label` and `CasResource/@table` use `{{.TOKEN}}`, and confirm `promote` in `PROC CASUTIL` / `%afi_caf_postprocess`. |
| Local Explainer TreeSHAP bar chart shows `_INTERCEPT_` or fails to cross-filter sensor series | Wrong `substr(_name_, pos)` offset when stripping `S_<TargetVar>_` prefix from `PROC ASTORE` `TREESHAP 1` output columns. | Compute `pos = length("S_<TargetVar>_") + 1` (e.g., `12` for `S__Anomaly_`) so `vname` equals the exact sensor name or `_INTERCEPT_`. |
