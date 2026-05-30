-- =============================================================================
-- 01_load_raw.sql — load PawCore CSVs from internal stage into RAW.* tables
-- =============================================================================
-- Run AFTER deploy.py uploads data/ to @PAWCORE_DATA_STAGE via snow stage copy.
-- Idempotent: CREATE OR REPLACE on tables, COPY with FORCE=TRUE.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ${TARGET_DB};
USE WAREHOUSE ${TARGET_WH};
USE SCHEMA RAW;

-- =============================================================================
-- 1. Create RAW.* tables (minimal — dbt staging does the typing + cleanup)
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
-- 2. COPY INTO from internal stage (populated by deploy.py snow stage copy)
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

-- Customer reviews
-- CSV column layout: $1=review_id, $2=product, $3=region, $4=date, $5=review_text, $6=rating
-- device_id + lot_number are NULL in raw; dbt stg_customer_reviews populates them.
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

-- =============================================================================
-- 3. Verify raw load
-- =============================================================================

SELECT 'RAW.TELEMETRY'         AS table_name, COUNT(*) AS row_count FROM RAW.TELEMETRY
UNION ALL SELECT 'RAW.QUALITY_LOGS',     COUNT(*) FROM RAW.QUALITY_LOGS
UNION ALL SELECT 'RAW.CUSTOMER_REVIEWS', COUNT(*) FROM RAW.CUSTOMER_REVIEWS
UNION ALL SELECT 'RAW.SLACK_MESSAGES',   COUNT(*) FROM RAW.SLACK_MESSAGES
ORDER BY table_name;
