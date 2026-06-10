# Exercise 2: Build-Your-Own Mart

**Duration**: 13 minutes · **You'll do:** prompt CoCo to write a brand-new dbt model, wire it up, and run the build

---

## The goal

Pick one of three business questions. Paste a ready-made prompt into CoCo. CoCo writes the SQL. You redeploy. Tests pass. You end with an analytical mart **you** designed — built entirely by prompting an AI pair programmer.

---

## How it works (read this first)

1. **Pick Option A, B, or C** below (A is easiest, C is hardest)
2. **Copy the pre-filled CoCo prompt** under your chosen option
3. **Paste it into Cortex Code** — CoCo reads the codebase and writes the .sql file for you
4. **Redeploy** — one command re-stages and rebuilds the dbt project
5. **Verify** — query your new mart to see the results

You are NOT writing SQL yourself. CoCo does the work. Your job is to evaluate what it produces and iterate if needed.

---

## Pick one

### Option A — Weekly battery trend by region (easiest)

**Business question:** "How is battery performance trending by region week over week?"

**Expected output columns:**
- `week_start` (DATE) — start of week
- `region` (VARCHAR)
- `avg_battery_level` (NUMBER)
- `min_battery_level` (NUMBER)
- `device_count` (NUMBER)

**Copy-paste this ENTIRE prompt into CoCo:**

```
I'm adding a new dbt mart to this project. Please:
1. Read dbt/models/marts/_exercise_starter.sql and the 3 existing marts in dbt/models/marts/
2. Also read dbt/models/staging/stg_telemetry.sql
3. Write dbt/models/marts/mart_weekly_battery_by_region.sql

Business question: "How is battery performance trending by region week over week?"

Expected columns: week_start (DATE), region (VARCHAR), avg_battery_level (NUMBER), min_battery_level (NUMBER), device_count (NUMBER)

Use DATE_TRUNC('week', timestamp) for week_start. Group by week_start and region. Use CTEs. Follow the existing mart style (config block at top, table materialization, ORDER BY at end).

Also add an entry to dbt/models/marts/__marts.yml with not_null tests on week_start, region, and avg_battery_level, plus accepted_values for region: ['AMERICAS', 'EMEA', 'APAC'].

IMPORTANT: Do NOT try to run dbt locally. This project uses server-side dbt (EXECUTE DBT PROJECT). Just write the file — I will deploy it with the deploy script.
```

**Expected row count:** ~27 rows (9 weeks × 3 regions)

---

### Option B — Top-10 problematic devices (medium)

**Business question:** "Which 10 devices are showing the worst signals right now?"

**Expected output columns:**
- `device_id`, `lot_number`, `region`
- `avg_battery_level`, `low_battery_reading_count` (readings < 20)
- `risk_score` (weighted: low_battery_count * 3 + (5 - avg_rating))

**Copy-paste this ENTIRE prompt into CoCo:**

```
I'm adding a new dbt mart to this project. Please:
1. Read dbt/models/marts/_exercise_starter.sql and the 3 existing marts in dbt/models/marts/
2. Also read dbt/models/staging/stg_telemetry.sql and stg_customer_reviews.sql
3. Write dbt/models/marts/mart_top10_problematic_devices.sql

Business question: "Which 10 devices are showing the worst signals right now?"

Expected columns: device_id (VARCHAR), lot_number (VARCHAR), region (VARCHAR), avg_battery_level (NUMBER), low_battery_reading_count (NUMBER — readings where battery_level < 20), avg_rating (NUMBER — from reviews), risk_score (NUMBER — weighted: low_battery_reading_count * 3 + (5 - avg_rating))

CRITICAL: Pre-aggregate stg_telemetry to one row per device BEFORE joining to stg_customer_reviews. Otherwise you get fanout (21K telemetry × 1.5K reviews). Use a CTE like: WITH device_stats AS (SELECT device_id, lot_number, region, AVG(battery_level), SUM(CASE WHEN battery_level < 20...) FROM stg_telemetry GROUP BY device_id, lot_number, region). Then LEFT JOIN to reviews aggregated per device_id. Rank by risk_score DESC and LIMIT 10.

Also add an entry to dbt/models/marts/__marts.yml with unique test on device_id and not_null on device_id, lot_number.

IMPORTANT: Do NOT try to run dbt locally. This project uses server-side dbt (EXECUTE DBT PROJECT). Just write the file — I will deploy it with the deploy script.
```

**Expected row count:** Exactly 10 rows

---

### Option C — Device-age vs. failure-rate correlation (advanced)

**Business question:** "Are older devices (more charging cycles) failing at a higher rate than newer ones?"

**Expected output columns:**
- `charging_cycles_bucket` (VARCHAR) — one of `0-50`, `51-100`, `101-200`, `201-500`, `500+`
- `device_count`, `low_battery_rate` (% of readings where battery < 20)
- `avg_temperature`, `avg_humidity`

**Copy-paste this ENTIRE prompt into CoCo:**

