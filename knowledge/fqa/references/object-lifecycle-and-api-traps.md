# Viya REST & MCP Object Lifecycle, Governance & API Traps (`[VERIFIED]`)

Live-verified REST API and MCP tool rules across all five SAS Field Quality Analytics (FQA) / Analytics for IoT (AIoT) workspace object families (`sas-mcp-server` `v1.20.2+` on SAS Viya 2026). Every behavior below was measured directly against live Viya endpoints (`/dataSelection`, `/iotAnalysis`, `/iotAnalysisModels`, `/folders`, CAS `QASMartStore` / `QASANLOUT` / `AIoTPgMeta`).

---

## 1. Data Selections (`/dataSelection/dataSelections`)

1. **Differentiating FQA vs. Non-FQA AIoT Data Selections (`filterCriteria[*].componentTypeCode`):**
   - **List endpoint (`GET /dataSelection/dataSelections` / `list_data_selections_tool`) has NO `solution`, `dataModel`, or `mart` tag:** Every summary item exposes only `id`, `name`, `description`, `owner`, `ownerDisplayName`, `createdBy`, `creationTimeStamp`, `creationType`, and `category`.
   - **List-time signal:** `creationType` $\in$ `{"EIENTERPRISE", "EIANALYTIC", "EITHRESHOLD"}` proves an FQA Early-Warning selection. However, standalone user-created FQA selections and non-FQA Predictive Maintenance / Sensor / Asset selections share identical list metadata (`creationType: "DEFAULT"`, `category: "SIMPLE"`).
   - **Detail-time domain classifier (`get_data_selection_details`):** Inspect `filterCriteria[*].componentTypeCode` (and `component`):
     - **FQA domains:** `PRODUCT`, `CLAIM`, `LABOR`, `PART`, `SSD`, `DTC` (often using `%wrna_calcperiods(p_dateVarName=g_dwLstRfrshDt,p_period=L<n>Y|M|Q)`).
     - **Non-FQA AIoT / PdM / Sensor domains:** `ASSET` (`DEVICE_TYPE`, `MODEL`), `EVENTS` (`PAM_EVENT_ID`, `EVENT_DTTM`), `TAGS` (`TAG_ID`, `MEASURE_DTTM`).
     - **Preflight rule:** Always refuse FQA SQL queries, FQA native analyses, and FQA project/launcher creation on `NON_FQA_IOT` cohorts (`ASSET`/`EVENTS`/`TAGS`) read-only before executing writes or compute jobs. (`DEFAULT` cohorts with empty `filterCriteria` carry no solution marker in DS JSON alone.)
2. **`POST /dataSelection/dataSelections` (`create_data_selection_tool`) Ignores `creationType`:**
   - Creating a standalone Data Selection directly always returns `creationType: "DEFAULT"`, `category: "SIMPLE"` even when `creation_type="ADHOC"` is requested. Always read `creationType` back from the response rather than assuming the requested value.
3. **`POST .../copy` & `combine_data_selections_tool` `EIENTERPRISE` `400 Bad Request` Trap:**
   - Calling `/dataSelection/dataSelections/{id}/copy` on an `EIENTERPRISE` child Data Selection without `creationType: "EIENTERPRISE"` fails with `HTTP 400 Bad Request`.
   - When combining multiple Data Selections via `combine_data_selections_tool(base_ds_id, additional_ds_ids, ...)`, **always order a standalone `ADHOC` or `DEFAULT` Data Selection first as `base_ds_id`** ahead of any `EIENTERPRISE` / `EIANALYTIC` / `EITHRESHOLD` child Data Selection regardless of user input order.
4. **`HTTP 423 Locked` (`errorCode 76003`) on `DELETE`:**
   - Viya blocks `DELETE /dataSelection/dataSelections/{id}` while any Analysis or Launcher references the Data Selection.
   - Build a read-only dependency graph first (project folder members + `list_iot_analyses_tool(data_selection_id=...)` + `list_launchers_tool(selection_id=...)`). When cascade deletion is approved, delete bottom-up: **child analyses $\rightarrow$ launchers $\rightarrow$ data selection**. Never use `force_delete_fqa_object_tool` to bypass colleague-owned dependents.
