# Exercise 1: Ask CoCo

**Duration**: 10 minutes · **You'll do:** prompt your own Cortex Code instance and share findings

---

## The goal

See what Cortex Code can do with a real codebase. You just ran a deploy that created 8 schemas, 4 raw tables, 4 curated domain tables, 3 marts, and 4 staging views. CoCo knows about all of it. Let's ask it to explain.

## Setup (30 seconds)

Open the **Cortex Code** chat panel in VS Code (click the Cortex Code icon in the sidebar). Make sure the repo folder `demo-coco-dbt-dcm` is open as your workspace — CoCo reads from the active workspace.

Keep this webinar tab open in your browser and Cortex Code in your editor side by side.

---

## Prompt 1 — "What did DCM just do?"

**Copy-paste into CoCo:**

```
Read dcm/manifest.yml and dcm/sources/definitions/schemas.sql.
Explain in 3-4 sentences what DCM is managing for this demo and why schemas (not tables) were the right choice for DCM to own.
```

**What to look for in CoCo's answer:**
- Mentions that DCM manages **schemas only** (not tables)
- Notes that schemas are **infrastructure** — reviewable, plan-deployable, versionable
- Picks up on the 8 schemas (RAW, STAGING, DEVICE_DATA, MANUFACTURING, SUPPORT, ANALYTICS, SEMANTIC, DBT_PROD)

> **Share in chat:** In one sentence, what does DCM own in this project? (Hint: it's NOT the tables.)

---

## Prompt 2 — "Walk me through the staging layer"

**Copy-paste into CoCo:**

```
Read dbt/models/staging/stg_customer_reviews.sql and dbt/models/staging/stg_telemetry.sql.
Compare them. Explain in 3-4 sentences what the staging layer does and why we CAST/UPPER columns here instead of in the COPY INTO.
```

**What to look for:**
- Notes that staging views handle type casting, normalization (UPPER), and null filtering
- Calls out that raw tables store data as-is from CSVs — staging is the "clean contract" layer
- Mentions the `relationships` dbt test that enforces `device_id` exists in `stg_telemetry`
- Explains **why dbt staging**: business logic is versioned, tested, and reviewable — COPY INTO isn't

**Bonus follow-up to try:**
```
If PawCore added a new region (LATAM) with its own lot number, what would I need to change in the data pipeline?
```
CoCo should identify the CSV data files and the staging views as the places to update — no hardcoded logic to edit.

---

## Prompt 3 — "Summarize the raw data we just loaded"

**Copy-paste into CoCo:**

```
Run a query against PAWCORE_ANALYTICS.RAW to show me:
- Row counts for each raw table
- The 3 regions and their lot numbers from RAW.TELEMETRY
- The top 5 review ratings distribution
Give me one business insight from what you see.
```

**What to look for:**
- CoCo runs 3 SELECT queries (not one monolithic join)
- Returns: TELEMETRY=21000, QUALITY_LOGS=1050, CUSTOMER_REVIEWS=1550, SLACK_MESSAGES=37
- Identifies the 3 lot-to-region mappings (LOT339/APAC, LOT340/Americas, LOT341/EMEA)
- The business insight should flag **something about LOT341 / EMEA** — low ratings, low battery, or high review volume

> **Share in chat:** What did YOUR CoCo flag about LOT341? Drop the one-liner in chat — let's see if everyone's CoCo found the same signal.

---

## Why these prompts matter

You're not watching me prompt — you're prompting **your own** CoCo, against **your own** trial account, and seeing how it reads code + queries data together. That's the pair-programmer pattern you'll take back to your real work.

Next up: **Exercise 2** — you're going to build a brand-new analytical mart by asking CoCo to write it.
