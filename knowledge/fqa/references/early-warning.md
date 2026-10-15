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

## Methodology (analytic) & the 3rd Time Dimension

- **Production-period (build) detection** follows Wu & Meeker (2002, *Technometrics*). Crucially,
  the Production Period model evaluates **three time dimensions** simultaneously (BP 1b):
  1. **Production (Build) Period** *i* (columns of the heat map).
  2. **Periods in Service (TIS / MIS)** *j* (rows of the heat map).
  3. **Sales Period Since Production (Sales Lag)** *k* — visible when you click a heat-map cell to
     open its **Details Chart**. The Details Chart plots the **actual event count (blue line)** vs.
     the **critical value $C_{ijk}$ (red line)** across the months elapsed between production and
     sale/registration. A cell turns red when the actual blue line crosses above the red critical
     line at one or more sales-lag points.
- **Baseline Chart**: Shows the historical average claim rate for each Time-in-Service period
  regardless of build period (the expected reference curve).
- **Event-period (calendar) detection** compares observed events with the expected count, which
  comes from the population's age distribution and the historical rates.
- Critical values come from a **Poisson** distribution.
- Also built in:
  - robust claim-intensity estimators;
  - seasonal factors estimated by logistic regression;
  - **alert index scores** (count, cost, and Weibull acceleration);
  - **reconciliation**, which keeps critical values constant across runs and merges/tracks active
    alerts over time;
  - **alert gap**, which merges nearby flagged **build periods** (along the production-period axis
    only, not across TIS rows) into one alert.
- **Alpha is entered as sigma:**
  - $1.0\sigma \implies \alpha \approx 0.15866$ (~15.87 % false positive rate)
  - $1.5\sigma \implies \alpha \approx 0.06681$ (~6.68 % false positive rate — recommended when $1\sigma$ floods the team with thousands of alerts)
  - $2.0\sigma \implies \alpha \approx 0.02275$ (~2.28 % false positive rate)
  - $3.0\sigma \implies \alpha \approx 0.00135$ (~0.13 % false positive rate)
  - Too many false alarms → make alpha smaller (higher sigma). Real problems missed → make alpha larger (lower sigma).
- FQA shows only significant combinations. Never recompute significance yourself
  (SKILL rule 1).

## Best Practice EI Setup: General vs. Specialist (BP 1a)

| Setup Type | Data Selection Filter | Product Reporting Variable | Event Reporting Variable | Recommended Settings |
|---|---|---|---|---|
| **General Setup** (broad screening) | Last 48 months of production (gives sufficient history for expected baseline rates) | **Series / Model Code** (plus optionally Engine Family or Plant; max 3 product vars) | **Object / Component Code** (e.g. 7-char hierarchy: Main Assembly Group [1] $\to$ Subgroup [2] $\to$ Function Group [3] $\to$ Assembly Group [4] $\to$ Object Code [7]) | `Production Period Only` (most actionable), Monitoring Window = `24` or `36` months, `Alert Gap = 3`, `Sigma = 1.5` (if $1\sigma$ yields too many alerts) |
| **Specialist Setup** (domain owner) | Filter "roughly" to area of responsibility at the **top hierarchy level** (e.g. Engine Family = X, or Main Assembly Group = Powertrain) | Domain-specific product attributes (e.g. **Exhaust Emission Limit**, **Key Account**, **Cab/Axle Config**) | **Object Code** (or Function/Assembly Group) | Same window & gap; lets specialists detect issues concentrated in specific technical configurations that dilute at the fleet level |

**What NEVER to put in an Emerging Issues run:**
- **Never use raw Damaged Part Number or Replaced Part Number** (~60,000–85,000 distinct values) as an EI event reporting variable. It fragments claims across superseded part numbers, starves cell counts, and explodes runtime. Use the component/object code in EI, then drill into part numbers via Pareto in Phase 1.
- **Never use Position, Location, or Damage Code** as primary EI event reporting variables — reserve those for Data Selections, Pareto, Statistical Drivers, and Failure Relationships during RCA.

