# SAS Analytics for IoT (AIoT) Platform, ETL, Data Selections & Predictive Maintenance

Architectural and operational guide to the SAS Analytics for IoT (AIoT) platform on SAS Viya 4 — covering the "3 Ds" lifecycle, the `QASMartStore` star schema, batch `%afi_dataload` ETL, Data Selections, Launchers, Stability Monitoring, and end-to-end Predictive Maintenance. Derived from the SAS AIoT & CAF Workshop KB (`Docu/AIOT_CAF.md`) and [CAF execution rules](../mcp_execution_rules.md).

---

## 1. Viya 4 Architecture, Solutions & "3 Ds" Lifecycle

SAS Analytics for IoT runs on SAS Viya 4 (Kubernetes microservices + CAS MPP in-memory grid + PostgreSQL `SharedServices`) across the **"3 Ds"** lifecycle:

1. **Data (Manage Data):** Batch ingestion via `%afi_dataload` into CAS (`QASMartStore` / libref `CASMART`) and PostgreSQL metadata (`AIoTPgMeta` / `mfgapp`), rejecting malformed records to `exceptions.csv`.
2. **Discovery (Develop Models):** Low/no-code AIoT Data Selections, Launchers, `Exploration`, `Stability Monitoring`, Visual Analytics, and Model Studio pipelines alongside SAS Studio / `PROC PYTHON` / `PROC CAS` / CAF.
3. **Deployment (Deploy Insights):** Model Manager (ASTORE, DS2, Python, ONNX versioning + champion/challenger), SAS Event Stream Processing (`ESP` + `ESM` edge/cloud streaming + ASTORE scoring), Grafana (live streaming alerts), and Visual Analytics / scheduled batch `%wrna_execute_batchjobs` (historical & static reporting).

### Common Attribute (`KeyGroup`) ↔ Solution Mapping

| Common Attribute (UI) | `KeyGroup` | Solution Code (`solution`) | Domain |
| :--- | :--- | :--- | :--- |
| **Assets** | `ASSET` | `AIOT` / `APA` | Asset telemetry & predictive maintenance |
| **Products** | `PRODUCT` | `FQA` | Field Quality Analytics (warranty, claims, labor/parts) |
| **Production assets** | `PRD_ASSET` | `PQA` | Production Quality Analytics & `EXPLORATION_PRD_ASSET` |
| **Batches** | `BATCH` | `PQA` | Batch manufacturing quality analytics |

---

## 2. `QASMartStore` / `CASMART` Sensor Star Schema

AIoT models asset telemetry around **Devices (`PAM_ASSET_DIM`)**, **Sensors (`PAM_TAG_DIM`)**, **Events (`PAM_EVENT_DIM`)**, **Measure Facts**, and **Event Facts**:

- **Dimensions:**
  - `PAM_ASSET_DIM`: `PAM_ASSET_DIM_RK`, `PAM_ASSET_ID`, `DEVICE_1_LVL..DEVICE_N_LVL`, `CURRENT_NUM`, `PROCESS_DTTM`.
  - `PAM_TAG_DIM`: `PAM_TAG_DIM_RK`, `TAG_ID`, `SENSOR_1_LVL..SENSOR_N_LVL`, `TAG_DEF_AGGREG_METHOD_CD`, `TAG_DEF_INTERPOL_METHOD_CD`, `TAG_COLUMN_NM`, `CURRENT_NUM`, `PROCESS_DTTM`.
  - `PAM_EVENT_DIM`: `PAM_EVENT_DIM_RK`, `EVENT_ID`, `EVENT_1_LVL..EVENT_N_LVL`, `EVENT_DEF_AGGREG_METHOD_CD`, `EVENT_COLUMN_NM`, `CURRENT_NUM`, `PROCESS_DTTM`.
- **Facts & Offloaded Partfiles:**
  - `PAM_ASSET_LOC_MEASURE_FACT`: `PAM_ASSET_DIM_RK`, `PAM_TAG_DIM_RK`, `MEASURE_DTTM`, `LOC_MEASURE_VALUE`, `PAM_DATE_DIM_RK`, `PAM_TIME_DIM_RK`, `PROCESS_DTTM`.
  - `PAM_ASSET_LOC_EVENT_FACT`: `PAM_EVENT_DIM_RK`, `PAM_ASSET_DIM_RK`, `EVENT_DTTM`, `EVENT_VALUE`, `PAM_DATE_DIM_RK`, `PAM_TIME_DIM_RK`, `PROCESS_DTTM`.
  - `PARTFILE_RANGE`: tracks large fact offloads (`<tablename>_savepartialtables=Y`) stored as `<tablename>_PARTFILE_<n>.sashdat`.
