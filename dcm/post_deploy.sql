-- =============================================================================
-- DCM post-deploy: runs AFTER `snow dcm deploy`.
-- Reserved for future hooks (e.g., grants on objects that DCM created).
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Confirm schemas are in place before dbt runs next
SHOW SCHEMAS IN DATABASE PAWCORE_ANALYTICS;
