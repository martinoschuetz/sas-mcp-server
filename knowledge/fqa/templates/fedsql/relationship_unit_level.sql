-- Unit-level failure relationship A -> B within a window (phase 3, RELATE).
-- First A claim vs. first B claim on the same unit, by REPAIR_OPEN_DATE. Counts UNITS, never claim pairs.
-- Placeholders: {{cohort_where}} on PRODUCT (e.g. MODEL_CD_RK = 8 AND PRODUCTION_DATE >= DATE '2019-10-01'),
--               {{a_filter}}, {{b_filter}} on CLAIM (e.g. PRIM_LABOR_CD_RK = 100), {{window_days}} (default 90)
-- Derived in the caller:
--   confidence = support_before / units_a
--   lift       = confidence / (units_b / cohort_units)
--   keep pair if support >= 10, confidence >= 0.2, lift >= 2.0
-- Cohort rule: model-level cohort of the scoped build periods (alert + baseline, all parts).
-- Verified on the reference tenant 2026-09-25 (Galacto builds >= 2019-10-01, I-011 -> I-007):
--   cohort 7668, units_a 75, units_b 77, support_before 21 (conf 0.28, lift ~28), support_after 0.
SELECT COUNT(*) AS cohort_units,
       SUM(CASE WHEN a.first_a IS NOT NULL THEN 1 ELSE 0 END) AS units_a,
       SUM(CASE WHEN b.first_b IS NOT NULL THEN 1 ELSE 0 END) AS units_b,
       SUM(CASE WHEN a.first_a IS NOT NULL AND b.first_b IS NOT NULL
                 AND b.first_b - a.first_a >= 0
                 AND b.first_b - a.first_a <= {{window_days}} THEN 1 ELSE 0 END) AS support_before,
       SUM(CASE WHEN a.first_a IS NOT NULL AND b.first_b IS NOT NULL
                 AND a.first_a - b.first_b >= 0
                 AND a.first_a - b.first_b <= {{window_days}} THEN 1 ELSE 0 END) AS support_after
FROM ( SELECT PRODUCT_ID FROM QASMartStore.PRODUCT
       WHERE {{cohort_where}} ) AS c
LEFT JOIN ( SELECT PRODUCT_ID, MIN(REPAIR_OPEN_DATE) AS first_a
            FROM QASMartStore.CLAIM WHERE {{a_filter}}
            GROUP BY PRODUCT_ID ) AS a ON c.PRODUCT_ID = a.PRODUCT_ID
LEFT JOIN ( SELECT PRODUCT_ID, MIN(REPAIR_OPEN_DATE) AS first_b
            FROM QASMartStore.CLAIM WHERE {{b_filter}}
            GROUP BY PRODUCT_ID ) AS b ON c.PRODUCT_ID = b.PRODUCT_ID
