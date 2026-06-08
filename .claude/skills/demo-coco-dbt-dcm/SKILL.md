---
name: demo-coco-dbt-dcm
description: 60-minute webinar HOL building a PawCore data pipeline with Cortex Code (CoCo), dbt Projects on Snowflake, and DCM. Use this skill when working in ~/Code/demo-coco-dbt-dcm, when adding/changing dbt models, DCM schemas, bootstrap SQL, or when prepping the demo for another attendee account. Triggers on keywords pawcore, dbt on snowflake, dcm, create dbt project, execute dbt project, lot341, region-lot mapping.
---

# demo-coco-dbt-dcm

## Purpose
Show attendees how Cortex Code pair-programs a real pipeline: CSVs (bundled in `data/`) → RAW (uploaded via `snow stage copy`) → dbt staging views → curated domain tables (matching the Cortex AI HOL #1 contract) → analytical marts. DCM owns the schemas; dbt owns every table. `.env`-gated deploy prevents accidental overwrites of an existing `PAWCORE_ANALYTICS` install.

## Architecture
```
CSVs (repo data/ folder)
     │ snow stage copy + COPY INTO
     ▼
${TARGET_DB}.RAW.{TELEMETRY, QUALITY_LOGS, CUSTOMER_REVIEWS, SLACK_MESSAGES}
     │ dbt staging (views: CAST, UPPER, null filter)
     ▼
${TARGET_DB}.STAGING.stg_*
     │ dbt hol/* (tables with schema overrides)
     ▼
${TARGET_DB}.{DEVICE_DATA, MANUFACTURING, SUPPORT}.*   ← domain tables
     │ dbt marts (pre-aggregated)
     ▼
${TARGET_DB}.ANALYTICS.MART_{LOT_QUALITY_CORRELATION, REGIONAL_CUSTOMER_IMPACT, BATTERY_MOISTURE_CORRELATION}
     │
     ▼
${TARGET_DB}.SEMANTIC.PAWCORE_ANALYSIS  ← semantic view (22 VQRs)
     │
     ▼
SNOWFLAKE_INTELLIGENCE.AGENTS.PAWCORE_ASSISTANT  ← Cortex Agent
```

Ownership split: bootstrap SQL owns DB/WH/stage/RAW; DCM owns schemas; dbt owns every non-raw table.

## Key Files
| Path | Role |
|---|---|
| `scripts/deploy.py` | Gated end-to-end deploy. Reads `.env`, refuses to run without `I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=1`. |
| `.env.example` | Config template. `TARGET_DATABASE` defaults to `PAWCORE_ANALYTICS` (HOL-compat) but can be overridden. |
| `bootstrap/00_bootstrap.sql` | DB + WH + internal stage. `envsubst`-parameterized. |
| `bootstrap/01_load_raw.sql` | CREATE TABLE + COPY INTO from stage. Column mapping for 8-column customer_reviews.csv (REVIEW_ID, DEVICE_ID, LOT_NUMBER, PRODUCT, REGION, DATE, REVIEW_TEXT, RATING). |
| `dcm/manifest.yml` + `sources/definitions/schemas.sql` | DEFINE SCHEMA for 8 schemas (incl. DBT_PROD for dbt default target). |
| `dbt/dbt_project.yml` | Per-layer `+schema` routing: staging→STAGING, hol/device_data→DEVICE_DATA, etc. |
| `dbt/macros/generate_schema_name.sql` | Strips the `DBT_PROD` prefix so `+schema: DEVICE_DATA` lands at exact FQN. |
| `dbt/models/staging/stg_customer_reviews.sql` | Typed passthrough. device_id and lot_number come from the source CSV (no synthetic mapping). |
| `dbt/dbt_packages/dbt_utils/` | Vendored. Native dbt on Snowflake requires packages present at `CREATE DBT PROJECT` time. |
| `snowflake/create_semantic_view.sql` | 6 tables, 17 metrics, 22 AI Verified Queries, AI_SQL_GENERATION + AI_QUESTION_CATEGORIZATION. |
| `snowflake/create_agent.sql` | Cortex Agent with text-to-SQL tool pointed at semantic view. |
| `docs/prompt_guide.md` | 22-question investigation flow for the agent. |
| `docs/facilitator_runbook.md` | Timed 60-min webinar script with CoCo prompts. |

## Extension Playbook — add a new mart

1. Decide the business question. Pick the staging sources (prefer `stg_telemetry`, `stg_quality_logs`, `stg_customer_reviews`).
2. **Check for fanout BEFORE writing the join.** If joining reviews (1,550) × telemetry (21,000) on `device_id`, pre-aggregate telemetry to one row per device first. See `mart_regional_customer_impact.sql` for the pattern.
3. Create `dbt/models/marts/mart_<name>.sql` with `{{ config(materialized='table') }}`.
4. Add an entry to `dbt/models/marts/__marts.yml` with `not_null` on any numeric column you claim as a business metric.
5. Re-deploy: `uv run scripts/deploy.py --stop-at build` (re-stages dbt project + rebuilds).
6. Verify the new mart with a sanity-check query (sum of row counts matches a known source count).

## Snowflake Objects (defaults)
| Object | Name | Owner |
|---|---|---|
| Database | `PAWCORE_ANALYTICS` (override via `TARGET_DATABASE` in `.env`) | bootstrap |
| Warehouse | `PAWCORE_DEMO_WH` (override via `TARGET_WAREHOUSE`) | bootstrap |
| Schemas | `RAW`, `STAGING`, `DEVICE_DATA`, `MANUFACTURING`, `SUPPORT`, `ANALYTICS`, `SEMANTIC`, `DBT_PROD` | DCM |
| Stage | `RAW.PAWCORE_DATA_STAGE` | bootstrap |
| DBT PROJECT | `PUBLIC.PAWCORE_DBT` | dbt |
| DCM PROJECT | `COCO_DCM_PROJECT` in `PUBLIC` | DCM |
| Semantic View | `SEMANTIC.PAWCORE_ANALYSIS` | create_semantic_view.sql |
| Agent | `SNOWFLAKE_INTELLIGENCE.AGENTS.PAWCORE_ASSISTANT` | create_agent.sql |

## Gotchas
- **Native dbt on Snowflake CREATE parses packages at create time.** `packages.yml` with uninstalled packages → `CREATE DBT PROJECT` fails. Vendor `dbt_packages/` into git.
- **`profiles.yml` `database:` must match TARGET_DB.** If attendee overrides `TARGET_DATABASE` in `.env`, they also need to edit `dbt/profiles.yml` — this is the one file that's not envsubst-covered (native dbt parses profiles.yml at CREATE time, before our scripts can substitute). Flagged in `docs/self_walkthrough.md`.
- **`EXECUTE DBT PROJECT` syntax is `args='build'` with single-quote value, NOT `ARGS('build')` with parens.** The latter is a syntax error.
- **customer_reviews.csv column order:** `$1=REVIEW_ID, $2=DEVICE_ID, $3=LOT_NUMBER, $4=PRODUCT, $5=REGION, $6=DATE, $7=REVIEW_TEXT, $8=RATING`. The COPY INTO maps these to table columns (skipping $4=PRODUCT).
- **Review data uses `Americas` (capitalized), telemetry uses the same.** After `UPPER()` in staging it becomes `AMERICAS`. Accepted values must be `['AMERICAS','EMEA','APAC']` — NOT `'NORTH AMERICA'`.
- **Regional mart fanout.** Don't join `stg_customer_reviews` directly to `stg_telemetry` on `device_id` — each review's device matches multiple telemetry rows → 4x inflation. Pre-aggregate telemetry to one row per device first.
- **DCM can't own its own parent.** `pre_deploy.sql` (or bootstrap) must create the database before `snow dcm deploy`.
- **`snow dcm deploy` uses the connection's default DB** unless you pass `--database`. Easy to accidentally create the DCM_PROJECT object in the wrong DB.
- **`snow dcm create` is separate from `deploy`.** First run needs `create`, subsequent runs need `deploy`. Use `|| true` on create to make it idempotent.
