-- Preflight for Failure Relationships: does the domain line table cover the target code?
-- coverage = units_with_domain_rows / claim_units_with_target. Pass: >= 0.5.
-- Placeholders: {{cohort_where_p}} on PRODUCT alias p, {{target_filter_c}} on CLAIM alias c
--   (e.g. c.PRIM_REPL_PART_CD_RK = 93), {{domain_table}} (QASMartStore.PART | QASMartStore.LABOR),
--   {{domain_filter_pt}} on the domain table alias pt (e.g. pt.REPL_PART_CD_RK = 93)
-- Uses joins only: FedSQL on CAS rejects IN (subquery).
-- Verified on the reference tenant 2026-09-25 (PART domain, part 9-040, Galacto builds >= 2019-10-01):
--   610 claim-level units, 2 with PART rows (3 PART lines cohort-wide) -> coverage 0.003 -> FAIL.
SELECT COUNT(*) AS claim_units_with_target,
       SUM(CASE WHEN dl.n_lines IS NOT NULL THEN 1 ELSE 0 END) AS units_with_domain_rows,
       SUM(CASE WHEN dl.n_lines IS NOT NULL THEN dl.n_lines ELSE 0 END) AS domain_rows
FROM ( SELECT DISTINCT c.PRODUCT_ID
       FROM QASMartStore.CLAIM AS c
       INNER JOIN QASMartStore.PRODUCT AS p ON c.PRODUCT_ID = p.PRODUCT_ID
       WHERE {{cohort_where_p}} AND {{target_filter_c}} ) AS t
LEFT JOIN ( SELECT cl.PRODUCT_ID, COUNT(*) AS n_lines
            FROM {{domain_table}} AS pt
            INNER JOIN QASMartStore.CLAIM AS cl ON pt.EVENT_ID = cl.EVENT_ID
            WHERE {{domain_filter_pt}}
            GROUP BY cl.PRODUCT_ID ) AS dl ON t.PRODUCT_ID = dl.PRODUCT_ID
