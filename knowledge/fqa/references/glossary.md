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
