-- =============================================================================
-- run_pipeline.sql — execute dbt build + smoke-test HOL-shape tables
-- =============================================================================
-- Runs AFTER snowflake/create_dbt_project.sql.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ${TARGET_DB};
USE WAREHOUSE ${TARGET_WH};

-- Install packages (dbt_utils) — packages vendored in /dbt/dbt_packages
-- so this is a no-op in most cases but kept for future package additions.
-- EXECUTE DBT PROJECT ${TARGET_DB}.PUBLIC.PAWCORE_DBT args='deps';

-- Full build: staging views → HOL tables → marts + run all tests
EXECUTE DBT PROJECT ${TARGET_DB}.PUBLIC.PAWCORE_DBT args='build';

-- =============================================================================
-- Smoke tests — confirm HOL-shape tables landed correctly
-- =============================================================================

SELECT 'TELEMETRY'         AS hol_table, COUNT(*) AS row_count FROM ${TARGET_DB}.DEVICE_DATA.TELEMETRY
UNION ALL SELECT 'QUALITY_LOGS',     COUNT(*) FROM ${TARGET_DB}.MANUFACTURING.QUALITY_LOGS
UNION ALL SELECT 'CUSTOMER_REVIEWS', COUNT(*) FROM ${TARGET_DB}.SUPPORT.CUSTOMER_REVIEWS
UNION ALL SELECT 'SLACK_MESSAGES',   COUNT(*) FROM ${TARGET_DB}.SUPPORT.SLACK_MESSAGES
ORDER BY hol_table;

-- Marts check
SELECT 'mart_lot_quality_correlation'       AS mart, COUNT(*) AS row_count FROM ${TARGET_DB}.ANALYTICS.MART_LOT_QUALITY_CORRELATION
UNION ALL SELECT 'mart_regional_customer_impact',    COUNT(*) FROM ${TARGET_DB}.ANALYTICS.MART_REGIONAL_CUSTOMER_IMPACT
UNION ALL SELECT 'mart_battery_moisture_correlation', COUNT(*) FROM ${TARGET_DB}.ANALYTICS.MART_BATTERY_MOISTURE_CORRELATION
ORDER BY mart;
