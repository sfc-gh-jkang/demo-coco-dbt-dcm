# Plan: Simplify & Clean Up Stale References

## Summary
After inlining CSVs and removing git integration, several files are broken or reference deleted artifacts. This plan fixes all 9 issues identified in the audit.

---

## Task 1: Delete dead files

- `snowflake/create_dbt_project.sql` — references deleted `DEMO_REPO`
- `deploy_all.sql` — broken, incomplete, superseded by `deploy.py`
- `dbt/local_dev/` directory — unused, undocumented
- `dbt/packages.yml` — vestigial (dbt_utils is vendored)

## Task 2: Fix `dbt_project.yml` clean-targets

Change line 11 from:
```yaml
clean-targets: ['target', 'dbt_packages']
```
to:
```yaml
clean-targets: ['target']
```
Prevents `dbt clean` from accidentally deleting vendored packages.

## Task 3: Add `dbt/.build/` to `.gitignore`

Add alongside the existing `dcm/.build/` entry. Protects against interrupted deploys leaving stale staging dirs.

## Task 4: Replace all `deploy.sh` references (26+ occurrences)

Files to update (all `deploy.sh` → `deploy.py`, `bash scripts/deploy.sh` → `uv run scripts/deploy.py`):

- `AGENTS.md` (line 31)
- `docs/facilitator_runbook.md` (~10 lines)
- `docs/self_walkthrough.md` (~5 lines)
- `docs/speaker_notes.md` (2 lines)
- `docs/architecture.md` (~4 lines)
- `dcm/sources/definitions/schemas.sql` (comment, lines 4-5)
- `dbt/profiles.yml` (comment, line 3)

## Task 5: Rewrite `AGENTS.md`

Update to reflect current reality:
- Directory map: add `data/`, `tests/`, `scripts/deploy.py`, `pyproject.toml`; remove `deploy.sh`, `deploy_all.sql`
- Ownership split: remove "git integration" mention
- Remove `deploy_all.sql` from the map
- Remove "Related repos" upstream data link (data is now local)

## Task 6: Fix `docs/exercises/02_build_mart.md`

The git-push + `ALTER GIT REPOSITORY DEMO_REPO FETCH` flow (lines 116-131) is broken. Replace with the stage-based approach:

**New step 2-3 (replaces git push + fetch):**
1. Create the model file locally in `dbt/models/marts/`
2. Re-run `uv run scripts/deploy.py --stop-at build` (which re-stages the dbt project including the new file and rebuilds)

OR for a scoped rebuild during the live activity:
1. Upload just the new file: `snow stage copy dbt/models/marts/mart_<name>.sql @<DB>.PUBLIC.DBT_PROJECT_STAGE/models/marts/ -c <conn> --overwrite`
2. Then `EXECUTE DBT PROJECT ... args='build --select mart_<name>+'`

The "Can't push?" fallback (lines 147-157) which uses `CREATE TABLE AS SELECT` remains valid.

## Task 7: Update `README.md` repo structure

Remove `deploy_all.sql` and `snowflake/create_dbt_project.sql` from the directory listing. Add note that `dbt_packages/` is vendored.

## Task 8: Update `SKILL.md`

Remove reference to `DEMO_REPO` in the extension playbook section (if any remain after earlier edits). Verify the key files table no longer mentions dead files.
