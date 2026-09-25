# Exposure

**Phase 4 — Normalization, run early.** Normalizes claims by exposure (time in service; mileage
or hours if the mart has them) to separate an inherent defect from heavy use.

## When
Right after scoping an alert, before interpreting anything else. The early-life view decides
whether the rest of the investigation is about a production change or about usage/field causes.

## Parameters
Native: `run_exposure_analysis_tool`, `exposure_type=TIS`, `tis_point_of_view=frombuild`,
`show_immature_exposure=N`.

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
