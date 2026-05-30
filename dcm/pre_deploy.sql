-- =============================================================================
-- DCM pre-deploy: parent objects DCM cannot own (its own parent DB + warehouse)
-- =============================================================================
-- Runs BEFORE `snow dcm deploy`. Idempotent.
-- ${TARGET_DB} / ${TARGET_WH} substituted by deploy.py at build time.
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
