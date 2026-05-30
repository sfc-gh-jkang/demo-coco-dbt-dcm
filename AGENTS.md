# AGENTS.md

Project-specific guidance for AI coding agents (Cortex Code, Claude, etc.) working in this repo.

## Purpose

60-minute webinar HOL demonstrating **Cortex Code + dbt Projects on Snowflake + DCM** on the PawCore dataset. Must run on a fresh Snowflake trial account with ACCOUNTADMIN.

## Non-negotiable constraints

1. **Trial-account compatible.** No SE-demo-account-only objects.
2. **HOL-compatible final tables.** Column names/types must match the upstream Cortex AI HOL exactly.
3. **Ownership split:** DCM owns schemas only; dbt owns all tables. Bootstrap SQL owns database/warehouse/stage.
4. **Re-runnable.** Every script must be idempotent (`CREATE OR REPLACE`, `IF NOT EXISTS`, `FORCE=TRUE`).
5. **Self-contained.** Data lives in `data/` — no external fetches at deploy time.

## Directory map

```
demo-coco-dbt-dcm/
├── data/                   # CSV source files (bundled, no external deps)
├── scripts/deploy.py       # Single deploy entry point (7 steps)
├── bootstrap/              # DB + WH + stage + raw table loading
├── dcm/                    # DCM project — schemas only
│   ├── manifest.yml
│   ├── pre_deploy.sql
│   ├── sources/definitions/schemas.sql
│   └── post_deploy.sql
├── dbt/                    # Native dbt on Snowflake project
│   ├── dbt_project.yml
│   ├── macros/generate_schema_name.sql
│   ├── models/{sources.yml, staging/, intermediate/, hol/, marts/}
│   └── dbt_packages/dbt_utils/   (vendored)
├── snowflake/              # Semantic view + agent creation SQL
├── tests/                  # pytest unit tests for deploy.py
├── docs/                   # Facilitator, attendee, architecture, exercises
├── pyproject.toml          # Python 3.14+, pytest, ruff, python-dotenv
├── .env.example            # Config template (3 vars + safety gate)
└── teardown.sql            # DROP everything
```

## When extending

- **Adding a new raw table:** add CSV to `data/`, add `CREATE TABLE` + `COPY INTO` to `bootstrap/01_load_raw.sql`, add source entry to `dbt/models/sources.yml`, add staging + HOL + mart models.
- **Changing HOL-compat column names:** NEVER.
- **Adding a new mart:** only if it serves a clear business question. Goes in `dbt/models/marts/` with an entry in `__marts.yml`.

## Connection routing

- Dev / rehearsal: `azure_spcs` or `aws_spcs` (SE demo account)
- Webinar live: fresh Snowflake trial, connection name varies per attendee

## Owner

John Kang · john.kang@snowflake.com · sfc-gh-jkang
