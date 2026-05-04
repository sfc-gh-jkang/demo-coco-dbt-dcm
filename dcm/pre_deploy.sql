-- =============================================================================
-- DCM pre-deploy: parent objects DCM cannot own (its own parent DB + warehouse)
-- =============================================================================
-- Runs BEFORE `snow dcm plan`. Idempotent.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Parent database for the DCM project + all managed schemas
CREATE DATABASE IF NOT EXISTS PAWCORE_ANALYTICS
    COMMENT = 'PawCore demo — CoCo + dbt + DCM webinar (Expires: 2026-06-03)';

-- Warehouse matches the upstream PawCore HOL so downstream labs drop in unchanged
CREATE WAREHOUSE IF NOT EXISTS PAWCORE_DEMO_WH
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    COMMENT = 'PawCore demo warehouse (Expires: 2026-06-03)';

USE DATABASE PAWCORE_ANALYTICS;
USE WAREHOUSE PAWCORE_DEMO_WH;

-- PUBLIC schema is where the DCM_PROJECT object itself lives (via manifest.yml)
CREATE SCHEMA IF NOT EXISTS PAWCORE_ANALYTICS.PUBLIC;