5. **Restart-Proof Undo Provenance:**
   - Viya Data Selection JSON carries no `copiedFrom` parent link (`additionalAttributes` only holds `parentAnalysisId` on EI children). Stamp `, base_ds=<base_uuid>` inside the provenance footer of copied Data Selections so undo/reconstruction can recover the base cohort across sessions.

---

## 2. Launchers (`dataSelectionLaunch` — `/dataSelection/launches`)

1. **MCP Lifecycle Surface (`v1.20.2+`):**
   - Read: `list_launchers_tool(selection_id=..., filter_query=..., sort_by=...)`, `get_launcher_details_tool(launch_id, selection_id=...)`.
   - Create / Launch: `launch_data_selection_tool` / `launch_data_selection_and_wait_tool` (`launch_app_name` $\in$ `{"CAS", "VA", "SASStudio", "ModelStudio", "CSV"}`).
   - Delete: `delete_launcher_tool(selection_id, launch_id)` — **only** the cohort-scoped path `DELETE /dataSelection/dataSelections/{selection_id}/launches/{launch_id}` accepts `DELETE` (top-level `/dataSelection/launches/{id}` rejects `DELETE`).
2. **Mandatory FQA Launch Payload (`HTTP 400 errorCode 76010`):**
   - Server/API defaults (`AIOT_LAUNCH_KEY_DIM="ASSET"`, `transpose_flag=1`, empty columns) are built for sensor telemetry and **fail or mis-key FQA cohorts**:
     - Always pass `launch_key_dim="PRODUCT"` and `transpose_flag=0` for FQA root-cause/claim tables.
     - Always pass explicit `launch_columns` and `launch_column_tables` (e.g. the 11 standard FQA columns across `PRODUCT` and `CLAIM`); omitting them fails with `400 errorCode 76010: "Specify the columns for the data selection launch."`
   - A launch response returns both the launcher's `id` and the compute job's `jobId` — poll **`jobId`** (never `id`) with `get_job_status`.
3. **Governed `table_name` (`<= 32` Chars, `[A-Za-z0-9_]`) Prevents Orphan `DS_<id>` Tables:**
   - Always pass an explicit CAS-safe `table_name` (`<= 32` characters, `[A-Za-z0-9_]`) to `launch_data_selection_tool`. Omitting `table_name` defaults to `DS_<selection_id>`, creating unprefixed launches that prefix-scoped governance guards cannot later clean up.
4. **Permission-Filtered Collection vs. Global `count` Trap:**
   - `GET /dataSelection/launches` (`list_launchers_tool` without `selection_id`) returns a **tenant-wide `count`** (e.g. `27`) while filtering `items` to only those visible to the calling identity (e.g. `9` items for `limit=10`). Treat `len(items) < limit` as the end of reachable items — never loop pagination until `count` is reached.
5. **`transposeFlag` Wire-Type Split:**
   - Collection `GET .../launches` serializes `transposeFlag` as boolean `true`/`false`, whereas single-item `GET /dataSelection/launches/{id}` serializes it as string `"1"`/`"0"`. Always normalize truthiness (`v in (True, 1, "1", "true", "TRUE")`), never `v is True`.

---

## 3. Standard & Early-Warning Analyses (`/iotAnalysis/analyses`)

1. **Whole-Collection Paging & Filtering on `list_iot_analyses_tool` (`v1.20.2+`):**
   - Pre-`v1.20.2` builds returned only the first 10 analyses of the tenant (`SVDD_ASSET` / `EXPLORATION_ASSET` often hid all `EIENTERPRISE_PRODUCT` runs). `v1.20.2+` supports `start`/`limit` paging and server-side scanning filters (`model_name`, `data_selection_id`, `search`, `created_by`, returning `scanned_count` and `tenant_total`).
   - **Project node visibility:** Completed child analysis nodes inside an FQA project can disappear from `/iotAnalysis/analyses` (`404 errorCode 76200` ~2 min after completion on some project templates) while remaining visible in `list_folders_and_projects_tool(folder_id=<project_folder_id>)`. Always enumerate project folders when checking a project's nodes or DS dependents.
