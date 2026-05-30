#!/usr/bin/env python3
"""
deploy.py — Gated end-to-end deploy for the PawCore demo pipeline.

Requires:
  Python 3.10+
  Snowflake CLI (`snow`) on PATH — Windows, Linux, macOS.

Cross-platform:
  Uses stdlib shutil for staging `dbt/` (no rsync). Optional gettext `envsubst`
  via --prefer-envsubst when installed.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from dotenv import load_dotenv as _dotenv_load


BRACE_VAR = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")

# Subprocess text I/O: UTF-8 avoids Windows code-page issues with SQL / JSON.
_SUB_TX = {"encoding": "utf-8", "errors": "replace"}


def snow_executable() -> str:
    """Locate the Snowflake CLI binary on the system PATH.

    Returns:
        Absolute path to the `snow` executable (e.g., '/usr/local/bin/snow').

    Raises:
        SystemExit: If `snow` is not found on PATH. Prints install URL to stderr.

    Notes:
        - On Windows, resolves snow.exe / snow.cmd via shutil.which.
        - Does NOT validate the CLI version — caller is responsible for
          ensuring v3.0+ if needed.
    """
    exe = shutil.which("snow")
    if not exe:
        print(
            "ERROR: Snowflake CLI not found. Install `snow` and ensure it is on PATH.\n"
            "  https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation",
            file=sys.stderr,
        )
        sys.exit(1)
    return exe


# Files/dirs excluded from the dbt staging copy.
# These are either build artifacts or template files that get substituted separately.
_DBT_ROOT_EXCLUDES = {".build", "target", "logs", "profiles.yml"}
_DBT_MODELS_EXCLUDES = {"sources.yml"}


def copy_dbt_staging_exclude_templates(src: Path, dst: Path) -> None:
    """Copy the dbt project tree to a staging directory, excluding generated/template files.

    Replicates rsync --exclude behavior for filtered directory copies,
    using pure-Python shutil so it works cross-platform without rsync installed.

    Args:
        src: Path to the source dbt/ directory.
        dst: Path to the staging output directory. Will be wiped and recreated
             if it already exists.

    Excludes (at root level):
        - .build/    — previous staging output (avoid recursive nesting)
        - target/    — dbt compile output
        - logs/      — dbt runtime logs
        - profiles.yml — template file (re-injected after substitution)

    Excludes (in models/ only):
        - sources.yml — template file (re-injected after substitution)

    Notes:
        - profiles.yml and sources.yml are excluded because they contain
          ${TARGET_DB} placeholders that must be substituted before staging.
          deploy.py writes the substituted versions into dst separately.
        - Symlinks are NOT followed (symlinks=False). Dangling symlinks are
          silently ignored.
        - If dst already exists, it is fully deleted first to ensure no stale
          files from a prior run persist.
    """

    src_r = src.resolve()
    dst_r = dst.resolve()

    def _ignore(dir_str: str, names: list[str]) -> set[str]:
        cur = Path(dir_str).resolve()
        try:
            rel = cur.relative_to(src_r)
        except ValueError:
            return set()
        if rel == Path("."):
            skipped = {n for n in names if n in _DBT_ROOT_EXCLUDES}
        elif rel == Path("models"):
            skipped = {n for n in names if n in _DBT_MODELS_EXCLUDES}
        else:
            skipped = set()
        return skipped

    if dst_r.exists():
        shutil.rmtree(dst_r)
    shutil.copytree(
        src_r,
        dst_r,
        ignore=_ignore,
        symlinks=False,
        ignore_dangling_symlinks=True,
    )


HELP_LINES = """\
deploy.py — gated end-to-end deploy wrapper.

Reads config from .env (copy .env.example first). Requires explicit
I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=1 to proceed.

Steps (in order):
  1. Bootstrap (DB, warehouse, stage)
  2. DCM create + deploy (schemas)
  3. Load raw CSVs
  4. Stage parameterized dbt project + create DBT PROJECT
  5. Execute dbt build
  6. Create semantic view (Cortex Analyst contract)
  7. Create Snowflake Intelligence agent

