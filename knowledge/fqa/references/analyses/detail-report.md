# Detail report (Details Table)

**Phase 3 — Context & causality.** Unaggregated, claim-by-claim records with technician and
customer narratives. The final human-validation step before engineering action.

## When & Scope (Narrow Leaf vs. Widened Context)
- **Use the narrow Phase 2 leaf here:** Unlike Phase 3 **Text Mining** and **Failure Relationships**
  (which must step back and *widen* the population because a small Phase 2 leaf fixes variables to
  a single level and starves statistical algorithms), the **Details Table** is specifically
  designed for the tightly filtered subpopulation (e.g. a 25-unit / 7-claim Decision Tree leaf or
  a specific Failure Relationships unit pair).
- Also used to verify exact unit and event counts at each step of a drill-down path before
  handing off a VIN/serial list to engineering or Field Quality Management systems (FMS) to pull
  workshop photos and returned parts.

## Parameters & `Enable Find Similar Contents`
Native: `run_detail_analysis_tool`. Templated: `query_data` on `CLAIM` ⋈ `COMMENT` for the drill
units, selected columns, ≤ 200 rows per pull.

- **`Enable Find Similar Contents = Yes`**: When enabled in the Details Table definition, a user can
  highlight a particularly informative technician or customer comment row in the output table and
  click **Find Similar Comments** to retrieve all other claims in the data selection with
  semantically similar narratives. When a narrow Phase 2 leaf yields a vivid symptom description
  on just 3–5 claims, run a Details Table with `Enable Find Similar Contents = Yes` on the
  **broader parent selection** to discover how many other vehicles experienced the same narrative
  even if coded under different labor/part numbers.

## Preflight
≥ 15 non-missing comments **per field** for statistical theme share reporting (though on a tiny
Decision Tree leaf of < 15 claims, you should still read all available comments and explicitly
report the exact count $n$).

## How to read
1. Split `TECH_COMMENT` and `CSTMR_COMMENT` (and `SSD` diagnostic logs if present).
2. Redact names/towns (safety.md).
3. Sample stratified (dealer/region) if > 40 comments; often the population is smaller — use all.
4. Group into themes, cite comment IDs per theme, give a share bucket (most / some / few) and
   `n_comments`.
5. Judge consistency: do the themes support one physical mechanism?
6. Use **Find Similar Contents** on exemplar comments if the theme is thin or if you want to check
   whether the same symptom hides under other part/damage codes in the parent cohort.

## Pitfalls
- Generic "replaced cable" comments are not support for a mechanism.
- Off-topic comments (dispatch calls, ECU questions) are noise.
- If customer text describes something else than the claim code, report a text-to-code mismatch.

