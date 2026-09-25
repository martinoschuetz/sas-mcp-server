# FQA data mart

The physical names below are FQA defaults. Always confirm them in the tenant profile.

## Contents
- Tables
- Surrogate keys and labels
- Which code variable to use
- Comments
- Things the standard mart usually lacks
- Onboarding checks

## Tables

| Logical | Physical (default) | Grain / key columns |
|---|---|---|
| units | `QASMartStore.PRODUCT` | one row per unit: `PRODUCT_ID`, `MODEL_CD_RK`, `PRODUCTION_DATE`, `INSERVICE_DATE`, `SELLING_DEALER_CD_RK` |
| claims | `QASMartStore.CLAIM` | one row per claim/event: `EVENT_ID`, `PRODUCT_ID`, `PRIM_LABOR_CD_RK`, `PRIM_REPL_PART_CD_RK`, `EVENT_STATUS_CD_RK`, `REPAIR_DEALER_CD_RK`, `REPAIR_OPEN_DATE`, `TOTAL_EVENT_AMT`, `EVENT_DAYS_INSERVICE_BUILD` |
| secondary labor lines | `QASMartStore.LABOR` | `EVENT_ID`, `LABOR_CD_RK`, `LABOR_CODE_EVENT_DATE` |
| parts lines | `QASMartStore.PART` | `EVENT_ID`, `REPL_PART_CD_RK`, … |
| comments | `QASMartStore.COMMENT` | `EVENT_ID`, `TECH_COMMENT`, `CSTMR_COMMENT` |
| dimensions | `MODEL`, `LABOR_CODE`, `PRIM_LC`, `PRIM_RP`, `REPL_PART_CODE`, `EVENT_STATUS`, `REPAIR_DEALER`, `SELLING_DEALER`, `CSTMR`, `GEO_COORDS`, `SYNONYMS`, `STOPLIST` | `*_RK` → `*_CD`, `*_NM` |
| alerts | `QASANLOUT.EIENTERPRISE_WMEXT_<hash>` | one row per alert of one EI run |
| alert cells | `QASANLOUT.EIENTERPRISE_WUMKR_<hash>` | build × TIS grid of one EI run |
| FQA metadata | `AIoTPgMeta.*` | column metadata, localization, FR defaults; no alert-workflow tables |

`<hash>` differs per EI run. Resolve it once at onboarding and pin it in the tenant profile.

`QASANLOUT` holds many **empty** tables from failed or abandoned runs. An empty output table does
not mean "no data" — check the run status first.

## Surrogate keys and labels

The mart stores surrogate keys (`*_RK`). Every readable code or label needs a join to its
dimension table, e.g. `CLAIM.PRIM_LABOR_CD_RK = LABOR_CODE.LABOR_CD_RK` → `LABOR_CD`, `LABOR_NM`,
`LABOR_GRP_CD`. Filter on the `_RK` value in queries (faster, unambiguous) and join for labels
only in the final output.

## Which code variable to use

- **Use the claim-level primary codes** (`CLAIM.PRIM_LABOR_CD_RK`, `CLAIM.PRIM_REPL_PART_CD_RK`)
  for Pareto, relationships and alert populations. Alerts are defined on them.
- The secondary `LABOR` and `PART` line tables may **not cover** the primary codes. Before any
  analysis in the PART or LABOR *domain*, measure coverage: rows of the target code in the line
  table ÷ claim-level units with that code. Below 0.5, that domain can't be used (see
  preflight.md). On the reference tenant the PART table held 3 lines for a part with 610
  claim-level units, and the LABOR table showed no sign of a sequence that was clear on
  `CLAIM.PRIM_LABOR_CD_RK`.
- Don't assume "part X ⇒ labor code X". Labor and part codes can be statistically independent in
  the data. Match them by **description** (e.g. part "Cruise control cable" ↔ labor "Replace
  Cruise Control Cable"), not by code.
- For **time**, use `REPAIR_OPEN_DATE` for claim sequencing and `PRODUCTION_DATE` for build
  periods. `EVENT_DAYS_INSERVICE_BUILD` gives days from build to event.

## Comments

- Two free-text fields per claim: `TECH_COMMENT` (technician) and `CSTMR_COMMENT` (customer).
  They can describe **different** things on the same claim — analyze them separately and flag a
  mismatch as a data-quality issue.
- Coverage is often low (0.65 % of claims on the reference tenant) and text may be truncated
  (100 characters). Always report `n_comments` next to any theme; the "sample" is often the full
  population.
- Comments contain PII (first names, towns) even when digits are masked upstream. Redact before
  quoting (safety.md).

## Things the standard mart usually lacks

Check before promising an analysis:
- Plant, supplier, lot, mileage, engine hours or usage columns on `PRODUCT`. Without them,
  manufacturing drivers are limited to `PRODUCTION_DATE` and `MODEL_CD`, and exposure is time in
  service only. Say "production or supplier change" and raise the plant/supplier question to the
  owner instead of guessing.
- DTC / telemetry data.

## Onboarding checks

1. `list_caslibs` → `list_castables(QASMartStore)` → `get_castable_columns` for each table.
   Record row counts.
2. For each EI run in scope, resolve the WMEXT/WUMKR hash. The WMEXT row count must equal the
   `total` returned by `list_alerts_for_run_tool`.
3. Build the **variable dictionary** from the mart columns. Do not rely on
   `list_fqa_data_model_variables_tool` — it returns only a handful of variables (5 on the
   reference tenant) and misses variables the native tools accept (e.g. `CLAIM.PRIM_LABOR_CD`).
4. Read the data refresh date (`g_dwLstRfrshDt`); relative periods resolve against it.
5. Measure PART/LABOR line-table coverage for the main part and labor codes.
6. Measure comment coverage per field.
