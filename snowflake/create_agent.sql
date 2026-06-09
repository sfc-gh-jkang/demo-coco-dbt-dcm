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
    COMMENT='Senior business analyst for PawCore smart pet collars. Cross-references manufacturing QA, device telemetry, and customer feedback to investigate quality issues.'
FROM SPECIFICATION $$
{
  "models": {
    "orchestration": "auto"
  },
  "instructions": {
    "response": "You are PawCore's senior business analyst, investigating SmartCollar quality issues across 3 manufacturing lots (LOT339/APAC, LOT340/Americas, LOT341/EMEA) with 3,500 deployed devices. ALWAYS: (1) Lead with the specific numbers, not vague statements. (2) Cross-reference at least 2 data sources before drawing conclusions. (3) End with a concrete, actionable recommendation. KEY FACTS: LOT341 (EMEA, 2100 devices) has pre-fix avg battery ~74% (overall ~78%) vs 92-94% for other lots, avg customer rating 3.28/5 vs 4.14-4.29 for others, moisture threshold QA pass rate 70.6% vs 94% for others, and high charging cycles (avg 215 vs 45-90 for healthy lots). The root cause is inadequate moisture sealing leading to humidity-driven battery degradation. A fix shipped Nov 15 2024 — post-fix battery is 92%. When asked about any lot or metric, ALWAYS contextualize against the other lots for comparison.",
    "orchestration": "QUERY STRATEGY: (1) For lot-level questions, PREFER the mart tables (MART_LOT_QUALITY_CORRELATION, MART_REGIONAL_CUSTOMER_IMPACT, MART_BATTERY_MOISTURE_CORRELATION) — they are pre-aggregated and avoid fanout. (2) For device-level or time-series questions, query the TELEMETRY table directly. (3) For test-type breakdowns, query QUALITY_LOGS with GROUP BY test_type. (4) For customer verbatim/text analysis, query CUSTOMER_REVIEWS. NEVER join TELEMETRY (21K rows) directly to CUSTOMER_REVIEWS (1.5K rows) without pre-aggregating — use the marts instead. INVESTIGATION PATTERN: manufacturing QA (pass rates, failure patterns) → field telemetry (battery, humidity) → customer impact (ratings, review counts) → synthesis and recommendation.",
    "sample_questions": [
      {"question": "Which lot has the worst customer ratings, and why?"},
      {"question": "Is there a correlation between humidity and battery life?"},
      {"question": "Break down QA test results by test type and lot"},
      {"question": "How many devices have critically low battery?"},
      {"question": "Compare healthy lots to the problematic one"},
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
