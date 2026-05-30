-- =============================================================================
-- 00_bootstrap.sql — one-time setup per trial account
-- =============================================================================
-- Prereqs: ACCOUNTADMIN role. Cortex enabled (default on trials).
-- Idempotent: safe to rerun.
--
-- PARAMETERIZATION: run via `scripts/deploy.py` which sources `.env` and
-- substitutes variables: ${TARGET_DB}, ${TARGET_WH}.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS ${TARGET_DB}
    COMMENT = 'PawCore demo — CoCo + dbt + DCM webinar';

CREATE WAREHOUSE IF NOT EXISTS ${TARGET_WH}
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE;

USE DATABASE ${TARGET_DB};
USE WAREHOUSE ${TARGET_WH};

CREATE SCHEMA IF NOT EXISTS ${TARGET_DB}.PUBLIC;
USE SCHEMA PUBLIC;

-- =============================================================================
-- Internal stage for raw CSVs (populated by deploy.py via snow stage copy)
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS ${TARGET_DB}.RAW
    COMMENT = 'RAW landing zone (also created by DCM)';

CREATE STAGE IF NOT EXISTS ${TARGET_DB}.RAW.PAWCORE_DATA_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Landing stage for PawCore CSVs (uploaded from repo data/ folder)';
