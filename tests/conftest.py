"""Shared fixtures for deploy.py tests."""

from pathlib import Path

import pytest


@pytest.fixture()
def clean_env(monkeypatch):
    """Strip deploy-related env vars so each test starts clean."""
    for key in [
        "SNOWFLAKE_CONNECTION",
        "TARGET_DATABASE",
        "TARGET_WAREHOUSE",
        "I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE",
        "TARGET_DB",
        "TARGET_WH",
    ]:
        monkeypatch.delenv(key, raising=False)


@pytest.fixture()
def dotenv_file(tmp_path: Path) -> Path:
    """Create a minimal .env file in tmp_path and return its parent."""
    env = tmp_path / ".env"
    env.write_text(
        "SNOWFLAKE_CONNECTION=test_conn\n"
        "TARGET_DATABASE=TEST_DB\n"
        "TARGET_WAREHOUSE=TEST_WH\n"
        "I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=1\n",
        encoding="utf-8",
    )
    return tmp_path


@pytest.fixture()
def dbt_tree(tmp_path: Path) -> Path:
    """Create a minimal dbt/ source tree for copy tests."""
    dbt = tmp_path / "dbt"
    dbt.mkdir()
    (dbt / "dbt_project.yml").write_text("name: test\n")
    (dbt / "profiles.yml").write_text("profile: test\n")
    (dbt / ".build").mkdir()
    (dbt / ".build" / "stale.txt").write_text("should be excluded")
    (dbt / "target").mkdir()
    (dbt / "target" / "manifest.json").write_text("{}")
    (dbt / "logs").mkdir()
    (dbt / "logs" / "dbt.log").write_text("log line")
    models = dbt / "models"
    models.mkdir()
    (models / "sources.yml").write_text("sources: []\n")
    (models / "staging").mkdir()
    (models / "staging" / "stg_orders.sql").write_text("SELECT 1")
    return dbt


@pytest.fixture()
def full_project_tree(dotenv_file: Path) -> Path:
    """Create a complete project tree for main() integration tests."""
    root = dotenv_file  # already has .env

    (root / "data" / "Telemetry").mkdir(parents=True)
    (root / "data" / "Telemetry" / "device_telemetry.csv").write_text("h\n")

    (root / "bootstrap").mkdir()
    (root / "bootstrap" / "00_bootstrap.sql").write_text("SELECT 1;")
    (root / "bootstrap" / "01_load_raw.sql").write_text("SELECT 1;")

    dcm = root / "dcm"
    dcm.mkdir()
    (dcm / "manifest.yml").write_text("database: PAWCORE_ANALYTICS\n")
    (dcm / "pre_deploy.sql").write_text("USE DATABASE ${TARGET_DB};")
    (dcm / "post_deploy.sql").write_text("SHOW SCHEMAS IN DATABASE ${TARGET_DB};")
    defs = dcm / "sources" / "definitions"
    defs.mkdir(parents=True)
    (defs / "schemas.sql").write_text("DEFINE SCHEMA ${TARGET_DB}.RAW;")

    dbt = root / "dbt"
    dbt.mkdir()
    (dbt / "dbt_project.yml").write_text("name: test\n")
    (dbt / "profiles.yml").write_text("database: ${TARGET_DB}\n")
    models = dbt / "models"
    models.mkdir()
    (models / "sources.yml").write_text("database: ${TARGET_DB}\n")

    snowflake = root / "snowflake"
    snowflake.mkdir()
    (snowflake / "run_pipeline.sql").write_text("SELECT 1;")
    (snowflake / "create_semantic_view.sql").write_text("SELECT 1;")
    (snowflake / "create_agent.sql").write_text("SELECT 1;")

    return root
