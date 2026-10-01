# Glossary

| Term | Meaning |
|---|---|
| FQA | SAS Field Quality Analytics, runs on SAS Viya / Analytics for IoT |
| Alert group | An Emerging Issues (EI) run over a data selection with a breakout and chart type |
| Alert | One breakout combination with a statistically significant excess over a period |
| Breakout | Dimensions an EI run computes alerts for, e.g. model × primary part |
| EI | Emerging Issues — FQA's early-warning statistic (`EIENTERPRISE_PRODUCT`, `EITHRESHOLD_PRODUCT`) |
| Score / Index | Statistical excess index of an alert (sort key) |
| Cost score | Cost-weighted excess (`Index_TOTAL_EVENT_AMT`) |
| Cell | One build period × time-in-service period of the alert grid |
| Build chart / production-period chart | Claims by build month and months in service |
| Event chart / event-period chart | Claims by calendar claim month |
| TIS | Time in service (from build or from in-service date; FQA default `frombuild`) |
| Data selection (DS) | Saved, launchable filter set over the mart |
| Refresh date | `g_dwLstRfrshDt`, the data's "today"; rolling periods resolve against it |
| Project | Folder tree of analyses rooted at an alert or DS |
| Subset | Slice of a parent node's data; from alert cells it adds `alert` = 0/1 |
| Alert-defining population | Units in the alert build periods with a claim on the alert breakout |
| Coverage | Share of the alert-defining units a mechanism explains |
| Primary / contributing | Hypothesis role; primary needs coverage ≥ 0.25 |
| Labor code / part code | Repair operation / replaced part; primary codes live on `CLAIM` |
| Domain (FR) | Which line table Failure Relationships mines: LABOR or PART |
| Support / confidence / lift | Units with A→B; share of A-units that get B; confidence ÷ B's base rate in the cohort |
| seq90 | A unit whose first B claim falls 0–90 days after its first A claim |
| Early-life rate | Share of units with a first failure within 30/90 days of build |
| Immature month | Build month with < 90 days of exposure at the refresh date |
| Step month | First build month whose 90-day rate exceeds baseline by the step factor (3×) |
| Weibull β | Shape parameter: < 1 infant mortality, ≈ 1 random, > 1 wear-out |
| Weak signal | Pareto top bars not significantly above baseline share |
| Window edge | Alert starting in the first 2 months of the EI monitoring window |
| Placeholder node | Successful Summary Tables node used to document backend findings in the UI |
| SB | Service bulletin |
| DEW | Data Elements Workbook: the Excel source of tables, columns, lookups and labels; exported to `fqa_dew_tables.csv` / `fqa_dew_variables.csv` |
| Precode / postcode | Customer programs run before (DEW to engine CSVs) and after (Postgres metadata, UI defaults, cache refresh) `%afi_dataload` |
| `custstg` | Customer staging library on disk; input to `%afi_dataload`; `FQACustStg` is its CAS counterpart for validation tables |
| Parameter file | `parameters_<mode>.txt`, `key=value` input to `%afi_dataload`; modes full, incremental, configonly, seqbom |
| Partfile | A large fact stored as `<TABLE>_PART_n` sashdat chunks (`*_partfiles=Y`, `*_partfilesize=`) |
| `column_rest` | Column visibility code in `column_parameters.csv`: 0 everywhere, 1 not in the DS tree, 2 mart only, 3 ignored |
| Override | Customer copy of a product macro in `programs/overrides`, logged as `***OVERRIDE IN USE***` |
| SYSPARM phase | Token passed to the load job: `LOADSTG`, `LOADMART`, `VALIDATE`, `BOMSEQ`, `SKIPBOM`, `CUSTOM_SNAPDATE=` |
| DAFFE / IIOTTRIAGE / FQA-nnnn | Ticket prefixes: customer project Jira, SAS support triage, product defect |
| `alt_date` | Token in an analysis description that makes the overridden runtime compute as of a past refresh date |