2. **Early-Warning System Container Rule (`HTTP 400 errorCode 76250`) & Root-DS Requirement (`F-2s1-4`):**
   - `create_iot_analysis_tool` for the 3 `ALERTS` models **fails with `400 errorCode 76250` on regular project folders** (and `400` if `folder_id` is omitted). Route each model strictly to its Viya system container:
     - `EIANALYTIC_PRODUCT` (**On Demand**) $\rightarrow$ `folder_id="onDemandContainer"`
     - `EITHRESHOLD_PRODUCT` (**Threshold**) $\rightarrow$ `folder_id="thresholdContainer"`
     - `EIENTERPRISE_PRODUCT` (**Emerging Issues**) $\rightarrow$ `folder_id="emergingIssueContainer"`
     *(Note: the `POST` response reports `folderID: null`, while `list_folders_and_projects_tool` on the container lists the created member.)*
   - **Root-DS preflight (`F-2s1-4`):** Creating a root `On-Demand`, `Threshold`, or `Emerging Issues` analysis on an `EIENTERPRISE` / `EIANALYTIC` / `EITHRESHOLD` child bookmark Data Selection fails with `400 Bad Request`. Require a standalone `DEFAULT` or `ADHOC` root Data Selection.
3. **`POST` Omits `"steps"` & `PUT` Requires `steps[0]` + `If-Match` (`428 Precondition Required`):**
   - `POST /iotAnalysis/analyses` (`create_iot_analysis_tool`) omits `"steps"` in its immediate JSON response. Call `get_iot_analysis_details_tool` first to read `steps[0].id` before calling `update_analysis_step_parameters_tool` (which sends the target step as `steps[0]` with `If-Match: <ETag>`).
   - Across the 3 EW models, `PUT /iotAnalysis/analyses/{id}` can return `428 Precondition Required`; to clone an existing EW definition onto a new Data Selection, use `copy_iot_analyses_tool` (`POST /iotAnalysis/analysisActions/copies` with `{version, resources:[...]}` and `Accept: application/json`).
4. **Deleting Running vs. Completed Analyses (`423` & `404`):**
   - Deleting a `RUNNING` analysis returns `HTTP 423 Locked` — poll `get_iot_analysis_run_status_tool` until it reaches a terminal state, then retry `delete_iot_analysis_tool` once.
   - Deleting a completed analysis can return `HTTP 404 Not Found` even though Viya carries out the deletion — treat `404` on delete as removed and verify via folder listing.
5. **Dynamic `shortId` Output Resolution & 3D WUMKR Fallback:**
   - Resolve `shortId` at runtime from `get_iot_analysis_details_tool` (`EIENTERPRISE_WMEXT_<shortId>`, `EIENTERPRISE_WUMKR_<shortId>`). Never hardcode hashes; ~62% of hex `shortId`s start with digits `0`–`9` (supported by `_validate_sas_identifier(..., allow_leading_digit=True)` in `v1.20.1+`).
   - On tenants where `_DETAILS_` tables are not materialized, 3rd-time-dimension sales-lag breaches live directly in `QASANLOUT.EIENTERPRISE_WUMKR_<shortId>`: `BUILD_PERIOD` ($i$), `SALETOCLAIMMONTHCOUNT` ($j$), `BUILDTOSALEMONTHCOUNT` ($k$), `Sijk` (actual count) vs. `cijk` (critical value), keyed by `uniq_dh` / `uniq_de`.

---

## 4. Projects, Folders & Folder Members (`/folders/folders`)

1. **Project Name Length Cap (`<= 36` Chars, `400 errorCode 76250`):**
   - `create_project_tool` rejects project names longer than **36 characters** with `400 Bad Request` (descriptions up to ~900 chars with UTF-8 symbols are accepted). `delete_project_tool` deletes the project and its backing folder while leaving referenced Data Selections intact.
