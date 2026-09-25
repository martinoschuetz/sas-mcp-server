# FedSQL traps in `query_data`

`query_data` runs FedSQL on CAS. These behaviours are verified and differ from standard SQL or
PROC SQL:

| Trap | Symptom | Do this |
|---|---|---|
| Date literals | `'01OCT2019'd` → syntax error; date vs. number → "Operator is not unique" | Use `DATE '2019-10-01'` |
| `ORDER BY` under the row cap | Result order not honored when the cap applies | Sort client-side, or aggregate so the result is below the cap |
| No CTEs | `WITH x AS (...)` fails | Use derived tables: `FROM (SELECT ...) AS x` |
| `GROUP BY` on an expression | `GROUP BY put(PRODUCTION_DATE, yyq6.)` → "Column must be GROUPed" | Compute the expression in a derived table, then group by its alias |
| `IN (subquery)` | "Unsupported operation in FedSQL query: IN/ANY/ALL subquery" | Rewrite as a join to a derived table |
| **Missing values compare low** | `CASE WHEN x < 30` is true for unmatched rows of a LEFT JOIN (SAS missing < any number) — silently inflates counts | Always guard: `x IS NOT NULL AND x < 30` |
| Surrogate keys | Codes are `*_RK` integers | Filter on `_RK`, join dimensions only for labels |
| Empty output tables | 0 rows in `QASANLOUT` | Check the run status before concluding "no data" |

## Patterns

Month bucket (derived table, then group by alias):

```sql
SELECT build_month, COUNT(*) AS units
FROM ( SELECT PRODUCT_ID,
              YEAR(PRODUCTION_DATE) * 100 + MONTH(PRODUCTION_DATE) AS build_month
       FROM QASMartStore.PRODUCT
       WHERE MODEL_CD_RK = {{model_rk}} ) AS p
GROUP BY build_month
```

First event per unit (unit-level, not claim-level):

```sql
SELECT PRODUCT_ID, MIN(REPAIR_OPEN_DATE) AS first_dt
FROM QASMartStore.CLAIM
WHERE PRIM_LABOR_CD_RK = {{labor_rk}}
GROUP BY PRODUCT_ID
```

Days between two dates: `d2 - d1` on two DATE columns returns days (verified 2026-09-25; it
agrees with the precomputed `EVENT_DAYS_INSERVICE_BUILD`). `YEAR()` and `MONTH()` work. Re-test
both with a one-row query on a new tenant.

Full query templates: [../templates/fedsql/](../templates/fedsql/).

## Heavier work

Use `execute_sas_code` (interactive, ~120 s) or `submit_batch_job` + `get_job_status` for
procedures (PROC LIFEREG for Weibull, PROC FREQ for stratified χ², text mining). On failure read
`get_job_log` and fix the cause; don't retry blindly. Write only to a scratch caslib/library,
never to `QASMartStore`.
