# Which MCP tool for which job

Server: `sas-viya-internal` (FQA-aware). The generic `sas-viya` server is only a fallback for SQL
and SAS code.

## Contents
- Evidence vs. UI objects (the key design choice)
- Tool map
- Known tool limits
- Native parameter conventions
- Auth

## Evidence vs. UI objects

**Compute evidence with templated queries over the mart; create native FQA analyses only so a
human can reopen the investigation in the UI.**

Why: completed native analyses often expose no readable result table
(`get_iot_analysis_output_tables_tool` returns `[]`, and `QASANLOUT` holds only the filter
criteria). Native runs on alert data selections can also be degenerate (e.g. Failure
Relationships on a single-part DS returns `nosequencesfound_warning`). Templated FedSQL/SAS gives
you numbers you can cite and reproduce.

Native `run_*_tool` calls create objects in the user's FQA workspace → they are write-backs and
need approval (writeback.md).

## Tool map

**Read — FQA metadata & bundled single-call triage (safe)**

| Job | Tool |
|---|---|
| rank all EI runs + get top run's sorted alerts in 1 call | `triage_emerging_issue_runs_tool` (single CAS call across all EI runs; returns top 10 runs & top 10 alerts sorted by `score` with `has_more` pagination) |
| 4-question alert triage (`_ALERTS_`, `_DETAILS_` Sales Lag, `_WUMKR_`, `_BASELINE_`) in 1 call | `inspect_emerging_issue_alert_context_tool` (single CAS call; checks `actual > C_ijk` sales lag, Weibull $\beta$, and $n < 5$) |
| 4-gate preflight check on a DS / CAS table in 1 call | `run_fqa_preflight_checks_tool` (single CAS call; checks cardinality, single-level pinning, Failure Relationships multi-code share, and Text Mining comment count) |
| 4-quadrant Common Cause vs. Special Cause screening in 1 call | `screen_common_cause_candidates_tool` (single CAS call; classifies components by rate/cost and Weibull $\beta$ + B-life `T01`–`T25`, top 10 by default) |
| list alert groups | `list_emerging_issue_runs_tool(status="Completed", sort_by="lastRunDate", limit=10)` |
| list alerts of a single run | `list_alerts_for_run_tool(analysis_id=..., sort_by="score", sort_order="desc", limit=10)` (sorts all alerts before slicing to top 10; includes `has_more` & `next_start`) |
| alert → FQA filter criteria | `get_alert_filters_tool` (pure translation, no side effects) |
| data selections | `list_data_selections_tool(limit=10, sort_by=...)`, `get_data_selection_details` |
| DS variable profile | `list_fqa_data_model_variables_tool` (incomplete — see data-model.md) |
| projects and nodes | `list_folders_and_projects_tool` |
| analyses | `list_iot_analyses_tool` (first 10 only!), `get_iot_analysis_details_tool`, `get_iot_analysis_run_status_tool`, `get_iot_analysis_results`, `get_iot_analysis_output_tables_tool` |
| can this analysis run natively? | `get_analysis_execution_capabilities` |

**Read — data (safe)**

`list_caslibs`, `list_castables`, `get_castable_info`, `get_castable_columns`, `get_castable_data`,
`query_data` (FedSQL, see fedsql.md), `list_compute_tables`, `list_compute_columns`,
`get_job_status`, `get_job_log`, `list_jobs`.

**Execute (scratch only)**

`execute_sas_code` (interactive, ~120 s), `submit_batch_job` (long jobs), `cancel_job`,
`reset_compute_session`. Write only into a scratch caslib/library; never `DROP`/`DELETE` outside it.

**Write — only after user approval**

