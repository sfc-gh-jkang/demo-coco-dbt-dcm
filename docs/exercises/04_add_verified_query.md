# Exercise 4: Add a Verified Query

**Duration**: 5-8 minutes
**Prerequisite**: Exercises 1-3 complete (pipeline deployed, agent working)

---

## Context

You've discovered that LOT341 has battery issues. Now you'll teach the AI agent a new question by adding a **Verified Query** to the semantic view. Verified queries improve Cortex Analyst accuracy by providing pre-verified SQL for common questions.

---

## Step 1: Write your verified query

Pick a business question the agent should answer well. Example:

> "What percentage of LOT341 devices have battery below 50%?"

Write the SQL using **logical names** from the semantic view (prefix tables with `__`):

```sql
SELECT
  lot_number,
  COUNT(CASE WHEN battery_value < 50 THEN 1 END) AS low_battery_devices,
  COUNT(*) AS total_readings,
  ROUND(COUNT(CASE WHEN battery_value < 50 THEN 1 END) * 100.0 / COUNT(*), 2) AS pct_below_50
FROM __telemetry
WHERE lot_number = 'LOT341'
GROUP BY lot_number
```

---

## Step 2: Add it to the semantic view

Open `snowflake/create_semantic_view.sql` and add your query inside the `AI_VERIFIED_QUERIES (...)` block, before the closing `);`:

```sql
    ,
    lot341_low_battery_pct AS (
      QUESTION 'What percentage of LOT341 devices have battery below 50%?'
      VERIFIED_AT 1748620800
      ONBOARDING_QUESTION FALSE
      VERIFIED_BY '(STEWARD = your.name@company.com)'
      SQL 'SELECT lot_number, COUNT(CASE WHEN battery_value < 50 THEN 1 END) AS low_battery_devices, COUNT(*) AS total_readings, ROUND(COUNT(CASE WHEN battery_value < 50 THEN 1 END) * 100.0 / COUNT(*), 2) AS pct_below_50 FROM __telemetry WHERE lot_number = ''LOT341'' GROUP BY lot_number'
    )
```

**Key syntax rules:**
- Use logical column names (left side of `AS` in FACTS/DIMENSIONS): `battery_value`, not `battery_level`
- Prefix table names with `__`: `FROM __telemetry`, not `FROM telemetry`
- Escape single quotes with `''` inside the SQL string
- Each VQR needs: `QUESTION`, `SQL`. Optional: `VERIFIED_AT`, `ONBOARDING_QUESTION`, `VERIFIED_BY`

---

## Step 3: Redeploy the semantic view

```bash
uv run scripts/deploy.py --semantic-only
```

This re-creates only the semantic view (with your new VQR) and the agent — steps 6–7 — in ~15 seconds, skipping bootstrap, raw load, and the dbt build.

---

## Step 4: Verify it's registered

```bash
uv run scripts/deploy.py --verify
```

Look for: `PASS  VERIFIED QUERIES: 23 registered` (was 22, now 23).

---

## Step 5: Test with the agent

Open the agent in Snowsight and ask your exact question:

> "What percentage of LOT341 devices have battery below 50%?"

The agent should use your verified query directly (faster, more accurate). You'll see `verified_query` in the confidence metadata if it matched.

---

## Bonus: Try these variations

Ask slightly different wordings to see if the VQR still triggers:
- "How many LOT341 readings are below 50% battery?"
- "LOT341 battery failure rate"
- "Percentage of critical battery events in LOT341"

The more similar the user's question is to your `QUESTION` text, the more likely Cortex Analyst will use your VQR.

---

## Logical Name Reference

| Semantic View Entity | Logical Name | Physical Column |
|---------------------|--------------|-----------------|
| `telemetry.battery_value` | battery_value | battery_level |
| `telemetry.humidity_value` | humidity_value | humidity_reading |
| `telemetry.device_identifier` | device_identifier | device_id |
| `telemetry.lot_number` | lot_number | lot_number |
| `customer_reviews.rating_value` | rating_value | rating |
| `quality_logs.test_lot` | test_lot | lot_number |
| `quality_logs.measurement` | measurement | measurement_value |
| `mart_lot.lot` | lot | lot_number |
| `mart_lot.lot_battery` | lot_battery | avg_battery_level |
| `mart_regional.regional_rating` | regional_rating | avg_rating |
| `mart_moisture.moisture_score` | moisture_score | moisture_resistance |
