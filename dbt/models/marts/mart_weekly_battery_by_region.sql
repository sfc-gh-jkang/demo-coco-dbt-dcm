{{ config(materialized='table') }}

-- mart_weekly_battery_by_region.sql — Activity 2 (Option A)
-- Business question: "How is battery performance trending by region week over week?"
-- Pre-aggregates stg_telemetry to one row per (week_start, region).

WITH weekly AS (
    SELECT
        DATE_TRUNC('week', timestamp)        AS week_start,
        region,
        battery_level,
        device_id
    FROM {{ ref('stg_telemetry') }}
),

aggregated AS (
    SELECT
        week_start,
        region,
        ROUND(AVG(battery_level), 2)         AS avg_battery_level,
        ROUND(MIN(battery_level), 2)         AS min_battery_level,
        COUNT(DISTINCT device_id)            AS device_count
    FROM weekly
    GROUP BY week_start, region
)

SELECT
    week_start,
    region,
    avg_battery_level,
    min_battery_level,
    device_count
FROM aggregated
ORDER BY week_start, region
