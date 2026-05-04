{{
    config(
        materialized='table',
        alias='QUALITY_LOGS'
    )
}}

-- HOL-compatible: PAWCORE_ANALYTICS.MANUFACTURING.QUALITY_LOGS
-- Matches upstream HOL pawcore_setup.sql line 253-263.

SELECT
    lot_number,
    timestamp,
    test_type,
    measurement_value,
    pass_fail,
    operator_id,
    station_id,
    test_name,
    notes
FROM {{ ref('stg_quality_logs') }}
