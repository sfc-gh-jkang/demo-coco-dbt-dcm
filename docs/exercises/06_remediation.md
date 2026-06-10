# Exercise 6: Track Remediation (Version 2 Storyline)

**Duration**: 5-8 minutes
**Prerequisite**: Pipeline deployed, semantic view with VQRs working

---

## Context

The post-mortem is complete. Engineering has identified the root cause (insufficient moisture sealing on LOT341) and shipped a hardware fix. New devices manufactured after the fix should show improved battery performance.

Your job: **update the semantic view to track improvement** so the agent can answer "Is LOT341 getting better?"

---

## Step 1: Ask CoCo to add a post-fix metric

**Copy-paste into CoCo:**

```
Read snowflake/create_semantic_view.sql — specifically the METRICS section.

I need to add a new metric that tracks battery performance AFTER a hardware fix was deployed on Nov 15, 2024. Add:

1. A metric called `post_fix_avg_battery` on the telemetry table that computes AVG(battery_value) only for readings where reading_time >= '2024-11-15'. Give it synonyms: 'recent_battery', 'post_fix_battery', 'improvement'. Add a comment explaining it shows ~92% post-fix vs ~74% pre-fix for LOT341.

2. A dimension called `reading_month` on the telemetry table using DATE_TRUNC('MONTH', timestamp) so the agent can do time-series trend analysis.

Follow the exact syntax of the existing metrics and dimensions in the file.
```

**What to look for:**
- Metric uses `CASE WHEN ... >= '2024-11-15' THEN battery_value END` inside an AVG
- Dimension uses `DATE_TRUNC('MONTH', timestamp)`
- Both placed in the correct sections (METRICS and DIMENSIONS)

---

## Step 2: Ask CoCo to add a verified query for improvement tracking

**Copy-paste into CoCo:**

```
Now add a verified query to the AI_VERIFIED_QUERIES section of snowflake/create_semantic_view.sql.

Question: "Is LOT341 battery improving after the fix?"
The SQL should compute overall avg battery vs post-fix avg battery for LOT341 only (WHERE lot_number = 'LOT341'). Use logical names: __telemetry, battery_value, reading_time, lot_number.
Set ONBOARDING_QUESTION TRUE so it appears as a suggested question.
Use VERIFIED_AT 1748620800.

Follow the same format as the existing VQRs in the file.
```

**Expected result when queried:** LOT341 overall avg is ~78% (degraded pre-fix readings drag it down), but `post_fix_avg` is ~92% — a clear +18 point improvement showing the moisture seal fix worked.

---

## Step 3: Redeploy the semantic view

```bash
uv run scripts/deploy.py --semantic-only
```

---

## Step 4: Verify

```bash
uv run scripts/deploy.py --verify
```

VQR count should increase by 1.

---

## Step 5: Ask the agent

Open the PawCore Assistant and try:

> "Is LOT341 battery improving after the fix?"

The agent should show overall avg vs. post-fix avg.

> "Show me battery trends by month for LOT341"

The agent can now use the `reading_month` dimension for time-series analysis.

---

## Bonus: Ask CoCo to add a derived metric

**Copy-paste into CoCo:**

```
Add a new metric to snowflake/create_semantic_view.sql called fix_effectiveness on the telemetry table that computes post-fix average battery minus overall average battery, so a positive value means battery improved after the Nov 15, 2024 fix.

Use this exact expression (a Snowflake semantic-view metric must be a single table-qualified aggregate expression — it cannot reference other metrics by name):
telemetry.fix_effectiveness AS AVG(CASE WHEN telemetry.reading_time >= '2024-11-15' THEN telemetry.battery_value END) - AVG(telemetry.battery_value)

Add the comment: "Positive = improving after the fix."
```

> **Why not just reference the metrics?** Snowflake semantic views don't support "derived metrics" that compose other metrics by name (e.g. `fix_effectiveness AS post_fix_avg_battery - avg_battery` fails with `invalid identifier 'POST_FIX_AVG_BATTERY'`). Each metric must be a self-contained, table-qualified aggregate expression. So we inline both aggregates instead of referencing the named metrics. This still shows the semantic view composing a new calculation without touching dbt models.

This shows how the semantic view adds new calculations without touching dbt models.

---

## What This Demonstrates

| Concept | How it's shown |
|---------|----------------|
| Semantic view evolution | Add metrics without touching dbt models |
| Verified Query Repository | Teach the agent new questions via CoCo |
| Derived metrics | Add composite metrics (inline aggregate expressions) |
| `--semantic-only` partial deploy | Update just the semantic layer in seconds |
| Agent-as-interface | Business users ask questions, never write SQL |
