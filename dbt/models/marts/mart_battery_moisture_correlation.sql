{{ config(materialized='table') }}

-- Humidity × battery performance correlation with moisture test measurements.
-- Mirrors agent verified query `moisture_battery_correlation`.

SELECT
    t.lot_number,
    t.region,
    AVG(t.humidity_reading)             AS avg_humidity,
    AVG(t.battery_level)                AS avg_battery,
    COUNT(DISTINCT t.device_id)         AS device_count,
    AVG(CASE WHEN q.test_type = 'MOISTURE_RESISTANCE'
             THEN q.measurement_value END) AS moisture_resistance
FROM {{ ref('stg_telemetry') }} t
JOIN {{ ref('stg_quality_logs') }} q
    ON t.lot_number = q.lot_number
GROUP BY t.lot_number, t.region
ORDER BY avg_battery ASC
