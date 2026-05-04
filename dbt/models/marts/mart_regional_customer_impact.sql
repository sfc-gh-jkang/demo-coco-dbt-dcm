{{ config(materialized='table') }}

-- Customer satisfaction × device telemetry by lot × region.
-- Mirrors agent verified query `customer_impact_analysis`.
-- Telemetry pre-aggregated by device to avoid review-row fanout.

WITH device_battery AS (
    SELECT device_id, AVG(battery_level) AS avg_battery_level
    FROM {{ ref('stg_telemetry') }}
    GROUP BY device_id
)

SELECT
    cr.lot_number,
    cr.region,
    AVG(cr.rating)                   AS avg_rating,
    COUNT(*)                         AS review_count,
    AVG(db.avg_battery_level)        AS avg_battery_level,
    COUNT(DISTINCT cr.device_id)     AS device_count
FROM {{ ref('stg_customer_reviews') }} cr
LEFT JOIN device_battery db
    ON cr.device_id = db.device_id
GROUP BY cr.lot_number, cr.region
ORDER BY avg_rating ASC
