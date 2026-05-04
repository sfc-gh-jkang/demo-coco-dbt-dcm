-- =============================================================================
-- create_agent.sql — Snowflake Intelligence agent setup
-- =============================================================================
-- Creates PAWCORE_ASSISTANT agent in the GLOBAL SNOWFLAKE_INTELLIGENCE.AGENTS
-- schema (where Snowsight's "AI & ML → Snowflake Intelligence" UI looks).
--
-- The agent reads from the per-deploy semantic view at
-- ${TARGET_DB}.SEMANTIC.PAWCORE_ANALYSIS.
--
-- PREREQ: snowflake/create_semantic_view.sql must have run first.
--
-- NOTE: agents must live in SNOWFLAKE_INTELLIGENCE.AGENTS (a SHARED, account-level
-- location) for Snowsight UI discoverability. We don't put them in TARGET_DB
-- because the Intelligence UI doesn't surface per-DB agents.
--
-- Parameterized via ${TARGET_DB} envsubst.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE ${TARGET_WH};

-- Ensure the GLOBAL Snowflake Intelligence schema exists
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE
    COMMENT = 'Account-level home for Snowflake Intelligence agents';
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS
    COMMENT = 'Discovery schema for Snowflake Intelligence agents (Snowsight reads here)';

GRANT USAGE ON DATABASE SNOWFLAKE_INTELLIGENCE TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS TO ROLE PUBLIC;
GRANT CREATE AGENT ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS TO ROLE ACCOUNTADMIN;

-- =============================================================================
-- Create agent pointing at the per-deploy semantic view
-- =============================================================================

CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.PAWCORE_ASSISTANT
WITH PROFILE='{"display_name": "PawCore Assistant"}'
    COMMENT='Senior business analyst for PawCore smart pet collars. Investigates quality, customer, and operational issues using the dbt-built marts.'
FROM SPECIFICATION $$
{
  "models": {
    "orchestration": "auto"
  },
  "instructions": {
    "response": "You are a senior business analyst for PawCore, a smart pet collar manufacturer. When asked a business question, look at multiple perspectives (manufacturing + field + customer) before answering. Focus on LOT341/EMEA as the known problematic area. Always cross-reference the marts to find the 'why' behind the numbers. Respond in clear, concise English with specific metrics and actionable recommendations.",
    "orchestration": "When investigating issues, always: (1) check manufacturing quality (mart_lot_quality_correlation), (2) check field telemetry (telemetry table + mart_battery_moisture_correlation), (3) check customer impact (mart_regional_customer_impact, customer_reviews). Cross-reference findings across these sources before concluding.",
    "sample_questions": [
      {"question": "Which lot has the worst customer ratings, and why?"},
      {"question": "Is there a correlation between humidity and battery life?"},
      {"question": "If you were head of product, what would you recommend we do next?"}
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "pawcore_analysis_tool",
        "description": "Use this tool for any question about PawCore devices, quality, customers, or operational metrics. Queries structured data across telemetry, quality logs, reviews, and pre-computed analytical marts."
      }
    }
  ],
  "tool_resources": {
    "pawcore_analysis_tool": {
      "semantic_view": "${TARGET_DB}.SEMANTIC.PAWCORE_ANALYSIS"
    }
  }
}
$$;

-- =============================================================================
-- Grants
-- =============================================================================

GRANT USAGE ON AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.PAWCORE_ASSISTANT TO ROLE PUBLIC;

-- =============================================================================
-- Verify
-- =============================================================================

SHOW AGENTS IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS;

SELECT 'AGENT CREATED' AS status,
       'SNOWFLAKE_INTELLIGENCE.AGENTS.PAWCORE_ASSISTANT' AS agent_fqn,
       'Open Snowsight → AI & ML → Snowflake Intelligence → PawCore Assistant' AS next_step;
