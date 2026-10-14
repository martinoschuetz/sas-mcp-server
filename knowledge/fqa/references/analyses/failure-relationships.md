# Failure Relationships

**Phase 3 — Context & causality.** Association rules and sequences between codes on the same
unit: "repair A is followed by repair B within N months". Separates a root-cause component from
collateral damage.

## Contents
- When
- Scope rule
- Domain routing
- Parameters
- Evidence (templated, unit-level)
- Thresholds
- Interpretation and pitfalls

## When
After the Pareto produced a surprising follow-up code, or drivers point to repair-induced or
collateral failures.

## Scope rule: Widen the Population in Phase 3
Mine on the **model/series-level cohort of the scoped build periods** (alert + baseline periods, all
parts/codes):
- **Never run on a narrow Phase 2 subpopulation (e.g. a 25-unit Decision Tree leaf):** In a small
  Phase 2 slice that already isolates a specific failure pattern, key product and event variables
  are already **fixed (pinned) to a single or tiny number of levels**, and unit counts are far too
  small to pass minimum support thresholds or build cross-component context. Always step back up
  the project tree to the wider parent cohort before running Failure Relationships.
- **Never on the alert part/code alone** — a single-part cohort can't contain cross-code sequences;
- **Never on full model history** — old builds dilute the signal (reference tenant: lift ≈ 28 on the
  alert cohort vs. 0.76 on pre-alert builds for the same pair).

Three further rules on the population (population-scoping.md):

- **Remove the event filter.** A data selection filtered to one object code or part leaves only
  that code's claims, so there is nothing to sequence against. Keep the unit filters.
- **Never condition on the outcome.** If every unit in the cohort already has the alert claim,
  that consequent's base rate is 1.0 and lift collapses to confidence, so the statistic that
  separates a real sequence from two common events stops working. Generate against the full
  comparable population, then filter the *output* to rules involving the code of interest.
- **The cohort needs elapsed time.** Units at one or two months in service have had one claim
  and no chronology. Use an older cohort of the same configuration, or an earlier cluster of the
  same component, and say which. For the alert cohort itself, list the claims and read them
  rather than mining them.

## Domain routing
Use the top **non-confounded** drivers (statistical-drivers.md) to set the order:

| Driver type | Examples | Order | Native settings for the first domain |
|---|---|---|---|
| Workmanship / repair-induced | selling/repair dealer, customer state, technician | LABOR, PART | `data_domain='PRODUCT,CLAIM,LABOR'`, `report_var='CLAIM.PRIM_LABOR_CD'` |
| Manufacturing / hardware | production period, plant, supplier, model | PART, LABOR | `data_domain='PRODUCT,CLAIM,PART'`, `report_var='PART.REPL_PART_CD'` |
| mixed / none | | LABOR, PART | |

Each domain runs only if its preflight passes. **Routing orders; it never excludes.** On the
reference tenant the driver was production period (→ PART first), but the PART table didn't
cover the alert part (3 lines vs. 610 units) — a hard route would have ended with no evidence.
If both domains fail, use the claim-level primary-code template.

## Parameters (native `run_failure_relationships_analysis_tool`) & Same-Claim vs. Sequential Mode
- Defaults to the PART domain (`report_var=PART.REPL_PART_CD`) — set domain deliberately.
- **`Maximum Inter-Occurrence Time` (`max_inter_oc_time`) controls the analysis mode:**
  - **`max_inter_oc_time = 0` (Co-Occurrence / Same-Claim Association Analysis):** Finds items
    (e.g., labor codes and replaced parts, or multiple parts) that occur together **within the
    same claim / same day**. In the FQA UI, the **`Minimum Lift` filter is ONLY available when
    `Maximum Inter-Occurrence Time = 0`**.
  - **`max_inter_oc_time > 0` (Sequential Analysis across claims, e.g. `3` months $\approx$ 90 days):**
    Finds chronological sequences where Event A on Claim 1 is followed by Event B on Claim 2 within
    $N$ months on the same unit. In the FQA UI, **`Include Rule Progression Table` is ONLY
    available when `Maximum Inter-Occurrence Time > 0`** (breaking down rule counts by the elapsed
    months between antecedent and consequent).
