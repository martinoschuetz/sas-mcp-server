# Trend by Exposure / Trend & Control

**Phase 1 — Descriptive** (and early-life tracking for phase 4).

- **Trend by Exposure** (`run_trend_by_exposure_analysis_tool`): claim rate by build month (or
  in-service month), with one series per TIS value (e.g. 1, 3, 6 months in service).
- **Trend & Control** (`run_trend_analysis_tool`): rate over time with control limits; part of
  `fqa_template_descriptive_triage_tool`. Best practice: set it with 1-month and 3-month maximum
  exposure to track infant mortality.

## When
- Find the **onset**: which build month (production lens) or calendar month (event lens) the
  rate changed.
- First choice in the fallback next-step order.

## Evidence (templated)
Rate per (period, TIS series) with numerator and denominator; change points computed in SAS
(e.g. first period exceeding the baseline by the step factor, or a segmented fit).

## Interpretation
- Production-period step → batch/assembly/supplier issue.
- Event-period spike → seasonal or service-action side effect.
- Recent build months are immature — they drop artificially. Flag and exclude them.

## Pitfalls
Always pair the chart with n per period; a change point on 20 units is not a change point.
