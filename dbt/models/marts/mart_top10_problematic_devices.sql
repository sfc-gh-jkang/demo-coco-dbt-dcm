{{ config(materialized='table') }}

-- Top 10 highest-risk devices by combined battery + customer-satisfaction signal.
-- Answers: "Which 10 devices are showing the worst signals right now?"
--
-- FANOUT GUARD: stg_telemetry (~21K rows) is pre-aggregated to one row per device
-- in device_stats, and reviews are pre-aggregated per device_id in device_reviews,
-- BEFORE the join. Joining the raw tables directly would fan out to 21K x 1.5K rows.

WITH device_stats AS (
    SELECT
        device_id,
        lot_number,
        region,
        AVG(battery_level)                                      AS avg_battery_level,
        SUM(CASE WHEN battery_level < 20 THEN 1 ELSE 0 END)     AS low_battery_reading_count
    FROM {{ ref('stg_telemetry') }}
    GROUP BY device_id, lot_number, region
),

device_reviews AS (
    SELECT
        device_id,
        AVG(rating) AS avg_rating
    FROM {{ ref('stg_customer_reviews') }}
    GROUP BY device_id
)

SELECT
    d.device_id,
    d.lot_number,
    d.region,
    d.avg_battery_level,
    d.low_battery_reading_count,
    r.avg_rating,
    -- Missing reviews contribute no satisfaction penalty: COALESCE rating to 5 so
    -- (5 - rating) = 0 for un-reviewed devices and the score never goes NULL.
    (d.low_battery_reading_count * 3) + (5 - COALESCE(r.avg_rating, 5)) AS risk_score
FROM device_stats d
LEFT JOIN device_reviews r
    ON d.device_id = r.device_id
ORDER BY risk_score DESC
LIMIT 10
