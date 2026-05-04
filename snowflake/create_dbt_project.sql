-- =============================================================================
-- create_dbt_project.sql — register the dbt project as a Snowflake DBT PROJECT
-- object sourced from the demo repo's /dbt subdirectory.
-- =============================================================================
-- Runs AFTER bootstrap/00_bootstrap.sql (which creates DEMO_REPO git repo).
-- Re-fetches the git repo first to pick up local dev changes.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ${TARGET_DB};
USE WAREHOUSE ${TARGET_WH};
USE SCHEMA PUBLIC;

-- Pull latest from git
ALTER GIT REPOSITORY ${TARGET_DB}.PUBLIC.DEMO_REPO FETCH;

-- Register dbt project as a Snowflake object, rooted at /dbt in the repo
CREATE OR REPLACE DBT PROJECT ${TARGET_DB}.PUBLIC.PAWCORE_DBT
    FROM @${TARGET_DB}.PUBLIC.DEMO_REPO/branches/main/dbt/
    COMMENT = 'PawCore dbt project — staging → HOL-shape → marts';

SHOW DBT PROJECTS LIKE 'PAWCORE_DBT' IN SCHEMA ${TARGET_DB}.PUBLIC;
