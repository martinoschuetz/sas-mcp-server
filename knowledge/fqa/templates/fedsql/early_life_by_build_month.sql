-- Early-life rate of the alert-defining event by build month (phase 4, NORMALIZE).
-- Unit-level: first qualifying claim per unit. Run via query_data (target='cas').
-- Placeholders: {{model_rk}}, {{event_filter}} (e.g. PRIM_REPL_PART_CD_RK = 93), {{from_date}} (YYYY-MM-DD)
-- Output: build_month (YYYYMM), units_built, units_lt30, units_lt90. Rates = units_ltN / units_built.
-- Afterwards: flag months with < 90 days of exposure at the data refresh date as immature;
-- step_month = first month whose 90-day rate >= 3 x the baseline rate.
-- Verified on the reference tenant 2026-09-25 (Galacto, part 9-040): Oct 2019 224/2073, Nov 294/2215.
-- NOTE: the IS NOT NULL guards are required: a missing value compares LOWER than any number.
SELECT p.build_month,
       COUNT(*) AS units_built,
       SUM(CASE WHEN f.first_days IS NOT NULL AND f.first_days < 30 THEN 1 ELSE 0 END) AS units_lt30,
       SUM(CASE WHEN f.first_days IS NOT NULL AND f.first_days < 90 THEN 1 ELSE 0 END) AS units_lt90
FROM ( SELECT PRODUCT_ID,
              YEAR(PRODUCTION_DATE) * 100 + MONTH(PRODUCTION_DATE) AS build_month
       FROM QASMartStore.PRODUCT
       WHERE MODEL_CD_RK = {{model_rk}}
         AND PRODUCTION_DATE >= DATE '{{from_date}}' ) AS p
LEFT JOIN ( SELECT PRODUCT_ID, MIN(EVENT_DAYS_INSERVICE_BUILD) AS first_days
            FROM QASMartStore.CLAIM
            WHERE {{event_filter}}
            GROUP BY PRODUCT_ID ) AS f
  ON p.PRODUCT_ID = f.PRODUCT_ID
GROUP BY p.build_month
