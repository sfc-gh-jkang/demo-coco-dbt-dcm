# Self-Guided Walkthrough

Solo run-through of the demo. Takes ~60 minutes the first time. Same content as the live webinar — exactly what you'd do during the hour.

---

## Before you start (5 min)

1. **Snowflake trial**: https://signup.snowflake.com/ (Standard, any cloud). You get ACCOUNTADMIN.
2. **Snowflake CLI**: `brew install snowflake-cli` (or https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation)
3. **Connection**:
   ```bash
   snow connection add --connection-name mytrial --account <your-locator> --user <your-user> --authenticator externalbrowser
   snow connection test --connection mytrial
   ```
4. **Cortex Code**: https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code → `cortex --version` → `cortex connections set mytrial`
5. **GitHub PAT** (only if you forked this repo and kept your fork private — the upstream is public): https://github.com/settings/tokens → classic, `repo` scope
6. **Clone + configure**:
   ```bash
   git clone https://github.com/sfc-gh-jkang/demo-coco-dbt-dcm.git
   cd demo-coco-dbt-dcm
   cp .env.example .env
   # edit .env: set SNOWFLAKE_CONNECTION=mytrial, I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=1 (GITHUB_PAT can stay blank)
   ```

---

## Phase 1 — Deploy the pipeline foundation (15 min)

Run the first 3 steps of deploy.py:

```bash
uv run scripts/deploy.py --stop-at raw-load
```

**What you'll see:**
- Safety gate check (passes because `I_UNDERSTAND=1`)
- Step 1/7: Bootstrap — DB, warehouse, secret, API integration, 2 git repos
- Step 2/7: DCM create + deploy — 8 schemas
- Step 3/7: Raw CSVs loaded (21000 + 1050 + 1550 + 37 rows)
- `✓ Stopped at raw-load`

**Quick verify:**
```bash
snow sql -c mytrial -q "
USE WAREHOUSE PAWCORE_DEMO_WH;
SELECT 'TELEMETRY' AS t, COUNT(*) FROM PAWCORE_ANALYTICS.RAW.TELEMETRY
UNION ALL SELECT 'QUALITY_LOGS', COUNT(*) FROM PAWCORE_ANALYTICS.RAW.QUALITY_LOGS
UNION ALL SELECT 'CUSTOMER_REVIEWS', COUNT(*) FROM PAWCORE_ANALYTICS.RAW.CUSTOMER_REVIEWS
UNION ALL SELECT 'SLACK_MESSAGES', COUNT(*) FROM PAWCORE_ANALYTICS.RAW.SLACK_MESSAGES"
```

---

## Phase 2 — Activity 1: Ask CoCo (10 min)

Open [docs/exercises/01_explore.md](exercises/01_explore.md) and run the 3 prompts in your own CoCo:

1. "What did DCM just do?"
2. "Walk me through stg_customer_reviews"
3. "Summarize the raw data we just loaded"

For each, check that CoCo's answer matches the expected elements in the exercise doc.

---

## Phase 3 — Build the dbt pipeline (3 min)

Run the next 2 steps:

```bash
uv run scripts/deploy.py --stop-at build
```

**Expected:** `Done. PASS=48 WARN=0 ERROR=0 SKIP=0`.

---

## Phase 4 — Activity 2: Build-your-own mart (13 min)

Open [docs/exercises/02_build_mart.md](exercises/02_build_mart.md). Pick Option A (easiest), B, or C.

1. Copy `dbt/models/marts/_exercise_starter.sql` → `mart_<your_choice>.sql`
2. Prompt CoCo with the template in the exercise doc
3. Add the entry to `__marts.yml` with the tests listed
4. Commit locally on a new branch (you won't push to main unless you're a maintainer)
5. Re-run CREATE DBT PROJECT pointed at your branch + EXECUTE to build just your mart

**Can't push to the repo?** Skip the git dance and run the generated SQL as a one-off `CREATE TABLE` in Snowsight. Same end state, no dbt test wrapping.

---

## Phase 5 — Activity 3: Plug in an agent (10 min)

Run the last 2 steps:

```bash
uv run scripts/deploy.py --semantic-only   # completes steps 6-7 (semantic view + agent)
```

**What happens:**
- Step 6/7: Creates `PAWCORE_ANALYTICS.SEMANTIC.PAWCORE_ANALYSIS` semantic view
- Step 7/7: Creates `PAWCORE_ASSISTANT` agent (if CREATE AGENT SQL works; otherwise UI fallback)

**Open the agent:** Snowsight → **AI & ML** → **Snowflake Intelligence** → `PAWCORE_ASSISTANT`.

Ask the 3 questions from [docs/exercises/03_agent.md](exercises/03_agent.md):

1. "Which lot has the worst customer ratings, and why?"
2. "Is there a correlation between humidity and battery life?"
3. "If you were the head of product, what would you do next?"

---

## Phase 6 — Recap

What you built:
- 8 schemas via DCM (git-backed, plan-reviewed, deployable)
- 4 raw tables loaded from upstream HOL CSVs
- 4 staging views with typing, normalization, and null filtering
- 4 HOL-shape tables (exact contract with the Cortex AI HOL)
- 3 analytical marts (+ 1 you built yourself)
- 1 semantic view describing everything
- 1 Snowflake Intelligence agent answering questions in plain English

And CoCo was your pair programmer the whole way.

---

## Teardown

```bash
snow sql -c mytrial -f teardown.sql
```

Drops the database, warehouse, and API integration.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `deploy.py` aborts at safety gate | Set `I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=1` in `.env` |
| `093550 Operation 'clone' is not authorized` | GitHub PAT invalid or missing. Regenerate, update `.env`, rerun |
| `CREATE DBT PROJECT` says "packages not installed" | `git pull` — `dbt_packages/` is vendored in recent commits |
| Test failure on `region` accepted_values | `git pull` — we use `AMERICAS` now (not `NORTH AMERICA`) |
| `CREATE AGENT` privilege error | Fall back to Snowsight UI path in exercises/03_agent.md |
| Agent answers "I don't know" | `SHOW SEMANTIC VIEWS IN SCHEMA PAWCORE_ANALYTICS.SEMANTIC` — if empty, re-run `snowflake/create_semantic_view.sql` |

---

## What's next

- Extend the agent with Cortex Search over the Slack messages (unstructured context)
- Run the full [Cortex AI + Snowflake Intelligence HOL](https://github.com/sfc-gh-calexander/HandsOnLabs/tree/main/1-Cortex-AI-Snowflake-Intelligence) for the deep version of the agent segment
- Fork the repo and adapt it to YOUR domain's dataset — the skeleton (gated deploy + DCM + dbt + semantic view + agent) transfers directly
