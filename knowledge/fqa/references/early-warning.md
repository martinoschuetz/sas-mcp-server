# Early warning: Emerging Issues, On Demand, Threshold

How FQA's early-warning analyses work, which settings matter, and what you can and cannot do
through MCP. Read this before creating or interpreting an alert group, or before advising a
user on EI configuration.

## Contents
- Names across releases
- Three kinds of early warning
- Methodology (analytic)
- Emerging Issues properties
- On Demand
- Threshold and calculation methods
- Working with alerts in the UI
- Scheduling
- MCP mapping and traps

## Names across releases

| FQA 6.3 (SAS 9) | Viya / AIoT UI | `modelName` |
|---|---|---|
| Enterprise Analytic | **Emerging Issues** | `EIENTERPRISE_PRODUCT` |
| Ad Hoc Analytic | **On Demand** | `EIANALYTIC_PRODUCT` (inferred, verify) |
| Ad Hoc Threshold | **Threshold** | `EITHRESHOLD_PRODUCT` |

Verify model names on the tenant with `list_iot_models_tool` / `get_iot_model_definition_tool`
before creating anything. Users often use the 6.3 names; map them silently.

## Three kinds of early warning

| Kind | Method | Recommended for |
|---|---|---|
| **Emerging Issues** | Statistical excess, scheduled batch over all reporting-variable combinations | Most issues; systematic monitoring |
| **On Demand** | The same statistics on a user's own data selection, run when needed or on an automatic-update schedule | A product line, supplier or campaign that the enterprise run doesn't break out |
| **Threshold** | Fixed user-defined target on a metric | Safety and regulatory issues with a known limit |
| Real-time | ESP models (external/custom analysis); email/SMS with a data snapshot | Connected products; outside the FQA batch |

FQA has no safety attribute on runs. Safety groups are usually configured with a more
sensitive alpha, or as Threshold analyses.

## Methodology (analytic)

- **Production-period (build) detection** follows Wu & Meeker (2002, *Technometrics*). For build
  period *i*, time in service *j* and reporting value *k*, the critical value C<sub>ijk</sub>
  depends on the historical claim rate, the sales proportions, units produced and alpha.
- **Event-period (calendar) detection** compares observed events with the expected count, which
  comes from the population's age distribution and the historical rates.
- Critical values come from a **Poisson** distribution.
- Also built in:
  - robust claim-intensity estimators;
  - seasonal factors estimated by logistic regression;
  - **alert index scores** (count and cost);
  - **reconciliation**, which keeps critical values constant across runs so alerts don't flip;
  - **alert gap**, which merges nearby flagged periods into one alert.
- **Alpha is entered as sigma.** For example, sigma 2 corresponds to alpha 0.02275.
  - Too many false alarms → make alpha smaller (higher sigma).
  - Real problems missed → make it larger.
- FQA shows only significant combinations. Never recompute significance yourself
  (SKILL rule 1).

## Emerging Issues properties

Properties marked **\*** are **immutable after the first run**. To change them, you need a new run
(`create_root_emerging_issues_analysis_tool`, an admin tool) and the history starts again. Flag
this whenever a user asks to "just change" one of them.

**Basic**

| Property | Notes |
|---|---|
| Data domain\* | Event domain monitored (claims, labor, parts, SSD, DTC) |
| Product reporting variables\* | Product side of the breakout, e.g. `MODEL_CD` |
| Event reporting variables\* | Event side of the breakout, e.g. `PRIM_REPL_PART_CD` |
| Analysis to perform | Production Period, Event Period or Both |
| Event cost parameter\* | Cost measure for the cost score |
| Priority metric | **Score**: events beyond expected. **Cost Score**: average cost × excess events. **Acceleration** (2026.03 LTS+): rate of change |
| Production / event period alert alpha | As sigma |
| Monitoring time window length\* | Usually the warranty length, e.g. 24 months |
| Analysis interval units | Months recommended |
| Reconcile analyses\* | Keep critical values stable across runs |
| Complete reset | Full recalculation on the next run |

**Advanced**

| Property | Notes |
|---|---|
| Event rate estimation time window | History used for the expected rates |
| Alert gap time window | Periods closer than this merge into one alert |
| Minimum event records for defined entity | Sparse cells are skipped |
| Minimum production unit count\* | Minimum units per build period |
| Minimum events per period; minimum production periods | Data-sufficiency rules |
| Seasonal adjustment (production / event) | Turns seasonal correction on or off per chart type |
| Seasonality interval | Monthly or Quarterly |
| Seasonal factor estimation window; minimum years for seasonal calculation | History needed for seasonal factors |
| Initial selection; seasonal factor removal | Which seasonal factors are kept |
| Consistency check (+ seasonal factor removal for consistency check) | Drops factors that aren't stable |
| Number of EI runs kept on disk | Retention of run history and output tables |

