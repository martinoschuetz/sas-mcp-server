# Detail report (Details Table)

**Phase 3 — Context & causality.** Unaggregated, claim-by-claim records with technician and
customer narratives. The final human-validation step before engineering action.

## When
After a relationship pair or decision-tree leaf defines a small population: read what
technicians wrote.

## Parameters
Native: `run_detail_analysis_tool`. Templated: `query_data` on `CLAIM` ⋈ `COMMENT` for the drill
units, selected columns, ≤ 200 rows per pull.

## Preflight
≥ 15 non-missing comments **per field**; otherwise report "insufficient text".

## How to read
1. Split `TECH_COMMENT` and `CSTMR_COMMENT`.
2. Redact names/towns (safety.md).
3. Sample stratified (dealer/region) if > 40 comments; often the population is smaller — use all.
4. Group into themes, cite comment IDs per theme, give a share bucket (most / some / few) and
   `n_comments`.
5. Judge consistency: do the themes support one physical mechanism?
6. Ask for similar-comment expansion on exemplar comments if the theme is thin.

## Pitfalls
- Generic "replaced cable" comments are not support for a mechanism.
- Off-topic comments (dispatch calls, ECU questions) are noise.
- If customer text describes something else than the claim code, report a text-to-code mismatch.
