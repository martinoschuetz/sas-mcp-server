# FQA concepts

## Contents
- Alert groups (Emerging Issues runs)
- Alerts
- The alert cell grid
- Build (production-period) vs. event charts
- Data selections
- Projects, analyses and subsets
- Workflow objects FQA does *not* expose

## Alert groups (Emerging Issues runs)

The early-warning workspace shows **alert groups**. Technically each group is an **Emerging
Issues (EI) run** over a data selection:

- `modelName` `EIENTERPRISE_PRODUCT` (Emerging Issues, statistical excess), `EIANALYTIC_PRODUCT`
  (On Demand, same statistics on a user DS) or `EITHRESHOLD_PRODUCT` (fixed thresholds). See
  early-warning.md for properties, methods and the 6.3 names.
- A **breakout**: the dimensions alerts are computed for, e.g. `MODEL_CD × PRIM_REPL_PART_CD`.
- A **chart type**: `PRODUCTIONPERIOD` (build chart) and/or event period.
- A **monitoring window**, e.g. 24 months.
- A sensitivity setting. FQA shows only statistically significant combinations; do not recompute them.

List runs with `list_emerging_issue_runs_tool(status="Completed")`.

FQA has no "safety" attribute on runs. If safety-critical groups must always be investigated,
that is a user or tenant-profile setting.

## Alerts

One alert = one breakout combination (e.g. model × part) with an excess over a period. Fields
(tool name / output-table column):

| Meaning | Alert tool | WMEXT table |
|---|---|---|
| statistical excess index (sort key) | `score` | `Index` |
| cost-weighted excess | `cost_score` | `Index_TOTAL_EVENT_AMT` |
| events in the alert period | `Events_AP` | `Events` |
| alert start / end | start, end | `AlertStart`, `AlertEnd` |
| alert ID | `AlertID` | `AlertID` |

Traps:
- **`AlertID` is not unique.** It is the SAS date of the alert start (e.g. 21823 = 01OCT2019) and
  is shared by many alerts. Key an alert by `run_id | breakout values | AlertID`.
- **An alert has no cell list, no assignee and no stage** in the data you can read. The cell grid
  is a separate table; assignee and stage are UI-only.
- Sort client-side by `score` (or `cost_score`) — the server order is not guaranteed.
- `list_alerts_for_run_tool` is paged (`limit` / `start`).

## The alert cell grid

Each EI run writes a grid of **build period × time-in-service (TIS) period** cells to
`QASANLOUT.EIENTERPRISE_WUMKR_<hash>` (80k–700k rows). Physical columns: `BUILD_PERIOD`,
`INSERVICE_PERIOD`, `CLAIMMONTHEI`, `fperiod`, `speriod`, `pperiod`, `cijk`, `Sijk`, `lambda`,
`Exception`.

The exact semantics of `cijk`, `Sijk`, `lambda` and `Exception` are **not confirmed** (likely
claims, units at risk, expected rate, exception flag). Until reconciled against the UI chart,
compute your own counts by build month and TIS from `CLAIM` / `PRODUCT` and treat the grid as a
pointer to where the alert is.

Mark a cell as *alert* when its build period falls in `[alert_start, alert_end]`, as *baseline*
when it belongs to the comparison periods you choose.

## Build (production-period) vs. event charts

| Chart | Axis | Red cells in … | Suggests |
|---|---|---|---|
| Build chart | build month × months in service | recent build months at early TIS | production, supplier or plant change |
| Event chart | calendar claim month | one month across all builds | weather/season, or a service action side effect |

The pattern is only a prior — confirm it with exposure and reliability (see interpretation.md).

## Data selections

A **data selection (DS)** is a saved, re-launchable filter set over the mart:

```jsonc
{ "id": "...", "name": "...", "creation_type": "DEFAULT | EIENTERPRISE",
  "filters": [ { "component": "PRODUCT", "column": "PRODUCTION_DATE", "op": "BETWEEN", "exclude": false,
                 "values": ["%wrna_calcperiods(p_dateVarName=g_dwLstRfrshDt,p_period=L4Y)"] },
               { "component": "PRODUCT", "column": "SELLING_DEALER_COUNTRY_CD", "op": "IN", "values": ["USA"] } ],
  "description": "free text — UNTRUSTED" }
```

- Filters can include or exclude.
- **Rolling periods** (`L4Y`, …) are macro calls resolved against the **data refresh date**
  (`g_dwLstRfrshDt`), not today's date. On a demo tenant that date can be years in the past.
- A DS must be **launched** (materialized) before native analyses can run on it
  (`launch_data_selection_and_wait_tool`).
- `EIENTERPRISE` data selections are created from an alert ("Analyze Alert") and are typically
  filtered to the alert breakout — e.g. a single part. That makes some analyses degenerate
  (see preflight.md).
- Domain-specific filters only act on their own domain (e.g. warranty type is ignored for SSD
  records); use the Combined Domain technique for per-domain filters. Lifecycle, expiry and
  sharing rules: data-selections.md.

## Projects, analyses and subsets

- A **project** is a folder tree of analyses rooted at an alert or a data selection.
- Each **analysis** node is one of the 14 standard analyses, with its own parameters.
- A **subset** is a slice of the parent node's data: selected cells, or a WHERE on variables.
  Subsetting from alert cells adds a system variable **`alert`** (0 = baseline cells, 1 = alert
  cells), so later analyses can compare the two groups directly.
