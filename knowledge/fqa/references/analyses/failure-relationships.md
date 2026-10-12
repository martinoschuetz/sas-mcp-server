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

## Scope rule
Mine on the **model-level cohort of the scoped build periods** (alert + baseline periods, all
parts):
- never on the alert part alone — a single-part cohort can't contain cross-code sequences;
- never on full model history — old builds dilute the signal (reference tenant: lift ≈ 28 on the
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

## Parameters (native `run_failure_relationships_analysis_tool`)
- Defaults to the PART domain (`report_var=PART.REPL_PART_CD`) — set domain deliberately.
- `max_inter_oc_time` = window in months (3 ≈ 90 days).
- `rule_type` (`TYPE4`), `min_support_p`, `min_conf_passoc`, `min_lift`, `rule_size`.
- `repair_before_sold=true`.
- Returns `nosequencesfound_warning` on degenerate data — that is a preflight failure you
  should have caught.

### UI configuration and field recommendations (native run)
- Domains available: claims, labor codes, replaced parts, OTA/NASYS DTC, SSD, workshop orders —
  the DS must contain the domain (data-selections.md).
- Rule size `1-1`, `1-n`, `n-1`, `n-n`; start with `1-1,1-2` to keep rule counts manageable.
- *Repeat repairs only* (`perform_repeat_repair`) restricts rules to the same code recurring.
- Rule strength filters: min support (percent or count), confidence, lift, total rule cost
  (`min_cost`), number of rules shown.
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
