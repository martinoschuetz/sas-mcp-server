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

- `modelName` `EIENTERPRISE_PRODUCT` (statistical excess) or `EITHRESHOLD_PRODUCT` (fixed thresholds).
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
**sharing** of analyses/data selections. Produce instructions the user can carry out in the UI.
