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
- A passing pair is association. Plausibility (physical mechanism) + comments make it a
  hypothesis; coverage decides whether it explains the alert.
