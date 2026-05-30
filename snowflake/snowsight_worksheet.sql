-- =============================================================================
-- snowsight_worksheet.sql — Ready-to-run queries for Snowsight
-- =============================================================================
-- Paste these into a Snowsight worksheet after deploying the pipeline.
-- Each query uses the SEMANTIC_VIEW() function against PAWCORE_ANALYSIS.
-- Replace PAWCORE_ANALYTICS with your TARGET_DATABASE if different.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE PAWCORE_DEMO_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. LOT BATTERY COMPARISON
-- Which lot has the worst battery health?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT * FROM SEMANTIC_VIEW(
  PAWCORE_ANALYTICS.SEMANTIC.PAWCORE_ANALYSIS
  DIMENSIONS mart_lot.lot
  METRICS telemetry.avg_battery
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. DEVICE COUNT BY LOT
-- How many unique devices are in each manufacturing lot?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT * FROM SEMANTIC_VIEW(
  PAWCORE_ANALYTICS.SEMANTIC.PAWCORE_ANALYSIS
  DIMENSIONS telemetry.lot_number
  METRICS telemetry.device_count
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. TOTAL TELEMETRY READINGS
-- How much data do we have per lot?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT * FROM SEMANTIC_VIEW(
  PAWCORE_ANALYTICS.SEMANTIC.PAWCORE_ANALYSIS
  DIMENSIONS telemetry.lot_number
  METRICS telemetry.reading_count
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. LOW BATTERY INCIDENTS
-- Which lots have devices dropping below 20% battery?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT * FROM SEMANTIC_VIEW(
  PAWCORE_ANALYTICS.SEMANTIC.PAWCORE_ANALYSIS
  DIMENSIONS telemetry.lot_number
  METRICS telemetry.low_battery_incidents, telemetry.low_battery_rate
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. CUSTOMER SATISFACTION
-- Average rating by lot
-- ─────────────────────────────────────────────────────────────────────────────
SELECT * FROM SEMANTIC_VIEW(
  PAWCORE_ANALYTICS.SEMANTIC.PAWCORE_ANALYSIS
  DIMENSIONS customer_reviews.review_region
  METRICS customer_reviews.avg_rating, customer_reviews.review_count
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. UNHAPPY CUSTOMERS
-- Count of 1-2 star reviews by region
-- ─────────────────────────────────────────────────────────────────────────────
SELECT * FROM SEMANTIC_VIEW(
  PAWCORE_ANALYTICS.SEMANTIC.PAWCORE_ANALYSIS
  DIMENSIONS customer_reviews.review_region
  METRICS customer_reviews.low_rating_count, customer_reviews.pct_unhappy
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. QA PASS RATE BY TEST TYPE
-- Manufacturing quality by test category
-- ─────────────────────────────────────────────────────────────────────────────
SELECT * FROM SEMANTIC_VIEW(
  PAWCORE_ANALYTICS.SEMANTIC.PAWCORE_ANALYSIS
  DIMENSIONS quality_logs.test_lot, quality_logs.test_type
  METRICS quality_logs.pass_rate, quality_logs.test_count
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. BATTERY + HUMIDITY TOGETHER
-- Environmental impact on battery (per lot)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT * FROM SEMANTIC_VIEW(
  PAWCORE_ANALYTICS.SEMANTIC.PAWCORE_ANALYSIS
  DIMENSIONS telemetry.lot_number
  METRICS telemetry.avg_battery, telemetry.avg_humidity, telemetry.avg_temperature
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. QA FAILURES
-- Which lots have the most failed tests?
-- ─────────────────────────────────────────────────────────────────────────────
SELECT * FROM SEMANTIC_VIEW(
  PAWCORE_ANALYTICS.SEMANTIC.PAWCORE_ANALYSIS
  DIMENSIONS quality_logs.test_lot
  METRICS quality_logs.failure_count, quality_logs.pass_rate
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. DIRECT MART QUERY (no SEMANTIC_VIEW function)
-- For participants who want to write raw SQL against the pre-aggregated marts
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    l.lot_number,
    l.pass_rate,
    l.avg_battery_level,
    l.low_battery_incidents,
    r.region,
    r.avg_rating,
    r.review_count,
    m.avg_humidity,
    m.moisture_resistance
FROM PAWCORE_ANALYTICS.ANALYTICS.MART_LOT_QUALITY_CORRELATION l
JOIN PAWCORE_ANALYTICS.ANALYTICS.MART_REGIONAL_CUSTOMER_IMPACT r
    ON l.lot_number = r.lot_number
JOIN PAWCORE_ANALYTICS.ANALYTICS.MART_BATTERY_MOISTURE_CORRELATION m
    ON l.lot_number = m.lot_number AND r.region = m.region
ORDER BY l.avg_battery_level ASC;
