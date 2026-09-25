# Statistical Drivers

**Phase 2 — Segmentation.** Ranks categorical variables by their main effect on the elevated
claim rate. A dimensionality-reduction step before the decision tree and before choosing the
Failure Relationships domain.

## When
After the descriptive phase, to learn *which kind* of variable drives the excess:
production-side (build period, model, plant, supplier) or field-side (dealer, region, technician).

## Parameters
Native: `run_statistical_driver_analysis_tool`. Candidates must exist in the mart variable
dictionary (not just the DS profile).

## Evidence (templated)
Per candidate: rate by level, χ² test overall **and within build-quarter strata**. A driver is
`confounded_with=production_period` when its within-strata p ≥ 0.01 or it shows no effect in
pre-step strata.

## Interpretation
- Top non-confounded driver type sets the **order** of relationship domains
  (failure-relationships.md § Domain routing).
- A dealer spread that vanishes within strata is a build-period effect. Heterogeneity that
  remains inside the affected stratum is a secondary modifier (reference tenant: χ² = 68.4,
  df = 34 among dealers within Oct–Nov builds) → decision-tree follow-up, not a workmanship root cause.

## Pitfalls
Unstratified drivers on a build-period step light up every variable correlated with build date
(dealer allocation, region). Earlier ad-hoc work on the reference tenant wrongly named the
selling dealer as root cause this way.
