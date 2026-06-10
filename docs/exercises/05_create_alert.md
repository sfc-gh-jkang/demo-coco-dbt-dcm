# Exercise 5: Create a Battery Alert

**Duration**: 5-8 minutes
**Prerequisite**: Pipeline deployed (all 7 steps complete)

---

## Context

LOT341's battery issue is now known. You want to be **alerted automatically** if the average battery level drops below a threshold — catching future problems before customers complain.

---

## Step 1: Ask CoCo to create the alert

**Copy-paste into CoCo:**

```
I want to create a Snowflake ALERT that monitors battery levels in my pipeline. Here's what I need:

1. A log table PAWCORE_ANALYTICS.ANALYTICS.BATTERY_ALERTS with columns:
   - alert_time (TIMESTAMP, default CURRENT_TIMESTAMP)
   - lot_number (VARCHAR)
   - avg_battery (NUMBER(10,2))
   - threshold (NUMBER(10,2))
   - message (VARCHAR)

2. An alert PAWCORE_ANALYTICS.ANALYTICS.LOW_BATTERY_ALERT that:
   - Uses warehouse PAWCORE_DEMO_WH
   - Runs every hour (CRON)
   - Checks if ANY lot in DEVICE_DATA.TELEMETRY has avg battery_level < 90
   - If triggered, INSERTs the offending lot(s) into the BATTERY_ALERTS table
   - Uses CREATE OR REPLACE and CREATE TABLE IF NOT EXISTS so it's idempotent

3. After creating it, RESUME the alert so it's active.

Generate the full SQL and run it.
```

**What to look for in CoCo's output:**
- Creates the log table with `IF NOT EXISTS`
- Alert has a `SCHEDULE = 'USING CRON 0 * * * * America/New_York'` (or similar hourly cron)
- `IF (EXISTS (...))` checks avg battery per lot
- `THEN` inserts into the log table
- Ends with `ALTER ALERT ... RESUME`

---

## Step 2: Test it manually

Ask CoCo:

```
Execute the alert manually with EXECUTE ALERT ANALYTICS.LOW_BATTERY_ALERT, then query ANALYTICS.BATTERY_ALERTS to show me which lots triggered. I expect LOT341 to appear (avg battery ~78%) but not LOT339 or LOT340 (both above 90%).
```

**Expected**: LOT341 appears with avg_battery ~78%. The other lots stay above 90%.

---

## Step 3: Clean up

Ask CoCo:

```
Suspend the LOW_BATTERY_ALERT so it doesn't keep running after the lab.
```

---

## Bonus: Email notification

Ask CoCo:

```
Create a second alert called LOW_BATTERY_EMAIL_ALERT that runs daily at 8am and uses SYSTEM$SEND_EMAIL to notify me when any lot drops below 90% battery. Use 'my_email_integration' as the notification integration name and 'your.email@company.com' as the recipient. Just show me the SQL — don't run it (I may not have an email integration configured).
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