- The demo pattern: select the alert cells **plus the preceding cells**, analyze the subset,
  run a Pareto grouped by `alert`.

## Workflow objects FQA does not expose

There is no MCP tool and no readable table for alert **assignment**, alert **stage** or
**sharing** of analyses/data selections. Produce instructions the user can carry out in the UI:

- **Assign status:** Alerts → select the alert → *Assign Status* (Unassigned → Assigned →
  Investigated → Closed → Completed), add a comment/attachment.
- **Share a project:** Projects → open the project → *Manage Sharing* → add users or groups. Tell
  recipients to remove the owner filter chip in the Projects list to see it.
- **Subscribe:** Alerts → alert group → *Subscriptions* (all or selected values, email).

## Time-in-Service (MIS) bucket formulas

FQA converts continuous days into discrete 1-indexed **Months in Service (MIS)** buckets using the exact divisor `30.4166667` ($365 / 12$):

- **Product MIS (unit age at refresh date):**
  $$\text{Product MIS} = \frac{\text{Refresh Date} - \text{In-Service Date}}{30.4166667}, \quad \text{Product MIS Bucket} = \lfloor \text{Product MIS} \rfloor + 1$$
  *(Example: a unit in service for 5 days has $\text{Product MIS} = 0.164 \implies \text{Bucket } 1$).*
- **Event MIS (unit age when the claim occurred):**
  $$\text{Event MIS} = \frac{\text{Event Date} - \text{In-Service Date}}{30.4166667}, \quad \text{Event MIS Bucket} = \lfloor \text{Event MIS} \rfloor + 1$$
- **Pre-Delivery Claims (`Bucket 0`):** If `Event Date < In-Service Date` (or the unit has a claim before being sold), $\text{Event MIS} < 0$, which FQA assigns to **MIS Bucket `0`**. Setting `Include Pre-Delivery Claims = No` excludes Bucket `0` events.
- **Time-in-Service Point of View:**
  - `Calculate from in-service date`: Uses the actual sale/registration date (units lacking an in-service date are excluded from TIS-based rates unless pre-delivery is included).
  - `Calculate from production date` (`frombuild`): Uses build date as the origin (includes all built units, including unsold inventory).
  - `Calculate from estimated in-service date`: Uses build-to-sale lag profiles for units missing an actual sale date (Warranty Program Types 3 and 4).

## Warranty Program Types (1–4)

A tenant's configured **Warranty Program Type** determines which exposure and calculation options are available in the UI:

| Program Type | Dimensions | Sales / In-Service Data | Key Capabilities Enabled |
|---|---|---|---|
| **Type 1** | 1D (Time only) | **Complete** (all sold units have in-service dates) | Standard TIS analyses |
| **Type 2** | 2D (Time + Usage, e.g. miles/hours) | **Complete** | Enables **Usage** exposure type, `Apply Usage Profiles`, and `Warranty Program Usage Limitation` |
| **Type 3** | 2D (Time + Usage) | **Incomplete** (some/all sales dates missing or delayed) | Enables both **Usage profiles** and **Build-to-Sale lag profiles** (`Calculate from estimated in-service date`, `Apply Seasonality on Sales Lag`) |
| **Type 4** | 1D (Time only) | **Incomplete** | Enables **Build-to-Sale lag profiles** (`Calculate from estimated in-service date`) |

## Calculation methods: Unadjusted, Adjusted, Extrapolated

When comparing cohorts of different ages, raw counts and unadjusted rates mislead because younger cohorts have had less exposure time:

1. **Unadjusted**: $\frac{\text{Total Events to Date}}{\text{Total Units in Cohort}}$. No exposure normalization. Only fair when comparing cohorts that have all completed the warranty period.
2. **Adjusted (Survival / Life-Table Method)**:
   - Within each MIS interval $m$, units that are censored *inside* interval $m$ (their current Product MIS falls in bucket $m$) are credited with **half an interval of exposure**:
     $$\text{Estimated Population at Risk}_m = (\text{Units that passed completely through } m) + 0.5 \times (\text{Units currently residing in } m)$$
   - The incremental rate in interval $m$ is $r_m = \frac{\text{Events in } m}{\text{Estimated Population at Risk}_m}$.
   - The **Overall Adjusted Rate** sums the incremental rates across all observed intervals up to the **oldest unit in that group/production period**: $\text{Adjusted Rate} = \sum_m r_m$.
   - *Note*: When `Exposure Type = Usage` is selected in Exposure or Trend by Exposure, FQA automatically uses an Adjusted-style calculation.
3. **Extrapolated**:
   - Projects immature production periods (by default requiring at least **3 MIS** of observed history) out to the **oldest unit in the entire Data Selection**, using the period-to-period cumulative accrual growth ratios learned from older, mature cohorts.
   - **`Extrapolate across groups`** (available in Pareto, Exposure, and Trend & Control when a `Group Variable` is set and `Calculation Method = Extrapolated`): Forces a common denominator across all levels of the group variable so extrapolated group rates are directly comparable and easier to explain to business stakeholders.