- **Pre-Aggregated UI Summary Tables:** `PAM_FACT_TAG_MEASURES_STATS`, `PAM_FACT_EVENT_MEASURES_STATS`, `PAM_VA_ASSET_STATS_SUMMARY`, `PAM_VA_TAG_STATS_SUMMARY`, `PAM_VA_EVENT_STATS_SUMMARY`, and `PREDEFINED_DATE`.
- **Reserved Column Names (Do NOT use in source CSVs/tables):** `PROCESS_DTTM`, `CURRENT_NUM`, `DATETIME_AIOT`, `PLOT_IN_EXPLORATION_AIOT`, `EVENT_FLAG_AIOT`, `VALUE`.

---

## 3. Batch ETL (`%afi_dataload`) Guardrails & Parameter Reference

`%afi_dataload(<path>/parameters.txt)` reads plain-text `name=value` assignments (valid lines never start with `*` or `/*`) and populates `CASMART`, PostgreSQL metadata (`config=Y`), and `exceptions.csv`. Call `%afi_access_casmart;` afterward to map `CASMART` in SAS Studio.

### Critical Operational Rules
1. **Admin Group Required:** Always run `%afi_dataload` under a user in the **AIOT Application Administrator** custom group; non-admin accounts can fail creating lookup metadata tables.
2. **SAS Drive Placement Constraint:** Parameter files and source CSVs stored in SAS Content **cannot** live under `/Public/` — place them under `/Products/...` (e.g., `/Products/SAS Analytics For IoT/...`) or a mounted OS path.
3. **Immutable `.sashdat` Partfiles (No Partial Deletes):** `incremental_load=Y` appends new `.sashdat` partfiles without editing existing ones. Deleting historical date slices requires `incremental_load=N` (full reset/reload); date subsetting belongs in Data Selections.
4. **Exception Codes (`exceptions.csv`):** Columns are `ExceptionDatetime, DataFile, RowNumber, ExceptionCodes, Data`. Key codes: `Dup_ID` (duplicate dimension/staging key), `Dttm_Miss` (missing/unparseable timestamp), `Dim_Lkup` (fact row referencing an unknown `SENSOR_ID`, `DEVICE_ID`, or `EVENT_ID`).

### Key Parameter File Directives

| Parameter | Purpose / Behavior |
| :--- | :--- |
| `solution` (`AIOT`\|`APA`\|`PQA`\|`FQA`), `etl=Y\|N`, `config=Y\|N`, `incremental_load=Y\|N` | Core solution scope and load/metadata mode (`config=Y` required on schema/column changes; triggers UI banner notification). |
| `<tbl>_csv_file` / `<tbl>_dataset`, `<tbl>_function=FACT\|DIM\|HIER` | Input path (`/Products/...` or OS path) or SAS/ACCESS libref.table, plus table role. |
| `<CODE>_type`, `<CODE>_aggregate=Y\|N`, `<CODE>_interpolate=Y\|N`, `<CODE>_agg_miss_method`, `<CODE>_int_miss_method` | Controls transposition aggregation (`MEAN`/`MIN`/`MAX`/`LAST`/`SUM`/`NONE`) and interpolation (`NONE`/`STEP`). Set `_aggregate=Y` + `_interpolate=N` for aggregation-only measures. |
| `<tbl>_savepartialtables=Y`, `<tbl>_size=<n>` | Offloads historical fact slices to compressed `.sashdat` partfiles, retaining roughly `1x..2x <tbl>_size` recent rows in CAS memory. |
| `<COL>_column`, `<COL>_function`, `<COL>_format`, `<COL>_informat`, `<COL>_rest` | Column roles (`DATETIME`, `VALUE`, `ID`, `COMMONID`, `TRANSPOSEID`, `TRANSNM`, `AGGREG`, `INTERPOL`, `NODE`, `PARENT`, `LEVEL`) and visibility restrictions (`0` = UI + app, `1` = hidden from DS UI, `2` = mart only, `3` = ignored). |
| `create_factcols_lookup=TRUE`, `GroupVars_Transposeddata`, `use_epoch_datetime`, `missing_char_val=?` | Fact-column distinct lookups (speeds Data Selection pickers), extra transpose grouping keys, Unix epoch divisor (e.g., `1000` for ms), missing character marker (`?`), optional `labels.csv` (`name,text_en,...,group_name=table_column_meta`), and level-skipping hierarchies (`<hier>_level_column`). |

