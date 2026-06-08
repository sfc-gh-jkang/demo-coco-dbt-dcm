# Exercise 6: Track Remediation (Version 2 Storyline)

**Duration**: 5-8 minutes
**Prerequisite**: Pipeline deployed, semantic view with VQRs working

---

## Context

The post-mortem is complete. Engineering has identified the root cause (insufficient moisture sealing on LOT341) and shipped a hardware fix. New devices manufactured after the fix should show improved battery performance.

Your job: **update the semantic view to track improvement** so the agent can answer "Is LOT341 getting better?"

---

## Step 1: Add a "post-fix" metric to the semantic view

Open `snowflake/create_semantic_view.sql` and add a new metric in the METRICS section:

```sql
    telemetry.post_fix_avg_battery AS AVG(
      CASE WHEN telemetry.reading_time >= '2024-11-15' THEN telemetry.battery_value END
    )
      WITH SYNONYMS = ('recent_battery', 'post_fix_battery', 'improvement')
      COMMENT = 'Average battery for readings after Nov 15 2024 (post-fix). Expected: ~92% post-fix vs ~74% pre-fix for LOT341.',
```

And add a dimension for time bucketing:

```sql
    telemetry.reading_month AS DATE_TRUNC('MONTH', timestamp)
      COMMENT = 'Month of the telemetry reading (for trend analysis).',
```

---

## Step 2: Add a verified query for improvement tracking

Add this to the `AI_VERIFIED_QUERIES` section:

```sql
    ,
    post_fix_improvement AS (
      QUESTION 'Is LOT341 battery improving after the fix?'
      VERIFIED_AT 1748620800
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = your.name@company.com)'
      SQL 'SELECT lot_number, AVG(battery_value) AS overall_avg, AVG(CASE WHEN reading_time >= ''2024-11-15'' THEN battery_value END) AS post_fix_avg FROM __telemetry WHERE lot_number = ''LOT341'' GROUP BY lot_number'
    )
```

> **Expected result:** LOT341 overall avg is ~78% (degraded pre-fix readings drag it down), but `post_fix_avg` is ~92% — a clear +18 point improvement showing the moisture seal fix worked. This is the payoff of the entire investigation storyline.

---

## Step 3: Redeploy the semantic view

```bash
uv run scripts/deploy.py --semantic-only
```

This re-creates the semantic view (with your new metric and VQR) and the agent — steps 6–7 — in ~15 seconds, skipping the earlier steps.

---

## Step 4: Verify

```bash
uv run scripts/deploy.py --verify
```

The registered count goes up by 1 for the VQR you just added: `PASS  VERIFIED QUERIES: 23 registered` if this is the only query you've added, or `24` if you also completed Exercise 4 (which adds one too).

---

## Step 5: Ask the agent

Open the PawCore Assistant and ask:

> "Is LOT341 battery improving after the fix?"

The agent should use your new verified query and show overall avg vs. post-fix avg.

> "Show me battery trends by month for LOT341"

The agent can now use the `reading_month` dimension for time-series analysis.

---

## Discussion Points

- **Why a separate metric?** Pre-computing the "post-fix window" as a metric means the agent doesn't have to guess the fix date — it's encoded in the semantic layer.
- **VQR as documentation**: The verified query serves double duty — it improves agent accuracy AND documents the expected SQL pattern for this business question.
- **Progressive enrichment**: Each time a new business question emerges, you add a metric + VQR. The semantic view grows organically.

---

## Bonus: Add a "fix effectiveness" derived metric

```sql
    -- In METRICS section (as a derived metric — no table prefix)
    fix_effectiveness AS telemetry.post_fix_avg_battery - telemetry.avg_battery
      COMMENT = 'Difference between post-fix and overall battery avg. Positive = improving.',
```

This derived metric combines two existing metrics without specifying a table, showing how the semantic view composes calculations.

---

## What This Demonstrates

| Concept | How it's shown |
|---------|----------------|
| Semantic view evolution | Add metrics without touching dbt models |
| Verified Query Repository | Teach the agent new questions in SQL |
| Derived metrics | Compose existing metrics into new insights |
| `--semantic-only` partial deploy | Update just the semantic layer (steps 6-7) in seconds |
| Agent-as-interface | Business users ask questions, never write SQL |
