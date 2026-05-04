# AGENTS.md

Project-specific guidance for AI coding agents (Cortex Code, Claude, etc.) working in this repo.

## Purpose

60-minute webinar HOL demonstrating **Cortex Code + dbt Projects on Snowflake + DCM** on the PawCore dataset. Must run on a fresh Snowflake trial account with ACCOUNTADMIN.

## Non-negotiable constraints

1. **Trial-account compatible.** No SE-demo-account-only objects. No `SNOWFLAKE_EXAMPLE` database, no `SFE_*` prefixes, no references to roles or warehouses that only exist in my account.
2. **HOL-compatible final tables.** `PAWCORE_ANALYTICS.DEVICE_DATA.TELEMETRY`, `.MANUFACTURING.QUALITY_LOGS`, `.SUPPORT.CUSTOMER_REVIEWS`, `.SUPPORT.SLACK_MESSAGES` must match the upstream HOL's column names and types **exactly**. The Cortex AI HOL #1 agent's semantic view reads these tables by FQN and column name.
3. **Ownership split:** DCM owns schemas only; dbt owns all tables. Bootstrap SQL owns database/warehouse/stage/RAW tables/git integration.
4. **Re-runnable.** Every script must be idempotent. Use `CREATE OR REPLACE`, `IF NOT EXISTS`, `TRUNCATE`/`FORCE=TRUE` on COPY.

## Directory map

```
demo-coco-dbt-dcm/
├── bootstrap/              # One-time setup SQL (runs before DCM)
├── dcm/                    # DCM project — schemas only
│   ├── manifest.yml
│   ├── pre_deploy.sql      # Parent DB + WH (DCM can't self-own)
│   ├── sources/definitions/schemas.sql  # DEFINE SCHEMA only
│   └── post_deploy.sql
├── dbt/                    # Native dbt on Snowflake project
│   ├── dbt_project.yml
│   ├── macros/generate_schema_name.sql  # Strips DBT_DEV prefix
│   └── models/{sources.yml, staging/, hol/, marts/}
├── snowflake/              # CREATE DBT PROJECT + EXECUTE DBT PROJECT
├── scripts/deploy.sh       # End-to-end wrapper
├── docs/                   # README, facilitator, attendee, architecture
├── deploy_all.sql          # SQL-only orchestration via !source
└── teardown.sql
```

## When extending

- **Adding a new raw table:** update `dcm/sources/definitions/schemas.sql` if new schema needed, add `CREATE TABLE` + `COPY INTO` to `bootstrap/01_load_raw.sql`, add source entry to `dbt/models/sources.yml`, add staging + HOL + mart models following the existing pattern.
- **Changing HOL-compat column names:** NEVER. The agent semantic view depends on exact names. If you need different column names, add them as aliases, don't rename the originals.
- **Adding a new mart:** only if it matches a verified query in the upstream agent OR serves a clear business question. New marts go in `dbt/models/marts/` with an entry in `__marts.yml`.

## Connection routing (dev vs webinar)

- Dev / rehearsal: `aws_spcs` (SE demo account)
- Webinar live: fresh Snowflake trial, connection name varies per attendee

Both must work from identical source code. If you need an env-specific setting, use env vars in `dbt/profiles.yml`, never hardcode.

## Related repos

- Upstream source data: https://github.com/calebaalexander/HandsOnLabs
- Follow-on Cortex AI HOL: https://github.com/sfc-gh-calexander/HandsOnLabs/tree/main/1-Cortex-AI-Snowflake-Intelligence

## Owner

John Kang · john.kang@snowflake.com · sfc-gh-jkang
