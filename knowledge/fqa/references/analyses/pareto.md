# Pareto

**Phase 1 — Descriptive.** Ranks the levels of one reporting variable by a measure. The first
analysis after scoping an alert.

## When
- Right after scoping: which labor codes / parts drive the alert subset?
- Grouped by the `alert` system variable, to compare alert vs. baseline cells.

## Parameters
| Concept | Native (`run_pareto_analysis_tool`) | Guidance |
|---|---|---|
| reporting variable | `report_var` (default `PRODUCT.MODEL_CD` — change it!) | `CLAIM.PRIM_LABOR_CD` first, then part/failure code |
| measure | `analysis_var` (default `CLAIM.CLAIMCOST`) | claims per 1000 units or claim count; cost as a second view |
| group | `by_var` (default `CLAIM.EVENT_STATUS_CD`) | `alert` when the subset has it |
| bars | `num_bars` (20) | top 10 is enough for interpretation |
| domain | `data_domain` (`PRODUCT,CLAIM,LABOR`) | match the reporting variable |

## Evidence (templated)
Count claims (and distinct units) per level of the claim-level primary code, split by `alert`.
Add per bar: rank in each group, share, rank change, share-difference z-score, and a Poisson
excess p-value vs. the baseline share with Bonferroni correction over levels.

## Preflight
- ≤ 50 levels; otherwise aggregate to the code group and report both views.
- Top-bar Poisson p < 0.01 after Bonferroni; otherwise `weak_signal`.

## Interpretation
- *Expected*: matches the alert breakout by **description** (not code).
- *Surprising*: no match, rises from `alert=0` to `alert=1` → follow-up code for Failure Relationships.
- Flat top bars → weak; follow up, but don't rest a high-confidence claim on it.

## Pitfalls
- Default native parameters report by model and cost — nearly useless for an alert on one model.
- The demo showed "Replace battery" at #2; on the reference tenant it was #1 (35 vs. 33). Don't
  depend on exact rank; depend on the role.
