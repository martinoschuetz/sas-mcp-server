# Other analyses

Not used for root cause; use for liability and planning.

| Analysis | Native tool | Use |
|---|---|---|
| Time of Event | `run_time_of_event_analysis_tool` | when failures happen relative to build / in-service; production vs. event lens |
| Event Forecasting | `run_event_forecasting_analysis_tool` | ARIMA / exponential smoothing forecast of claim counts, cost, labor hours for budgeting |

## Phase templates (native, create several nodes at once)

| Tool | Creates |
|---|---|
| `fqa_template_descriptive_triage_tool` | Pareto + Geographic + Trend & Control (phase 1) |
| `fqa_template_algorithmic_segmentation_tool` | phase 2 segmentation nodes |
| `fqa_template_validation_and_forecasting_tool` | phase 4 validation / forecasting nodes |

They are write-backs (approval). Useful to recreate an investigation in the UI in one call.

## Event Forecasting: setup and limits

It fits a time series to claim history. It knows nothing about a defect, a population or a
mechanism, which makes it right for a fleet budget and wrong for the defect itself.

| Setting | Guidance |
|---|---|
| Measure | Check which measures are flagged forecastable in `column_parameters` — usually event count, event cost and rate, often *not* labour hours |
| Interval | Month. Quarter is too coarse for a warranty horizon, week is noise at low volume |
| Warranty length | Match the dominant warranty type, and run the others as sensitivity. Statutory, goodwill and extended cover expire at different points |
| Usage limit | Set the mileage cap. On mixed fleets it binds before the time limit for high-mileage duty cycles and truncates their tail early |
| Seasonality minimum | 2 years, so seasonality is estimated from more than one cycle |

**Truncate the fitting window.** The most recent periods always under-report, because claims
arrive weeks to months after the repair. Where claim submit lag adjustment is off in the
tenant's global defaults, nothing compensates and a model fitted through those periods reads the
artificial decline as a downward trend. Measure the typical lag from repair date against
submission date, then hold that many periods back. This matters more than every parameter above.

**Bound it from the other direction.** A time-series model assumes the process continues, but a
defect population is finite and closed: once production changes, no new units enter it. Take the
shape and scale from the reliability fit, or the early-life rate if no fit was viable, and
multiply by the at-risk count from the decision-tree rule. Use the time series for the fleet
baseline and that product for the defect, and present the second as the intervention case.

Two populations the claim data cannot supply: units built to the suspect specification but not
yet delivered, and units still being built. Add both by hand from production records.

### Grouping
- **Warranty type** for a cost baseline. Goodwill volume responds to policy rather than to
  failures, so leaving it in one series makes a claims-handling change look like a failure-rate
  change.
- **The at-risk flag** for the defect increment. Only the baseline group will have enough
  history, which is the technique rather than a failure: forecast the baseline, then read the
  gap between observed total and forecast baseline as the increment.
- **Product line** where the budget is allocated that way and exposure differs by duty cycle.
- Avoid region (series too thin) and **build period** (it is an age cohort, not calendar time —
  see population-scoping.md).
- Grouped models are fitted independently, so group forecasts do not sum to the ungrouped one.
  Quote one or the other and say which.

## Advanced methods on raw data (outside the FQA UI)

Use via `execute_sas_code` when the standard analyses aren't enough:
- **Association rules (Apriori)** over codes × attributes, evaluated by support / confidence / lift.
- **Random forest** variable importance to find interactions; feed top variables back into the FQA tree.
- **Cox PH (PROC PHREG)** with censoring; hazard ratios per trait.
- **Automated subgroup discovery**: actual vs. expected rates with Poisson/binomial tests over
  variable permutations (the Poisson test is also used for the Pareto weak-signal check).
