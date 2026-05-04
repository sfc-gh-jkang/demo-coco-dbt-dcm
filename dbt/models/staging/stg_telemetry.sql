{{ config(materialized='view') }}

-- stg_telemetry — typed passthrough of RAW.TELEMETRY.
-- Business logic (lot_number enrichment, region normalization) stays here.

SELECT
    CAST(device_id AS VARCHAR(50))          AS device_id,
    CAST(timestamp AS TIMESTAMP)            AS timestamp,
    CAST(battery_level AS FLOAT)            AS battery_level,
    CAST(humidity_reading AS FLOAT)         AS humidity_reading,
    CAST(temperature AS FLOAT)              AS temperature,
    CAST(charging_cycles AS INTEGER)        AS charging_cycles,
    CAST(lot_number AS VARCHAR(50))         AS lot_number,
    CAST(UPPER(region) AS VARCHAR(50))      AS region
FROM {{ source('raw', 'telemetry') }}
WHERE device_id IS NOT NULL
  AND timestamp IS NOT NULL
