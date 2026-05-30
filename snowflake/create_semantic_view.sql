-- =============================================================================
-- create_semantic_view.sql — semantic view over HOL tables + marts
-- =============================================================================
-- Creates ${TARGET_DB}.SEMANTIC.PAWCORE_ANALYSIS using native CREATE SEMANTIC
-- VIEW DDL.
--
-- Run AFTER the dbt build. Parameterized via envsubst — only ${TARGET_DB} and
-- ${TARGET_WH} are substituted.
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
      WITH SYNONYMS = ('device_telemetry', 'sensor_readings', 'device_data', 'field_data')
      COMMENT = 'IoT SmartCollar telemetry: battery level, humidity, temperature, charging cycles per device per timestamp. 21K rows. Join to other tables on lot_number or device_id.',

    quality_logs AS ${TARGET_DB}.MANUFACTURING.QUALITY_LOGS
      PRIMARY KEY (lot_number, test_type, timestamp)
      WITH SYNONYMS = ('manufacturing_tests', 'qa_logs', 'inspection_results', 'quality_records')
      COMMENT = 'Manufacturing QA test results. 1,050 rows. Each row is one test on one lot. Test types: BATTERY_LIFE, BATTERY_LIFE_HUMID, MOISTURE_THRESHOLD, THERMAL_CYCLING. pass_fail is PASS or FAIL.',

    customer_reviews AS ${TARGET_DB}.SUPPORT.CUSTOMER_REVIEWS
      PRIMARY KEY (review_id)
      WITH SYNONYMS = ('product_reviews', 'feedback', 'ratings', 'customer_feedback', 'csat_data')
      COMMENT = 'Customer star ratings (1-5) with review text. 1,550 rows. Each review is linked to a device_id and lot_number. Join to telemetry on device_id for per-device context.',

    mart_lot AS ${TARGET_DB}.ANALYTICS.MART_LOT_QUALITY_CORRELATION
      PRIMARY KEY (lot_number)
      WITH SYNONYMS = ('lot_summary', 'lot_stats', 'lot_quality', 'manufacturing_field_correlation')
      COMMENT = 'Pre-aggregated per-lot stats: QA pass rate + field battery/humidity metrics. ONE ROW PER LOT (3 rows total). Use this for lot-level comparisons — avoids fanout. Columns: lot_number, test_count, pass_count, failure_count, pass_rate, device_count, avg_battery_level, avg_temperature, avg_humidity, low_battery_incidents.',

    mart_regional AS ${TARGET_DB}.ANALYTICS.MART_REGIONAL_CUSTOMER_IMPACT
      PRIMARY KEY (lot_number, region)
      WITH SYNONYMS = ('regional_csat', 'customer_impact_by_region', 'lot_region_ratings')
      COMMENT = 'Customer satisfaction by lot x region with device battery context. ONE ROW PER LOT+REGION (3 rows total). Columns: lot_number, region, avg_rating, review_count, avg_battery_level, device_count.',

    mart_moisture AS ${TARGET_DB}.ANALYTICS.MART_BATTERY_MOISTURE_CORRELATION
      PRIMARY KEY (lot_number, region)
      WITH SYNONYMS = ('humidity_battery', 'moisture_correlation', 'environmental_impact')
      COMMENT = 'Battery vs humidity correlation by lot x region with moisture resistance test scores. ONE ROW PER LOT+REGION (3 rows total). Columns: lot_number, region, avg_humidity, avg_battery, device_count, moisture_resistance.'
  )

  RELATIONSHIPS (
    reviews_to_lot AS
      customer_reviews (lot_number) REFERENCES mart_lot,
    telemetry_to_lot AS
      telemetry (lot_number) REFERENCES mart_lot,
    quality_to_lot AS
      quality_logs (lot_number) REFERENCES mart_lot,
    moisture_to_lot AS
      mart_moisture (lot_number) REFERENCES mart_lot,
    regional_to_lot AS
      mart_regional (lot_number) REFERENCES mart_lot
  )

  FACTS (
    -- Telemetry measurements
    telemetry.battery_value AS battery_level
      COMMENT = 'Battery level percentage (0-100). LOT341 avg is ~87%, others are 92-94%. Below 20% indicates severe degradation.',
    telemetry.humidity_value AS humidity_reading
      COMMENT = 'Ambient humidity percentage. All lots have similar ~60% avg. High humidity exposure correlates with battery issues in LOT341.',
    telemetry.temp_value AS temperature
      COMMENT = 'Temperature in degrees Celsius.',
    telemetry.charging_cycles_count AS charging_cycles
      COMMENT = 'Total charging cycles for this device. Higher = older/more-used device.',

    -- Customer reviews
    customer_reviews.rating_value AS rating
      COMMENT = 'Star rating 1-5. LOT341/EMEA avg is 4.10; LOT339/APAC is 4.29.',

    -- Quality logs
    quality_logs.measurement AS measurement_value
      COMMENT = 'Numeric test measurement value. Interpretation depends on test_type.',
    quality_logs.pass_indicator AS CASE WHEN pass_fail = 'PASS' THEN 1 ELSE 0 END
      COMMENT = 'Binary 1=passed, 0=failed. Used to compute pass_rate metric.',

    -- Mart facts (pre-aggregated)
    mart_lot.lot_pass_rate AS pass_rate
      COMMENT = 'Pre-computed QA pass rate for the lot (percentage).',
    mart_lot.lot_battery AS avg_battery_level
      COMMENT = 'Pre-computed average battery level for all devices in the lot.',
    mart_lot.lot_low_battery AS low_battery_incidents
      COMMENT = 'Pre-computed count of readings with battery below 20%.',
    mart_regional.regional_rating AS avg_rating
      COMMENT = 'Pre-computed average customer rating for lot+region.',
    mart_regional.regional_reviews AS review_count
      COMMENT = 'Pre-computed count of reviews for lot+region.',
    mart_moisture.moisture_avg_battery AS avg_battery
      COMMENT = 'Pre-computed average battery from the moisture correlation mart.',
    mart_moisture.moisture_humidity AS avg_humidity
      COMMENT = 'Pre-computed average humidity from the moisture correlation mart.',
    mart_moisture.moisture_score AS moisture_resistance
      COMMENT = 'Average moisture resistance test score. NULL if no MOISTURE_THRESHOLD tests for this lot+region.'
  )

  DIMENSIONS (
    -- Telemetry dimensions
    telemetry.lot_number AS lot_number
      WITH SYNONYMS = ('batch', 'production_lot', 'lot_id', 'lot')
      COMMENT = 'Manufacturing lot identifier. Known values: LOT339 (APAC, healthy, 400 devices), LOT340 (AMERICAS, healthy, 1000 devices), LOT341 (EMEA, PROBLEMATIC, 2100 devices).',
    telemetry.region AS region
      WITH SYNONYMS = ('market', 'geography', 'sales_region')
      COMMENT = 'Sales region. Values: AMERICAS, EMEA, APAC. Each lot maps to exactly one region.',
    telemetry.reading_time AS timestamp
      COMMENT = 'Telemetry reading timestamp.',
    telemetry.device_identifier AS device_id
      WITH SYNONYMS = ('device', 'collar_id', 'unit_id')
      COMMENT = 'Unique SmartCollar device identifier.',

    -- Customer review dimensions
    customer_reviews.review_date AS date
      WITH SYNONYMS = ('review_date', 'feedback_date')
      COMMENT = 'Date the customer submitted the review.',
    customer_reviews.review_region AS region
      COMMENT = 'Region of the reviewer (matches telemetry region values).',

    -- Quality log dimensions
    quality_logs.test_type AS test_type
      WITH SYNONYMS = ('test_category', 'test_kind', 'qa_test')
      COMMENT = 'Type of manufacturing QA test. Values: BATTERY_LIFE, BATTERY_LIFE_HUMID, MOISTURE_THRESHOLD, THERMAL_CYCLING.',
    quality_logs.pass_fail AS pass_fail
      WITH SYNONYMS = ('test_result', 'test_outcome')
      COMMENT = 'Test outcome. Values: PASS, FAIL.',
    quality_logs.test_lot AS lot_number
      COMMENT = 'Lot identifier on the QA table (same values as telemetry.lot_number).',

    -- Mart dimensions
    mart_lot.lot AS lot_number
      COMMENT = 'Lot identifier in the lot-level summary mart.',
    mart_regional.regional_lot AS lot_number
      COMMENT = 'Lot identifier in the regional mart.',
    mart_regional.regional_area AS region
      COMMENT = 'Region in the regional mart.',
    mart_moisture.moisture_lot AS lot_number
      COMMENT = 'Lot in the moisture correlation mart.',
    mart_moisture.moisture_region AS region
      COMMENT = 'Region in the moisture correlation mart.'
  )

  METRICS (
    -- Telemetry metrics
    telemetry.avg_battery AS AVG(telemetry.battery_value)
      WITH SYNONYMS = ('average_battery', 'battery_health', 'mean_battery')
      COMMENT = 'Average battery level across readings. LOT341=87%, LOT340=92%, LOT339=94%.',
    telemetry.avg_humidity AS AVG(telemetry.humidity_value)
      WITH SYNONYMS = ('average_humidity', 'mean_humidity')
      COMMENT = 'Average humidity reading.',
    telemetry.avg_temperature AS AVG(telemetry.temp_value)
      COMMENT = 'Average temperature reading.',
    telemetry.device_count AS COUNT(DISTINCT telemetry.device_identifier)
      WITH SYNONYMS = ('number_of_devices', 'unique_devices')
      COMMENT = 'Count of distinct devices.',
    telemetry.reading_count AS COUNT(*)
      COMMENT = 'Total number of telemetry readings.',
    telemetry.low_battery_incidents AS SUM(CASE WHEN telemetry.battery_value < 20 THEN 1 ELSE 0 END)
      WITH SYNONYMS = ('critical_battery_events', 'battery_failures')
      COMMENT = 'Count of readings with battery below 20%. Indicates device degradation.',
    telemetry.low_battery_rate AS AVG(CASE WHEN telemetry.battery_value < 20 THEN 1.0 ELSE 0.0 END) * 100
      COMMENT = 'Percentage of readings with critically low battery.',

    -- Customer metrics
    customer_reviews.avg_rating AS AVG(customer_reviews.rating_value)
      WITH SYNONYMS = ('average_rating', 'csat', 'customer_satisfaction', 'mean_rating')
      COMMENT = 'Average star rating (1-5). Below 3.5 indicates significant dissatisfaction.',
    customer_reviews.review_count AS COUNT(*)
      WITH SYNONYMS = ('number_of_reviews', 'feedback_count', 'total_reviews')
      COMMENT = 'Number of customer reviews.',
    customer_reviews.low_rating_count AS SUM(CASE WHEN customer_reviews.rating_value <= 2 THEN 1 ELSE 0 END)
      WITH SYNONYMS = ('unhappy_customers', 'negative_reviews', 'detractors')
      COMMENT = 'Count of 1-star and 2-star reviews.',
    customer_reviews.high_rating_count AS SUM(CASE WHEN customer_reviews.rating_value >= 4 THEN 1 ELSE 0 END)
      WITH SYNONYMS = ('happy_customers', 'positive_reviews', 'promoters')
      COMMENT = 'Count of 4-star and 5-star reviews.',
    customer_reviews.pct_unhappy AS AVG(CASE WHEN customer_reviews.rating_value <= 2 THEN 100.0 ELSE 0.0 END)
      COMMENT = 'Percentage of reviews that are 1 or 2 stars.',

    -- Quality metrics
    quality_logs.pass_rate AS AVG(quality_logs.pass_indicator) * 100
      WITH SYNONYMS = ('quality_pass_rate', 'qa_pass_rate', 'manufacturing_quality')
      COMMENT = 'QA test pass rate as a percentage (0-100).',
    quality_logs.test_count AS COUNT(*)
      WITH SYNONYMS = ('total_tests', 'number_of_tests')
      COMMENT = 'Total number of QA tests performed.',
    quality_logs.failure_count AS SUM(CASE WHEN quality_logs.pass_indicator = 0 THEN 1 ELSE 0 END)
      WITH SYNONYMS = ('failed_tests', 'qa_failures')
      COMMENT = 'Number of failed QA tests.'
  )

  COMMENT = 'PawCore SmartCollar analytics. Cross-references manufacturing QA, device telemetry, and customer feedback. LOT341 (EMEA) is a known-problematic batch — high humidity correlates with battery degradation and low customer ratings. Always join by lot_number when investigating issues. Use mart tables for pre-aggregated answers (faster, no fanout risk); use raw tables only when you need row-level detail.';

-- =============================================================================
-- Verify + grants
-- =============================================================================

SHOW SEMANTIC VIEWS IN SCHEMA ${TARGET_DB}.SEMANTIC;

GRANT SELECT, REFERENCES ON SEMANTIC VIEW ${TARGET_DB}.SEMANTIC.PAWCORE_ANALYSIS TO ROLE ACCOUNTADMIN;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW ${TARGET_DB}.SEMANTIC.PAWCORE_ANALYSIS TO ROLE PUBLIC;

SELECT 'SEMANTIC VIEW CREATED' AS status, 'PAWCORE_ANALYSIS' AS view_name;
