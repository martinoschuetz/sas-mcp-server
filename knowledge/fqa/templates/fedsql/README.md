# FedSQL templates

Run with `query_data` (`target='cas'`). Replace `{{placeholders}}` only with values from the
tenant profile's variable dictionary (allow-listed `_RK` codes, ISO dates) — never with free text.

| Template | Purpose | Step |
|---|---|---|
| `early_life_by_build_month.sql` | 30/90-day first-event rates by build month | Normalize |
| `preflight_fr_multicode.sql` | ≥ 2 distinct codes per unit (FR feasibility) | Preflight |
| `preflight_domain_coverage.sql` | does PART/LABOR line table cover the target code | Preflight |
| `relationship_unit_level.sql` | support / confidence / lift, both directions | Relate |
| `coverage.sql` | share of alert-defining units a mechanism explains | Hypothesize |

All five were verified on the reference tenant on 2026-09-25 and reproduce the golden values in
`tenants/reference/golden-values.yaml`.

Dialect rules applied (see ../../references/fedsql.md): `DATE 'YYYY-MM-DD'` literals, derived
tables instead of CTEs, joins instead of `IN (subquery)`, `IS NOT NULL` guards before numeric
comparisons, grouping by derived-table aliases.