Usage:
  python3 scripts/deploy.py
  python3 scripts/deploy.py --stop-at raw-load
  python3 scripts/deploy.py --stop-at build
  python3 scripts/deploy.py --resume
  py -3 scripts\\deploy.py                 # Windows (same flags)
"""


def repo_root() -> Path:
    """Return the absolute path to the repository root directory.

    Returns:
        Path to the project root (parent of `scripts/`).

    Notes:
        Derived from this file's location: `scripts/deploy.py` → parent.parent.
        Always returns a resolved absolute path regardless of the caller's cwd.
    """
    return Path(__file__).resolve().parent.parent


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments for the deploy script.

    Args:
        argv: Argument list (typically sys.argv[1:]).

    Returns:
        Namespace with attributes:
            - stop_at (str): 'raw-load', 'build', or 'full'
            - resume (bool): whether --resume was passed
            - prefer_envsubst (bool): whether to use external envsubst

    Raises:
        SystemExit: On invalid arguments (argparse handles error output).

    Behavior:
        --resume always takes priority over --stop-at. If both are provided
        (in any order), stop_at is forced to 'full'. This is a post-parse
        override, not positional — argparse parses both independently, then
        the if-check fires unconditionally.
    """
    p = argparse.ArgumentParser(
        description="Gated PawCore deploy (bootstrap → DCM → dbt → semantic view → agent).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=HELP_LINES,
    )
    p.add_argument(
        "--stop-at",
        choices=["raw-load", "build", "full"],
        default="full",
        help="Stop after a specific stage (default: full).",
    )
    p.add_argument(
        "--resume",
        action="store_true",
        help="Run all steps from the beginning (equivalent to --stop-at full; "
        "does NOT skip already-completed steps).",
    )
    p.add_argument(
        "--prefer-envsubst",
        action="store_true",
        help="Use external gettext envsubst when installed.",
    )
    ns = p.parse_args(argv)
    if ns.resume:
        ns.stop_at = "full"
    return ns


def load_dotenv(repo_root_: Path) -> None:
    """Load key=value pairs from .env into os.environ.

    Uses python-dotenv to parse the file. Values from .env override existing
    environment variables (override=True), matching bash `set -a; source .env`.

    Args:
        repo_root_: Path to the directory containing the .env file.

    Raises:
        SystemExit: If .env does not exist.
    """
    env_path = repo_root_ / ".env"
    if not env_path.is_file():
        print(
            "ERROR: .env not found. Copy .env.example to .env and edit values.",
            file=sys.stderr,
        )
        sys.exit(1)
    _dotenv_load(env_path, override=True)


def require_env(name: str) -> str:
    """Retrieve a required environment variable or exit.

    Args:
        name: The environment variable name to look up.

    Returns:
        The variable's value (guaranteed non-empty).

    Raises:
        SystemExit: If the variable is missing or is an empty string.

    Notes:
        Whitespace-only values (e.g., '  ') are considered valid — only
        truly empty strings trigger an exit. Call after load_dotenv() to
        ensure .env values are available.
    """
    v = os.environ.get(name)
    if v is None or v == "":
        print(f"must be set in .env: {name}", file=sys.stderr)
        sys.exit(1)
    return v


def envsubst_python(text: str, *, only: frozenset[str] | None) -> str:
    """Replace ${VAR} placeholders in text with values from os.environ.

    Args:
        text: Template string containing ${VAR_NAME} placeholders.
        only: If provided, only variables in this set are replaced.
              Variables not in the set are left as literal '${VAR}' in output.
              If None, ALL ${VAR} occurrences are replaced.

    Returns:
        The text with placeholders substituted. Missing env vars become
        empty strings (not errors).

    Notes:
        - Only matches ${VAR_NAME} syntax (with braces). Bare $VAR is
          left untouched.
        - Variable names must match [A-Za-z_][A-Za-z0-9_]*.
        - An empty `only=frozenset()` means nothing is replaced.
    """
    def repl(m: re.Match[str]) -> str:
        key = m.group(1)
        if only is not None and key not in only:
            return m.group(0)
        return os.environ.get(key, "")

    return BRACE_VAR.sub(repl, text)


