# Activity 2 — Build-Your-Own Mart

**Time:** 13 minutes · **You'll do:** prompt CoCo to write a brand-new dbt model, wire it up, and run the build

---

## The goal

Pick one of three business questions. Prompt CoCo to write the dbt model. Commit locally. Re-run `EXECUTE DBT PROJECT`. Verify tests pass. You'll end the activity with an analytical mart **you** designed.

## Setup (90 seconds)

1. Open the repo in your editor (VSCode, Cursor, whatever).
2. Open Cortex Code in a terminal.
3. Copy the starter file:
   ```bash
   cp dbt/models/marts/_exercise_starter.sql dbt/models/marts/mart_<your_choice>.sql
   ```
4. Remember the mart name — we'll reference it in the build command.

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

**Target table:** `mart_weekly_battery_by_region`

**dbt test to add (in `__marts.yml`):**
- `not_null` on `week_start`, `region`, `avg_battery_level`
- `accepted_values` for region: `['AMERICAS', 'EMEA', 'APAC']`

**Hint if stuck:** The source is `{{ ref('stg_telemetry') }}`. Use `DATE_TRUNC('week', timestamp)`. Group by `week_start, region`.

---

### Option B — Top-10 problematic devices (medium)

**Business question:** "Which 10 devices are showing the worst signals right now?"

**Expected output columns:**
- `device_id` (VARCHAR)
- `lot_number` (VARCHAR)
- `region` (VARCHAR)
- `avg_battery_level` (NUMBER)
- `low_battery_reading_count` (NUMBER) — readings < 20
- `failed_quality_tests` (NUMBER) — joined by lot
- `review_count` (NUMBER)
- `worst_rating` (NUMBER)
- `risk_score` (NUMBER) — weighted: low_battery * 3 + failed_tests * 2 + (6 - worst_rating) * 1

**Target table:** `mart_top10_problematic_devices`

**dbt test to add:**
- `unique` on `device_id`
- `not_null` on `device_id`, `lot_number`
- Row count test: model should return exactly 10 rows (use `dbt_utils.equal_rowcount` or a custom SQL test)

**Hint:** Pre-aggregate `stg_telemetry` per device BEFORE joining. Otherwise you'll get fanout like we caught in the original `mart_regional_customer_impact` bug. Rank at the end with `ROW_NUMBER() OVER (ORDER BY risk_score DESC) QUALIFY rn <= 10`.

---

### Option C — Device-age vs. failure-rate correlation (advanced)

**Business question:** "Are older devices (more charging cycles) failing at a higher rate than newer ones?"

**Expected output columns:**
- `charging_cycles_bucket` (VARCHAR) — one of `0-50`, `51-100`, `101-200`, `201-500`, `500+`
- `device_count` (NUMBER)
- `low_battery_rate` (NUMBER) — % of readings where battery < 20
- `avg_temperature` (NUMBER)
- `avg_humidity` (NUMBER)
- `pct_devices_with_failed_tests` (NUMBER) — % of devices in this bucket whose lot has any FAIL in quality logs

**Target table:** `mart_device_age_cohort_analysis`

**dbt test to add:**
- `not_null` on all columns
- `accepted_values` on `charging_cycles_bucket` (the 5 buckets listed)

**Hint:** Use `CASE` for bucketing. The `pct_devices_with_failed_tests` needs a sub-aggregation: first find lots with any FAIL, then count matching devices per bucket, divide by total devices in bucket.

---

## CoCo prompt template (copy this)

```
I'm adding a new dbt mart to this project. Please:
1. Read dbt/models/marts/_exercise_starter.sql and the 3 existing marts in dbt/models/marts/
2. Also read dbt/models/staging/stg_telemetry.sql, stg_quality_logs.sql, and stg_customer_reviews.sql
3. Write dbt/models/marts/mart_<your_choice>.sql to answer this business question:

<paste your chosen Option A, B, or C description here>

Expected columns: <paste the column list>

Use CTEs to keep logic readable. Follow the existing mart style (config block at top, table materialization, ORDER BY at end). Watch out for fanout — pre-aggregate source tables before joining.
```

---

## Build + verify (3 minutes)

After CoCo writes the file:

1. **Add the entry to `dbt/models/marts/__marts.yml`** — CoCo can do this too, or copy the pattern from existing entries. Include the tests listed above.
2. **Commit + push** — from the repo directory:
   ```bash
   git checkout -b exercise/mart-<your-name>
   git add dbt/models/marts/mart_<your_choice>.sql dbt/models/marts/__marts.yml
   git -c commit.gpgsign=false commit -m "exercise: add <mart name>"
   git push origin exercise/mart-<your-name>
   ```
   (Note: you're pushing to YOUR fork or YOUR branch — you won't have push access to `main` on the demo repo.)

3. **Update Snowflake to see your branch** — in Snowsight or via `snow sql`:
   ```sql
   -- if your PAT hits your branch:
   ALTER GIT REPOSITORY PAWCORE_ANALYTICS.PUBLIC.DEMO_REPO FETCH;
   CREATE OR REPLACE DBT PROJECT PAWCORE_ANALYTICS.PUBLIC.PAWCORE_DBT
       FROM @PAWCORE_ANALYTICS.PUBLIC.DEMO_REPO/branches/exercise/mart-<your-name>/dbt/;
   ```

4. **Run the build** — scoped to just your new mart:
   ```sql
   EXECUTE DBT PROJECT PAWCORE_ANALYTICS.PUBLIC.PAWCORE_DBT
       args='build --select mart_<your_choice>+';
   ```
   The `+` pulls in its upstream dependencies (staging) automatically.

5. **Verify** — run the mart:
   ```sql
   SELECT * FROM PAWCORE_ANALYTICS.ANALYTICS.MART_<YOUR_CHOICE> LIMIT 10;
   ```

---

## Can't push to the repo?

Totally fine. Skip step 2-3 above and instead:

1. Create the file locally.
2. Use Cortex Code to copy the file's contents into Snowsight's SQL worksheet:
   ```
   Run this as a one-off CREATE TABLE against PAWCORE_ANALYTICS.ANALYTICS.MART_<YOUR_CHOICE>.
   <paste the CTE-based SELECT from your file>
   ```
3. You lose the dbt test wrapping but you still get a working mart. Good enough for the demo.

---

## Gotchas (CoCo will probably warn you about these)

- **Fanout**: Never join `stg_telemetry` (21k rows) to `stg_customer_reviews` (1.5k rows) on `device_id` without pre-aggregating telemetry first. The original `mart_regional_customer_impact` had this bug — `review_count` was 4x inflated.
- **NULL battery in joins**: If you join device_id across staging, some reviews may not match a telemetry row. Use LEFT JOIN and handle NULLs explicitly.
- **Test the mart total vs. source**: For Option A, rows = weeks × regions. For Option B, exactly 10. For Option C, exactly 5 (one per bucket). Always verify a row count expectation before declaring done.

---

## Share your work

Once your mart builds and the tests pass, paste a one-line description of what YOUR CoCo came up with into the webinar chat. We'll feature 2-3 in the recap.

Next up: **Activity 3** — plug a Snowflake Intelligence agent on top of all the marts we've built and ask it questions in plain English.
