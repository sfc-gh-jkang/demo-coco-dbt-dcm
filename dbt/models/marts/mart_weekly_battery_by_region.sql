{{ config(materialized='table') }}

-- Battery performance trend by region, week over week.
-- Answers: "How is battery performance trending by region week over week?"
-- Telemetry truncated to week in a CTE, then aggregated per week × region.

WITH weekly_telemetry AS (
    SELECT
        CAST(DATE_TRUNC('week', timestamp) AS DATE) AS week_start,
        region,
        battery_level,
        device_id
    FROM {{ ref('stg_telemetry') }}
)

SELECT
    week_start,
    region,
    AVG(battery_level)          AS avg_battery_level,
    MIN(battery_level)          AS min_battery_level,
    COUNT(DISTINCT device_id)   AS device_count
FROM weekly_telemetry
GROUP BY week_start, region
ORDER BY week_start, region
