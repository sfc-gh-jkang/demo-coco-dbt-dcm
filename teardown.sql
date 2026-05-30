-- =============================================================================
-- teardown.sql — drop all demo objects. Safe to rerun.
-- =============================================================================
-- NOTE: Contains ${TARGET_DB} / ${TARGET_WH} placeholders. Run via:
--   uv run scripts/deploy.py --teardown   (future)
-- Or substitute manually:
--   sed "s/\${TARGET_DB}/PAWCORE_ANALYTICS/g; s/\${TARGET_WH}/PAWCORE_DEMO_WH/g" teardown.sql | snow sql -c <conn> -i
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- The agent lives in the GLOBAL SNOWFLAKE_INTELLIGENCE.AGENTS schema
DROP AGENT IF EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS.PAWCORE_ASSISTANT;

-- The pipeline DB + warehouse
DROP DATABASE IF EXISTS ${TARGET_DB};
DROP WAREHOUSE IF EXISTS ${TARGET_WH};

SELECT 'TEARDOWN COMPLETE' AS status, CURRENT_TIMESTAMP() AS completed_at;
