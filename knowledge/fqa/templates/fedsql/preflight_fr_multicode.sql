-- Preflight for Failure Relationships: share of cohort claim units with >= 2 distinct codes.
-- Pass: units_multi_code / claim_units >= 0.20 AND units_multi_code >= 200.
-- Placeholders: {{cohort_where_p}} on PRODUCT alias p, {{code_col}} on CLAIM alias c
--   LABOR domain / claim level: c.PRIM_LABOR_CD_RK
--   PART domain: join QASMartStore.PART on EVENT_ID and count REPL_PART_CD_RK instead
-- Verified on the reference tenant 2026-09-25 (Galacto builds >= 2019-04-01, primary labor code):
--   2705 of 5426 claim units (50 %) -> pass.
SELECT COUNT(*) AS claim_units,
       SUM(CASE WHEN n_codes >= 2 THEN 1 ELSE 0 END) AS units_multi_code
FROM ( SELECT c.PRODUCT_ID, COUNT(DISTINCT {{code_col}}) AS n_codes
       FROM QASMartStore.CLAIM AS c
       INNER JOIN QASMartStore.PRODUCT AS p ON c.PRODUCT_ID = p.PRODUCT_ID
       WHERE {{cohort_where_p}}
       GROUP BY c.PRODUCT_ID ) AS u
