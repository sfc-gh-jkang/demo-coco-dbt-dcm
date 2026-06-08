# Exercise 5: Create a Battery Alert

**Duration**: 5-8 minutes
**Prerequisite**: Pipeline deployed (all 7 steps complete)

---

## Context

LOT341's battery issue is now known. You want to be **alerted automatically** if the average battery level drops below a threshold — catching future problems before customers complain.

---

## Step 1: Create an alert log table

```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE PAWCORE_ANALYTICS;
USE WAREHOUSE PAWCORE_DEMO_WH;

CREATE TABLE IF NOT EXISTS ANALYTICS.BATTERY_ALERTS (
    alert_time    TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    lot_number    VARCHAR,
    avg_battery   NUMBER(10,2),
    threshold     NUMBER(10,2),
    message       VARCHAR
);
```

---

## Step 2: Create the alert

```sql
CREATE OR REPLACE ALERT ANALYTICS.LOW_BATTERY_ALERT
  WAREHOUSE = PAWCORE_DEMO_WH
  SCHEDULE = 'USING CRON 0 * * * * America/New_York'  -- Every hour
  IF (EXISTS (
    SELECT lot_number, AVG(battery_level) AS avg_batt
    FROM DEVICE_DATA.TELEMETRY
    GROUP BY lot_number
    HAVING AVG(battery_level) < 90  -- threshold: 90%
  ))
  THEN
    INSERT INTO ANALYTICS.BATTERY_ALERTS (lot_number, avg_battery, threshold, message)
    SELECT
      lot_number,
      ROUND(AVG(battery_level), 2),
      90,
      'Battery below 90% threshold'
    FROM DEVICE_DATA.TELEMETRY
    GROUP BY lot_number
    HAVING AVG(battery_level) < 90;
```

**How it works:**
- **SCHEDULE**: Runs every hour (CRON expression)
- **IF (EXISTS ...)**: The condition — only fires if any lot has avg battery < 90%
- **THEN**: The action — logs the offending lot(s) to the alert table

---

## Step 3: Resume (activate) the alert

Alerts are created in a SUSPENDED state. Activate it:

```sql
ALTER ALERT ANALYTICS.LOW_BATTERY_ALERT RESUME;
```

Verify it's active:

```sql
SHOW ALERTS IN SCHEMA ANALYTICS;
```

You should see `state = started`.

---

## Step 4: Manually trigger to test

You can't wait an hour during a lab. Force the condition check:

```sql
EXECUTE ALERT ANALYTICS.LOW_BATTERY_ALERT;
```

Then check the results:

```sql
SELECT * FROM ANALYTICS.BATTERY_ALERTS ORDER BY alert_time DESC;
```

**Expected**: LOT341 appears with avg_battery ~74% (below the 90% threshold). LOT339 and LOT340 stay above 90%, so only LOT341 is logged.

---

## Step 5: Clean up

```sql
ALTER ALERT ANALYTICS.LOW_BATTERY_ALERT SUSPEND;
-- Or drop it entirely:
-- DROP ALERT ANALYTICS.LOW_BATTERY_ALERT;
```

---

## Bonus: Email notification

If you have a notification integration configured:

```sql
CREATE OR REPLACE ALERT ANALYTICS.LOW_BATTERY_EMAIL_ALERT
  WAREHOUSE = PAWCORE_DEMO_WH
  SCHEDULE = 'USING CRON 0 8 * * * America/New_York'  -- Daily at 8am
  IF (EXISTS (
    SELECT 1 FROM DEVICE_DATA.TELEMETRY
    GROUP BY lot_number
    HAVING AVG(battery_level) < 90
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'my_email_integration',
      'your.email@company.com',
      'PawCore Battery Alert',
      'One or more lots have average battery below 90%. Check ANALYTICS.MART_LOT_QUALITY_CORRELATION for details.'
    );
```

---

## Key Concepts

| Concept | What it means |
|---------|--------------|
| `SCHEDULE` | CRON or interval (`'1 HOUR'`) — how often the condition is checked |
| `IF (EXISTS ...)` | The condition query — alert only fires when this returns rows |
| `THEN` | The action — any SQL statement (INSERT, CALL, EXECUTE TASK, etc.) |
| `SUSPEND / RESUME` | Toggle without dropping — saves the definition |
| `EXECUTE ALERT` | Manual trigger for testing (skips the schedule) |
