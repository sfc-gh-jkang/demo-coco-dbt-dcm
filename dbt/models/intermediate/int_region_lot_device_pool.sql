{{ config(materialized='view') }}

-- Derived from actual telemetry: every (region, lot_number, device_id) triple
-- that exists in the device data. Assigns a stable rank per region so
-- downstream review assignment is deterministic and repeatable.
--
-- This replaces the brittle hardcoded CASE mapping that previously lived in
-- stg_customer_reviews.sql (which invented lot numbers that don't exist).

SELECT
    region,
    lot_number,
    device_id,
    ROW_NUMBER() OVER (PARTITION BY region ORDER BY device_id) AS device_rank,
    COUNT(*)   OVER (PARTITION BY region)                       AS region_device_count
FROM (
    SELECT DISTINCT region, lot_number, device_id
    FROM {{ ref('stg_telemetry') }}
    WHERE device_id IS NOT NULL
      AND lot_number IS NOT NULL
      AND region IS NOT NULL
)
