# Shipped `STANDARD` and `ALERTS` CAF Model Contracts (`QASANLOUT`)

Verified package metadata, UI/hidden defaults, row caps, SpEL rules, and Visual Analytics output contracts extracted directly from the 14 `STANDARD` and 3 `ALERTS` SAS-shipped CAF models (`%anl_driver` Generation-3 architecture). Use this when mapping native MCP tools to their underlying Viya models or checking parameter limits.

---

## 1. Complete Model Inventory (`[VERIFIED]`)

| Investigation Role / MCP Tool | `modelName` (`<Name>`) | Type / `KeyGroup` | Params | SpEL | VA Tokens | Key Operational Defaults & Caps |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| `run_pareto_analysis_tool` | `PARETO_PRODUCT` | `STANDARD` / `PRODUCT` | 45 | 16 | 36 | `NUMBARS=20` (`max=25`), `MAXROWSCOUNT=3000`, `MAXBYVAR=20`, `MAXBYVARCOUNT=3000`; UI flags `ISCUMMLINE`, `ISOTHERBAR`, `DISPLAYGRID` (`RERUN_REQUIRED=false`). |
| `run_trend_analysis_tool` | `TREND_PRODUCT` | `STANDARD` / `PRODUCT` | 46 | 17 | 234 | Shewhart limits (`SYSTEM`/`USER` `LCL`/`UCL`), `CONTROLCHARTS=TRUE` (`RERUN_REQUIRED=false`), `MAXBYVAR=20`; largest shipped BIRD template (`857 KB`, 54 graphs, 160 tables). |
| `run_trend_by_exposure_analysis_tool` | `TRENDEXP_PRODUCT` | `STANDARD` / `PRODUCT` | 44 | 19 | 30 | TIS series tracking (`Incremental` \| `Cumulative`), `SEASSALELAG`, `MAXBYVAR=20`, maturity & exposure controls. |
| `run_exposure_analysis_tool` | `EXPOSURE_PRODUCT` | `STANDARD` / `PRODUCT` | 39 | 16 | 30 | `EXPOSURETYPE=TIS\|USAGE`, `TISPOINTOFVIEW=frombuild\|fromsale`, `CALCMETHOD=ASIS\|PROJECTED\|EXTRAPOLATED`, `EXPCHARTTYPE`. |
| `run_reliability_analysis_tool` | `RELIABILITY_PRODUCT` | `STANDARD` / `PRODUCT` | 45 | 15 | 145 | `DISTRIBUTION` (`WEIBULL`, `BIWEIBULL`, `LOGNORMAL`, `EXPONENTIAL`), `RELIABILITYFITTYPE`, `CONFIDENCE`; emits `OUTPUTTABLENAME1..5` (requires survivors!). |
| `run_decision_tree_analysis_tool` | `MULTIVARIATE_PRODUCT` | `STANDARD` / `PRODUCT` | 38 | 8 | 72 | **`MAXREPORTLEVEL=100`**, **`MAXREPORTVAR=25`**, `MINNUMOBS=10`, `MAXBRANCH`, `MAXDEPTH`, `LEAFSIZE`. |
| `run_failure_relationships_analysis_tool` | `FAILREL_PRODUCT` | `STANDARD` / `PRODUCT` | 79 | 22 | 37 | **5 `CASTABLE` lookups** (`QASMartStore.FAILREL_RV`); defaults to `PART.REPL_PART_CD` (`PRODUCT,CLAIM,PART`), `MAXNODENUMBER=300`, `MAXLINKNUMBER=2000`, `RULETYPE=TYPE4`. |
| `run_detail_analysis_tool` | `DETAIL_PRODUCT` | `STANDARD` / `PRODUCT` | 32 | 3 | 2 | Unaggregated claim/product/comment export (`OUTPUTTABLENAME1..2`). |
| `run_text_mining_analysis_tool` | `TEXTANALYSIS_PRODUCT` | `STANDARD` / `PRODUCT` | 21 | 3 | 149 | Topic & category discovery (`CUSTOM_CATEGORY` flag; CAS `textManagement.identifyLanguage` when overridden for mixed locales). |
| `run_geographic_analysis_tool` | `GEOGRAPHIC_PRODUCT` | `STANDARD` / `PRODUCT` | 38 | 8 | 31 | Spatial concentration & geo-rate mapping using `GEO_COORDS`. |
| `run_summary_tables_analysis_tool` | `CROSSTAB_PRODUCT` | `STANDARD` / `PRODUCT` | 39 | 38 | 56 | Rich `<Crosstab>` matrix; richest SpEL set (`38` rules) coordinating row/column/measure fields (`RERUN_REQUIRED=false` display controls). |
| `run_time_of_event_analysis_tool` | `TIMEOFCLAIM_PRODUCT` | `STANDARD` / `PRODUCT` | 32 | 5 | 25 | Calendar/build claim volume & cost distribution. |
| `run_event_forecasting_analysis_tool` | `FORECASTING_PRODUCT` | `STANDARD` / `PRODUCT` | 50 | 13 | 70 | Liability/reserve projection (`forecast_interval`, warranty & mileage bounds). |
| Telemetry triage (`create_iot_analysis_tool`) | `EXPLORATION_PRD_ASSET` | `STANDARD` / `PRD_ASSET` | 3 | 0 | 16 | Compact sensor/event viewer: `QUERY_ONLY_CAS=Y\|N`, `MAXOBS_SENSOR=40000` (`0..999999999`), `EVENT_TO_SHOW` (`NONE`\|`BATCHES`\|`ITEMS`). |
| Scheduled EI (`create_root_emerging_issues_analysis_tool`) | `EIENTERPRISE_PRODUCT` | `ALERTS` / `PRODUCT` | 58 | 10 | 43 | Wu–Meeker `BOTH`/`PRODUCTIONPERIOD`/`EVENTPERIOD`; 9 core fields locked via `#ctx.getStepStatus('EIENTERPRISE_PRODUCT') != 'SAVED'`; dynamic `__VECHILDANALYSIS__` (`ve22` vs `ve80`) from `alert_type`; retains `EIRUNSTOKEEP=3` (`1..6`), hidden `CMAX=2000`, `ALPHAAW=0.01`, `RHO`, `K`. |
| Ad-hoc EI (`create_iot_analysis_tool`) | `EIANALYTIC_PRODUCT` | `ALERTS` / `PRODUCT` | 55 | 1 | 42 | Single-run Wu–Meeker on a user Data Selection (`9` visible + `46` hidden defaults incl. `RUNWUMEEKER=Y`, `RUNMODELA=Y`, `EIRGRUN=Y`). |
| Rule Threshold (`create_iot_analysis_tool`) | `EITHRESHOLD_PRODUCT` | `ALERTS` / `PRODUCT` | 39 | 8 | 30 | Fixed numeric target `THRESHOLDVALUE` (`fraction=2`, `0..999999999`), `CALCMETHOD` (`ASIS`\|`PROJECTED`\|`EXTRAPOLATED`), `NUMBARS=20` (`1..25`); SpEL `MINSAMPLESIZETYPE` mutates `MINSAMPLESIZE` `min/max/fraction` (`0..999999999` vs `0..100`). |

