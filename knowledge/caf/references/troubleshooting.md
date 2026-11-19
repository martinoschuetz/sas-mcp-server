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
| Step status is `COMPLETED` (`0` SAS errors), but VA report shows "Data is not available" or blank charts | 1) Missing `outputParams` producer for a `{{.TOKEN}}`; 2) `DataSource/@label` was left hardcoded while only `CasResource/@table` was tokenized; 3) CAS table was not `promote`d to global scope in `QASAnlOut`; or 4) `maxRowsBehavior="noData"` exceeded VA's 250,000-cell ceiling (`dataTruncatedToNothing`). | Run `validate_analysis_type_spec` (`0` blocking errors), verify both `DataSource/@label` and `CasResource/@table` use `{{.TOKEN}}`, confirm `promote`, trim `MultidimensionalDataDefinition` columns (`<= 3`), and set `maxRows="250000" maxRowsBehavior="truncate"`. |
| VA custom graph (`graphType="custom"`) ignores asset/date filter or locks to a stale asset (`'KaHA231D'`) | `autoInteractionMode="oneWayFilter"` does not work on custom graphs, or exported `<SASReportState>` contains hardcoded `<PromptState>` values. | Remove `oneWayFilter`, wire explicit `<Interaction type="filter">` rules with `PAM_ASSET_ID` in slider & graph + dynamic `first` defaults on `<Prompt>` (never on `<NumericRangeConstraint>`), and reset `<SASReportState><View/></SASReportState>`. |
| `sas-report-images` returns `HTTP 500` / `EOF` on dense time-series chart | Discrete `<LineChart>` (`<XAxisOpts type="discrete">`) treats `45k+` timestamps as string categories. | Replace with continuous-time `<SeriesPlot connectOrder="xaxis">` + `<TimeOpts>`. |
| VA tabs freeze browser or generate `4+ MB` / `92k`-line SVGs | Tab 1 runs multiple queries against $p\times$ transposed `TS_TRANS`, `ComboBox` loads `45k` timestamps, or explainer overlays draw `45k` `<ScatterPlot>` circles + `display="ALL"` markers. | Drive Tab 1 from a 1-row/timestamp series table, delete dead `<DataDefinition>`s inside `synchronized` blocks, omit `display="ALL"` markers on dense `<SeriesPlot>`s, and cap/replace 45k-point scatter & `ComboBox` queries. |
| Local Explainer bar chart shows `_INTERCEPT_` or clicking a bar wipes/restricts the time axis | Wrong `substr(_name_, pos)` offset stripping `S_<TargetVar>_`, or `dm372` / `ve364` still maps `DATETIME` (`bi343 -> bi8`) in bar-to-scatter filtering. | Compute exact `pos = length("S_<TargetVar>_") + 1`, exclude `_INTERCEPT_` before CAS load (or filter in `dd365`), and remove `DATETIME` from `InternalDataSourceMapping` & `sourceInteractionVariables` so clicks filter strictly on `(vname -> _NAME_, PAM_ASSET_ID)`. |
| Score saturates at ceiling immediately outside `STABLE_PERIOD` | Elapsed-time counter/odometer (`\|corr(x,t)\| >= 0.90`, e.g. `RH_HRS`) or constant training tag (`TSP_DEGC`) entered training, or Step 2 skipped `STDSTAT` standardisation on multi-scale units. | Run pre-training `VARSCREEN` (`SCREEN_MIN_KEEP=2`), compute frozen `STDSTAT` inside `STABLE_PERIOD` (re-applying via `method=in(...)` in Step 3), and freeze Step 2 `THRESH_*` + `DMAX_*` (`WARN_RUNLEN >= 1`). |

---

## 5. AIoT Workspace, Data Selection, Launcher & Folder REST Errors

| Symptom | Root Cause | Exact Fix |
| :--- | :--- | :--- |
| `HTTP 400 errorCode 76010` (`"Column information needs to be passed..."`) on `launch_data_selection_tool` | `launch_columns` and `launch_column_tables` were omitted on `POST /dataSelection/dataSelections/{id}/launches`. | Always pass explicit `launch_columns`, `launch_column_tables`, `launch_key_dim` (`"ASSET"` or `"PRODUCT"`), `transpose_flag` (`1` or `0`), and a `<= 32`-char `[A-Za-z0-9_]` `table_name`; poll `jobId` (not `id`). |
| `HTTP 400 errorCode 76250` on `create_iot_analysis_tool` (or `400 Bad Request` on EW analysis creation) | Standard/custom analysis routed to an Alert container (or Alert/EW model routed to a regular project instead of `onDemandContainer`/`thresholdContainer`/`emergingIssueContainer`), OR an `EIENTERPRISE` child bookmark DS was passed to a root EW model. | Route `STANDARD`/`CUSTOM` models to a project `folderId` in `IoTProjects`, route `ALERTS` models to their dedicated container with a standalone `DEFAULT`/`ADHOC` root Data Selection, and verify Data Selection domain compatibility (`{ASSET, EVENTS, TAGS}` vs. `{PRODUCT, CLAIM, ...}`) via `get_data_selection_details`. |
| `HTTP 403 Forbidden` immediately after creating a folder under `/folders/folders/IoTProjects` | `create_folder_tool` inside `IoTProjects` creates a raw folder with broken Viya ACLs locked even to its creator. | Never call `create_folder_tool` under `IoTProjects`. Use `create_project_tool` (`<= 36` chars) for AIoT projects in `IoTProjects`, and use `@myFolder` for custom user folders. |
| `HTTP 409 Conflict` on `add_folder_member_tool` | `member_type="child"` was passed for an existing analysis or Data Selection URI that already belongs to a container/service. | Pass `member_type="reference"` when adding existing AIoT objects to `@myFolder` folders; pass the **member entry ID** (not the target object UUID) to `remove_folder_member_tool`. |
| `HTTP 423 Locked` (`errorCode 76003`) on `delete_data_selection_tool` or `delete_iot_analysis_tool` | For a Data Selection, at least one Analysis or Launcher still references it; for an Analysis, its execution status is still `RUNNING`. | For `RUNNING` analyses, poll `get_iot_analysis_run_status_tool` until terminal and retry delete once. For Data Selections, enumerate dependent child analyses and launchers first and delete bottom-up (`child analyses -> launchers -> DS`). |
| `Step <id> not found` or empty `steps` immediately after `create_iot_analysis_tool` | `POST /iotAnalysis/analyses` omits `"steps"` in its creation response. | Call `get_iot_analysis_details_tool(analysis_id)` right after creation to read `steps[0].stepId` before calling `update_analysis_step_parameters_tool`. |
| `list_launchers_tool` loops forever on pagination, or `DELETE /dataSelection/launches/{id}` returns `404`/`405` | `GET /dataSelection/launches` returns a tenant-wide `count` while permission-filtering `items` to the caller; top-level `/launches/{id}` does not support `DELETE`. | Stop paging as soon as `len(items) < limit` (never `offset < count`), and always delete via cohort-scoped `delete_launcher_tool(selection_id, launch_id)`. |
| SAS job fails in `%wrna_calcperiods` with `ERROR: Required operator not found in expression: . - 4` | `AIoTPgMeta.TABLE_META_PG.last_data_dttm` is `NULL`/missing after metadata reload. | Check `TABLE_META_PG.last_data_dttm` first when reading step logs (`first ERROR:` line, not trailing cascade errors) and ask an administrator to populate `last_data_dttm` via `%afi_dataload` / metadata refresh. |
