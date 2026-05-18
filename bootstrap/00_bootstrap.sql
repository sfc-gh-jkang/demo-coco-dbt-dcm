-- =============================================================================
-- 00_bootstrap.sql — one-time setup per trial account
-- =============================================================================
-- Prereqs: ACCOUNTADMIN role. Cortex enabled (default on trials).
-- Idempotent: safe to rerun.
--
-- PARAMETERIZATION: run via `scripts/deploy.sh` which sources `.env` and
-- pipes through envsubst. Variables: ${TARGET_DB}, ${TARGET_WH},
-- ${GITHUB_USER}, ${GITHUB_PAT} (optional — only needed if you fork this
-- repo and keep your fork private; the upstream repo is public).
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS ${TARGET_DB}
    COMMENT = 'PawCore demo — CoCo + dbt + DCM webinar (Expires: 2026-09-03)';

CREATE WAREHOUSE IF NOT EXISTS ${TARGET_WH}
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE;

USE DATABASE ${TARGET_DB};
USE WAREHOUSE ${TARGET_WH};

CREATE SCHEMA IF NOT EXISTS ${TARGET_DB}.PUBLIC;
USE SCHEMA PUBLIC;

-- =============================================================================
-- Optional: PAT secret (only used if you fork this repo and keep your fork
-- private). Leaving GITHUB_PAT blank in .env creates an empty-password secret
-- that goes unused — harmless.
-- =============================================================================

CREATE OR REPLACE SECRET github_sfc_gh_jkang_pat
    TYPE = password
    USERNAME = '${GITHUB_USER}'
    PASSWORD = '${GITHUB_PAT}';

-- =============================================================================
-- Git integration
-- =============================================================================

CREATE OR REPLACE API INTEGRATION pawcore_github_api
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = (
        'https://github.com/calebaalexander/',
        'https://github.com/${GITHUB_USER}/'
    )
    ALLOWED_AUTHENTICATION_SECRETS = (github_sfc_gh_jkang_pat)
    ENABLED = TRUE
    COMMENT = 'GitHub API integration for PawCore demo';

-- Upstream repo (public)
CREATE OR REPLACE GIT REPOSITORY ${TARGET_DB}.PUBLIC.UPSTREAM_HOL_REPO
    API_INTEGRATION = pawcore_github_api
    ORIGIN = 'https://github.com/calebaalexander/HandsOnLabs.git'
    COMMENT = 'Upstream PawCore HOL repo — source of raw CSVs';
ALTER GIT REPOSITORY ${TARGET_DB}.PUBLIC.UPSTREAM_HOL_REPO FETCH;

-- Demo repo (public — no credentials needed)
CREATE OR REPLACE GIT REPOSITORY ${TARGET_DB}.PUBLIC.DEMO_REPO
    API_INTEGRATION = pawcore_github_api
    ORIGIN = 'https://github.com/${GITHUB_USER}/demo-coco-dbt-dcm.git'
    COMMENT = 'Demo repo — dbt project + DCM project sources';
ALTER GIT REPOSITORY ${TARGET_DB}.PUBLIC.DEMO_REPO FETCH;

-- =============================================================================
-- Internal stage for raw CSVs
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS ${TARGET_DB}.RAW
    COMMENT = 'RAW landing zone (also created by DCM)';

CREATE STAGE IF NOT EXISTS ${TARGET_DB}.RAW.PAWCORE_DATA_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Landing stage for PawCore HOL CSVs';

SHOW GIT REPOSITORIES IN SCHEMA ${TARGET_DB}.PUBLIC;
