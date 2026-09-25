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

## Advanced methods on raw data (outside the FQA UI)

Use via `execute_sas_code` when the standard analyses aren't enough:
- **Association rules (Apriori)** over codes × attributes, evaluated by support / confidence / lift.
- **Random forest** variable importance to find interactions; feed top variables back into the FQA tree.
- **Cox PH (PROC PHREG)** with censoring; hazard ratios per trait.
- **Automated subgroup discovery**: actual vs. expected rates with Poisson/binomial tests over
  variable permutations (the Poisson test is also used for the Pareto weak-signal check).
