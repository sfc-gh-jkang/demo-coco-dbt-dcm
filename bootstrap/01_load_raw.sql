-- =============================================================================
-- 01_load_raw.sql — load PawCore CSVs from upstream HOL repo into RAW.* tables
-- =============================================================================
-- Run AFTER `snow dcm deploy` (so STAGING, DEVICE_DATA, MANUFACTURING, SUPPORT,
-- ANALYTICS, SEMANTIC schemas all exist).
-- Idempotent: CREATE OR REPLACE on tables, COPY with FORCE=TRUE.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ${TARGET_DB};
USE WAREHOUSE ${TARGET_WH};

-- Speed up the COPY FILES step
ALTER WAREHOUSE ${TARGET_WH} SET WAREHOUSE_SIZE = 'MEDIUM';

-- =============================================================================
-- 1. Copy CSVs from git repo into internal stage
-- =============================================================================

USE SCHEMA RAW;

COPY FILES
INTO @PAWCORE_DATA_STAGE/Telemetry/
FROM @${TARGET_DB}.PUBLIC.UPSTREAM_HOL_REPO/branches/main/2-Cortex-Code/data/Telemetry/;

COPY FILES
INTO @PAWCORE_DATA_STAGE/Manufacturing/
FROM @${TARGET_DB}.PUBLIC.UPSTREAM_HOL_REPO/branches/main/2-Cortex-Code/data/Manufacturing/;

COPY FILES
INTO @PAWCORE_DATA_STAGE/Document_Stage/
FROM @${TARGET_DB}.PUBLIC.UPSTREAM_HOL_REPO/branches/main/2-Cortex-Code/data/Document_Stage/;

LIST @PAWCORE_DATA_STAGE;

-- =============================================================================
-- 2. Create RAW.* tables (minimal — dbt staging does the typing + cleanup)
-- =============================================================================

CREATE OR REPLACE TABLE RAW.TELEMETRY (
    device_id VARCHAR(50),
    timestamp TIMESTAMP,
    battery_level FLOAT,
    humidity_reading FLOAT,
    temperature FLOAT,
    charging_cycles INTEGER,
    lot_number VARCHAR(50),
    region VARCHAR(50)
);

CREATE OR REPLACE TABLE RAW.QUALITY_LOGS (
    lot_number VARCHAR(50),
    timestamp TIMESTAMP,
    test_type VARCHAR(100),
    measurement_value FLOAT,
    pass_fail VARCHAR(10),
    operator_id VARCHAR(50),
    station_id VARCHAR(50),
    test_name VARCHAR(100),
    notes TEXT
);

CREATE OR REPLACE TABLE RAW.CUSTOMER_REVIEWS (
    review_id VARCHAR(50),
    device_id VARCHAR(50),
    lot_number VARCHAR(50),
    rating INTEGER,
    review_text TEXT,
    date DATE,
    region VARCHAR(50)
);

CREATE OR REPLACE TABLE RAW.SLACK_MESSAGES (
    message_id VARCHAR(50),
    slack_channel VARCHAR(50),
    user_name VARCHAR(100),
    text TEXT,
    thread_id VARCHAR(50)
);

-- =============================================================================
-- 3. COPY INTO — same logic as upstream HOL, but into RAW schema
-- =============================================================================

-- Telemetry
COPY INTO RAW.TELEMETRY (device_id, timestamp, battery_level, humidity_reading, temperature, charging_cycles, lot_number, region)
FROM (
    SELECT $1, $2, $3, $4, $5, $6, $7, $8
    FROM @PAWCORE_DATA_STAGE/Telemetry/
)
FILE_FORMAT = (
    TYPE = 'CSV' FIELD_DELIMITER = ',' SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('NULL', 'null') EMPTY_FIELD_AS_NULL = TRUE
    TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS'
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
)
PATTERN = '.*[.]csv'
ON_ERROR = 'CONTINUE'
FORCE = TRUE;

-- Quality logs
COPY INTO RAW.QUALITY_LOGS
FROM @PAWCORE_DATA_STAGE/Manufacturing/
FILE_FORMAT = (
    TYPE = 'CSV' FIELD_DELIMITER = ',' SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('NULL', 'null') EMPTY_FIELD_AS_NULL = TRUE
    TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS'
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    TRIM_SPACE = TRUE
)
PATTERN = '.*[.]csv'
ON_ERROR = 'CONTINUE'
FORCE = TRUE;

-- Customer reviews — lot_number CASE logic moved to dbt staging model.
-- Here we load the CSV as-is (lot_number may be null in the raw file).
-- Customer reviews. CSV column layout (from upstream repo): 
--   $1=review_id, $2=product, $3=region, $4=date, $5=review_text, $6=rating
-- device_id + lot_number are NULL in raw; dbt int_region_lot_device_pool +
-- stg_customer_reviews populate them from actual telemetry data.
COPY INTO RAW.CUSTOMER_REVIEWS (review_id, device_id, lot_number, rating, review_text, date, region)
FROM (
    SELECT
        $1 AS review_id,
        NULL AS device_id,
        NULL AS lot_number,
        $6 AS rating,
        $5 AS review_text,
        $4 AS date,
        $3 AS region
    FROM @PAWCORE_DATA_STAGE/Document_Stage/customer_reviews.csv
)
FILE_FORMAT = (
    TYPE = 'CSV' FIELD_DELIMITER = ',' SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('NULL', 'null') EMPTY_FIELD_AS_NULL = TRUE
    DATE_FORMAT = 'YYYY-MM-DD'
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
)
ON_ERROR = 'CONTINUE'
FORCE = TRUE;

-- Slack messages
COPY INTO RAW.SLACK_MESSAGES (message_id, slack_channel, user_name, text, thread_id)
FROM @PAWCORE_DATA_STAGE/Document_Stage/pawcore_slack.csv
FILE_FORMAT = (
    TYPE = 'CSV' FIELD_DELIMITER = ',' SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('NULL', 'null') EMPTY_FIELD_AS_NULL = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    TRIM_SPACE = TRUE
)
ON_ERROR = 'CONTINUE'
FORCE = TRUE;

-- Scale warehouse back down
ALTER WAREHOUSE ${TARGET_WH} SET WAREHOUSE_SIZE = 'XSMALL';

-- =============================================================================
-- 4. Verify raw load
-- =============================================================================

SELECT 'RAW.TELEMETRY'         AS table_name, COUNT(*) AS row_count FROM RAW.TELEMETRY
UNION ALL SELECT 'RAW.QUALITY_LOGS',     COUNT(*) FROM RAW.QUALITY_LOGS
UNION ALL SELECT 'RAW.CUSTOMER_REVIEWS', COUNT(*) FROM RAW.CUSTOMER_REVIEWS
UNION ALL SELECT 'RAW.SLACK_MESSAGES',   COUNT(*) FROM RAW.SLACK_MESSAGES
ORDER BY table_name;
