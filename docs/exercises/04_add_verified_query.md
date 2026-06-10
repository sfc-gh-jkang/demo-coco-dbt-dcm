# Exercise 4: Add a Verified Query

**Duration**: 5-8 minutes
**Prerequisite**: Exercises 1-3 complete (pipeline deployed, agent working)

---

## Context

You've discovered that LOT341 has battery issues. Now you'll teach the AI agent a new question by adding a **Verified Query** to the semantic view. Verified queries improve Cortex Analyst accuracy by providing pre-verified SQL for common questions.

---

## Step 1: Ask CoCo to write the verified query

**Copy-paste into CoCo:**

```
Read snowflake/create_semantic_view.sql — specifically the AI_VERIFIED_QUERIES section at the bottom.

I want to add a new verified query that answers: "What percentage of LOT341 devices have battery below 50%?"

Look at the existing VQR syntax and logical names used in the semantic view (tables prefixed with __, column names from the FACTS/DIMENSIONS definitions — NOT the raw physical column names).

Write the new VQR entry and add it to the file. Follow the exact same format as the existing entries. Use VERIFIED_AT 1748620800 and ONBOARDING_QUESTION FALSE.
```

**What to look for in CoCo's edit:**
- Uses `__telemetry` (not `telemetry` or the physical table name)
- Uses `battery_value` (the logical name from FACTS), not `battery_level` (the physical column)
- Escapes single quotes with `''` inside the SQL string
- Places the entry inside the `AI_VERIFIED_QUERIES (...)` block before the closing `)`

---

## Step 2: Redeploy the semantic view

```bash
uv run scripts/deploy.py --semantic-only
```

This re-creates only the semantic view (with your new VQR) and the agent — steps 6-7 — in ~15 seconds.

---

## Step 3: Verify it's registered

```bash
uv run scripts/deploy.py --verify
```

Look for: `PASS  VERIFIED QUERIES: 23 registered` (was 22, now 23).

---

## Step 4: Test with the agent

Open the agent in Snowsight and ask your exact question:

> "What percentage of LOT341 devices have battery below 50%?"

The agent should use your verified query directly (faster, more accurate). You'll see `verified_query` in the confidence metadata if it matched.

---

## Bonus: Try variations

Ask slightly different wordings to see if the VQR still triggers:
- "How many LOT341 readings are below 50% battery?"
- "LOT341 battery failure rate"
- "Percentage of critical battery events in LOT341"

The more similar the user's question is to your `QUESTION` text, the more likely Cortex Analyst will use your VQR.

---

## If CoCo gets the syntax wrong

Paste this follow-up:

```
The verified query syntax is wrong. Here are the rules:
1. Table names must be prefixed with __ (double underscore): FROM __telemetry
2. Column names must use the LOGICAL name from the semantic view FACTS/DIMENSIONS, not the physical column name. Example: battery_value (not battery_level)
3. Single quotes inside the SQL string must be escaped as '' (two single quotes)
4. The entry goes INSIDE the AI_VERIFIED_QUERIES (...) block, before the closing );

Please fix the VQR in snowflake/create_semantic_view.sql.
```

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