---

## 4. Data Selections, Launchers, Workspace Folders & Standard Asset Tools

- **Data Selections (`/dataSelection/dataSelections`):** Store filter criteria in PostgreSQL without executing SAS code until Launch or Analysis run.
  - **Solution / Domain Metadata Differentiation (`[VERIFIED]`):** `list_data_selections_tool` (`GET /dataSelection/dataSelections`) returns only 9 summary fields (`id`, `name`, `description`, `owner`, `ownerDisplayName`, `createdBy`, `creationTimeStamp`, `creationType`, `category`) with **no `solution` or `dataModel` field** — standalone Asset/PdM and Product/FQA selections both report `creationType="DEFAULT"`, `category="SIMPLE"`. Always call `get_data_selection_details` and inspect `filterCriteria[*].componentTypeCode`:
    - **AIoT / Asset Telemetry (`ASSET` / `PRD_ASSET`):** `{ASSET, EVENTS, TAGS}`
    - **FQA / Product Warranty (`PRODUCT`):** `{PRODUCT, CLAIM, LABOR, PART, SSD, DTC}`
  - **Creation, Copy & Delete REST Guardrails (`[VERIFIED]`):**
    - `POST /dataSelection/dataSelections` (`create_data_selection_tool`) ignores any requested `creationType` and always stamps `"DEFAULT"`.
    - `POST /dataSelection/dataSelections/{id}/copy` (`copy_data_selection_tool`) rejects copying `EIENTERPRISE`/`EIANALYTIC`/`EITHRESHOLD` child bookmark selections unless `creationType` matches; when combining selections (`combine_data_selections_tool`), always pass a standalone `DEFAULT`/`ADHOC` selection first as `base_ds_id`.
    - `DELETE /dataSelection/dataSelections/{id}` returns `HTTP 423 Locked` (`errorCode 76003`) whenever any Launcher or Analysis references the selection. Enumerate dependents first and delete bottom-up (`child analyses -> launchers -> data selection`).
  - **UI Value Exclusion Trap:** Unless forming a negative number, filter values starting with `@`, `=`, `+`, `-`, or `|` are treated as **exclusions**.
  - **Predefined Date Anchoring:** Predefined intervals (e.g., `Last 90 days`) anchor against the **maximum date present in the fact tables**, not wall-clock today.
  - **Ownership Transfer Reset:** Changing Data Selection or Launcher owner resets Launcher status from `Completed` to `Saved` (requiring rerun). Running a Data Selection executes single-step child analyses, whereas multi-step CAFs require per-step interactive inputs.
- **Launchers (`%qas_makelauncher` / `/dataSelection/.../launches`):** Materialize filtered (and optionally periodicity-transposed with `Step` interpolation and `Mean`/`Max`/etc. aggregation) ABTs into `CASUSER` (`In-memory` vs. `Historical` partfiles) or target apps (`CAS`, `VA`, `SASStudio`, `ModelStudio`, `CSV`). CAF steps can also invoke `%qas_makelauncher` programmatically.
  - **Mandatory Launch Parameters (`[VERIFIED]`):** `launch_data_selection_tool` (`POST /dataSelection/dataSelections/{id}/launches`) returns `HTTP 400 errorCode 76010` (`"Column information needs to be passed..."`) if `launch_columns` / `launch_column_tables` are omitted. Pass `launch_key_dim="ASSET"` + `transpose_flag=1` (with periodicity) for sensor series or `launch_key_dim="PRODUCT"` + `transpose_flag=0` for row-level FQA cohorts, always supply an explicit `<= 32`-char `[A-Za-z0-9_]` `table_name` (avoiding auto-generated `DS_<id>` orphans), and poll completion via `jobId` (JES job UUID) rather than `id` (launcher record UUID).
  - **Listing & Deletion Quirks (`[VERIFIED]`):** `list_launchers_tool` (`GET /dataSelection/launches`) returns a **tenant-wide `count`** while permission-filtering `items` to the caller (`len(items) < limit` marks end-of-list), and serializes `transposeFlag` as boolean `true`/`false` on list vs. string `"1"`/`"0"` on `get_launcher_details_tool`. `DELETE` only works on the cohort-scoped route `/dataSelection/dataSelections/{selection_id}/launches/{launch_id}` (`delete_launcher_tool`).
