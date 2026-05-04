{{
    config(
        materialized='table',
        alias='CUSTOMER_REVIEWS'
    )
}}

-- HOL-compatible: PAWCORE_ANALYTICS.SUPPORT.CUSTOMER_REVIEWS
-- Matches upstream HOL pawcore_setup.sql line 269-277.
-- Column name `date` (NOT `review_date`) — semantic view depends on this.

SELECT
    review_id,
    device_id,
    lot_number,
    rating,
    review_text,
    date,
    region
FROM {{ ref('stg_customer_reviews') }}
