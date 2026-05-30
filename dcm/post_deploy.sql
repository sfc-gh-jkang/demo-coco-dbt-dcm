-- =============================================================================
-- DCM post-deploy: runs AFTER `snow dcm deploy`.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Confirm schemas are in place before dbt runs next
SHOW SCHEMAS IN DATABASE ${TARGET_DB};
