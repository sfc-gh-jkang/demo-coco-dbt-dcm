# Project Rules — demo-coco-dbt-dcm

## dbt runs SERVER-SIDE only

This project uses **dbt Projects on Snowflake** (native server-side execution). There is NO local dbt CLI installed and you should NOT try to run `dbt build`, `dbt compile`, `dbt run`, or `dbt test` locally.

To build dbt models:
```bash
uv run scripts/deploy.py --stop-at build
```

This uploads the dbt project to a Snowflake internal stage and runs `EXECUTE DBT PROJECT` server-side.

Do NOT:
- Install dbt-core or dbt-snowflake locally
- Run `dbt` commands directly
- Suggest `pip install dbt` or `uv add dbt-snowflake`

## Deploy script is the single entry point

All Snowflake operations go through `scripts/deploy.py`:
- `uv run scripts/deploy.py` — full 7-step deploy
- `uv run scripts/deploy.py --stop-at build` — steps 1-5 (stops after dbt)
- `uv run scripts/deploy.py --resume 6` — steps 6-7 only (semantic view + agent)
- `uv run scripts/deploy.py --verify` — check deployed objects
- `uv run scripts/deploy.py --teardown` — drop everything

## SQL parameterization

All SQL files use `${TARGET_DB}` and `${TARGET_WH}` placeholders. These are substituted at runtime by `deploy.py`. Do NOT hardcode `PAWCORE_ANALYTICS` in SQL files.

## Data is in the repo

CSV data lives in `data/`. No external data sources, no GitHub PAT, no API keys needed. The deploy script uploads CSVs to an internal stage via `snow stage copy`.

## Semantic view uses logical names in VQRs

Verified Query SQL uses logical names (left side of `AS` in FACTS/DIMENSIONS), not physical column names. Tables are prefixed with `__` (e.g., `FROM __mart_lot`).
