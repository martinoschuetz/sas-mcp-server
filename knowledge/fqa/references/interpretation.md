# Interpreting FQA results

Domain priors for reading statistical output. They guide judgment; they never replace a number
computed in SAS.

## Contents
- Chart patterns → mechanism classes
- Early life and Weibull β
- Pareto: expected, surprising, weak
- Relationships: support, confidence, lift, scope
- Coverage: explaining the alert
- Drivers and confounding
- Comments and text clusters
- Artifacts and small numbers
- Mechanism classes
- Wording

## Chart patterns → mechanism classes

| Pattern | Looks like | First suspects |
|---|---|---|
| `recent_build_early_tis` | build chart: red cells in recent build months, early months in service | production change, supplier change, plant incident |
| `single_build_period` | one build month (or short run) elevated at all TIS | batch/lot defect, line stoppage, one-off assembly error |
| `event_spike` | event chart: one calendar month elevated across builds | seasonal weather, service-action side effect |
| `event_step` | event chart: sustained rise from a calendar month | new service procedure, parts change in the field, policy change |
| `diffuse` | many scattered cells | usage/wear, data artifact, low signal |

## Early life and Weibull β

- Early-life rate = share of units with a first failure within 30 / 90 days of build, by build
  month. A **step** by build month + high early-life ratio = production-side defect.
- Weibull shape β (reliability analysis):
  - β < 1 → infant mortality / assembly or supplier defect.
  - β ≈ 1 → random or environmental failures.
  - β > 1 → wear-out / fatigue.
- Compare β for alert vs. baseline builds. A lower β in the alert builds supports a production
  change.
- A build month needs ≥ 90 days of exposure at the refresh date before its 90-day rate means
  anything. Immature months look *good* (few claims yet) — never read them as recovery.

## Pareto: expected, surprising, weak

- **Expected**: the bar matches the alert breakout by description (alert part "cruise control
  cable" → labor "Replace Cruise Control Cable").
- **Surprising**: doesn't match the breakout and rises in rank or share from `alert=0` to
  `alert=1`. Surprising bars become follow-up codes for relationships.
- **Baseline shift**: the whole distribution moves; not one code.
- **Weak signal**: the top bars are close together (e.g. 35, 33, 25, 23, 22 of 75 levels) or the
  Poisson excess test isn't significant after Bonferroni. You may still follow the bar, but mark
  the finding *weak* and don't let it carry a high-confidence hypothesis.

## Relationships: support, confidence, lift, scope

- Support = units with antecedent then consequent within the window. Confidence = support ÷
  units with the antecedent. Lift = confidence ÷ the consequent's unit rate in the **same cohort**.
- **Scope decides the answer.** The same pair can pass on the scoped cohort and fail on full
  history (reference tenant: lift ≈ 28 on the alert cohort, 0.76 on pre-alert builds). Always
  state the cohort next to the numbers.
- A single-part cohort can't contain cross-code sequences — widen to the model-level cohort of
  the scoped build periods.
- Check the reverse direction. Zero reverse sequences strengthen a precursor reading.

## Coverage: explaining the alert

Every mechanism must answer: *how many of the alert-defining units does it explain?*

- coverage = alert-defining units that show the mechanism ÷ all alert-defining units (computed in SAS).
- ≥ 0.25 can be primary; < 0.25 is contributing.
- Reference-tenant lesson: the demo's "battery acid → cable" sequence was real (lift ≈ 28, comment
  support) but covered only 38 of 610 alert units (6.2 %). The alert itself was an early-life step
  in builds from Oct 2019. A real, vivid mechanism can still be a sideshow.

## Drivers and confounding

- Rank drivers **within build-period strata** (quarter). A dealer or region effect that
  disappears within strata is a production-period effect in disguise.
- Driver type suggests where to look for relationships:
  - dealer, customer state, technician → workmanship / repair-induced → LABOR domain first;
  - production period, plant, supplier, model → manufacturing / hardware → PART domain first.
- Heterogeneity that remains within the affected stratum (e.g. dealers inside the step months)
  is a **secondary modifier** — a candidate for a decision-tree follow-up, not a root cause.

## Comments and text clusters

- Read technician and customer comments separately. When they disagree (e.g. tech text about the
  cable, customer text about fuel pressure on the same claims), report a text-to-code mismatch;
  never cite the off-topic field as evidence.
- Themes need cited comment IDs and a share bucket. With few comments, "some" is honest; "most"
  needs the numbers.
- Off-topic noise (dispatch calls, unrelated questions) produces no theme.

## Artifacts and small numbers

- **Window edge**: alerts starting in the first 2 months of the monitoring window are often
  edge effects of the EI statistic (51 of 145 on the reference run).
- **Volume bias**: almost all alerts on one high-volume model is expected, not a finding.
- **Small n**: say "few events (n = …)" in the interpretation; don't rank urgency high on n < ~50
  without other evidence.
- **Multiplicity**: many regions/dealers → some look extreme by chance. Use corrected tests;
  geography is frequently a negative control.
- **Empty output tables** mean "check the run", not "no problem".

## Mechanism classes

`production_change`, `supplier_change`, `plant_incident`, `seasonal_weather`,
`service_action_side_effect`, `usage_or_wear`, `secondary_failure` (one failure damaging another
component), `workmanship`, `data_artifact`.

## Wording

| Evidence | Say |
|---|---|
| association only | "associated with", "consistent with" |
| strong association + mechanism + comments | "strong association consistent with a causal link" |
| high confidence (≥ 3 findings, ≥ 2 analysis types, incl. comments) | "likely cause" / "root cause" allowed |
| coverage < 0.25 | "contributing mechanism", never "root cause of the alert" |
| data can't distinguish plant vs. supplier | "production or supplier change" + owner question + part returns |
