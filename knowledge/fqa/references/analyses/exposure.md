# Exposure

**Phase 4 — Normalization, run early.** Normalizes claims by exposure (time in service; mileage
or hours if the mart has them) to separate an inherent defect from heavy use.

## When
Right after scoping an alert, before interpreting anything else. The early-life view decides
whether the rest of the investigation is about a production change or about usage/field causes.

## Parameters & Mechanics
Native: `run_exposure_analysis_tool`, `exposure_type=TIS`, `tis_point_of_view=frombuild`,
`show_immature_exposure=N`.

- **`Summary Type` (`Incremental` vs. `Cumulative`, applicable when `Exposure Type = Time in Service`):**
  - `Incremental`: Shows the failure rate or event count occurring *strictly within* each individual TIS period.
  - `Cumulative`: Shows the accumulated failure rate or event count *up to and including* each TIS period (revealing the cumulative growth slope over the vehicle's life).
- **`Exposure Type = Usage`** (Warranty Program Types 2 and 3 only): Plots event activity across usage intervals (e.g., mileage or operating hours bins set via `Bin Increment`). When `Usage` is selected, you cannot manually choose a `Calculation Method` — FQA automatically applies an **Adjusted-style** survival calculation across usage bins.
- **`Immature Flag` (75 % Rule):** In the Exposure and Trend by Exposure results tables, FQA marks a time-in-service or usage period as **immature** if **75 % or more of the product units being analyzed have not yet reached that period**.
- **Proactive Change / New Launch Comparison (BP 11):** Run Exposure Analysis on a **Combined Data Selection** (predecessor product + new launch product) with `Group Variable = Model Code` to directly compare the new launch's TIS curve against the predecessor baseline.

## Evidence (templated) — early life by build month
For the alert-defining event (e.g. primary part = alert part):
- per build month: units built, units with a first event < 30 days and < 90 days after build;
- 90-day rate per month; baseline rate = months before the alert;
- `step_month` = first month with 90-day rate ≥ 3 × baseline;
- time-to-first-event histogram (0–29, 30–59, 60–89, 90–119 days) for the alert cohort.

Template: `templates/fedsql/early_life_by_build_month.sql`.

## Preflight
Every build month used as evidence has ≥ 90 days of exposure at the refresh date; otherwise
flag `immature`.

## Interpretation
A clear step (reference tenant: ≤ 0.9 % for Jun–Sep builds → 10.8 % Oct, 13.3 % Nov) with most
failures in the first 90 days = early-life production defect. That becomes the primary
hypothesis candidate, and every other mechanism must be measured against it by coverage.

## Pitfalls
Without mileage/usage columns, "exposure" is time only — say so; don't claim usage was ruled out.

