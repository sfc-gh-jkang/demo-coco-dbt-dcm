# Activity 1 — Ask CoCo

**Time:** 10 minutes · **You'll do:** prompt your own Cortex Code instance and share findings

---

## The goal

See what Cortex Code can do with a real codebase. You just ran a deploy that created 8 schemas, 4 raw tables, 4 HOL-compatible tables, 3 marts, and 5 staging views. CoCo knows about all of it. Let's ask it to explain.

## Setup (30 seconds)

Open Cortex Code in your terminal. Make sure it's pointed at your trial:

```bash
cortex connections list
cortex connections set <your-trial-connection>
```

Keep this webinar tab open in your browser and keep Cortex Code in your terminal side by side.

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
- **Checkpoint:** paste CoCo's one-line summary of DCM into the webinar chat

---

## Prompt 2 — "Walk me through stg_customer_reviews"

**Copy-paste into CoCo:**

```
Read dbt/models/staging/stg_customer_reviews.sql and dbt/models/intermediate/int_region_lot_device_pool.sql.
Explain the business logic that maps a review to a specific device and lot number. Why is this done in dbt staging instead of the raw COPY INTO?
```

**What to look for:**
- Describes the round-robin device assignment (MOD-based)
- Calls out that review_id → device_id → lot_number is derived from **real telemetry data**, not hardcoded
- Mentions the `relationships` dbt test that enforces `device_id` exists in `stg_telemetry`
- Explains **why dbt**: business logic is versioned, tested, and reviewable — COPY INTO isn't

**Bonus follow-up to try:**
```
If PawCore added a new region (LATAM) with its own lot number, what would I need to change? Walk me through the file changes.
```
CoCo should identify `int_region_lot_device_pool` as the single source of truth — no hardcoded CASE to edit.

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

**Chat prompt:** what's the business insight YOUR CoCo surfaced? Post it in the webinar chat.

---

## Why these prompts matter

You're not watching me prompt — you're prompting **your own** CoCo, against **your own** trial account, and seeing how it reads code + queries data together. That's the pair-programmer pattern you'll take back to your real work.

Next up: **Activity 2** — you're going to build a brand-new analytical mart by asking CoCo to write it.
