{{ config(materialized='view') }}

-- stg_customer_reviews — typed + enriched with REAL device_id/lot_number from
-- the telemetry device pool (not fictional hardcoded mappings).
--
-- Per-region round-robin device assignment guarantees every synthetic
-- device_id actually exists in stg_telemetry — enforced by the
-- `relationships` test in __staging.yml.

WITH raw_reviews AS (
    SELECT
        review_id,
        CAST(rating AS INTEGER) AS rating,
        CAST(review_text AS TEXT) AS review_text,
        CAST(date AS DATE) AS date,
        CAST(UPPER(region) AS VARCHAR(50)) AS region
    FROM {{ source('raw', 'customer_reviews') }}
    WHERE review_id IS NOT NULL
),

reviews_ranked AS (
    SELECT
        review_id, rating, review_text, date, region,
        ROW_NUMBER() OVER (PARTITION BY region ORDER BY TRY_CAST(review_id AS INTEGER), review_id) AS review_rank
    FROM raw_reviews
),

pool AS (
    -- Case-insensitive join on region so 'EMEA' / 'Americas' / 'APAC' from
    -- telemetry (mixed case, uppercased in stg_telemetry) align with the
    -- already-uppercased raw_reviews.region.
    SELECT UPPER(region) AS region_upper, lot_number, device_id, device_rank, region_device_count
    FROM {{ ref('int_region_lot_device_pool') }}
)

SELECT
    r.review_id,
    p.device_id,
    p.lot_number,
    r.rating,
    r.review_text,
    r.date,
    r.region
FROM reviews_ranked r
LEFT JOIN pool p
    ON r.region = p.region_upper
   AND MOD(r.review_rank - 1, p.region_device_count) + 1 = p.device_rank