---

## 2. Diagnostic & Query Implications for FQA Agents

1. **Why Native Summary/Visual Checks Differ from Raw FedSQL:** Native `STANDARD` nodes automatically enforce hidden caps (`MAXREPORTLEVEL=100` / `MAXREPORTVAR=25` in Decision Tree, `NUMBARS<=25` in Pareto/Threshold, `MAXBYVAR=20` across grouped charts, `MAXNODENUMBER=300` / `MAXLINKNUMBER=2000` in Failure Relationships). When a templated SAS/FedSQL query returns more groups than the native visual cap, state that explicitly when reconciling counts.
2. **`_vaoutput` vs. Raw Tables:** `OUTPUTTABLENAME1..N` in `QASANLOUT` expire per `qas_cas_output_lifetime` (default 259,200 s) unless re-run, and failed/abandoned analyses leave empty tables behind — always check step status before trusting `QASANLOUT` tables.
3. **Immutable `EIENTERPRISE_PRODUCT` Fields Enforced by SpEL:** The UI itself disables `DATADOMAIN`, `BYVAR`, `REPORTVAR`, `ANALYSISVAR`, `M`, `EI_INTERVAL`, `RECONCILE`, and peers as soon as `#ctx.getStepStatus('EIENTERPRISE_PRODUCT') != 'SAVED'` (`EIENTERPRISE_REPORTVAR_02`), matching the server-side immutability rule in [early-warning.md](early-warning.md).
