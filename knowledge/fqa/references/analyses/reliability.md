# Reliability (Weibull)

**Phase 4 — Normalization.** Fits time-to-first-failure with suspensions (censored units) to a
Weibull distribution.

## When
To confirm the failure mode type and compare alert vs. baseline builds; to project 12-month
failure rates.

## Parameters
Native: `run_reliability_analysis_tool`. Templated: PROC LIFEREG (or PROC RELIABILITY) via
`execute_sas_code` / `submit_batch_job`, one fit per group (alert builds, baseline builds).

## Preflight
≥ 30 failures per compared group, and censoring times available (time in service of units
without failure at the refresh date).

## Interpretation
| β | Reading |
|---|---|
| < 1 | infant mortality — assembly or supplier defect |
| ≈ 1 | random / environmental |
| > 1 | wear-out / fatigue |

β lower in alert builds than in baseline builds supports a production change.

## Pitfalls
Pin the values on first measurement; β on small groups has wide intervals — report them.
