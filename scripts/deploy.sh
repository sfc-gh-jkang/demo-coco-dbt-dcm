#!/usr/bin/env bash
# =============================================================================
# deploy.sh — gated end-to-end deploy wrapper
# =============================================================================
# Reads config from .env (copy .env.example first). Requires explicit
# I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=1 to proceed.
#
# Steps (in order):
#   1. Bootstrap (DB, warehouse, secret, API integration, git repos)
#   2. DCM create + deploy (schemas)
#   3. Load raw CSVs
#   4. Create dbt project from git
#   5. Execute dbt build
#   6. Create semantic view (Cortex Analyst contract)
#   7. Create Snowflake Intelligence agent
#
# Usage:
#   bash scripts/deploy.sh                     # run all 7 steps
#   bash scripts/deploy.sh --stop-at raw-load  # stop after step 3 (for webinar Segment 1)
#   bash scripts/deploy.sh --stop-at build     # stop after step 5 (marts ready, no agent)
#   bash scripts/deploy.sh --resume            # re-runs idempotent steps to catch up
# =============================================================================

set -euo pipefail

# ─── Arg parsing ────────────────────────────────────────────────────────────
STOP_AT="full"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --stop-at)  STOP_AT="$2"; shift 2 ;;
        --resume)   STOP_AT="full"; shift ;;
        -h|--help)  sed -n '2,21p' "$0"; exit 0 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done
case "$STOP_AT" in
    raw-load|build|full) ;;
    *) echo "--stop-at must be one of: raw-load, build, full" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# ─── Load config ────────────────────────────────────────────────────────────
if [[ ! -f .env ]]; then
    echo "ERROR: .env not found. Copy .env.example to .env and edit values." >&2
    exit 1
fi

# shellcheck disable=SC1091
set -a; source .env; set +a

: "${SNOWFLAKE_CONNECTION:?must be set in .env}"
: "${TARGET_DATABASE:?must be set in .env}"
: "${TARGET_WAREHOUSE:?must be set in .env}"
: "${GITHUB_USER:?must be set in .env}"
: "${I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE:=0}"

# ─── Safety gate ────────────────────────────────────────────────────────────
if [[ "$I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE" != "1" ]]; then
    cat <<EOF >&2

╭──────────────────────────────────────────────────────────────────────────────╮
│ SAFETY GATE — deploy aborted                                                 │
│                                                                              │
│  TARGET_DATABASE=${TARGET_DATABASE} on connection '${SNOWFLAKE_CONNECTION}'
│                                                                              │
│  This deploy creates/overwrites tables in ${TARGET_DATABASE}.                 │
│  If that database already contains a PawCore HOL install, its tables will    │
│  be replaced.                                                                │
│                                                                              │
│  To proceed, set in .env:                                                    │
│      I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=1                      │
│                                                                              │
│  To avoid overwriting, change TARGET_DATABASE to a scratch name              │
│  (e.g., PAWCORE_SANDBOX_\$(whoami | tr a-z A-Z)).                             │
╰──────────────────────────────────────────────────────────────────────────────╯
EOF
    exit 2
fi

# ─── Pre-flight: show existing state so user sees what will change ──────────
echo "==> Pre-flight: checking existing state of ${TARGET_DATABASE}"
snow sql -c "$SNOWFLAKE_CONNECTION" -q "
SELECT COUNT(*) AS existing_schemas
FROM ${TARGET_DATABASE}.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME NOT IN ('INFORMATION_SCHEMA','PUBLIC');
" 2>/dev/null || echo "   (database does not yet exist — clean install)"

# ─── Run deploy ─────────────────────────────────────────────────────────────
echo "==> Step 1/7: Bootstrap (DB, warehouse, secret, API integration, git repos)"
export TARGET_DB="$TARGET_DATABASE"
export TARGET_WH="$TARGET_WAREHOUSE"
export GITHUB_PAT GITHUB_USER
envsubst < bootstrap/00_bootstrap.sql | snow sql -c "$SNOWFLAKE_CONNECTION" -i

echo "==> Step 2/7: DCM create + deploy (schemas)"
# Build a temp DCM dir with TARGET_DB substituted into schemas.sql
DCM_BUILD="$REPO_ROOT/dcm/.build"
rm -rf "$DCM_BUILD"
mkdir -p "$DCM_BUILD/sources/definitions"
cp "$REPO_ROOT/dcm/manifest.yml" "$DCM_BUILD/manifest.yml"
cp "$REPO_ROOT/dcm/pre_deploy.sql" "$DCM_BUILD/pre_deploy.sql"
cp "$REPO_ROOT/dcm/post_deploy.sql" "$DCM_BUILD/post_deploy.sql"
envsubst < "$REPO_ROOT/dcm/sources/definitions/schemas.sql" > "$DCM_BUILD/sources/definitions/schemas.sql"
# Also parameterize manifest.yml's project_name (TARGET_DB.PUBLIC.COCO_DCM_PROJECT)
sed -i '' "s/PAWCORE_ANALYTICS/${TARGET_DATABASE}/g" "$DCM_BUILD/manifest.yml"

