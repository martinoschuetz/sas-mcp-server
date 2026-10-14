# Trend by Exposure / Trend & Control

**Phase 1 — Descriptive** (and early-life tracking for phase 4).

- **Trend by Exposure** (`run_trend_by_exposure_analysis_tool`): claim rate by build month (or
  in-service month), with one series per TIS value (`Bins to Display`, e.g. 1, 3, 6, 12, 24 months
  in service). Supports `Summary Type` (`Incremental` vs. `Cumulative`) and `Apply Seasonality on
  Sales Lag` (when `Time in Service Point of View = Calculate from estimated in-service date`).
- **Trend & Control** (`run_trend_analysis_tool`): rate over production time periods with control
  limits; part of `fqa_template_descriptive_triage_tool`.

## Control Charts & the Three Statistical Tests (Trend & Control)
When `Display control charts = Yes` is enabled, FQA generates two control charts in a dedicated tab:
1. **Individual Value Chart**: Plots the trend line with a central mean line and Upper/Lower Control
   Limits (`Let the system calculate the limits` statistically, or `Manually enter the limits`).
   Points violating any of the **three statistical tests** are highlighted in red (hover to see the
   test number):
   - **Test 1**: One point falls outside the control limits (sudden spike/anomaly).
   - **Test 2**: Seven points in a row fall on the same side of the central line (sustained shift in
     process mean).
   - **Test 3**: Six points in a row steadily increasing or steadily decreasing (systematic drift).
2. **Moving Range Chart**: Plots the absolute value of the period-to-period change
   ($|x_t - x_{t-1}|$) with statistically calculated control limits to detect sudden jumps in
   volatility.

## Best Practice: Monitoring the Front End of the Failure Distribution (BP 5)
To monitor infant mortality on new product launches, supplier changes, or cost-reduction initiatives:
- Create **two Trend & Control charts**: one with **`Maximum Exposure = 1 month`** and a second
  with **`Maximum Exposure = 3 months`**.
- Set `Analysis Variable` to a **rate** (e.g. `Failure Rate`) and `Calculation Method = Adjusted`.
- This isolates the infant-mortality region of the bathtub curve and detects production/supplier
  shifts months before full warranty maturity.

## When
- Find the **onset**: which build month (production lens) or calendar month (event lens) the
  rate changed.
- Verify **closed issues / CAPA effectiveness (BP 6)**: confirm that post-clean-point build months
  drop back within the pre-issue control band.
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

