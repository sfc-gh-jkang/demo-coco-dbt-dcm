-- =============================================================================
-- create_semantic_view.sql — semantic view over HOL tables + marts
-- =============================================================================
-- Creates ${TARGET_DB}.SEMANTIC.PAWCORE_ANALYSIS using native CREATE SEMANTIC
-- VIEW DDL (NOT the YAML stored procedure — that doesn't pipe cleanly through
-- snow sql).
--
-- Run AFTER the dbt build. Parameterized via envsubst — only ${TARGET_DB} and
-- ${TARGET_WH} are substituted; bare $name in code stays literal.
--
-- Reference: https://docs.snowflake.com/en/user-guide/views-semantic/sql
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ${TARGET_DB};
USE WAREHOUSE ${TARGET_WH};

-- Ensure schemas exist + grants for follow-on agent creation
CREATE SCHEMA IF NOT EXISTS ${TARGET_DB}.SEMANTIC;
CREATE SCHEMA IF NOT EXISTS ${TARGET_DB}.SNOWFLAKE_INTELLIGENCE;
GRANT USAGE ON SCHEMA ${TARGET_DB}.SEMANTIC TO ROLE ACCOUNTADMIN;
GRANT USAGE ON SCHEMA ${TARGET_DB}.SNOWFLAKE_INTELLIGENCE TO ROLE ACCOUNTADMIN;
GRANT CREATE AGENT ON SCHEMA ${TARGET_DB}.SNOWFLAKE_INTELLIGENCE TO ROLE ACCOUNTADMIN;
GRANT CREATE SEMANTIC VIEW ON SCHEMA ${TARGET_DB}.SEMANTIC TO ROLE ACCOUNTADMIN;

USE SCHEMA SEMANTIC;

