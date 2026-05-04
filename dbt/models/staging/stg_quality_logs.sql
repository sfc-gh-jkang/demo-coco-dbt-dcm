{{ config(materialized='view') }}

-- stg_quality_logs — typed passthrough of RAW.QUALITY_LOGS.

SELECT
    CAST(lot_number AS VARCHAR(50))         AS lot_number,
    CAST(timestamp AS TIMESTAMP)            AS timestamp,
    CAST(test_type AS VARCHAR(100))         AS test_type,
    CAST(measurement_value AS FLOAT)        AS measurement_value,
    CAST(UPPER(pass_fail) AS VARCHAR(10))   AS pass_fail,
    CAST(operator_id AS VARCHAR(50))        AS operator_id,
    CAST(station_id AS VARCHAR(50))         AS station_id,
    CAST(test_name AS VARCHAR(100))         AS test_name,
    CAST(notes AS TEXT)                     AS notes
FROM {{ source('raw', 'quality_logs') }}
WHERE lot_number IS NOT NULL