def envsubst_maybe(
    text: str, *, prefer: bool, only: frozenset[str] | None
) -> str:
    """Substitute ${VAR} placeholders, optionally using external envsubst.

    Routing logic:
        1. If `only` is set → always use envsubst_python (whitelist semantics
           differ between Python impl and GNU gettext, so we avoid portability
           issues by never delegating to the external tool with a whitelist).
        2. If `prefer=True` and envsubst is on PATH → delegate to the external
           binary via subprocess (passes all of os.environ to it).
        3. Otherwise → fall back to envsubst_python.

    Args:
        text: Template string with ${VAR} placeholders.
        prefer: If True, attempt to use the system `envsubst` binary.
        only: Whitelist of variable names to replace (see envsubst_python).

    Returns:
        Substituted text.

    Gotchas:
        - External envsubst replaces ALL ${VAR} occurrences it finds — there
          is no whitelist mode when delegating. That's why `only` forces the
          Python path.
        - If envsubst is not installed and prefer=True, silently falls back
          to Python impl (no error).
    """
    if only is not None:
        # Whitelist semantics must match bash; avoid portability issues with gettext.
        return envsubst_python(text, only=only)
    if prefer and shutil.which("envsubst"):
        proc = subprocess.run(
            ["envsubst"],
            input=text,
            capture_output=True,
            env=os.environ,
            check=True,
            **_SUB_TX,
        )
        return proc.stdout
    return envsubst_python(text, only=only)


def run_snow_ci(snow_exe: str, connection: str, sql: str) -> subprocess.CompletedProcess:
    """Execute a SQL string via `snow sql -c <connection> -i` (stdin mode).

    Args:
        snow_exe: Absolute path to the snow CLI binary.
        connection: Snowflake connection name (from `snow connection list`).
        sql: One or more SQL statements to execute (passed via stdin).

    Returns:
        subprocess.CompletedProcess with returncode, stdout, stderr.
        A returncode of 0 means all statements succeeded.

    Notes:
        - Uses `-i` (stdin input mode), not `-q` (inline query). This
          supports multi-statement SQL separated by semicolons.
        - Does NOT raise on non-zero exit — caller must check returncode.
        - UTF-8 encoding with error replacement (handles emoji in SQL comments).
        - We shell out to `snow` CLI rather than using snowflake-connector-python
          directly because this pipeline also requires `snow dcm` and
          `snow stage copy --recursive`, which have no Python API equivalent.
          Using the CLI for everything keeps a single auth path and avoids a
          hybrid approach.
    """
    return subprocess.run(
        [snow_exe, "sql", "-c", connection, "-i"],
        input=sql,
        **_SUB_TX,
    )


SAFETY_BOX = """\
SAFETY GATE — deploy aborted.

  TARGET_DATABASE = {db}
  Connection       = {conn}

  This deploy creates/overwrites tables in {db}.
  If that database already contains a PawCore HOL install, its tables
  will be replaced.

  To proceed, set in .env:
      I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=1

  To avoid overwriting, change TARGET_DATABASE to a different name
  (e.g., PAWCORE_SANDBOX_<YOURNAME>).
"""


def dcm_filtered(
    snow_exe: str,
    connection: str,
    dcm_build: Path,
    target_database: str,
    *,
    create: bool,
) -> None:
    """Run `snow dcm create` or `snow dcm deploy` with output filtering.

    Executes the DCM command and suppresses 'already exists' lines from stdout
    (which are normal on re-runs). Any stderr output is forwarded to the user.

    Args:
        snow_exe: Absolute path to the snow CLI binary.
        connection: Snowflake connection name.
        dcm_build: Path to the DCM build directory (contains manifest.yml,
                   pre_deploy.sql, post_deploy.sql, sources/).
        target_database: Database name for the `--database` flag.
        create: If True, runs `snow dcm create COCO_DCM_PROJECT`.
                If False, runs `snow dcm deploy COCO_DCM_PROJECT`.

    Returns:
        None. Exit code is intentionally ignored — DCM commands return
        non-zero for 'already exists' which is expected on re-deploys.

    Gotchas:
        - Exit code is ALWAYS ignored. If DCM fails for a real reason
          (e.g., bad SQL in schemas.sql), the error appears in stderr
          but the deploy continues. This is by design for idempotency.
        - The filtering is simple substring match: any stdout line containing
          'already exists' is suppressed. This could theoretically hide
          a legitimate message that happens to contain that phrase.
    """
    subcmd = ["create", "COCO_DCM_PROJECT"] if create else ["deploy", "COCO_DCM_PROJECT"]
    cmd = [
        snow_exe,
        "dcm",
        *subcmd,
        "--from",
        str(dcm_build),
        "--connection",
        connection,
        "--database",
        target_database,
        "--schema",
        "PUBLIC",
    ]
    p = subprocess.run(cmd, capture_output=True, **_SUB_TX)
    out_lines = [
        ln for ln in (p.stdout or "").splitlines() if "already exists" not in ln
    ]
    if out_lines:
        print("\n".join(out_lines))
    err = (p.stderr or "").strip()
    if err:
        print(err, file=sys.stderr)