```
I'm adding a new dbt mart to this project. Please:
1. Read dbt/models/marts/_exercise_starter.sql and the 3 existing marts in dbt/models/marts/
2. Also read dbt/models/staging/stg_telemetry.sql and stg_quality_logs.sql
3. Write dbt/models/marts/mart_device_age_cohort_analysis.sql

Business question: "Are older devices (more charging cycles) failing at a higher rate than newer ones?"

Expected columns: charging_cycles_bucket (VARCHAR — one of '0-50', '51-100', '101-200', '201-500', '500+'), device_count (NUMBER), low_battery_rate (NUMBER — percentage of readings where battery_level < 20), avg_temperature (NUMBER), avg_humidity (NUMBER)

Use CASE WHEN charging_cycles <= 50 THEN '0-50' WHEN charging_cycles <= 100 THEN '51-100' etc. for bucketing. First compute per-device stats (avg charging_cycles, low_battery_rate, avg_temp, avg_humidity) then bucket and aggregate. Use CTEs.

Also add an entry to dbt/models/marts/__marts.yml with not_null on all columns and accepted_values on charging_cycles_bucket for the 5 bucket values.

IMPORTANT: Do NOT try to run dbt locally. This project uses server-side dbt (EXECUTE DBT PROJECT). Just write the file — I will deploy it with the deploy script.
```

**Expected row count:** ~4 rows — one per populated bucket. With the current data the highest per-device average is ~350 cycles, so the `500+` bucket is empty and won't appear. (The `accepted_values` test still lists all 5 — that's fine; it only checks values are *in* the list.)

---

## Build + verify (3 minutes)

**Important:** CoCo may say something like *"dbt isn't installed in the venv"* or try to validate the SQL by running it directly against Snowflake. **This is normal.** This project runs dbt server-side inside Snowflake (via `EXECUTE DBT PROJECT`), not locally. There's no local dbt CLI. CoCo is being smart about finding an alternative way to check the SQL — let it do its thing. The real test is the redeploy step below.

After CoCo writes the file:

1. **Redeploy the dbt project** — this re-stages all dbt files (including your new mart) and rebuilds:
   ```bash
   uv run scripts/deploy.py --dbt-only
   ```
   Watch for `PASS` on your new model and its tests. All existing tests should still pass too.

   > This only re-stages the dbt files and runs `EXECUTE DBT PROJECT` (~30 seconds). It does NOT re-upload CSVs or re-run bootstrap — those already ran during initial deploy.

2. **Verify** — query your new mart (copy the one matching your option):

   **Option A** (~27 rows):
   ```bash
   snow sql -q "SELECT * FROM PAWCORE_ANALYTICS.ANALYTICS.MART_WEEKLY_BATTERY_BY_REGION ORDER BY WEEK_START, REGION"
   ```

   **Option B** (10 rows):
   ```bash
   snow sql -q "SELECT * FROM PAWCORE_ANALYTICS.ANALYTICS.MART_TOP10_PROBLEMATIC_DEVICES ORDER BY RISK_SCORE DESC"
   ```

   **Option C** (~4 rows):
   ```bash
   snow sql -q "SELECT * FROM PAWCORE_ANALYTICS.ANALYTICS.MART_DEVICE_AGE_COHORT_ANALYSIS ORDER BY CHARGING_CYCLES_BUCKET"
   ```

3. **Check the row count** matches the expected count listed under your option.

---

## If CoCo gives you something wrong

This happens. Here's what to do:

### "The build failed with an ERROR"

Paste this into CoCo:
```
The dbt build failed. Here's the error: <paste the error message>. Please fix the SQL in dbt/models/marts/mart_<name>.sql.
```

### "Row count is way too high (fanout)"

This means CoCo joined two tables without pre-aggregating. Paste this:
```
The mart has too many rows — I think there's a fanout from joining stg_telemetry directly to stg_customer_reviews without pre-aggregating. Please fix dbt/models/marts/mart_<name>.sql: pre-aggregate stg_telemetry to one row per device_id in a CTE before joining.
```

### "Column has NULL values but shouldn't"

```
The column <name> has NULLs. This is probably from a LEFT JOIN that didn't match. Please use COALESCE(<column>, 0) or switch to INNER JOIN if every device should have data.
```

### "CoCo wrote something completely different from what I asked"

Start over with a more specific prompt:
```
Delete what you wrote in dbt/models/marts/mart_<name>.sql and try again. Here are the EXACT columns I need: <list them>. The ONLY source table is {{ ref('stg_telemetry') }}. Do not join to any other table. GROUP BY <fields>. ORDER BY <field> DESC.
```

### "Tests fail but the data looks right"

The YAML test definition might not match what CoCo wrote. Paste:
```
The dbt test <test_name> is failing. Read the test definition in __marts.yml and the actual SQL in mart_<name>.sql. Fix whichever one is wrong — the test should match the actual column names and logic.
```

---

## Alternative: skip the dbt project entirely

If re-deploying is too slow or you hit issues, create the table directly in Snowsight:

```sql
CREATE OR REPLACE TABLE PAWCORE_ANALYTICS.ANALYTICS.MART_<YOUR_CHOICE> AS
-- paste the SELECT statement CoCo wrote (everything after the config block)
;
```

You lose the dbt test wrapping but you still get a working mart. Good enough for the demo.

---

## Share your work

Once your mart builds and the tests pass:

> **Share in chat:** What business question does your mart answer? (e.g., "Which region has the most devices with critically low battery?")

Next up: **Exercise 3** — plug a Snowflake Intelligence agent on top of all the marts we've built and ask it questions in plain English.