| Job | Tool |
|---|---|
| project / folder | `create_project_tool`, `create_folder_tool` |
| "Analyze Alert" (EI data selection + analysis from an alert) | `analyze_emerging_issue_alert_tool` (filters from `get_alert_filters_tool`) |
| On Demand / Threshold early warning | `get_iot_model_definition_tool` first, then `create_iot_analysis_tool(model_name="EIANALYTIC_PRODUCT" \| "EITHRESHOLD_PRODUCT", …)` (early-warning.md) |
| child DS / child analysis | `create_child_data_selection_and_launch_tool`, `create_child_analysis_and_run_tool` |
| launch a DS | `launch_data_selection_tool`, `launch_data_selection_and_wait_tool` |
| edit DS | `update_data_selection_tool`, `update_data_selection_filters_tool`, `set_data_selection_date_range_tool`, `copy_data_selection(s)_tool`, `combine_data_selections_tool` |
| native analyses | `run_pareto_analysis_tool`, `run_summary_tables_analysis_tool`, `run_geographic_analysis_tool`, `run_trend_analysis_tool` (Trend & Control), `run_trend_by_exposure_analysis_tool`, `run_exposure_analysis_tool`, `run_reliability_analysis_tool`, `run_statistical_driver_analysis_tool`, `run_decision_tree_analysis_tool`, `run_failure_relationships_analysis_tool`, `run_detail_analysis_tool`, `run_text_mining_analysis_tool`, `run_time_of_event_analysis_tool`, `run_event_forecasting_analysis_tool` |
| phase templates | `fqa_template_descriptive_triage_tool` (Pareto + Geographic + Trend & Control), `fqa_template_algorithmic_segmentation_tool`, `fqa_template_validation_and_forecasting_tool` |
| rollback | `delete_project_tool`, `delete_data_selection_tool`, `delete_iot_analysis_tool`, `force_delete_fqa_object_tool` (locked objects — only for objects you created) |

**Admin — don't use in investigations**

`reload_fqa_metadata_tool` (reloads FQA config into Postgres; minutes-long), `create_root_emerging_issues_analysis_tool`, `remediate_high_cardinality_tool` (rewrites a CAS table column), `copy_iot_analyses_tool`.

**Doesn't exist**: alert assignment, alert stage, sharing. Export instructions instead.

## Known tool limits

- `list_iot_analyses_tool` returns only the first 10 analyses and cannot page. Enumerate project
  nodes with `list_folders_and_projects_tool` on the project folder.
- Alert tool and WMEXT table use different column names (`score`/`Index`,
  `cost_score`/`Index_TOTAL_EVENT_AMT`, `Events_AP`/`Events`). Normalize.
- `list_fqa_data_model_variables_tool` is not a reliable variable oracle.
- Native Failure Relationships defaults to the **PART** domain (`report_var=PART.REPL_PART_CD`,
  `data_domain=PRODUCT,CLAIM,PART`). Change it deliberately (failure-relationships.md).
- Native Pareto defaults to `report_var=PRODUCT.MODEL_CD` and `analysis_var=CLAIM.CLAIMCOST`.
  Set both explicitly.

## Native parameter conventions

- `report_var`: the variable bars/nodes are reported by, e.g. `PRODUCT.MODEL_CD`,
  `CLAIM.PRIM_LABOR_CD`, `PART.REPL_PART_CD`.
- `analysis_var`: the measure, e.g. `CLAIM.CLAIMCOST`, `CLAIM.CLAIMCOUNT`.
- `by_var`: grouping, default `CLAIM.EVENT_STATUS_CD`.
- `data_domain`: comma list of mart components, e.g. `PRODUCT,CLAIM,LABOR`.
- `exposure_type=TIS`, `tis_point_of_view=frombuild`.
- `show_immature_exposure=N` hides immature periods — keep it.
- `repair_before_sold=true` excludes pre-delivery repairs.
- Pass `folder_id` (project) and `parent_analysis_id` to place a node in the right tree.

## Auth

A 401 means the OAuth token expired. Stop, ask the user to re-login (`/viya-login`), then
continue. Do not retry in a loop.