def _build_and_deploy_dcm(
    snow_exe: str,
    connection: str,
    repo: Path,
    target_database: str,
    sub_all,
) -> None:
    """Build a parameterized DCM project directory and deploy it.

    Creates a temp .build/ dir with substituted SQL files, runs
    `snow dcm create` + `snow dcm deploy`, then cleans up.
    """
    dcm_build = repo / "dcm" / ".build"
    if dcm_build.exists():
        shutil.rmtree(dcm_build)
    dcm_build.mkdir(parents=True)

    # Copy and parameterize all DCM files
    shutil.copy(repo / "dcm" / "manifest.yml", dcm_build / "manifest.yml")
    (dcm_build / "pre_deploy.sql").write_text(
        sub_all((repo / "dcm" / "pre_deploy.sql").read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    (dcm_build / "post_deploy.sql").write_text(
        sub_all((repo / "dcm" / "post_deploy.sql").read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    defs = dcm_build / "sources" / "definitions"
    defs.mkdir(parents=True)
    (defs / "schemas.sql").write_text(
        sub_all(
            (repo / "dcm" / "sources" / "definitions" / "schemas.sql").read_text(
                encoding="utf-8"
            )
        ),
        encoding="utf-8",
    )

    # Replace hardcoded default DB name in manifest
    myml = (dcm_build / "manifest.yml").read_text(encoding="utf-8").replace(
        "PAWCORE_ANALYTICS", target_database
    )
    (dcm_build / "manifest.yml").write_text(myml, encoding="utf-8")

    dcm_filtered(snow_exe, connection, dcm_build, target_database, create=True)
    dcm_filtered(snow_exe, connection, dcm_build, target_database, create=False)
    shutil.rmtree(dcm_build)


def _stage_dbt_project(
    snow_exe: str,
    connection: str,
    repo: Path,
    target_database: str,
    target_wh: str,
    prefer: bool,
) -> None:
    """Copy dbt project, substitute templates, upload to stage, and create DBT PROJECT.

    Steps:
        1. Copy dbt/ to dbt/.build/ excluding artifacts + template files
        2. Write substituted profiles.yml and sources.yml into .build/
        3. Create the internal stage (idempotent)
        4. Upload .build/ to the stage
        5. CREATE OR REPLACE DBT PROJECT from the stage
        6. Clean up .build/
    """
    dbt_src = repo / "dbt"
    dbt_build = dbt_src / ".build"
    copy_dbt_staging_exclude_templates(dbt_src, dbt_build)

    # Inject substituted template files
    (dbt_build / "profiles.yml").write_text(
        envsubst_maybe(
            (repo / "dbt" / "profiles.yml").read_text(encoding="utf-8"),
            prefer=prefer, only=None,
        ),
        encoding="utf-8",
    )
    (dbt_build / "models" / "sources.yml").write_text(
        envsubst_maybe(
            (repo / "dbt" / "models" / "sources.yml").read_text(encoding="utf-8"),
            prefer=prefer, only=None,
        ),
        encoding="utf-8",
    )

    # Create/clear the internal stage
    stage_sql = (
        f"USE ROLE ACCOUNTADMIN;\n"
        f"USE DATABASE {target_database};\n"
        f"CREATE STAGE IF NOT EXISTS PUBLIC.DBT_PROJECT_STAGE\n"
        f"    DIRECTORY = (ENABLE = TRUE)\n"
        f"    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')\n"
        f"    COMMENT = 'Parameterized dbt project files (populated by deploy.py)';\n"
        f"REMOVE @{target_database}.PUBLIC.DBT_PROJECT_STAGE;"
    )
    subprocess.run(
        [snow_exe, "sql", "-c", connection, "-q", stage_sql],
        check=True,
        **_SUB_TX,
    )

    # Upload dbt build dir to stage
    subprocess.run(
        [
            snow_exe, "stage", "copy",
            str(dbt_build),
            f"@{target_database}.PUBLIC.DBT_PROJECT_STAGE",
            "-c", connection,
            "--recursive", "--overwrite",
        ],
        check=True,
        **_SUB_TX,
    )

    # Register the dbt project
    dbtproj_sql = (
        f"USE ROLE ACCOUNTADMIN;\n"
        f"USE DATABASE {target_database};\n"
        f"USE WAREHOUSE {target_wh};\n"
        f"CREATE OR REPLACE DBT PROJECT {target_database}.PUBLIC.PAWCORE_DBT\n"
        f"    FROM @{target_database}.PUBLIC.DBT_PROJECT_STAGE/\n"
        f"    COMMENT = 'PawCore dbt project — staging → HOL-shape → marts';\n"
        f"SHOW DBT PROJECTS LIKE 'PAWCORE_DBT' IN SCHEMA {target_database}.PUBLIC;"
    )
    subprocess.run(
        [snow_exe, "sql", "-c", connection, "-q", dbtproj_sql],
        check=True,
        **_SUB_TX,
    )
    shutil.rmtree(dbt_build)


def main() -> None:
    """Orchestrate the full 7-step deploy pipeline.

    Steps:
        1. Bootstrap — create DB, warehouse, internal stage
        2. DCM — create + deploy schema definitions (8 schemas)
        3. Raw load — COPY INTO 4 RAW tables from GitHub CSVs
        4. dbt stage — copy dbt tree, substitute templates, upload to stage,
           CREATE DBT PROJECT
        5. dbt build — EXECUTE DBT PROJECT args='build' (12 models + 36 tests)
        6. Semantic view — CREATE SEMANTIC VIEW for Cortex Analyst
        7. Agent — CREATE AGENT for Snowflake Intelligence

    Configuration:
        All config comes from .env (loaded into os.environ). Key vars:
        SNOWFLAKE_CONNECTION, TARGET_DATABASE, TARGET_WAREHOUSE.

    Safety:
        Refuses to run unless I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=1
        is set in .env. Exits with code 2 if missing.

    Early exits:
        - --stop-at raw-load: returns after step 3
        - --stop-at build: returns after step 5
        - Step 1/3/5/6 failure: sys.exit with snow CLI's returncode
        - Step 7 failure: prints warning but does NOT exit (non-fatal)

    Side effects:
        - Sets os.environ['TARGET_DB'] and os.environ['TARGET_WH']
        - Changes cwd to repo root
        - Creates and deletes temporary .build/ directories
    """
    ns = parse_args(sys.argv[1:])
    repo = repo_root()
    os.chdir(repo)

    load_dotenv(repo)

    connection = require_env("SNOWFLAKE_CONNECTION")
    target_database = require_env("TARGET_DATABASE")
    target_wh = require_env("TARGET_WAREHOUSE")

    os.environ.setdefault("I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE", "0")
    if os.environ.get("I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE") != "1":
        print(SAFETY_BOX.format(db=target_database, conn=connection), file=sys.stderr)
        sys.exit(2)

    snow_exe = snow_executable()

    os.environ["TARGET_DB"] = target_database
    os.environ["TARGET_WH"] = target_wh

    prefer = ns.prefer_envsubst
    stop_at = ns.stop_at

    def sub_all(template: str) -> str:
        return envsubst_maybe(template, prefer=prefer, only=None)

    print(f"==> Pre-flight: checking existing state of {target_database}")
    sql_pf = (
        f"SELECT COUNT(*) AS existing_schemas\nFROM {target_database}"
        ".INFORMATION_SCHEMA.SCHEMATA\n"
        "WHERE SCHEMA_NAME NOT IN ('INFORMATION_SCHEMA','PUBLIC');"
    )
    pr = subprocess.run(
        [snow_exe, "sql", "-c", connection, "-q", sql_pf],
        capture_output=True,
        **_SUB_TX,
    )
    if pr.returncode != 0:
        print("   (database does not yet exist — clean install)")
    elif (pr.stdout or "").strip():
        print(f"   {(pr.stdout or '').strip()}")

    print("==> Step 1/7: Bootstrap (DB, warehouse, stage)")
    bootstrap_txt = (repo / "bootstrap" / "00_bootstrap.sql").read_text(encoding="utf-8")
    r1 = run_snow_ci(snow_exe, connection, sub_all(bootstrap_txt))
    if r1.returncode != 0:
        sys.exit(r1.returncode)

    print("==> Step 2/7: DCM create + deploy (schemas)")
    _build_and_deploy_dcm(snow_exe, connection, repo, target_database, sub_all)

    print("==> Step 3/7: Upload data/ to stage + load raw CSVs")
    subprocess.run(
        [
            snow_exe, "stage", "copy",
            str(repo / "data"),
            f"@{target_database}.RAW.PAWCORE_DATA_STAGE",
            "-c", connection,
            "--recursive", "--overwrite",
        ],
        check=True,
        **_SUB_TX,
    )
    raw_sql = (repo / "bootstrap" / "01_load_raw.sql").read_text(encoding="utf-8")
    r3 = run_snow_ci(snow_exe, connection, sub_all(raw_sql))
    if r3.returncode != 0:
        sys.exit(r3.returncode)

    if stop_at == "raw-load":
        print("")
        print("✓ Stopped at raw-load. Schemas + RAW tables ready.")
        print("  Re-run without --stop-at to continue to dbt build.")
        return

    print("==> Step 4/7: Stage parameterized dbt project + create DBT PROJECT")
    _stage_dbt_project(snow_exe, connection, repo, target_database, target_wh, prefer)

    print("==> Step 5/7: Execute dbt build")
    pipeline_txt = (repo / "snowflake" / "run_pipeline.sql").read_text(encoding="utf-8")
    r5 = run_snow_ci(snow_exe, connection, sub_all(pipeline_txt))
    if r5.returncode != 0:
        sys.exit(r5.returncode)

    if stop_at == "build":
        print("")
        print(
            "✓ Stopped at dbt build. Marts ready. Re-run without --stop-at "
            "for semantic view + agent."
        )
        return

    only_db_wh = frozenset({"TARGET_DB", "TARGET_WH"})

    print("==> Step 6/7: Create semantic view")
    sem_txt = (repo / "snowflake" / "create_semantic_view.sql").read_text(encoding="utf-8")
    r6 = run_snow_ci(
        snow_exe, connection, envsubst_maybe(sem_txt, prefer=prefer, only=only_db_wh)
    )
    if r6.returncode != 0:
        sys.exit(r6.returncode)

    print("==> Step 7/7: Create Snowflake Intelligence agent")
    agent_txt = (repo / "snowflake" / "create_agent.sql").read_text(encoding="utf-8")
    r7 = run_snow_ci(
        snow_exe, connection, envsubst_maybe(agent_txt, prefer=prefer, only=only_db_wh)
    )
    if r7.returncode != 0:
        print(
            "\n⚠  CREATE AGENT failed. Fall back to Snowsight UI:\n"
            "   AI & ML → Snowflake Intelligence → + Create Agent\n"
            "   See docs/exercises/03_agent.md Option B for the click-path."
        )

    print("")
    print(f"✓ Deploy complete. Target: {target_database} on {connection}")
    print(
        "  Open the agent: https://app.snowflake.com/"
        "#/agents/SNOWFLAKE_INTELLIGENCE/AGENTS/PAWCORE_ASSISTANT"
    )
    print(
        "  Or via Snowsight → AI & ML → Snowflake Intelligence → 'PawCore Assistant'"
    )
    print('  Try: "Which lot has the worst customer ratings?"')


if __name__ == "__main__":
    main()