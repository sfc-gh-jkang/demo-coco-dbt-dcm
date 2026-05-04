---
name: demo-coco-dbt-dcm
description: 60-minute webinar HOL building a PawCore data pipeline with Cortex Code (CoCo), dbt Projects on Snowflake, and DCM. Use this skill when working in ~/Code/demo-coco-dbt-dcm, when adding/changing dbt models, DCM schemas, bootstrap SQL, or when prepping the demo for another attendee account. Triggers on keywords pawcore, dbt on snowflake, dcm, create dbt project, execute dbt project, lot341, region-lot mapping.
---

# demo-coco-dbt-dcm

## Purpose
Show attendees how Cortex Code pair-programs a real pipeline: CSVs → RAW (loaded via `COPY FILES` from upstream HOL git) → dbt staging views → HOL-shape tables (matching the Cortex AI HOL #1 contract) → analytical marts. DCM owns the schemas; dbt owns every table. `.env`-gated deploy prevents accidental overwrites of an existing `PAWCORE_ANALYTICS` install.

## Architecture
```
CSVs (upstream HOL GitHub)
     │ COPY FILES
     ▼
${TARGET_DB}.RAW.{TELEMETRY, QUALITY_LOGS, CUSTOMER_REVIEWS, SLACK_MESSAGES}
     │ dbt staging (views)
     ▼
${TARGET_DB}.STAGING.stg_*   + intermediate/int_region_lot_device_pool
     │ dbt hol/* (tables with schema overrides)
     ▼
${TARGET_DB}.{DEVICE_DATA, MANUFACTURING, SUPPORT}.*   ← HOL contract
     │ dbt marts
     ▼
${TARGET_DB}.ANALYTICS.MART_{LOT_QUALITY_CORRELATION, REGIONAL_CUSTOMER_IMPACT, BATTERY_MOISTURE_CORRELATION}
```

Ownership split: bootstrap SQL owns DB/WH/stage/RAW; DCM owns schemas; dbt owns every non-raw table.

## Key Files
| Path | Role |
|---|---|
| `scripts/deploy.sh` | Gated end-to-end deploy. Reads `.env`, refuses to run without `I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=1`. |
| `.env.example` | Config template. `TARGET_DATABASE` defaults to `PAWCORE_ANALYTICS` (HOL-compat) but can be overridden. |
| `bootstrap/00_bootstrap.sql` | DB + WH + secret + API integration + 2 git repos (upstream HOL + demo). `envsubst`-parameterized. |
| `bootstrap/01_load_raw.sql` | COPY FILES → RAW.* tables. Column mapping for `customer_reviews.csv` (order: review_id, product, region, date, review_text, rating). |
| `dcm/manifest.yml` + `sources/definitions/schemas.sql` | DEFINE SCHEMA for 8 schemas (incl. DBT_PROD for dbt default target). |
| `dbt/dbt_project.yml` | Per-layer `+schema` routing: staging→STAGING, hol/device_data→DEVICE_DATA, etc. |
| `dbt/macros/generate_schema_name.sql` | Strips the `DBT_PROD` prefix so `+schema: DEVICE_DATA` lands at exact FQN. |
| `dbt/models/intermediate/int_region_lot_device_pool.sql` | Derives (region, lot, device_id) triples from `stg_telemetry`. Drives review→device assignment. |
| `dbt/models/staging/stg_customer_reviews.sql` | Round-robin review → real device assignment. `relationships` test enforces `device_id` exists in `stg_telemetry`. |
| `dbt/dbt_packages/dbt_utils/` | Vendored. Native dbt on Snowflake requires packages present at `CREATE DBT PROJECT` time. |
| `docs/self_walkthrough.md` | Step-by-step solo rehearsal guide. |
| `docs/facilitator_runbook.md` | Timed 60-min webinar script with CoCo prompts. |

## Extension Playbook — add a new mart

1. Decide the business question. Pick the staging sources (prefer `stg_telemetry`, `stg_quality_logs`, `stg_customer_reviews`).
2. **Check for fanout BEFORE writing the join.** If joining reviews (1,550) × telemetry (21,000) on `device_id`, pre-aggregate telemetry to one row per device first. See `mart_regional_customer_impact.sql` for the pattern — it failed on first attempt with 6,545 review rows instead of 1,550.
3. Create `dbt/models/marts/mart_<name>.sql` with `{{ config(materialized='table') }}`.
4. Add an entry to `dbt/models/marts/__marts.yml` with `not_null` on any numeric column you claim as a business metric — this shields against future regressions like the null `avg_battery_level` bug.
5. Push to git.
6. `ALTER GIT REPOSITORY ${TARGET_DB}.PUBLIC.DEMO_REPO FETCH;` then `CREATE OR REPLACE DBT PROJECT ... FROM @DEMO_REPO/branches/main/dbt/` then `EXECUTE DBT PROJECT ... args='build';`
7. Verify the new mart with a sanity-check query (sum of row counts matches a known source count).

## Snowflake Objects (defaults)
| Object | Name | Owner |
|---|---|---|
| Database | `PAWCORE_ANALYTICS` (override via `TARGET_DATABASE` in `.env`) | bootstrap |
| Warehouse | `PAWCORE_DEMO_WH` (override via `TARGET_WAREHOUSE`) | bootstrap |
| Schemas | `RAW`, `STAGING`, `DEVICE_DATA`, `MANUFACTURING`, `SUPPORT`, `ANALYTICS`, `SEMANTIC`, `DBT_PROD` | DCM |
| API Integration | `pawcore_github_api` | bootstrap |
| Secret | `github_sfc_gh_jkang_pat` | bootstrap |
| Git Repos | `UPSTREAM_HOL_REPO`, `DEMO_REPO` | bootstrap |
| DBT PROJECT | `COCO_DBT_DCM.PUBLIC.PAWCORE_DBT` | dbt |
| DCM PROJECT | `COCO_DCM_PROJECT` in `PUBLIC` | DCM |

## Gotchas
- **Native dbt on Snowflake CREATE parses packages at create time.** `packages.yml` with uninstalled packages → `CREATE DBT PROJECT` fails. Vendor `dbt_packages/` into git.
- **`profiles.yml` `database:` must match TARGET_DB.** If attendee overrides `TARGET_DATABASE` in `.env`, they also need to edit `dbt/profiles.yml` — this is the one file that's not envsubst-covered (native dbt parses profiles.yml at CREATE time, before our scripts can substitute). Flagged in `docs/self_walkthrough.md`.
- **`EXECUTE DBT PROJECT` syntax is `args='build'` with single-quote value, NOT `ARGS('build')` with parens.** The latter is a syntax error. Took 20 min of blind retries to figure out.
- **Upstream HOL CSVs moved from `/data/` to `/2-Cortex-Code/data/`.** The upstream `pawcore_setup.sql` in `calebaalexander/HandsOnLabs` still has the old paths — broken in source. Flagged to Caleb.
- **customer_reviews.csv is `$1=review_id, $2=product, $3=region, $4=date, $5=review_text, $6=rating`.** NOT the order the upstream COPY INTO suggests.
- **Review data uses `Americas` (capitalized), telemetry uses the same.** After `UPPER()` in staging it becomes `AMERICAS`. Accepted values must be `['AMERICAS','EMEA','APAC']` — NOT `'NORTH AMERICA'`.
- **Regional mart fanout.** Don't join `stg_customer_reviews` directly to `stg_telemetry` on `device_id` — each review's device matches multiple telemetry rows → 4x inflation. Pre-aggregate telemetry to one row per device first.
- **DCM can't own its own parent.** `pre_deploy.sql` (or bootstrap) must create the database before `snow dcm deploy`.
- **`snow dcm deploy` uses the connection's default DB** unless you pass `--database`. Easy to accidentally create the DCM_PROJECT object in the wrong DB.
- **`snow dcm create` is separate from `deploy`.** First run needs `create`, subsequent runs need `deploy`. Use `|| true` on create to make it idempotent.
- **GitHub PAT capture bug.** `$(gh auth switch --user X && gh auth token)` bleeds the switch's stdout into the token → corrupted PAT → `093550 Operation 'clone' is not authorized`. Always redirect: `gh auth switch --user X >/dev/null 2>&1 && gh auth token`.
