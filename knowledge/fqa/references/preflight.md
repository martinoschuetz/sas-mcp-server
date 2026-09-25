# Preflight: can this analysis work on this data?

Run the check **before** every analysis — templated query or native tool. If it fails:

1. Do **not** run the analysis.
2. Tell the user why, with the measured numbers ("0 of 3,432 units have ≥ 2 distinct parts, so
   Failure Relationships can't find sequences in this single-part selection").
3. Offer the remedy if there is one (widen the cohort, aggregate levels, switch domain).

A preflight is a cheap count query. Templates: `../templates/fedsql/preflight_*.sql`.
Thresholds are defaults; the tenant profile may override them.

| Analysis | Check | Default threshold | Remedy on fail |
|---|---|---|---|
| Failure Relationships | share of cohort units with ≥ 2 distinct codes **in the chosen domain table** | ≥ 20 % and ≥ 200 units | widen to the model-level cohort of the scoped build periods, all parts |
| Failure Relationships | domain coverage: target-code rows in the domain table ÷ claim-level units with the target code | ≥ 0.5 | use the other domain, or the claim-level primary-code template |
| Pareto, Summary Tables | levels of the reporting variable | ≤ 50 | aggregate to the code group (`LABOR_GRP_CD`, `REPL_PART_GRP_CD`); report both |
| Pareto (interpretation) | top bar's Poisson excess vs. baseline share, Bonferroni over levels | p < 0.01 | run anyway, mark `weak_signal` |
| Statistical Drivers, Decision Tree | target and every candidate exist in the **mart variable dictionary** | all present | drop missing candidates; say so |
| Statistical Drivers | effects tested within build-period strata | — | mark `confounded_with=production_period` |
| Decision Tree | events in subset | ≥ 100 and ≥ 2 × min leaf | widen scope or skip |
| Text Mining, comment review | non-missing comments **per field** | ≥ 15 | skip, report "insufficient text"; try the widest scope that still holds the pattern |
| Reliability | failures per compared group; censoring times available | ≥ 30 per group | skip; rely on early-life rates |
| Exposure | each build month used has ≥ 90 days of exposure at the refresh date | — | flag `immature`, exclude from evidence |
| any native `run_*_tool` | the DS filters don't make the analysis degenerate (e.g. FR on a DS filtered to one part) | — | compute with a template on a widened cohort; document via placeholder node |

## Why these checks exist

- Failure Relationships is association-rule mining over sequences. It needs units with several
  distinct events. An alert DS filtered to one part or one labor code has none → the native macro
  fails or returns `nosequencesfound_warning`.
- Line tables (`PART`, `LABOR`) may barely cover the claim-level primary codes; a domain with low
  coverage can't show the pattern even if it exists.
- The DS variable profile tool lists only a few variables; checking it would wrongly fail valid
  analyses. The mart dictionary is the oracle.
- Unstratified drivers mislead when the issue is a build-period step: every build-correlated
  variable (dealer allocation, region) lights up.

## Widening is a rule, not a guess

When a preflight fails because the scope is too narrow, the widened cohort is fixed: **same
model, alert + baseline build periods, all parts**. Log that you widened and why.
