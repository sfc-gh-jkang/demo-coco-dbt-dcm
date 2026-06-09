# Prompt to Pipeline: Cortex Code + dbt on Snowflake + DCM

A 60-minute hands-on lab that builds a complete, production-shaped Snowflake data pipeline using AI-assisted development.

---

## Objective

Demonstrate how **Cortex Code** (Snowflake's AI coding agent), **dbt Projects on Snowflake**, and **Database Change Management (DCM)** work together to take a dataset from raw CSVs to a queryable Snowflake Intelligence agent — entirely within Snowflake, no external infrastructure.

By the end of this lab, participants will have:

1. Used DCM to declaratively define and version-control 8 database schemas
2. Built a 3-layer dbt pipeline (staging → curated domain tables → marts) that runs natively inside Snowflake
3. Created a semantic view that maps business concepts to SQL
4. Deployed a Cortex Agent that answers natural-language questions about the data
5. Experienced using Cortex Code as a pair programmer to generate and explain all of the above

---

## What It Builds

The deploy script creates the following Snowflake objects in a single database (configurable via `.env`):

```
PAWCORE_ANALYTICS                          ← database (name configurable)
├── RAW                                    ← 4 source tables (CSV-loaded)
│   ├── TELEMETRY          (21,000 rows)
│   ├── QUALITY_LOGS       (1,050 rows)
│   ├── CUSTOMER_REVIEWS   (1,550 rows)
│   └── SLACK_MESSAGES     (37 rows)
├── STAGING                                ← 4 dbt views (cast, normalize, filter)
├── DEVICE_DATA                            ← 1 curated domain table
│   └── TELEMETRY
├── MANUFACTURING                          ← 1 curated domain table
│   └── QUALITY_LOGS
├── SUPPORT                                ← 2 curated domain tables
│   ├── CUSTOMER_REVIEWS
│   └── SLACK_MESSAGES
├── ANALYTICS                              ← 3 analytical marts
│   ├── MART_LOT_QUALITY_CORRELATION
│   ├── MART_REGIONAL_CUSTOMER_IMPACT
│   └── MART_BATTERY_MOISTURE_CORRELATION
└── SEMANTIC
    └── PAWCORE_ANALYSIS                   ← semantic view (6 tables, 17 metrics, 22 VQRs)

SNOWFLAKE_INTELLIGENCE.AGENTS
└── PAWCORE_ASSISTANT                      ← Cortex Agent with text-to-SQL
```

Plus: a warehouse (`PAWCORE_DEMO_WH`) and an internal stage.

---

## Dependencies

| Dependency | Version | Purpose |
|-----------|---------|---------|
| [Git](https://git-scm.com/downloads) | any | Clone this repo |
| [Snowflake CLI (`snow`)](https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation) | v3.0+ | Executes all SQL and DCM commands |
| [uv](https://docs.astral.sh/uv/getting-started/installation/) | latest | Python environment + dependency management (auto-installs Python 3.10+ if missing) |
| [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code) | latest | AI pair programmer (for hands-on exercises) |
| Snowflake account | any edition | Must have ACCOUNTADMIN role |

**No other tools required.** No dbt CLI, no Docker, no Node.js, no GitHub PAT, no cloud credentials. Everything runs through `snow` CLI and Snowflake-native execution. Data files are included in the repo under `data/`.

**Python dependencies** (managed automatically by uv):
- `python-dotenv` — .env file parsing (runtime)
- `pytest` — test runner (dev only)
- `ruff` — linter (dev only)

### Install from scratch (zero dependencies)

If starting on a fresh machine with nothing installed:

**macOS:**
```bash
# Git (included with Xcode CLI tools)
xcode-select --install

# uv (installs Python automatically)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Snowflake CLI
pip install snowflake-cli-labs
# or: brew install snowflake-cli

# Cortex Code (VS Code extension)
# Install from VS Code marketplace: search "Cortex Code"
```

**Windows (PowerShell as admin):**
```powershell
# Git
winget install Git.Git

# uv (installs Python automatically)
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# Snowflake CLI
pip install snowflake-cli-labs
# or: winget install Snowflake.SnowflakeCLI

# Cortex Code (VS Code extension)
# Install from VS Code marketplace: search "Cortex Code"
```

**Linux:**
```bash
# Git
sudo apt install git  # Debian/Ubuntu
# or: sudo dnf install git  # Fedora

# uv (installs Python automatically)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Snowflake CLI
pip install snowflake-cli-labs

# Cortex Code (VS Code extension)
# Install from VS Code marketplace: search "Cortex Code"
```

After installing, configure your Snowflake connection:
```bash
snow connection add        # Interactive setup
snow connection test       # Verify it works
```

---

## The PawCore Dataset

A synthetic IoT dataset simulating **PawCore**, a smart pet collar manufacturer investigating a quality issue:

| Table | Rows | Description |
|-------|------|-------------|
| `TELEMETRY` | 21,000 | Battery, humidity, temperature readings per device |
| `QUALITY_LOGS` | 1,050 | Manufacturing QA pass/fail by lot and test type |
| `CUSTOMER_REVIEWS` | 1,550 | Star ratings (1-5) with review text |
| `SLACK_MESSAGES` | 37 | Internal team Slack messages about issues |

**Embedded signal**: LOT341 (EMEA region) has systematically lower battery levels (overall avg ~78% — degraded to ~74% pre-fix, recovered to ~92% after the Nov 15 fix — vs 92-94% for healthy lots, with 500+ critical readings below 20%) correlated with high humidity, failed moisture resistance tests, and low customer ratings. The Cortex Agent should discover this correlation when asked "Which lot has the worst customer ratings, and why?"

---

## Quick Start

```bash
git clone https://github.com/sfc-gh-jkang/demo-coco-dbt-dcm.git
cd demo-coco-dbt-dcm

cp .env.example .env
# Edit .env: set SNOWFLAKE_CONNECTION, TARGET_DATABASE, TARGET_WAREHOUSE
# Set I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=1

uv run scripts/deploy.py
```

Deploy takes ~4 minutes. On success:
```
✓ Deploy complete. Target: PAWCORE_ANALYTICS on <your_connection>
  Try: "Which lot has the worst customer ratings?"
```

### Deploy Flags

```bash
uv run scripts/deploy.py --stop-at raw-load   # Stop after CSV loading (steps 1-3)
uv run scripts/deploy.py --stop-at build       # Stop after dbt build (steps 1-5)
uv run scripts/deploy.py --resume              # Run all 7 steps (default)
uv run scripts/deploy.py --semantic-only       # Rebuild steps 6-7 only (semantic view + agent), ~15s
uv run scripts/deploy.py --verify              # Validate deployed objects after build
uv run scripts/deploy.py --teardown            # Drop all objects and exit
uv run scripts/deploy.py --dry-run             # Show what would run without executing
uv run scripts/deploy.py --prefer-envsubst     # Use system envsubst if installed
```

### Verify

```bash
snow sql -c <conn> -q "
SELECT 'TELEMETRY' AS t, COUNT(*) AS n FROM <DB>.DEVICE_DATA.TELEMETRY
UNION ALL SELECT 'QUALITY_LOGS', COUNT(*) FROM <DB>.MANUFACTURING.QUALITY_LOGS
UNION ALL SELECT 'REVIEWS', COUNT(*) FROM <DB>.SUPPORT.CUSTOMER_REVIEWS;
"
```

Expected: TELEMETRY=21000, QUALITY_LOGS=1050, REVIEWS=1550.

### Teardown

```bash
snow sql -f teardown.sql
```

---

## Architecture

### Deploy Pipeline (7 Steps)

```
.env ──► deploy.py ──► snow CLI ──► Snowflake Account

Step 1: Bootstrap       → DB, warehouse, internal stage
Step 2: DCM deploy      → 8 schema definitions (declarative, version-controlled)
Step 3: Raw load        → Upload data/ to stage + COPY INTO 4 RAW tables
Step 4: dbt stage       → Upload parameterized dbt project to internal stage
Step 5: dbt build       → EXECUTE DBT PROJECT (11 models + 34 tests = 45 nodes)
Step 6: Semantic view   → CREATE SEMANTIC VIEW with metrics, dimensions, relationships
Step 7: Agent           → CREATE AGENT with text-to-SQL tool
```

### Data Flow

```
Local CSVs (data/ folder in repo)
    │
    ▼  snow stage copy → COPY INTO
RAW.{telemetry, quality_logs, customer_reviews, slack_messages}
    │
    ▼  dbt staging views (CAST, UPPER, null filtering)
STAGING.stg_*
    │
    ├──► Curated domain tables (compatible with Cortex AI HOL #1)
    │    DEVICE_DATA.TELEMETRY
    │    MANUFACTURING.QUALITY_LOGS
    │    SUPPORT.{CUSTOMER_REVIEWS, SLACK_MESSAGES}
    │
    └──► Analytical marts (pre-aggregated, fanout-safe)
         ANALYTICS.mart_*
              │
              ▼
         SEMANTIC.PAWCORE_ANALYSIS (semantic view)
              │
              ▼
         SNOWFLAKE_INTELLIGENCE.AGENTS.PAWCORE_ASSISTANT
```

### Ownership Split

| Layer | Owner | What it manages |
|-------|-------|-----------------|
| Infrastructure (DB, WH, stage) | Bootstrap SQL | `00_bootstrap.sql` |
| Schema lifecycle (8 schemas) | DCM | `dcm/sources/definitions/schemas.sql` |
| All data objects (tables + views) | dbt | `dbt/models/` |
| AI contract (semantic view) | SQL script | `snowflake/create_semantic_view.sql` |
| User-facing agent | SQL script | `snowflake/create_agent.sql` |

---

## Repository Structure

```
demo-coco-dbt-dcm/
├── data/
│   ├── Telemetry/device_telemetry.csv     # 21K IoT sensor readings
│   ├── Manufacturing/quality_logs.csv     # 1K QA test results
│   └── Document_Stage/
│       ├── customer_reviews.csv           # 1.5K star ratings
│       └── pawcore_slack.csv              # 37 internal messages
├── scripts/
│   └── deploy.py              # Single entry point — runs all 7 steps
├── bootstrap/
│   ├── 00_bootstrap.sql       # DB, WH, internal stage
│   └── 01_load_raw.sql        # CREATE TABLE + COPY INTO from stage
├── dcm/
│   ├── manifest.yml           # DCM project definition
│   ├── pre_deploy.sql         # Creates parent DB+WH (DCM can't own its parent)
│   ├── post_deploy.sql        # Verification (SHOW SCHEMAS)
│   └── sources/definitions/
│       └── schemas.sql        # DEFINE SCHEMA for all 8 schemas
├── dbt/
│   ├── dbt_project.yml        # Materialization + schema routing config
│   ├── profiles.yml           # Connection template (${TARGET_DB} substituted)
│   ├── macros/
│   │   └── generate_schema_name.sql  # Exact schema placement (no prefix)
│   ├── models/
│   │   ├── sources.yml        # 4 raw sources with tests
│   │   ├── staging/           # 4 views: cast, normalize, filter
│   │   ├── hol/               # 4 curated domain tables (Cortex AI HOL-compatible)
│   │   └── marts/             # 3 analytical aggregations
│   └── dbt_packages/dbt_utils/  # Vendored (no network at build time)
├── snowflake/
│   ├── create_semantic_view.sql   # 6 tables, 17 metrics, 22 VQRs
│   ├── create_agent.sql           # Cortex Agent with text-to-SQL
│   ├── snowsight_worksheet.sql    # 10 ready-to-paste SEMANTIC_VIEW queries
│   └── run_pipeline.sql           # EXECUTE DBT PROJECT + smoke tests
├── streamlit/
│   ├── app.py                     # Streamlit-in-Snowflake dashboard
│   └── environment.yml            # SiS deployment dependencies
├── docs/
│   ├── architecture.md            # Mermaid diagrams
│   ├── facilitator_runbook.md     # 60-min timed facilitator script
│   ├── attendee_quickstart.md     # Pre-work checklist
│   ├── self_walkthrough.md        # Solo rehearsal guide
│   ├── speaker_notes.md           # Per-slide notes
│   ├── prompt_guide.md            # 22 agent questions with expected answers
│   ├── certificate_template.html  # Print-ready completion certificate
│   └── exercises/                 # 7 hands-on activities (6 core + 1 bonus)
├── tests/
│   ├── conftest.py                # Shared pytest fixtures
│   └── test_deploy.py            # 103 unit tests for deploy.py
├── .env.example                   # Configuration template
├── pyproject.toml                 # Python 3.10+, pytest, ruff, python-dotenv
├── teardown.sql                   # DROP everything
├── AGENTS.md                      # AI agent project constraints
└── LICENSE                        # Apache-2.0
```

---

## Component Details

### `scripts/deploy.py`

Cross-platform deploy engine (one runtime dependency: `python-dotenv`). Key behaviors:

- **Single-knob config**: `.env` is the only file you edit. All SQL templates use `${TARGET_DB}` / `${TARGET_WH}` placeholders substituted at runtime.
- **Safety gate**: aborts unless `I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=1` is set.
- **Incremental**: `--stop-at raw-load` / `--stop-at build` for partial deploys.
- **Idempotent**: every step uses `CREATE OR REPLACE` / `IF NOT EXISTS`.
- **Non-fatal agent step**: step 7 failure prints a UI fallback, doesn't abort.

### `dcm/` — Database Change Management

Manages schema lifecycle declaratively via `DEFINE SCHEMA` statements. DCM tracks state in a `COCO_DCM_PROJECT` object in the `PUBLIC` schema. Schemas are additive-only — DCM never drops schemas it created.

### `dbt/` — Transformations

**3-layer model architecture:**

| Layer | Materialization | Purpose |
|-------|----------------|---------|
| `staging/` | view | CAST, UPPER, null filter — zero business logic |
| `hol/` | table | Curated domain tables — schema-compatible with [Cortex AI HOL #1](https://quickstarts.snowflake.com/guide/getting-started-with-cortex-analyst/) |
| `marts/` | table | Pre-aggregated analytics (fanout-safe for semantic view) |

**Key design choices:**
- `generate_schema_name.sql` macro strips dbt's default prefix so `+schema: DEVICE_DATA` places the table at `DEVICE_DATA.TELEMETRY` exactly.
- `dbt_utils` is vendored because `EXECUTE DBT PROJECT` has no internet access.
- Marts pre-aggregate per grain before joining to avoid N×M fanout.

### `snowflake/create_semantic_view.sql`

Defines the Cortex Analyst contract (`PAWCORE_ANALYSIS`) with:
- 6 tables (raw + marts) with detailed comments and synonyms
- 5 relationships (lot_number as join key across domains)
- 16 facts, 15 dimensions, 17 metrics
- Synonyms for natural-language discovery (e.g., "csat" → avg_rating)
- Domain knowledge in comments (e.g., "LOT341 is problematic")
- `AI_SQL_GENERATION` — instructs Cortex Analyst to prefer marts, round to 2dp
- `AI_QUESTION_CATEGORIZATION` — rejects off-topic questions, prompts for specifics
- `AI_VERIFIED_QUERIES` — 22 verified queries (7 onboarding) across 6 categories:
  - Lot-level analysis, humidity/battery correlation, customer impact
  - Device telemetry details, manufacturing QA, cross-domain root cause

### `snowflake/create_agent.sql`

Creates `PAWCORE_ASSISTANT` in `SNOWFLAKE_INTELLIGENCE.AGENTS` with:
- `cortex_analyst_text_to_sql` tool pointed at the semantic view
- Instructions to cross-reference manufacturing + field + customer data
- 3 sample questions for users

---

## Hands-On Lab Activities

| # | Activity | Duration | Doc |
|---|----------|----------|-----|
| 1 | Explore the pipeline with CoCo (3 prompts) | 10 min | [01_explore.md](docs/exercises/01_explore.md) |
| 2 | Build your own mart (choose a business question) | 13 min | [02_build_mart.md](docs/exercises/02_build_mart.md) |
| 3 | Create a Snowflake Intelligence agent | 10 min | [03_agent.md](docs/exercises/03_agent.md) |
| 4 | Add a verified query to the semantic view | 5-8 min | [04_add_verified_query.md](docs/exercises/04_add_verified_query.md) |
| 5 | Create a battery alert | 5-8 min | [05_create_alert.md](docs/exercises/05_create_alert.md) |
| 6 | Track remediation (version 2 storyline) | 5-8 min | [06_remediation.md](docs/exercises/06_remediation.md) |
| 7 | Advanced: observability, eval, search, guardrails | 20-30 min | [07_advanced_cortex.md](docs/exercises/07_advanced_cortex.md) |

Facilitator script with timing anchors: [facilitator_runbook.md](docs/facilitator_runbook.md)

---

## Testing

```bash
uv run pytest tests/ -v    # 103 unit tests, <1s
uv run ruff check .        # Lint
```

Tests cover all `deploy.py` functions with mocked subprocess calls. No Snowflake account needed to run them.

---

## Design Constraints

1. **Trial-account compatible** — works on any Snowflake edition, no SE-only features
2. **HOL-compatible** — curated domain tables match the schema of the [Cortex AI HOL #1](https://quickstarts.snowflake.com/guide/getting-started-with-cortex-analyst/), so participants can continue directly into that lab
3. **Single-knob config** — `.env` is the only file you edit
4. **Idempotent** — safe to re-run at any time
5. **Cross-platform** — one runtime dep (`python-dotenv`), no bash/rsync dependencies
6. **Offline build** — dbt_utils vendored, no network fetch during `EXECUTE DBT PROJECT`

---

## Repository Owner

- **Owner**: John Kang, Sales Engineer, Snowflake
- **Contact**: john.kang@snowflake.com | [@sfc-gh-jkang](https://github.com/sfc-gh-jkang)
- **License**: Apache-2.0
