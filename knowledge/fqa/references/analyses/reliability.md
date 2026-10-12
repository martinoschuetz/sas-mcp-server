# Reliability (Weibull)

**Phase 4 — Normalization.** Fits time-to-first-failure with suspensions (censored units) to a
Weibull distribution.

## When
To confirm the failure mode type and compare alert vs. baseline builds; to project 12-month
failure rates.

## Parameters
Native: `run_reliability_analysis_tool`. Templated: PROC LIFEREG (or PROC RELIABILITY) via
`execute_sas_code` / `submit_batch_job`, one fit per group (alert builds, baseline builds).

## Population and time origin
**Keep** the event filter that defines the failure, and keep the survivors. Units without the
claim are the censored observations, so a cohort restricted to failed units cannot be fitted at
all (population-scoping.md). Make the build window wide enough that failures appear across a
range of ages. A cohort censored at a uniform early age — an alert on recent builds at one or
two months in service — has no spread for the shape parameter, and the fit returns a β whose
interval spans infant mortality to wear-out.

Fit from the **in-service date** rather than from build when the mart has both. A unit standing
in a yard accumulates no exposure, and for an early-life defect the two origins disagree
sharply: a truck built in June, registered in August and failing on first use reads as a failure
at three months from build and at zero from registration.

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
- Pin the values on first measurement; β on small groups has wide intervals — report them.
- **Bimodal failure times break a single Weibull.** When the chart shows two clusters (e.g. one
  at 1–2 months and one at 14–15), a single fit returns a shape between the two modes that
  describes neither. Fit the groups separately, or use a two-component Weibull if the tenant has
  it configured (check the `DISTRIBUTION` parameter lookup). A two-component fit that resolves
  into a clear early mode and a clear later mode is itself evidence of two mechanisms.
- When the preflight fails, do not fit and report β anyway. Fall back to the early-life rate
  (share of units failing within 30/90 days by build month), which stays honest at low counts
  and still supports an intervention case.
- For the forecast, β is the part that matters: below 1 the affected population largely clears
  itself and the liability is front-loaded; above 1 every exposed unit is still ahead of its
  failures. Multiply by the at-risk count from the decision-tree rule to get the projection.