2. **CRITICAL `IoTProjects` Child-Folder `403 Forbidden` ACL Trap:**
   - Never call `create_folder_tool` with `parent_folder_uri="/folders/folders/IoTProjects"`. Plain Viya folders created under `IoTProjects` inherit `sas.iotAnalysis` container ACLs and **immediately return `403 Forbidden` on `GET`, `/members`, `createChild`, and `DELETE` even to their creator** (requiring a Viya admin to remove).
   - Use `create_project_tool` for projects in `IoTProjects`, and scope all user/agent folder trees (`create_folder_tool`, `delete_folder_tool(recursive=...)`) strictly under **`@myFolder`**.
3. **Folder Members (`add_folder_member_tool` / `remove_folder_member_tool`) — Default to `reference` (`409 Conflict`):**
   - Viya allows only **one** owning `child` folder per object (e.g. a newly copied Data Selection is already a `child` of the caller's `My Folder`), so adding it elsewhere with `member_type="child"` fails with `HTTP 409 Conflict`. Always default to **`member_type="reference"`** (URI shortcut).
   - `remove_folder_member_tool(folder_id, member_id)` requires the **folder member entry ID** from `list_folders_and_projects_tool`, **not** the underlying Data Selection or Analysis UUID.
4. **`IoTProjects` >20-Item Pagination Cutoff & Service Account Visibility:**
   - `list_folders_and_projects_tool` defaults to `limit=20`. Once `IoTProjects` exceeds 20 projects, system containers (`Emerging Issue`, `OnDemand`, `Threshold`, `AIoTAnalyisVAOuputReports`) can fall off Page 1 — pass `limit=200` when resolving system containers.
   - Service accounts (such as `ram-app`) only see shared `IoTProjects` containers and projects they own/are shared on, not individual human users' private folders.

---

## 5. Lifecycle Monitoring, CAPA Verification & ETL Health Diagnostics

1. **Proactive Launch / Change Monitoring (`BP 11` + `BP 3/4`):**
   - Compare launch vs. predecessor baseline cohorts at **matched early-life Time-in-Service** (`30 / 60 / 90 / 120` days), strictly separating mature launch builds (`exposure_days >= tis_days`) from right-censored immature builds, and test Weibull shape $\beta$ **95% confidence interval (`ci95`) overlap**. For standing watchdogs, configure `EITHRESHOLD_PRODUCT` with `Adjusted` or `Extrapolated` mode (**never** `Unadjusted` on young builds) plus `EIANALYTIC_PRODUCT` with 3rd-time-dimension sales lag.
2. **4-View CAPA Clean-Point Verification (`BP 6`):**
   - Verify corrective actions across all 4 views before closing an alert: **(1)** Pre- vs. Post-clean-point WUMKR breach cells (`Sijk > cijk`) & `BP 6` reconciliation activity; **(2)** Matched-TIS fault-window vs. mature post-CAPA rate reduction (two-proportion $z$-test, **enforcing an immature exposure guard**: never declare `EFFECTIVE_CLOSE_ALERT` if `post_mature_units < 30` or `0` mature post-CAPA build months exist); **(3)** Historical pre-issue baseline mean + binomial $+2\sigma$ upper control band; **(4)** Weibull $\beta$ and B-life (`T01`, `T05`, `T10`) shift.
3. **Missing `TABLE_META_PG.last_data_dttm` (`WRNA_CALCPERIODS` Crash Signature):**
   - If `AIoTPgMeta.TABLE_META_PG.last_data_dttm` is null/empty for `PRODUCT`/`CLAIM`/`LABOR`/`PART`, **every** Emerging Issues run fails ~50s in inside `WRNA_CALCPERIODS` with `. - 4` (`g_refresh_PRODUCT` missing; subsequent `upcase(&g_origanalysisid)` errors are knock-on). Always read the **first** `ERROR:` line in `get_iot_analysis_step_log_tool`, and audit both `QASMartStore` table load status and `AIoTPgMeta.TABLE_META_PG.last_data_dttm` during health checks (`QASANLOUT` tables also expire after `259,200s` = 72h per `IIOTTRIAGE-320`).
