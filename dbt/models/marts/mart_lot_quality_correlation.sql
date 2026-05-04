{{ config(materialized='table') }}

-- Manufacturing × field-performance correlation by lot.
-- Mirrors agent verified query `manufacturing_field_performance_correlation`.

WITH quality_metrics AS (
    SELECT
        lot_number,
        COUNT(*)                                                     AS test_count,
        SUM(CASE WHEN pass_fail = 'PASS' THEN 1 ELSE 0 END)          AS pass_count,
        SUM(CASE WHEN pass_fail = 'FAIL' THEN 1 ELSE 0 END)          AS failure_count,
        AVG(CASE WHEN pass_fail = 'PASS' THEN 100.0 ELSE 0 END)      AS pass_rate
    FROM {{ ref('stg_quality_logs') }}
    GROUP BY lot_number
),

field_metrics AS (
    SELECT
        lot_number,
        MIN(timestamp)                                               AS field_start_date,
        MAX(timestamp)                                               AS field_end_date,
        COUNT(DISTINCT device_id)                                    AS device_count,
        AVG(battery_level)                                           AS avg_battery_level,
        AVG(temperature)                                             AS avg_temperature,
        AVG(humidity_reading)                                        AS avg_humidity,
        SUM(CASE WHEN battery_level < 20 THEN 1 ELSE 0 END)          AS low_battery_incidents
    FROM {{ ref('stg_telemetry') }}
    GROUP BY lot_number
)

SELECT
    q.lot_number,
    q.test_count,
    q.pass_count,
    q.failure_count,
    q.pass_rate,
    f.field_start_date,
    f.field_end_date,
    f.device_count,
    f.avg_battery_level,
    f.avg_temperature,
    f.avg_humidity,
    f.low_battery_incidents
FROM quality_metrics q
LEFT JOIN field_metrics f
    ON q.lot_number = f.lot_number
ORDER BY q.lot_number