- `rule_type` (`TYPE4`), `min_support_p`, `min_conf_passoc`, `min_lift`, `rule_size`.
- `repair_before_sold=true` (`Include Pre-Delivery Claims`).
- Returns `nosequencesfound_warning` on degenerate data — that is a preflight failure you
  should have caught.

### UI configuration, output views, and field recommendations (native run)
- Domains available: claims, labor codes, replaced parts, OTA/NASYS DTC, SSD, workshop orders —
  the DS must contain the domain (data-selections.md). Up to **3 reporting variables** can be
  analyzed simultaneously (e.g. `Primary Labor Code` + `Replaced Part Code` to see which labor
  operations co-occur with or precede part replacements).
- **Rule Size** (`1-1`, `1-n`, `n-1`, `n-n`): Controls how many items appear on the antecedent and
  consequent sides (`1-2` = 1 antecedent code leading to 2 consequent codes). Start with `1-1,1-2`
  to keep rule counts manageable.
- **Repeat repairs only** (`perform_repeat_repair`): Restricts rules to the *same* code recurring
  on the same unit across subsequent claims.
- **Four Output Views in the UI:**
  1. **Node Link Graph**: Directed network where node size = support/cost and arrow thickness = confidence/lift.
  2. **Constellation Plot**: Overview of rule clusters.
  3. **Rule Details Table**: Support, Confidence, Lift, Transaction Count, Product Count, and Total Rule Cost per rule.
  4. **Rule Progression Table** (when `max_inter_oc_time > 0`): Histogram of inter-occurrence times (Month 1, Month 2, Month 3, …) between Event A and Event B.
- Field practice for the **native node** shown to users: 3–6 month window for slow sequences,
  `min_lift` ≈ 1.2 to drop trivial wear-item pairs, `min_cost` at a business-meaningful level
  (e.g. 10,000). These are display filters — the evidence thresholds below still apply.

## Evidence (templated, unit-level)
For antecedent A and consequent B in cohort C:
- `units_A` = units in C with any A claim; `units_B` = units in C with any B claim;
- `support` = units whose **first** B claim is 0–window days after their **first** A claim
  (by `REPAIR_OPEN_DATE`);
- `confidence` = support ÷ units_A; `lift` = confidence ÷ (units_B ÷ units in C);
- repeat with direction `after` (B before A) when relevant;
- `coverage` = alert-defining units with the sequence ÷ alert-defining units.

Template: `templates/fedsql/relationship_unit_level.sql`, `coverage.sql`.

## Thresholds
Keep a pair if support ≥ 10 units, confidence ≥ 0.2, lift ≥ 2.0. Drill at most 2 pairs.

## Interpretation and pitfalls
- **Count units, not claim pairs.** Claim-pair counting on the reference tenant reported
  "3,780 pairs, 46.7 % confidence" for a pattern whose unit-level confidence was 0.089.
- Use primary codes on `CLAIM`; the secondary `LABOR` table showed only 12 of 2,431 seq90 units
  for the same pattern.
- Zero sequences in the reverse direction support a precursor reading.
- Read **both directions** as separate findings: what precedes the claim points upstream at a
  cause, what follows it points at collateral damage or a repair that did not work.
- **Same-value rules are usually excluded by configuration** (`SAME_VALUE_FLG_CD=0` in the
  failure-relationship CSV), so a repeat claim on the *same* code never appears. That is normally
  right and occasionally hides the clearest evidence of a wrong diagnosis or an ineffective
  repair. Count repeat failures per unit with a direct query instead.
- Prefer a **component-grain** target (object code) over a part-number target for the first run.
  Part numbers fragment one component across variants, and the support threshold then eliminates
  every rule.
- A passing pair is association. Plausibility (physical mechanism) + comments make it a
  hypothesis; coverage decides whether it explains the alert.