snow dcm create COCO_DCM_PROJECT \
    --from "$DCM_BUILD" \
    --connection "$SNOWFLAKE_CONNECTION" \
    --database "$TARGET_DATABASE" \
    --schema PUBLIC 2>&1 | grep -v "already exists" || true
snow dcm deploy COCO_DCM_PROJECT \
    --from "$DCM_BUILD" \
    --connection "$SNOWFLAKE_CONNECTION" \
    --database "$TARGET_DATABASE" \
    --schema PUBLIC || true
rm -rf "$DCM_BUILD"

echo "==> Step 3/7: Load raw CSVs"
export TARGET_DB="$TARGET_DATABASE" TARGET_WH="$TARGET_WAREHOUSE"
envsubst < bootstrap/01_load_raw.sql | snow sql -c "$SNOWFLAKE_CONNECTION" -i

if [[ "$STOP_AT" == "raw-load" ]]; then
    echo ""
    echo "✓ Stopped at raw-load. Schemas + RAW tables ready."
    echo "  Re-run without --stop-at to continue to dbt build."
    exit 0
fi

echo "==> Step 4/7: Stage parameterized dbt project + create DBT PROJECT"
DBT_BUILD="$REPO_ROOT/dbt/.build"
rm -rf "$DBT_BUILD"
mkdir -p "$DBT_BUILD/models"

# Copy entire dbt project, then overwrite profiles.yml + sources.yml with envsubst-ed versions
rsync -a --exclude='.build' --exclude='target' --exclude='logs' --exclude='profiles.yml' --exclude='models/sources.yml' "$REPO_ROOT/dbt/" "$DBT_BUILD/"
envsubst < "$REPO_ROOT/dbt/profiles.yml" > "$DBT_BUILD/profiles.yml"
envsubst < "$REPO_ROOT/dbt/models/sources.yml" > "$DBT_BUILD/models/sources.yml"

# PUT the parameterized dbt project to a stage
snow sql -c "$SNOWFLAKE_CONNECTION" -q "
USE ROLE ACCOUNTADMIN;
USE DATABASE ${TARGET_DATABASE};
CREATE STAGE IF NOT EXISTS PUBLIC.DBT_PROJECT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Parameterized dbt project files (populated by deploy.sh)';
REMOVE @${TARGET_DATABASE}.PUBLIC.DBT_PROJECT_STAGE;
"

snow stage copy "$DBT_BUILD" "@${TARGET_DATABASE}.PUBLIC.DBT_PROJECT_STAGE" \
    -c "$SNOWFLAKE_CONNECTION" --recursive --overwrite

# Create dbt project from stage (not git — supports any TARGET_DATABASE)
snow sql -c "$SNOWFLAKE_CONNECTION" -q "
USE ROLE ACCOUNTADMIN;
USE DATABASE ${TARGET_DATABASE};
USE WAREHOUSE ${TARGET_WAREHOUSE};
CREATE OR REPLACE DBT PROJECT ${TARGET_DATABASE}.PUBLIC.PAWCORE_DBT
    FROM @${TARGET_DATABASE}.PUBLIC.DBT_PROJECT_STAGE/
    COMMENT = 'PawCore dbt project — staging → HOL-shape → marts';
SHOW DBT PROJECTS LIKE 'PAWCORE_DBT' IN SCHEMA ${TARGET_DATABASE}.PUBLIC;
"
rm -rf "$DBT_BUILD"

echo "==> Step 5/7: Execute dbt build"
envsubst < snowflake/run_pipeline.sql | snow sql -c "$SNOWFLAKE_CONNECTION" -i

if [[ "$STOP_AT" == "build" ]]; then
    echo ""
    echo "✓ Stopped at dbt build. Marts ready. Re-run without --stop-at for semantic view + agent."
    exit 0
fi

echo "==> Step 6/7: Create semantic view"
envsubst '${TARGET_DB} ${TARGET_WH}' < snowflake/create_semantic_view.sql \
    | snow sql -c "$SNOWFLAKE_CONNECTION" -i

echo "==> Step 7/7: Create Snowflake Intelligence agent"
envsubst '${TARGET_DB} ${TARGET_WH}' < snowflake/create_agent.sql \
    | snow sql -c "$SNOWFLAKE_CONNECTION" -i || {
    echo ""
    echo "⚠  CREATE AGENT failed. Fall back to Snowsight UI:"
    echo "   AI & ML → Snowflake Intelligence → + Create Agent"
    echo "   See docs/exercises/03_agent.md Option B for the click-path."
}

echo ""
echo "✓ Deploy complete. Target: ${TARGET_DATABASE} on ${SNOWFLAKE_CONNECTION}"
echo "  Open the agent: https://app.snowflake.com/#/agents/SNOWFLAKE_INTELLIGENCE/AGENTS/PAWCORE_ASSISTANT"
echo "  Or via Snowsight → AI & ML → Snowflake Intelligence → 'PawCore Assistant'"
echo "  Try: \"Which lot has the worst customer ratings?\""