## New Emerging Issues Reliability Columns & Joint Interpretation (LTS 2026.09+)

In LTS 2026.09+, the Alert table (`WMEXT`) and UI include Weibull-based reliability columns fitted to observed failure data using two Weibull parameters:
- **Shape parameter ($\beta$)**: Describes how the fitted failure rate changes over time ($\beta < 1$ decreasing / early-life; $\beta = 1$ constant / random; $\beta > 1$ increasing / wear, degradation, or aging) and provides the **acceleration** value.
- **Scale parameter ($\eta$)**: Represents the characteristic life of the fitted population and drives the projected time-to-failure calculations.

### 1. Columns and Data Windows (Critical Comparison Rule)
Because overall columns and alert-period columns are fitted over **different data windows**, always confirm which column is being reviewed before comparing or ranking alerts:

| Column | Data Window Used | What the Value Shows & Analytical Use |
|---|---|---|
| `Acceleration-Overall` (`Acceleration`) | **Complete monitoring window** | How the fitted failure rate ($\beta$) changes across the full analysis period (longer-term failure behavior). |
| `Acceleration-Alert Period` (`Acceleration_AP`) | **`Alert Start Date` through `Alert End Date`** | How the fitted failure rate ($\beta$) changes strictly during the alert window. Essential when recent cohort behavior diverges from the longer-term pattern. |
| `Events-Overall` | **Complete monitoring window** | Total events across the complete monitoring window. |
| `Events-Alert Period` (`Events`) | **`Alert Start Date` through `Alert End Date`** | Events occurring within the flagged alert window. |
| `Alert Duration (Months)` | **`Alert Start Date` through `Alert End Date`** | Number of months spanned by the alert window (1-month batch spike vs. sustained multi-month issue). |
| `T01` (`Time To 1 Pct Failure`, `B1`) | **Complete monitoring window** | Estimated time for **1 %** ($F_x = 0.01$) of the population to fail. |
| `T05` (`Time to 5 Pct Failure`, `B5`) | **Complete monitoring window** | Estimated time for **5 %** ($F_x = 0.05$) of the population to fail. |
| `T10` (`Time to 10 Pct Failure`, `B10`) | **Complete monitoring window** | Estimated time for **10 %** ($F_x = 0.10$) of the population to fail. |
| `T20` (`Time to 20 Pct Failure`, `B20`) | **Complete monitoring window** | Estimated time for **20 %** ($F_x = 0.20$) of the population to fail. |
| `T25` (`Time to 25 Pct Failure`, `B25`) | **Complete monitoring window** | Estimated time for **25 %** ($F_x = 0.25$) of the population to fail. |

> **Unit Rule for `T01`–`T25`:** The unit for `T01`, `T05`, `T10`, `T20`, and `T25` always follows the **selected analysis interval** of the Emerging Issues run. If the analysis interval is expressed in **months**, the time-to-failure values are also expressed in **months**.

### 2. Closed-Form Weibull Calculation for `T01`–`T25`
The time-to-failure values are derived from the Weibull cumulative distribution function (CDF):
$$F(t) = 1 - \exp\left[-\left(\frac{t}{\eta}\right)^\beta\right]$$
For a selected failure proportion $F_x \in \{0.01, 0.05, 0.10, 0.20, 0.25\}$, the equation is inverted to estimate the corresponding time $t_x$:
$$t_x = \eta \cdot [-\ln(1 - F_x)]^{1/\beta}$$

### 3. Reading Acceleration ($\beta$) and Time-to-Failure (`T01`–`T25`) Together
Acceleration describes the **direction and speed of change** in the fitted failure pattern, while `T01`–`T25` estimate **when specific failure thresholds will be reached**. Reading both together provides a more complete prioritization view than either metric alone:

| Joint Pattern | What It Indicates | Investigation & Prioritization Implication |
|---|---|---|
| **High acceleration ($\beta > 1$) + shorter `T01`–`T25` values** | Failures are increasing rapidly and selected failure thresholds are projected to be reached sooner. | **Highest urgency:** Runaway wear-out or degradation that will hit fleet failure milestones quickly. |
| **High acceleration ($\beta > 1$) + longer `T01`–`T25` values** | The failure pattern is increasing over time, but the projected fleet impact is further into the future. | **Emerging aging issue:** Escalate to engineering with lead time before warranty maturity is reached. |
| **Lower acceleration ($\beta < 1$) + shorter `T01`–`T25` values** | Failures appear early in service, but the pattern is not driven by aging or wear. | **Early-life / batch defect:** Investigate manufacturing lot, supplier batch, assembly, or pre-delivery handling. |
| **Acceleration near 1 ($\beta \approx 1$)** | The fitted pattern is consistent with a relatively constant hazard rate over time. | **Random / broad exposure:** Requires broader investigation of process, operating environment, and usage conditions. |

> **Guardrail:** These values are analytical estimates based on the available data and selected analysis interval. Always combine them with broader issue context, supporting data (`_DETAILS_` sales lag, `_WUMKR_` cell breadth), and domain knowledge rather than using them as a standalone decision rule.

## Emerging Issues properties

Properties marked **\*** are **immutable after the first run**. To change them, you need a new run
(`create_root_emerging_issues_analysis_tool`, an admin tool) and the history starts again. Flag
this whenever a user asks to "just change" one of them.

**Basic**

| Property | Notes |
|---|---|
| Data domain\* | Event domain monitored (claims, labor, parts, SSD, DTC) |
| Product reporting variables\* | Product side of the breakout, e.g. `MODEL_CD` (up to 3) |
| Event reporting variables\* | Event side of the breakout, e.g. `OBJECT_CD` / `PRIM_REPL_PART_CD` (up to 3) |
| Analysis to perform | Production Period, Event Period or Both |
| Event cost parameter\* | Cost measure for the cost score |
| Priority metric | **Score**: events beyond expected. **Cost Score**: average cost × excess events. **Acceleration** (2026.03 LTS+): rate of change ($\beta$) |
| Production / event period alert alpha | As sigma (e.g. 1.5 or 2.0) |
| Monitoring time window length\* | Usually the warranty length, e.g. 24 or 36 months |
| Analysis interval units | Months recommended |
| Reconcile analyses\* | Keep critical values stable and carry forward alert status/comments across runs |
| Complete reset | Full recalculation on the next run |

**Advanced**

| Property | Notes |
|---|---|
| Event rate estimation time window | History used for the expected rates (e.g. 24–48 months) |
| Alert gap time window | Build periods closer than this merge into one alert (only along the build axis, not TIS) |
| Minimum event records for defined entity | Sparse cells are skipped |
| Minimum production unit count\* | Minimum units per build period |
| Minimum events per period; minimum production periods | Data-sufficiency rules |
| Seasonal adjustment (production / event) | Turns seasonal correction on or off per chart type |
| Seasonality interval | Monthly or Quarterly |
| Seasonal factor estimation window; minimum years for seasonal calculation | History needed for seasonal factors |
| Initial selection; seasonal factor removal | Which seasonal factors are kept |
| Consistency check (+ seasonal factor removal for consistency check) | Drops factors that aren't stable |
| Number of EI runs kept on disk | Retention of run history and output tables |

## Automatic Alert Reconciliation & Lifecycle (BP 6)

When `Reconcile analyses` is enabled, subsequent runs of the same Emerging Issues definition automatically reconcile alerts that match on **Product Parameter + Event Parameter** and fall within the **`Alert Gap` window**:
- **Carried forward automatically**: Alert Status (`Unassigned`, `Assigned`, `Investigated`, `Closed`, `Completed`), user comments, and attachments.
- **`Alert Issue Date` never changes**: The date the alert was first generated is permanently preserved.
- **`Alert Start Date` and `Alert End Date` can only expand, never shrink**: If new build months trigger red cells within the Alert Gap window, `Alert End Date` advances.
- **Detecting inactive open alerts**: Compare `Alert End Date` against the current run date. If an alert is still marked `Assigned` or `Investigated`, but its `Alert End Date` stopped advancing many months ago, the issue is no longer active in recent production.

