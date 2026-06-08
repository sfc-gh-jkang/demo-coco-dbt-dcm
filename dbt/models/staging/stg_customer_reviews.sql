{{ config(materialized='view') }}

-- stg_customer_reviews — typed and filtered.
-- device_id and lot_number come directly from the source CSV (no synthetic mapping).

SELECT
    review_id,
    CAST(device_id AS VARCHAR(50)) AS device_id,
    CAST(lot_number AS VARCHAR(20)) AS lot_number,
    CAST(rating AS INTEGER) AS rating,
    CAST(review_text AS TEXT) AS review_text,
    CAST(date AS DATE) AS date,
    CAST(UPPER(region) AS VARCHAR(50)) AS region
FROM {{ source('raw', 'customer_reviews') }}
WHERE review_id IS NOT NULL