- **Projects, Folders & Analysis Lifecycle (`IoTProjects` vs. `@myFolder`, `[VERIFIED]`):**
  - **Never call `create_folder_tool` under `/folders/folders/IoTProjects`:** Viya creates a folder with broken ACLs that immediately returns `HTTP 403 Forbidden` even to its creator. Always use `create_project_tool` (`<= 36`-char name) for AIoT projects in `IoTProjects` (list with `limit=200` so shared containers `Emerging Issue`, `OnDemand`, `Threshold` are not truncated past item 20), and create custom folders exclusively under `@myFolder`.
  - **Folder Members:** Default `add_folder_member_tool` to `member_type="reference"` (`"child"` returns `HTTP 409 Conflict` when pointing at live analyses or Data Selections); pass the **member entry ID** (from `/folders/folders/{id}/members`) to `remove_folder_member_tool`, not the target object's UUID.
  - **Analysis Step IDs & `423` Locks:** `POST /iotAnalysis/analyses` (`create_iot_analysis_tool`) omits `"steps"` in its `201`/`200` payload — call `get_iot_analysis_details_tool` first to retrieve `steps[0].stepId` before calling `update_analysis_step_parameters_tool`. `DELETE /iotAnalysis/analyses/{id}` returns `HTTP 423 Locked` while `status == "RUNNING"`; poll `get_iot_analysis_run_status_tool` to terminal state before deleting, and use paged/filtered `list_iot_analyses_tool` (`sas-mcp-server v1.20.2+`) rather than assuming a 10-item unpaged list covers the tenant.
- **Standard Asset/PRD_ASSET Built-Ins:**
  - `Exploration` (`EXPLORATION_PRD_ASSET`, `3` params): Telemetry & event timeline visual triage capped via `MAXOBS_SENSOR` (default `40,000`, `1..30,000` recommended) and `MAXOBS_EVENT` (`3,000`), switching between CAS memory (`QUERY_ONLY_CAS=Y`) and historical (`N`).
  - `Stability Monitoring` (`STABILITY_ASSET`, 4 steps): `1)` Periodicity/aggregation/transformation → `2)` Interactive `STABLEPERIOD` brush → `3)` `REG` / `ARIMA` holdout comparison (`RMSE`/`MAPE`) → `4)` Scoring with 4 Western Electric / Nelson violation tests (1 point outside band; 7 same side of predicted; 6 trending; 14 alternating).
  - `Automatically Update Output` (`AUTOUPDATE`): Flags saved analyses for batch re-execution via `%wrna_execute_batchjobs` after incremental ETL loads.

---

## 5. End-to-End 4-Layer Predictive Maintenance Blueprint

When architecting full predictive maintenance workflows in AIoT (`Docu/AIOT_CAF.md` §5):

1. **Layer 1 — Anomaly Detection:** Train RBF `PROC SVDD` (or `ISOLATION_FOREST` / `MTS_SIMPLE`) on healthy `STABLEPERIOD` sensor telemetry (`QASAnlOut` / Model Manager ASTORE). Use `_SVDDDISTANCE_` as a health feature.
2. **Layer 2 — Pending Failure Classification:** Engineer **48-hour pre-failure target windows** (`comp1..comp4`) combining smoothed telemetry (`PROC EXPAND` WMA/EWMA/MovRange), weekly error counts, and `SVDD_Dist`; train Model Studio Forest/GB champions and register DS2 + ASTORE models in Model Manager.
3. **Layer 3 — Real-Time Streaming (`SAS ESP`):** Score incoming telemetry + SVDD + component classifiers in continuous query (`cq1`), apply **persistence windows** (e.g., 5 hours) and **alert latching** (e.g., 24-hour suppression per `MachineID`/component) to prevent alert fatigue, and stream live alerts to Grafana.
4. **Layer 4 — Remaining Useful Life (`RUL`):** Progress from Kaplan–Meier survival curves (handling maintenance censoring) → parametric Weibull/Lognormal → Cox PH → Multinomial Logistic Regression with cubic splines over daily telemetry ABTs surfaced in VA heatmaps.
