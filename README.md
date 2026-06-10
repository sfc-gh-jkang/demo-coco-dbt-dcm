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
| [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code) | latest | AI pair programmer (for hands-on exercises). Requires cross-region inference enabled — see [Quick Start step 3](#3-enable-cortex-code-one-time-required-for-the-hands-on-exercises). |
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

# Snowflake CLI (via uv — no separate pip needed)
uv tool install snowflake-cli

# Cortex Code (VS Code extension)
# Install from VS Code marketplace: search "Cortex Code"
```

**Windows (PowerShell):**
```powershell
# Git — pick one:
winget install Git.Git                # if you have winget (Windows 11+)
# or download from: https://git-scm.com/download/win

# uv (installs Python automatically)
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# Snowflake CLI (via uv — no separate pip needed)
uv tool install snowflake-cli

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

# Snowflake CLI (via uv — no separate pip needed)
uv tool install snowflake-cli

# Cortex Code (VS Code extension)
# Install from VS Code marketplace: search "Cortex Code"
```

Verify everything installed:
```bash
git --version && uv --version && snow --version
```

> **Gotcha — `snow: command not found` after `uv tool install`?** `uv tool install snowflake-cli` installs `snow` into uv's tool bin directory (`~/.local/bin` on macOS/Linux, `%APPDATA%\uv\tools` bin on Windows). That directory must be on your `PATH` for the bare `snow` command to resolve. If `snow --version` fails right after install, run:
> ```bash
> uv tool update-shell
> ```
> then **open a new terminal** (or `source ~/.zshrc` / `~/.bashrc`) and re-check. This is a one-time setup per machine. (uv also prints this same hint automatically when the bin dir isn't on PATH.)

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

### 1. Clone the repo

```bash
git clone https://github.com/sfc-gh-jkang/demo-coco-dbt-dcm.git
cd demo-coco-dbt-dcm
```

### 2. Set up your Snowflake connection

**Option A — Interactive (recommended):**
```bash
snow connection add
```
Follow the prompts. When asked for authenticator, choose `externalbrowser` to log in via your browser (supports SSO/MFA), or `snowflake_jwt` / leave blank for username+password.

**Option B — Manual file edit:**

Create/edit `~/.snowflake/connections.toml` (macOS/Linux) or `%USERPROFILE%\.snowflake\connections.toml` (Windows):

```toml
[my_trial]
account = "ORGNAME-ACCOUNTNAME"    # from your Snowflake URL: https://ORGNAME-ACCOUNTNAME.snowflakecomputing.com
user = "your_username"
authenticator = "externalbrowser"   # opens browser for login (no password stored)
role = "ACCOUNTADMIN"
warehouse = "COMPUTE_WH"           # any existing warehouse
```

Find your account identifier in Snowsight: click your name (bottom-left) → **Account** → copy the `ORGNAME-ACCOUNTNAME` value.

**Verify it works:**
```bash
snow connection test -c my_trial
# or if it's your default connection:
snow connection test
```

### 3. Enable Cortex Code (one-time, required for the hands-on exercises)

The hands-on exercises use **Cortex Code** as your AI pair programmer. On a brand-new trial account this usually needs **one ACCOUNTADMIN command first** — otherwise Cortex Code can't reach an LLM and appears broken with no obvious error.

Cortex Code's models (Claude / GPT) often aren't hosted in your trial's home region, so you must enable **cross-region inference**:

```sql
USE ROLE ACCOUNTADMIN;

-- Route Cortex requests to a region that hosts the models.
-- 'AWS_US' is the best default for Claude Opus; use 'ANY_REGION' for best-effort global routing.
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'AWS_US';
```

Also confirm your user has the Cortex role (all users have it by default via PUBLIC unless your org revoked it):

```sql
SHOW GRANTS TO ROLE PUBLIC;   -- look for SNOWFLAKE.CORTEX_USER
-- If missing: GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE <your_role>;
```

> **Why this is needed:** per the [Cortex Code docs](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code), the CLI is *"available to all Commercial (non-Gov) accounts **with cross-region inference enabled**."* If a model isn't available in your region, cross-region inference is **required**, and enabling it requires ACCOUNTADMIN. On a trial, Cortex Code is billed pay-as-you-go against your trial credits — a lab session uses a negligible amount. For region/model details see [Cross-region inference](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cross-region-inference).

### 4. Configure `.env`

Copy the template and edit it:

```bash
cp .env.example .env        # macOS/Linux
# copy .env.example .env    # Windows (cmd) or: Copy-Item .env.example .env (PowerShell)
```

Then edit `.env` with these values:

| Variable | What to set | How to find it |
|----------|------------|----------------|
| `SNOWFLAKE_CONNECTION` | Your connection name | Run `snow connection list` — use the name of the connection you set up with `snow connection add` |
| `TARGET_DATABASE` | Database name to create | Default `PAWCORE_ANALYTICS` works fine. Change if you want to avoid conflicts. |
| `TARGET_WAREHOUSE` | Warehouse name to create | Default `PAWCORE_DEMO_WH` works fine. |
| `I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE` | `1` | Set to `1` after confirming the database name. This is a safety gate — deploy will refuse to run without it. |

Example `.env` for a trial account:
```
SNOWFLAKE_CONNECTION=my_trial
TARGET_DATABASE=PAWCORE_ANALYTICS
TARGET_WAREHOUSE=PAWCORE_DEMO_WH
I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=1
```

### 5. Deploy

```bash
uv run scripts/deploy.py
```

Deploy takes ~3-4 minutes. On success:
```
✓ Deploy complete. Target: PAWCORE_ANALYTICS on <your_connection>
  Try: "Which lot has the worst customer ratings?"
```

### Deploy Flags

```bash
uv run scripts/deploy.py --stop-at raw-load   # Stop after CSV loading (steps 1-3)
uv run scripts/deploy.py --stop-at build       # Stop after dbt build (steps 1-5)
uv run scripts/deploy.py --dbt-only            # Re-stage + rebuild dbt only (steps 4-5), ~2min
uv run scripts/deploy.py --semantic-only       # Rebuild steps 6-7 only (semantic view + agent), ~15s
uv run scripts/deploy.py --dry-run             # Show what would run without executing
uv run scripts/deploy.py --prefer-envsubst     # Use system envsubst if installed
```

### Verify

```bash
uv run scripts/deploy.py --verify
```

Expected output:
```
  PASS  DEVICE_DATA.TELEMETRY: 21,000 rows
  PASS  MANUFACTURING.QUALITY_LOGS: 1,050 rows
  PASS  SUPPORT.CUSTOMER_REVIEWS: 1,550 rows
  ...
  PASS  VERIFIED QUERIES: 22 registered
  PASS  AGENT: PAWCORE_ASSISTANT
✓ All checks passed.
```

### Teardown

```bash
uv run scripts/deploy.py --teardown   # Drops agent, database, and warehouse
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
│   ├── attendee_quickstart.md     # Pre-work checklist
│   ├── self_walkthrough.md        # Solo rehearsal guide
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

| # | Exercise | Duration | Doc |
|---|----------|----------|-----|
| 1 | Ask CoCo (3 prompts to explore the pipeline) | 10 min | [01_explore.md](docs/exercises/01_explore.md) |
| 2 | Build-Your-Own Mart (choose a business question) | 13 min | [02_build_mart.md](docs/exercises/02_build_mart.md) |
| 3 | Plug in a Snowflake Intelligence Agent | 10 min | [03_agent.md](docs/exercises/03_agent.md) |
| 4 | Add a Verified Query to the semantic view | 5-8 min | [04_add_verified_query.md](docs/exercises/04_add_verified_query.md) |
| 5 | Create a Battery Alert | 5-8 min | [05_create_alert.md](docs/exercises/05_create_alert.md) |
| 6 | Track Remediation (version 2 storyline) | 5-8 min | [06_remediation.md](docs/exercises/06_remediation.md) |
| 7 | Advanced Cortex Agent Features (Bonus) | 20-30 min | [07_advanced_cortex.md](docs/exercises/07_advanced_cortex.md) |


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

## FAQ

### Why do we run a bootstrap SQL script (DB, warehouse, stage) when the very next step uses DCM? Isn't DCM supposed to manage infrastructure?

Good catch — and the answer is that **DCM literally cannot create these three objects** in this project, so something has to create them first.

**The database and warehouse — DCM can't own its own parent.** The DCM project is registered as a Snowflake object at `PAWCORE_ANALYTICS.PUBLIC.COCO_DCM_PROJECT` (see `dcm/manifest.yml`). A DCM project lives *inside* a database and can only `DEFINE` objects *inside* its own parent database/schema — never the parent itself. Per Snowflake's DCM model: *a DCM project cannot define its parent database or schema; those containers must already exist.* So it's a chicken-and-egg problem: `snow dcm deploy` needs `PAWCORE_ANALYTICS` (and its `PUBLIC` schema) to already exist before it can register the project there, and it needs a warehouse to run on — it can't spin up the compute it's currently executing inside. That's why `pre_deploy.sql` (and `00_bootstrap.sql`) create the DB + WH with `CREATE ... IF NOT EXISTS`. The header comment in `dcm/pre_deploy.sql` says it directly: *"parent objects DCM cannot own (its own parent DB + warehouse)."*

**The stage — needed before DCM, and intentionally kept out of DCM's scope.** `RAW.PAWCORE_DATA_STAGE` is created in bootstrap because Step 3 (raw CSV load) uploads `data/*.csv` into it and `COPY INTO`s from it. DCM in this demo is deliberately scoped to **schemas only** — *"the only thing DCM owns in this demo"* (see `schemas.sql`). Tables and views are owned by dbt; the stage and parent infra are owned by bootstrap. DCM *can* technically `DEFINE` an internal stage, but the demo keeps a clean ownership split:

| Object | Owner | Why |
|--------|-------|-----|
| Database, warehouse, `PUBLIC`, stage | `00_bootstrap.sql` / `dcm/pre_deploy.sql` | DCM can't create its own parent DB/WH; the stage is needed for raw load |
| 8 schemas | DCM (`schemas.sql`) | Reviewable, version-controlled, plan-deployable schema lifecycle |
| Tables + views | dbt (`dbt/models/`) | Transformations, tested + documented |

**You may notice `RAW` is created twice** — once in bootstrap (commented *"also created by DCM"*) and once by DCM (`DEFINE SCHEMA ... RAW`). That's intentional and harmless: bootstrap needs `RAW` to exist so it can place the stage there before DCM runs, and both forms are idempotent/declarative so the second pass is a no-op. DCM is additive-only and never drops schemas it manages, so there's no conflict.

**Bottom line:** bootstrap exists because DCM cannot create its own parent database or the warehouse it runs on, and because the immediately-following raw-load step needs the stage. DCM's job in this lab is strictly the 8-schema lifecycle.

---

## Repository Owner

- **Owner**: John Kang, Sales Engineer, Snowflake
- **Contact**: john.kang@snowflake.com | [@sfc-gh-jkang](https://github.com/sfc-gh-jkang)
- **License**: Apache-2.0
