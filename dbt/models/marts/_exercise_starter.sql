{{
    config(
        enabled=false,
        materialized='table',
        alias='MART_RENAME_ME'
    )
}}

-- =============================================================================
-- mart_<rename_me>.sql — Activity 2 starter template
-- =============================================================================
-- IMPORTANT: this template is disabled (enabled=false) so dbt doesn't try to
-- compile the placeholder refs. When you copy this to a new file:
--   1. Remove the `enabled=false` line from the config block
--   2. Rename the file to match your chosen business question:
--      - mart_weekly_battery_by_region.sql    (Option A)
--      - mart_top10_problematic_devices.sql   (Option B)
--      - mart_device_age_cohort_analysis.sql  (Option C)
--   3. Update the alias to match (uppercase)
--   4. Replace the placeholder SELECT with your real query
--
-- STYLE RULES (match existing marts):
--   1. Use CTEs to separate logic (don't inline subqueries in JOINs)
--   2. Pre-aggregate source tables BEFORE joining to avoid fanout
--   3. Reference staging models with ref('stg_...') — never hit RAW directly
--   4. ORDER BY at the end for stable demo output
-- =============================================================================

-- The line below uses a placeholder staging ref. Replace with a real one
-- (e.g. stg_telemetry, stg_quality_logs, stg_customer_reviews).
WITH source_data AS (
    SELECT 1 AS placeholder
    -- Real pattern (uncomment + adapt):
    -- FROM {{ ref('stg_telemetry') }}
)

SELECT * FROM source_data
