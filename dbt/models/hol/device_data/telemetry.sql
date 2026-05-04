{{
    config(
        materialized='table',
        alias='TELEMETRY'
    )
}}

-- HOL-compatible: PAWCORE_ANALYTICS.DEVICE_DATA.TELEMETRY
-- Column order and types MUST match upstream HOL pawcore_setup.sql line 238-247.
-- The Cortex AI HOL agent's semantic view PAWCORE_ANALYSIS reads from here.

SELECT
    device_id,
    timestamp,
    battery_level,
    humidity_reading,
    temperature,
    charging_cycles,
    lot_number,
    region
FROM {{ ref('stg_telemetry') }}
