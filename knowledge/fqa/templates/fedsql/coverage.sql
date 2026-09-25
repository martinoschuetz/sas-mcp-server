-- Coverage of a mechanism over the alert-defining population (D7 / hypothesis role).
-- alert-defining units = units in the alert build periods with a claim on the alert breakout.
-- A unit is "explained" when its first mechanism claim falls 0..window days BEFORE its first alert-defining claim.
-- Placeholders: {{cohort_where_p}} on PRODUCT alias p (e.g. p.MODEL_CD_RK = 8 AND p.PRODUCTION_DATE >= DATE '2019-10-01'),
--               {{defining_filter_c}} on CLAIM alias c (e.g. c.PRIM_REPL_PART_CD_RK = 93),
--               {{mechanism_filter}} on CLAIM (e.g. PRIM_LABOR_CD_RK = 100), {{window_days}} (default 90)
-- coverage = units_explained / alert_defining_units. >= 0.25 may be primary; < 0.25 is contributing.
-- Verified on the reference tenant 2026-09-25 (battery -> cable part): 38 / 610 = 0.062 (39 with any battery claim).
SELECT COUNT(*) AS alert_defining_units,
       SUM(CASE WHEN m.first_m IS NOT NULL THEN 1 ELSE 0 END) AS units_with_mech_any,
       SUM(CASE WHEN m.first_m IS NOT NULL
                 AND d.first_d - m.first_m >= 0
                 AND d.first_d - m.first_m <= {{window_days}} THEN 1 ELSE 0 END) AS units_explained
FROM ( SELECT c.PRODUCT_ID, MIN(c.REPAIR_OPEN_DATE) AS first_d
       FROM QASMartStore.CLAIM AS c
       INNER JOIN QASMartStore.PRODUCT AS p ON c.PRODUCT_ID = p.PRODUCT_ID
       WHERE {{cohort_where_p}} AND {{defining_filter_c}}
       GROUP BY c.PRODUCT_ID ) AS d
LEFT JOIN ( SELECT PRODUCT_ID, MIN(REPAIR_OPEN_DATE) AS first_m
            FROM QASMartStore.CLAIM WHERE {{mechanism_filter}}
            GROUP BY PRODUCT_ID ) AS m ON d.PRODUCT_ID = m.PRODUCT_ID
