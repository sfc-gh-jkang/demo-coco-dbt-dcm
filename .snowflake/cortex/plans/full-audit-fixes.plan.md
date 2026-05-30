# Plan: Full Audit Fixes

## Decisions Made
- **Naming**: keep `TARGET_DATABASE` in `.env`, keep `TARGET_DB` in SQL templates. The bridge in deploy.py (`os.environ["TARGET_DB"] = target_database`) stays but gets a clear comment.
- **Python version**: lower to `>=3.10`

---

## Task 1: Parameterize DCM pre/post_deploy.sql + teardown.sql

**dcm/pre_deploy.sql**: Replace hardcoded `PAWCORE_ANALYTICS` → `${TARGET_DATABASE}`, `PAWCORE_DEMO_WH` → `${TARGET_WAREHOUSE}`.

**dcm/post_deploy.sql**: Replace `PAWCORE_ANALYTICS` → `${TARGET_DATABASE}`.

**deploy.py step 2** (line ~521): Run `sub_all()` on pre_deploy.sql and post_deploy.sql before writing to dcm_build (currently just `shutil.copy` verbatim).

**teardown.sql**: Replace hardcoded names with `${TARGET_DATABASE}` / `${TARGET_WAREHOUSE}`. Add a comment noting it requires envsubst (or run via `deploy.py --teardown` in future).

Note: DCM `pre_deploy.sql` uses `${TARGET_DATABASE}` (the full .env name) because deploy.py's `sub_all()` has access to both `TARGET_DB` and `TARGET_DATABASE` in os.environ. Actually — `sub_all()` uses envsubst which reads ALL env vars. Since deploy.py sets `os.environ["TARGET_DB"] = target_database`, we can use either `${TARGET_DB}` or `${TARGET_DATABASE}` in templates. For consistency with existing SQL files, use `${TARGET_DB}` and `${TARGET_WH}`.

## Task 2: Lower requires-python to >=3.10

`pyproject.toml` line 5: change `">=3.14"` → `">=3.10"`.

## Task 3: Fix dbt not_null test on avg_battery_level

`dbt/models/marts/__marts.yml` line 28: Remove `tests: [not_null]` from the `avg_battery_level` column (LEFT JOIN makes NULLs possible if a lot×region has no telemetry-matched devices).

## Task 4: Fix all stale comments

- `snowflake/run_pipeline.sql` line 3: "Runs AFTER snowflake/create_dbt_project.sql" → "Runs AFTER deploy.py step 4 (CREATE DBT PROJECT)"
- `snowflake/run_pipeline.sql` lines 10-12: Delete commented-out `deps` block
- `deploy.py` HELP_LINES (line 127): "Bootstrap (DB, warehouse, secret, API integration, git repos)" → "Bootstrap (DB, warehouse, stage)"
- `deploy.py` main() docstring (line 438): same fix
- `deploy.py` print at line 509: same fix
- `docs/architecture.md` line 11: `PAWCORE_DBT_DEMO` → `PAWCORE_ANALYTICS`
- `docs/architecture.md` line 7: "PawCore HOL repo (GitHub)" → "Local data/ folder"

## Task 5: Clean up _SUB_TX / text=True redundancy

Remove `text=True` from all `subprocess.run` calls that also pass `**_SUB_TX` (since `encoding=` already implies text mode). This makes the intent clearer: `_SUB_TX` handles text mode + encoding in one place.

## Task 6: Refactor deploy.py — extract step 2 and step 4 into functions

Extract:
- `build_and_deploy_dcm(snow_exe, connection, repo, target_database, sub_all)` — the 23-line DCM build block
- `stage_dbt_project(snow_exe, connection, repo, target_database, target_wh, prefer)` — the 70-line step 4 block

This makes main() a clean sequence of named steps and makes both blocks independently testable.

## Task 7: Simplify SAFETY_BOX

Replace the broken box-drawing (uneven right border) with a simple, clean warning format that doesn't fight with variable-length placeholders.

## Task 8: Narrow .gitignore secret patterns

Replace `**/*secret*` and `**/*credential*` with more specific patterns that won't accidentally ignore legitimate docs. Keep `**/secrets/` directory pattern.

## Task 9: Standardize pre-flight SQL style

Change the pre-flight check (line 493-507) to use `run_snow_ci()` for consistency with the rest of deploy.py. The only reason it used `-q` was historical.

## Task 10: Add shared test fixture + missing test coverage

- **conftest.py**: Add `full_project_tree` fixture that creates bootstrap/, dcm/, dbt/, snowflake/ dirs with minimal files (deduplicates setup across 4+ test classes)
- **New tests**:
  - `test_stage_copy_failure_raises` — mock CalledProcessError on snow stage copy
  - `test_envsubst_maybe_external_failure_raises` — mock envsubst returning non-zero
  - `test_dcm_filtered_stderr_on_real_failure` — verify stderr is printed when DCM fails
  - `test_build_and_deploy_dcm` — new function unit test
  - `test_stage_dbt_project` — new function unit test

## Task 11: Rename --resume to document its actual behavior

Add a comment in the argparse help clarifying that `--resume` just means "run all steps" (it does NOT skip completed steps). Consider renaming to `--all` as an alias, but keep `--resume` for backward compat.

## Task 12: Fix docs/architecture.md stale references

- Line 7: "PawCore HOL repo (GitHub)" → "data/ (local CSV files)"
- Line 11: `PAWCORE_DBT_DEMO` → `PAWCORE_ANALYTICS` (or `TARGET_DATABASE`)
- Line 95: Update the deploy.py invocation to use `uv run`
