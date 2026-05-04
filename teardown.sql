-- =============================================================================
-- teardown.sql — drop all demo objects. Safe to rerun.
-- =============================================================================
-- Note: this removes ALL PawCore objects, including the global
-- SNOWFLAKE_INTELLIGENCE.AGENTS.PAWCORE_ASSISTANT agent and its semantic view.
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- The agent lives in the GLOBAL SNOWFLAKE_INTELLIGENCE.AGENTS schema
DROP AGENT IF EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS.PAWCORE_ASSISTANT;

-- The pipeline DB + warehouse + API integration
DROP DATABASE IF EXISTS PAWCORE_ANALYTICS;
DROP WAREHOUSE IF EXISTS PAWCORE_DEMO_WH;
DROP API INTEGRATION IF EXISTS pawcore_github_api;

SELECT 'TEARDOWN COMPLETE' AS status, CURRENT_TIMESTAMP() AS completed_at;