## On Demand

The same statistics as Emerging Issues, on a data selection that the user owns. Ideal for **Specialist monitoring** or **Proactive New Product Launch monitoring (BP 11)** where a Combined Data Selection unions predecessor and new product cohorts so the predecessor sets the expected baseline for the new launch.

| Group | Parameters |
|---|---|
| Basic | data selection, name, description, reporting variable, monitoring time window length, production-period alpha, warranty time length, event-period alpha |
| Advanced | event cost parameter, event rate estimation window, minimum production periods, value to display, notification method, users to notify, automatic update (start/end date) |
| Actions | replace data selection, view/download SAS log, subscriptions |

Administrators can set default values per alert-group type.

## Threshold and calculation methods

An alert fires when the metric crosses the threshold value (0–1,000,000,000). Ideal when no prior product baseline exists and engineering sets a fixed target limit.

| Group | Parameters |
|---|---|
| Basic | data selection, name, description, reporting variable, analysis variable, TIS point of view, **calculation method**, usage type, usage profile (Adjusted/Extrapolated only) + warranty-program usage limitation, threshold value, title/subtitle/footnote |
| Advanced | include pre-delivery claims, claims per unit, maximum exposure, maturity level, minimum sample size (percent 1–100 or count 1–1e9), claim submit lag, number of bars (1–25), value to display, notification, automatic update |

| Method | How | Use for |
|---|---|---|
| Unadjusted | Actual totals to date | "Total warranty cost as of today", or Common Cause screening on mature 12–18m cohorts |
| Adjusted | Incremental rate per TIS interval ($\text{passed} + 0.5 \times \text{residing}$), cumulated and projected to the oldest unit in the build period | Comparing builds of different ages; Early-Life 1m/3m Trend & Control |
| Extrapolated | Accrual growth ratios of mature builds project young builds ($\ge 3$ MIS default) out to the oldest unit in the data selection | Recent builds, "latest stock" |

Unadjusted rates on young builds are right-censored and look healthy
(population-scoping.md § Censoring). Recommend Adjusted or Extrapolated for any comparison
across build ages.

## Working with alerts in the UI

Use this section to write instructions for the user. None of these actions has an MCP tool.

- **Alert groups.** Each alert has a build-period chart (heat map) and an event-period chart.
  - Views: one chart, chart + table, table, or multiple charts.
  - The **Details chart** exists only for production-period heat-map cells (shows the 3rd time dimension: actual blue vs. critical red events across Sales Period Since Production). The **Baseline chart** shows historical expected behaviour across TIS.
- **Filter syntax in the alert table.**
  - `|` means OR.
  - Matches whole words only.
  - For decimals, use `<` / `>`, not `=`.
- **Assign Status:** Unassigned → Assigned → Investigated → Closed → Completed. Comments can carry attachments.
- **Subscriptions** send email for all or selected values (include/exclude). *Copy URL* gives a deep link.
- **Export** to PDF, Excel or CSV.
- **Analyze in Project** creates a project node, an *alert data selection* (stored snapshot,
  `creation_type=EIENTERPRISE`) and the first analysis.
  - The user chooses a name, description and **weeks to expire**.
  - After expiry, the DS goes to Error and can't feed new analyses. Existing outputs remain.
  - MCP equivalent: `analyze_emerging_issue_alert_tool` (write-back, needs approval).
- **Subsetting from alert cells (BP 2)** adds the system variable `alert` (0 = non-alert baseline cells, 1 = alert cells). Always select both the red alert cells and surrounding non-alert baseline cells so downstream analyses can group by `Alert`.


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
