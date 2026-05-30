# Plan: Inline CSV Data into Repo

## Problem
The current deploy fetches CSVs from an external GitHub repo (`calebaalexander/HandsOnLabs`) via Snowflake's git integration. This requires a GitHub API integration, a PAT secret, and internet access at deploy time — a fragile external dependency.

## Solution
Move the CSV files into this repo under `data/`, upload them to the internal stage via `snow stage copy`, and remove all GitHub git integration objects.

## Changes

### 1. Create `data/` directory with CSVs
Download from upstream:
- `data/Telemetry/*.csv` (telemetry data, ~21K rows)
- `data/Manufacturing/*.csv` (quality logs, ~1K rows)  
- `data/Document_Stage/customer_reviews.csv` (~1.5K rows)
- `data/Document_Stage/pawcore_slack.csv` (37 rows)

### 2. Rewrite `bootstrap/00_bootstrap.sql`
**Remove:**
- `CREATE SECRET github_sfc_gh_jkang_pat`
- `CREATE API INTEGRATION pawcore_github_api`
- `CREATE GIT REPOSITORY UPSTREAM_HOL_REPO`
- `CREATE GIT REPOSITORY DEMO_REPO`
- All `ALTER GIT REPOSITORY ... FETCH`

**Keep:**
- `CREATE DATABASE`, `CREATE WAREHOUSE`
- `CREATE SCHEMA RAW`
- `CREATE STAGE PAWCORE_DATA_STAGE`

### 3. Rewrite `bootstrap/01_load_raw.sql`
**Remove:**
- All `COPY FILES INTO @PAWCORE_DATA_STAGE FROM @UPSTREAM_HOL_REPO/...`
- The `ALTER WAREHOUSE SET SIZE = MEDIUM` (no longer needed — stage copy is fast)

**Keep:**
- All `CREATE OR REPLACE TABLE` statements
- All `COPY INTO` statements (unchanged — they still read from `@PAWCORE_DATA_STAGE`)
- Verification query

The stage is now populated by deploy.py (step 3) before this SQL runs.

### 4. Update `deploy.py` step 3
Add before `run_snow_ci(... 01_load_raw.sql)`:
```python
# Upload local data/ to internal stage
subprocess.run([
    snow_exe, "stage", "copy",
    str(repo / "data"),
    f"@{target_database}.RAW.PAWCORE_DATA_STAGE",
    "-c", connection, "--recursive", "--overwrite",
], check=True, text=True, **_SUB_TX)
```

### 5. Simplify `.env.example`
Remove `GITHUB_PAT` and `GITHUB_USER` — no longer needed.
Update `deploy.py` `require_env("GITHUB_USER")` → remove that check.

### 6. Update references
- `teardown.sql`: remove `DROP API INTEGRATION`
- `README.md`: remove GitHub PAT prerequisite, update architecture
- `SKILL.md`: update data flow description
- `docs/facilitator_runbook.md`: update "COPY FILES from upstream" reference
- `snowflake/create_dbt_project.sql`: note that deploy.py now uses stage-based approach (this file becomes an alternative/legacy path)

### 7. Verify
Run `uv run scripts/deploy.py` against `azure_spcs` to confirm full pipeline works with local data.

## Impact
- **Removes**: GitHub PAT requirement, API integration, git repo objects, external fetch dependency
- **Adds**: ~2MB of CSV files to the repo
- **Net effect**: fully self-contained, offline-capable deploy