-- =============================================================================
-- Semantic view DDL
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW ${TARGET_DB}.SEMANTIC.PAWCORE_ANALYSIS

  TABLES (
    telemetry AS ${TARGET_DB}.DEVICE_DATA.TELEMETRY
      PRIMARY KEY (device_id, timestamp)
      WITH SYNONYMS = ('device_telemetry', 'sensor_readings', 'device_data')
      COMMENT = 'Real-time SmartCollar telemetry — battery, humidity, temperature, charging cycles',

    quality_logs AS ${TARGET_DB}.MANUFACTURING.QUALITY_LOGS
      WITH SYNONYMS = ('manufacturing_tests', 'inspection_logs', 'quality_records')
      COMMENT = 'Manufacturing QA test pass/fail by lot',

    customer_reviews AS ${TARGET_DB}.SUPPORT.CUSTOMER_REVIEWS
      PRIMARY KEY (review_id)
      WITH SYNONYMS = ('product_reviews', 'feedback', 'ratings')
      COMMENT = 'Customer star ratings and review text',

    mart_lot AS ${TARGET_DB}.ANALYTICS.MART_LOT_QUALITY_CORRELATION
      PRIMARY KEY (lot_number)
      WITH SYNONYMS = ('lot_summary', 'lot_stats', 'manufacturing_field_correlation')
      COMMENT = 'Pre-computed per-lot QA + field-performance stats (one row per lot, fanout-safe)',

    mart_regional AS ${TARGET_DB}.ANALYTICS.MART_REGIONAL_CUSTOMER_IMPACT
      WITH SYNONYMS = ('regional_csat', 'customer_impact_by_region')
      COMMENT = 'Customer ratings by lot x region with device telemetry context (one row per lot+region)',

    mart_moisture AS ${TARGET_DB}.ANALYTICS.MART_BATTERY_MOISTURE_CORRELATION
      WITH SYNONYMS = ('humidity_battery', 'moisture_correlation')
      COMMENT = 'Battery level vs humidity readings + moisture resistance test results, by lot x region'
  )

  RELATIONSHIPS (
    reviews_to_lot AS
      customer_reviews (lot_number) REFERENCES mart_lot,
    telemetry_to_lot AS
      telemetry (lot_number) REFERENCES mart_lot,
    quality_to_lot AS
      quality_logs (lot_number) REFERENCES mart_lot
  )

  FACTS (
    telemetry.battery_value AS battery_level
      COMMENT = 'Single-reading battery level (0-100). Below 20 indicates device degradation.',
    telemetry.humidity_value AS humidity_reading
      COMMENT = 'Single-reading humidity (%). Above 70 correlates with device failures.',
    telemetry.temp_value AS temperature
      COMMENT = 'Single-reading temperature (degrees C).',
    telemetry.charging_cycles_count AS charging_cycles
      COMMENT = 'Charging cycles for this device. Higher = older device.',
    customer_reviews.rating_value AS rating
      COMMENT = 'Star rating (1-5).',
    quality_logs.measurement AS measurement_value
      COMMENT = 'Numeric test measurement.',
    quality_logs.pass_indicator AS CASE WHEN pass_fail = 'PASS' THEN 1 ELSE 0 END
      COMMENT = 'Binary 1/0 for pass/fail (used by pass_rate metric).'
  )

  DIMENSIONS (
    telemetry.lot_number AS lot_number
      WITH SYNONYMS = ('batch', 'production_lot', 'lot_id')
      COMMENT = 'Manufacturing lot. Known values: LOT339 (APAC, healthy), LOT340 (Americas, healthy), LOT341 (EMEA, PROBLEMATIC).',
    telemetry.region AS region
      WITH SYNONYMS = ('market', 'geography')
      COMMENT = 'Sales region. Values: AMERICAS, EMEA, APAC.',
    telemetry.timestamp AS timestamp
      COMMENT = 'Reading timestamp.',
    telemetry.device_identifier AS device_id
      COMMENT = 'Unique device identifier (SC-YYYY-LOT-NNN).',
    customer_reviews.review_date AS date
      COMMENT = 'Review submission date.',
    customer_reviews.review_region AS region
      COMMENT = 'Region of the reviewer. Values: AMERICAS, EMEA, APAC.',
    quality_logs.test_type AS test_type
      WITH SYNONYMS = ('test_category', 'test_kind')
      COMMENT = 'Type of QA test. Values: BATTERY_CAPACITY, MOISTURE_RESISTANCE, TEMPERATURE_RESISTANCE.',
    quality_logs.pass_fail AS pass_fail
      COMMENT = 'Test outcome. Values: PASS, FAIL.',
    quality_logs.test_lot AS lot_number
      COMMENT = 'Lot identifier on the QA side.',
    mart_lot.lot AS lot_number
      COMMENT = 'Lot identifier on the mart hub.',
    mart_regional.region AS region
      COMMENT = 'Region in the regional mart.',
    mart_regional.regional_lot AS lot_number
      COMMENT = 'Lot in the regional mart.'
  )

  METRICS (
    telemetry.avg_battery AS AVG(telemetry.battery_value)
      WITH SYNONYMS = ('average_battery', 'battery_health')
      COMMENT = 'Average battery level. Below 20 indicates device degradation.',
    telemetry.avg_humidity AS AVG(telemetry.humidity_value)
      COMMENT = 'Average ambient humidity reading.',
    telemetry.avg_temperature AS AVG(telemetry.temp_value)
      COMMENT = 'Average temperature reading.',
    telemetry.device_count AS COUNT(DISTINCT telemetry.device_identifier)
      COMMENT = 'Distinct device count.',
    telemetry.low_battery_incidents AS SUM(CASE WHEN telemetry.battery_value < 20 THEN 1 ELSE 0 END)
      COMMENT = 'Count of telemetry readings with battery below 20 percent.',
    customer_reviews.avg_rating AS AVG(customer_reviews.rating_value)
      WITH SYNONYMS = ('average_rating', 'csat', 'customer_satisfaction')
      COMMENT = 'Average star rating. Below 3 indicates dissatisfaction.',
    customer_reviews.review_count AS COUNT(*)
      COMMENT = 'Number of customer reviews.',
    customer_reviews.low_rating_count AS SUM(CASE WHEN customer_reviews.rating_value <= 2 THEN 1 ELSE 0 END)
      COMMENT = 'Number of unhappy customers (rating 1 or 2).',
    quality_logs.pass_rate AS AVG(quality_logs.pass_indicator) * 100
      WITH SYNONYMS = ('quality_pass_rate', 'qa_pass_rate')
      COMMENT = 'Manufacturing QA pass rate as percentage.',
    quality_logs.test_count AS COUNT(*)
      COMMENT = 'Total QA tests run.',
    quality_logs.failure_count AS SUM(CASE WHEN quality_logs.pass_indicator = 0 THEN 1 ELSE 0 END)
      COMMENT = 'Number of failed QA tests.'
  )

  COMMENT = 'PawCore SmartCollar pipeline. LOT341 (EMEA) is a known-problematic manufacturing batch — high humidity correlates with battery degradation and low customer ratings. Cross-reference manufacturing QA, field telemetry, and customer feedback by lot_number when investigating issues.';

-- =============================================================================
-- Verify + grants
-- =============================================================================

SHOW SEMANTIC VIEWS IN SCHEMA ${TARGET_DB}.SEMANTIC;

GRANT SELECT, REFERENCES ON SEMANTIC VIEW ${TARGET_DB}.SEMANTIC.PAWCORE_ANALYSIS TO ROLE ACCOUNTADMIN;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW ${TARGET_DB}.SEMANTIC.PAWCORE_ANALYSIS TO ROLE PUBLIC;

SELECT 'SEMANTIC VIEW CREATED' AS status, 'PAWCORE_ANALYSIS' AS view_name;