Interpretation hooks:
- An alert in the first months of the monitoring window is a *window edge* alert
  (interpretation.md).
- A seasonal flag means the excess is already adjusted for season.

## On Demand

The same statistics as Emerging Issues, on a data selection that the user owns.

| Group | Parameters |
|---|---|
| Basic | data selection, name, description, reporting variable, monitoring time window length, production-period alpha, warranty time length, event-period alpha |
| Advanced | event cost parameter, event rate estimation window, minimum production periods, value to display, notification method, users to notify, automatic update (start/end date) |
| Actions | replace data selection, view/download SAS log, subscriptions |

Administrators can set default values per alert-group type.

## Threshold and calculation methods

An alert fires when the metric crosses the threshold value (0–1,000,000,000).

| Group | Parameters |
|---|---|
| Basic | data selection, name, description, reporting variable, analysis variable, TIS point of view, **calculation method**, usage type, usage profile (Adjusted/Extrapolated only) + warranty-program usage limitation, threshold value, title/subtitle/footnote |
| Advanced | include pre-delivery claims, claims per unit, maximum exposure, maturity level, minimum sample size (percent 1–100 or count 1–1e9), claim submit lag, number of bars (1–25), value to display, notification, automatic update |

| Method | How | Use for |
|---|---|---|
| Unadjusted | Actual totals to date | "Total warranty cost as of today" |
| Adjusted | Incremental rate per TIS interval, cumulated and projected to maturity | Comparing builds of different ages |
| Extrapolated | Accrual pattern of mature builds projects young builds | Recent builds, "latest stock" |

Unadjusted rates on young builds are right-censored and look healthy
(population-scoping.md § Censoring). Recommend Adjusted or Extrapolated for any comparison
across build ages.

## Working with alerts in the UI

Use this section to write instructions for the user. None of these actions has an MCP tool.

- **Alert groups.** Each alert has a build-period chart (heat map) and an event-period chart.
  - Views: one chart, chart + table, table, or multiple charts.
  - The Details chart exists only for production-period heat-map cells. The Baseline chart shows expected behaviour.
- **Filter syntax in the alert table.**
  - `|` means OR.
  - Matches whole words only.
  - For decimals, use `<` / `>`, not `=`.
- **Assign Status:** Unassigned → Assigned → Investigated → Closed. Comments can carry attachments.
- **Subscriptions** send email for all or selected values (include/exclude). *Copy URL* gives a deep link.
- **Export** to PDF, Excel or CSV.
- **Analyze in Project** creates a project node, an *alert data selection* (stored snapshot,
  `creation_type=EIENTERPRISE`) and the first analysis.
  - The user chooses a name, description and **weeks to expire**.
  - After expiry, the DS goes to Error and can't feed new analyses. Existing outputs remain.
  - MCP equivalent: `analyze_emerging_issue_alert_tool` (write-back, needs approval).
- **Subsetting from alert cells** adds the system variable `alert` (0 baseline, 1 alert).

## Scheduling

- Emerging Issues run in batch (`fqaetl_batchrpt_emerging.sas`). The standard incremental job runs them on **Sundays**.
  - So alerts reflect the last Sunday run, not the latest load.
  - Check the run's completion date against the refresh date.
- On Demand and Threshold analyses with automatic update are rerun by
  `%wrna_execute_batchjobs` when due.
- Run status **Completed with Errors** exists only for Emerging Issues. Some cells failed, but alerts were
  produced. Read the log before trusting completeness.

## MCP mapping and traps

| Job | Tool | Class |
|---|---|---|
| list runs | `list_emerging_issue_runs_tool(status="Completed")` | read |
| list alerts | `list_alerts_for_run_tool` (paged; filters `alert_type`, `model_cd`, `cstmr_country_cd`, `seasonal_flag`, `display_status_cd`, `attribute_filters`) | read |
| alert → filters | `get_alert_filters_tool(alert_row)` | read |
| Analyze in Project | `analyze_emerging_issue_alert_tool` | write, approval |
| On Demand / Threshold | `get_iot_model_definition_tool` first, then `create_iot_analysis_tool(name, model_name, data_selection_id, folder_id, …)` | write, approval |
| new root EI run | `create_root_emerging_issues_analysis_tool` (clones a base EI and swaps the DS; plain POST with `EIENTERPRISE_PRODUCT` creates an Analyze-Alert node instead) | admin |

Traps:
- `AlertID` is not unique (concepts.md).
- Sort client-side by `score` / `cost_score`.
- Outputs are in `QASANLOUT.EIENTERPRISE_WMEXT_<hash>` (alerts) and `_WUMKR_<hash>` (cell grid). Take the
  hash from the tenant profile, never guess it.
- The tool's `display_status_cd` reflects the assignment status in the UI, but you can't set it.
