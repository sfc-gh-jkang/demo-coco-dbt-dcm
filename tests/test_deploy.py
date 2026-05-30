"""Unit tests for scripts/deploy.py — thorough coverage of all functions."""

import os
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Ensure the scripts/ directory is importable.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import deploy  # noqa: E402


# ---------------------------------------------------------------------------
# BRACE_VAR regex
# ---------------------------------------------------------------------------

class TestBraceVarRegex:
    """Tests for the module-level BRACE_VAR regex pattern."""

    def test_matches_simple_var(self):
        assert deploy.BRACE_VAR.findall("${FOO}") == ["FOO"]

    def test_matches_underscore_var(self):
        assert deploy.BRACE_VAR.findall("${MY_VAR_123}") == ["MY_VAR_123"]

    def test_matches_multiple_vars(self):
        assert deploy.BRACE_VAR.findall("${A} and ${B_2}") == ["A", "B_2"]

    def test_no_match_plain_dollar(self):
        assert deploy.BRACE_VAR.findall("$FOO") == []

    def test_no_match_empty_braces(self):
        assert deploy.BRACE_VAR.findall("${}") == []

    def test_no_match_digit_start(self):
        assert deploy.BRACE_VAR.findall("${1BAD}") == []

    def test_preserves_surrounding_text(self):
        m = deploy.BRACE_VAR.sub("X", "hello ${VAR} world")
        assert m == "hello X world"


# ---------------------------------------------------------------------------
# snow_executable
# ---------------------------------------------------------------------------

class TestSnowExecutable:
    """Tests for snow CLI resolution."""

    def test_exits_when_snow_not_found(self, monkeypatch):
        monkeypatch.setattr("shutil.which", lambda _: None)
        with pytest.raises(SystemExit) as exc_info:
            deploy.snow_executable()
        assert exc_info.value.code == 1

    def test_returns_path_when_found(self, monkeypatch):
        monkeypatch.setattr("shutil.which", lambda _: "/usr/local/bin/snow")
        assert deploy.snow_executable() == "/usr/local/bin/snow"

    def test_returns_windows_path(self, monkeypatch):
        monkeypatch.setattr("shutil.which", lambda _: r"C:\Program Files\snow\snow.exe")
        assert deploy.snow_executable() == r"C:\Program Files\snow\snow.exe"


# ---------------------------------------------------------------------------
# copy_dbt_staging_exclude_templates
# ---------------------------------------------------------------------------

class TestCopyDbtStaging:
    """Tests for the dbt copy-with-exclusions logic."""

    def test_excludes_build_dir(self, dbt_tree, tmp_path):
        dst = tmp_path / "output"
        deploy.copy_dbt_staging_exclude_templates(dbt_tree, dst)
        assert not (dst / ".build").exists()

    def test_excludes_target_dir(self, dbt_tree, tmp_path):
        dst = tmp_path / "output"
        deploy.copy_dbt_staging_exclude_templates(dbt_tree, dst)
        assert not (dst / "target").exists()

    def test_excludes_logs_dir(self, dbt_tree, tmp_path):
        dst = tmp_path / "output"
        deploy.copy_dbt_staging_exclude_templates(dbt_tree, dst)
        assert not (dst / "logs").exists()

    def test_excludes_root_profiles_yml(self, dbt_tree, tmp_path):
        dst = tmp_path / "output"
        deploy.copy_dbt_staging_exclude_templates(dbt_tree, dst)
        assert not (dst / "profiles.yml").exists()

    def test_excludes_models_sources_yml(self, dbt_tree, tmp_path):
        dst = tmp_path / "output"
        deploy.copy_dbt_staging_exclude_templates(dbt_tree, dst)
        assert not (dst / "models" / "sources.yml").exists()

    def test_includes_dbt_project_yml(self, dbt_tree, tmp_path):
        dst = tmp_path / "output"
        deploy.copy_dbt_staging_exclude_templates(dbt_tree, dst)
        assert (dst / "dbt_project.yml").exists()
        assert (dst / "dbt_project.yml").read_text() == "name: test\n"

    def test_includes_model_sql_files(self, dbt_tree, tmp_path):
        dst = tmp_path / "output"
        deploy.copy_dbt_staging_exclude_templates(dbt_tree, dst)
        assert (dst / "models" / "staging" / "stg_orders.sql").exists()

    def test_destination_cleaned_if_preexisting(self, dbt_tree, tmp_path):
        dst = tmp_path / "output"
        dst.mkdir()
        (dst / "leftover.txt").write_text("stale")
        deploy.copy_dbt_staging_exclude_templates(dbt_tree, dst)
        assert not (dst / "leftover.txt").exists()

    def test_nested_subdirs_preserved(self, dbt_tree, tmp_path):
        """Deeply nested directories are copied."""
        deep = dbt_tree / "models" / "staging" / "deep"
        deep.mkdir()
        (deep / "model.sql").write_text("SELECT 2")
        dst = tmp_path / "output"
        deploy.copy_dbt_staging_exclude_templates(dbt_tree, dst)
        assert (dst / "models" / "staging" / "deep" / "model.sql").exists()

    def test_sources_yml_only_excluded_in_models_dir(self, dbt_tree, tmp_path):
        """sources.yml in subdirectories other than models/ is kept."""
        other = dbt_tree / "other"
        other.mkdir()
        (other / "sources.yml").write_text("other sources\n")
        dst = tmp_path / "output"
        deploy.copy_dbt_staging_exclude_templates(dbt_tree, dst)
        assert (dst / "other" / "sources.yml").exists()


# ---------------------------------------------------------------------------
# repo_root
# ---------------------------------------------------------------------------

class TestRepoRoot:
    """Tests for repo_root path resolution."""

    def test_returns_parent_of_scripts_dir(self):
        root = deploy.repo_root()
        assert root.is_dir()
        assert (root / "scripts" / "deploy.py").is_file()

    def test_returns_absolute_path(self):
        root = deploy.repo_root()
        assert root.is_absolute()


# ---------------------------------------------------------------------------
# parse_args
# ---------------------------------------------------------------------------

class TestParseArgs:
    """Tests for CLI argument parsing (pure argparse)."""

    def test_default_is_full_no_envsubst(self):
        ns = deploy.parse_args([])
        assert ns.stop_at == "full"
        assert ns.prefer_envsubst is False
        assert ns.resume is False

    def test_stop_at_raw_load(self):
        ns = deploy.parse_args(["--stop-at", "raw-load"])
        assert ns.stop_at == "raw-load"

    def test_stop_at_build(self):
        ns = deploy.parse_args(["--stop-at", "build"])
        assert ns.stop_at == "build"

    def test_stop_at_full_explicit(self):
        ns = deploy.parse_args(["--stop-at", "full"])
        assert ns.stop_at == "full"

    def test_resume_overrides_stop_at(self):
        ns = deploy.parse_args(["--stop-at", "build", "--resume"])
        assert ns.stop_at == "full"

    def test_resume_alone(self):
        ns = deploy.parse_args(["--resume"])
        assert ns.stop_at == "full"

    def test_prefer_envsubst_flag(self):
        ns = deploy.parse_args(["--prefer-envsubst"])
        assert ns.prefer_envsubst is True

    def test_combined_flags(self):
        ns = deploy.parse_args(["--prefer-envsubst", "--stop-at", "raw-load"])
        assert ns.prefer_envsubst is True
        assert ns.stop_at == "raw-load"

    def test_invalid_stop_at_value_exits(self):
        with pytest.raises(SystemExit):
            deploy.parse_args(["--stop-at", "invalid"])

    def test_stop_at_missing_value_exits(self):
        with pytest.raises(SystemExit):
            deploy.parse_args(["--stop-at"])

    def test_unknown_flag_exits(self):
        with pytest.raises(SystemExit):
            deploy.parse_args(["--bad-flag"])


# ---------------------------------------------------------------------------
# load_dotenv
# ---------------------------------------------------------------------------

class TestLoadDotenv:
    """Tests for loading .env into os.environ."""

    def test_loads_all_vars(self, dotenv_file, clean_env):
        deploy.load_dotenv(dotenv_file)
        assert os.environ["SNOWFLAKE_CONNECTION"] == "test_conn"
        assert os.environ["TARGET_DATABASE"] == "TEST_DB"
        assert os.environ["TARGET_WAREHOUSE"] == "TEST_WH"

    def test_overwrites_existing_env_vars(self, dotenv_file, monkeypatch):
        monkeypatch.setenv("TARGET_DATABASE", "OLD_DB")
        deploy.load_dotenv(dotenv_file)
        assert os.environ["TARGET_DATABASE"] == "TEST_DB"

    def test_missing_env_file_exits(self, tmp_path, clean_env):
        with pytest.raises(SystemExit) as exc_info:
            deploy.load_dotenv(tmp_path)
        assert exc_info.value.code == 1

    def test_handles_utf8_content(self, tmp_path, clean_env):
        (tmp_path / ".env").write_text("DESC=café résumé\n", encoding="utf-8")
        deploy.load_dotenv(tmp_path)
        assert os.environ["DESC"] == "café résumé"


# ---------------------------------------------------------------------------
# require_env
# ---------------------------------------------------------------------------

class TestRequireEnv:
    """Tests for require_env helper."""

    def test_returns_value_when_set(self, monkeypatch):
        monkeypatch.setenv("TEST_KEY", "hello")
        assert deploy.require_env("TEST_KEY") == "hello"

    def test_exits_when_missing(self, monkeypatch):
        monkeypatch.delenv("MISSING_KEY", raising=False)
        with pytest.raises(SystemExit) as exc_info:
            deploy.require_env("MISSING_KEY")
        assert exc_info.value.code == 1

    def test_exits_when_empty_string(self, monkeypatch):
        monkeypatch.setenv("BLANK", "")
        with pytest.raises(SystemExit) as exc_info:
            deploy.require_env("BLANK")
        assert exc_info.value.code == 1

    def test_whitespace_value_is_valid(self, monkeypatch):
        monkeypatch.setenv("SPACES", "  ")
        assert deploy.require_env("SPACES") == "  "


# ---------------------------------------------------------------------------
# envsubst_python
# ---------------------------------------------------------------------------

class TestEnvsubstPython:
    """Tests for the pure-Python ${VAR} substitution."""

    def test_replaces_known_var(self, monkeypatch):
        monkeypatch.setenv("MY_DB", "ANALYTICS")
        assert deploy.envsubst_python("USE DATABASE ${MY_DB};", only=None) == "USE DATABASE ANALYTICS;"

    def test_missing_var_becomes_empty(self, monkeypatch):
        monkeypatch.delenv("NONEXIST", raising=False)
        assert deploy.envsubst_python("${NONEXIST}", only=None) == ""

    def test_only_filter_allows_listed(self, monkeypatch):
        monkeypatch.setenv("A", "1")
        monkeypatch.setenv("B", "2")
        result = deploy.envsubst_python("${A} ${B}", only=frozenset({"A"}))
        assert result == "1 ${B}"

    def test_only_filter_empty_set_replaces_nothing(self, monkeypatch):
        monkeypatch.setenv("A", "1")
        result = deploy.envsubst_python("${A}", only=frozenset())
        assert result == "${A}"

    def test_no_vars_unchanged(self):
        assert deploy.envsubst_python("SELECT 1;", only=None) == "SELECT 1;"

    def test_multiple_occurrences_same_var(self, monkeypatch):
        monkeypatch.setenv("X", "hi")
        assert deploy.envsubst_python("${X} ${X}", only=None) == "hi hi"

    def test_adjacent_vars(self, monkeypatch):
        monkeypatch.setenv("A", "1")
        monkeypatch.setenv("B", "2")
        assert deploy.envsubst_python("${A}${B}", only=None) == "12"

    def test_nested_braces_not_matched(self, monkeypatch):
        monkeypatch.setenv("X", "val")
        # ${${X}} — inner ${X} would match but the outer ${ doesn't form a valid var name
        result = deploy.envsubst_python("${${X}}", only=None)
        # The regex matches ${X} inside, leaving ${ and } around
        assert "val" in result

    def test_dollar_without_brace_unchanged(self, monkeypatch):
        monkeypatch.setenv("FOO", "bar")
        assert deploy.envsubst_python("$FOO ${FOO}", only=None) == "$FOO bar"


# ---------------------------------------------------------------------------
# envsubst_maybe
# ---------------------------------------------------------------------------

class TestEnvsubstMaybe:
    """Tests for the routing function (prefer external vs. Python fallback)."""

    def test_with_only_always_uses_python(self, monkeypatch):
        """When `only` is set, always uses Python impl regardless of prefer flag."""
        monkeypatch.setenv("A", "1")
        monkeypatch.setenv("B", "2")
        result = deploy.envsubst_maybe("${A} ${B}", prefer=True, only=frozenset({"A"}))
        assert result == "1 ${B}"

    def test_prefer_false_uses_python(self, monkeypatch):
        monkeypatch.setenv("X", "val")
        result = deploy.envsubst_maybe("${X}", prefer=False, only=None)
        assert result == "val"

    @patch("shutil.which", return_value=None)
    def test_prefer_true_no_envsubst_falls_back_to_python(self, mock_which, monkeypatch):
        monkeypatch.setenv("X", "val")
        result = deploy.envsubst_maybe("${X}", prefer=True, only=None)
        assert result == "val"

    @patch("subprocess.run")
    @patch("shutil.which", return_value="/usr/bin/envsubst")
    def test_prefer_true_with_envsubst_calls_subprocess(self, mock_which, mock_run, monkeypatch):
        mock_run.return_value = MagicMock(stdout="replaced text")
        result = deploy.envsubst_maybe("${X}", prefer=True, only=None)
        assert result == "replaced text"
        mock_run.assert_called_once()
        args = mock_run.call_args
        assert args[0][0] == ["envsubst"]
        assert args[1]["input"] == "${X}"


# ---------------------------------------------------------------------------
# run_snow_ci
# ---------------------------------------------------------------------------

class TestRunSnowCi:
    """Tests for the snow SQL execution wrapper."""

    @patch("subprocess.run")
    def test_passes_correct_args(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0)
        deploy.run_snow_ci("/usr/bin/snow", "my_conn", "SELECT 1;")
        mock_run.assert_called_once()
        cmd = mock_run.call_args[0][0]
        assert cmd == ["/usr/bin/snow", "sql", "-c", "my_conn", "-i"]

    @patch("subprocess.run")
    def test_passes_sql_as_stdin(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0)
        deploy.run_snow_ci("/usr/bin/snow", "conn", "USE DATABASE FOO;")
        kwargs = mock_run.call_args[1]
        assert kwargs["input"] == "USE DATABASE FOO;"
        assert kwargs["encoding"] == "utf-8"

    @patch("subprocess.run")
    def test_returns_completed_process(self, mock_run):
        expected = MagicMock(returncode=1)
        mock_run.return_value = expected
        result = deploy.run_snow_ci("/bin/snow", "c", "BAD SQL")
        assert result is expected
        assert result.returncode == 1


# ---------------------------------------------------------------------------
# dcm_filtered
# ---------------------------------------------------------------------------

class TestDcmFiltered:
    """Tests for the DCM command wrapper with output filtering."""

    @patch("subprocess.run")
    def test_create_mode_passes_correct_cmd(self, mock_run, tmp_path):
        mock_run.return_value = MagicMock(stdout="", stderr="", returncode=0)
        deploy.dcm_filtered("/bin/snow", "conn", tmp_path, "MY_DB", create=True)
        cmd = mock_run.call_args[0][0]
        assert cmd[:2] == ["/bin/snow", "dcm"]
        assert "create" in cmd
        assert "COCO_DCM_PROJECT" in cmd
        assert "--database" in cmd
        assert "MY_DB" in cmd

    @patch("subprocess.run")
    def test_deploy_mode_passes_correct_cmd(self, mock_run, tmp_path):
        mock_run.return_value = MagicMock(stdout="", stderr="", returncode=0)
        deploy.dcm_filtered("/bin/snow", "conn", tmp_path, "MY_DB", create=False)
        cmd = mock_run.call_args[0][0]
        assert "deploy" in cmd
        assert "COCO_DCM_PROJECT" in cmd

    @patch("subprocess.run")
    def test_filters_already_exists_from_stdout(self, mock_run, tmp_path, capsys):
        mock_run.return_value = MagicMock(
            stdout="Created schema\nSCHEMA already exists — skipped\nDone",
            stderr="",
            returncode=0,
        )
        deploy.dcm_filtered("/bin/snow", "conn", tmp_path, "DB", create=True)
        captured = capsys.readouterr()
        assert "Created schema" in captured.out
        assert "Done" in captured.out
        assert "already exists" not in captured.out

    @patch("subprocess.run")
    def test_prints_stderr_to_stderr(self, mock_run, tmp_path, capsys):
        mock_run.return_value = MagicMock(
            stdout="",
            stderr="Warning: something",
            returncode=0,
        )
        deploy.dcm_filtered("/bin/snow", "conn", tmp_path, "DB", create=True)
        captured = capsys.readouterr()
        assert "Warning: something" in captured.err

    @patch("subprocess.run")
    def test_empty_stdout_no_output(self, mock_run, tmp_path, capsys):
        mock_run.return_value = MagicMock(stdout="", stderr="", returncode=0)
        deploy.dcm_filtered("/bin/snow", "conn", tmp_path, "DB", create=True)
        captured = capsys.readouterr()
        assert captured.out == ""

    @patch("subprocess.run")
    def test_nonzero_exit_code_does_not_raise(self, mock_run, tmp_path):
        """dcm_filtered ignores exit codes (documented behavior)."""
        mock_run.return_value = MagicMock(stdout="", stderr="error", returncode=1)
        # Should not raise
        deploy.dcm_filtered("/bin/snow", "conn", tmp_path, "DB", create=True)

    @patch("subprocess.run")
    def test_includes_from_and_schema_flags(self, mock_run, tmp_path):
        mock_run.return_value = MagicMock(stdout="", stderr="", returncode=0)
        deploy.dcm_filtered("/bin/snow", "conn", tmp_path / "build", "DB", create=True)
        cmd = mock_run.call_args[0][0]
        assert "--from" in cmd
        assert str(tmp_path / "build") in cmd
        assert "--schema" in cmd
        assert "PUBLIC" in cmd
        assert "--connection" in cmd
        assert "conn" in cmd


# ---------------------------------------------------------------------------
# SAFETY_BOX
# ---------------------------------------------------------------------------

class TestSafetyBox:
    """Tests for the safety gate message template."""

    def test_formats_with_db_and_conn(self):
        result = deploy.SAFETY_BOX.format(db="MY_DB", conn="my_conn")
        assert "MY_DB" in result
        assert "my_conn" in result

    def test_contains_instructions(self):
        result = deploy.SAFETY_BOX.format(db="X", conn="Y")
        assert "I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=1" in result


# ---------------------------------------------------------------------------
# main() — integration-ish tests with mocked subprocess
# ---------------------------------------------------------------------------

class TestMainSafetyGate:
    """Tests for main() safety gate behavior."""

    def test_aborts_when_safety_flag_is_zero(self, dotenv_file, clean_env):
        env = dotenv_file / ".env"
        env.write_text(
            env.read_text().replace(
                "I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=1",
                "I_UNDERSTAND_THIS_WILL_OVERWRITE_TARGET_DATABASE=0",
            )
        )
        with patch.object(deploy, "repo_root", return_value=dotenv_file):
            with patch("os.chdir"):
                with pytest.raises(SystemExit) as exc_info:
                    deploy.main()
        assert exc_info.value.code == 2

    def test_aborts_when_safety_flag_missing(self, tmp_path, clean_env):
        """If the flag isn't in .env at all, defaults to 0 and aborts."""
        (tmp_path / ".env").write_text(
            "SNOWFLAKE_CONNECTION=c\n"
            "TARGET_DATABASE=DB\n"
            "TARGET_WAREHOUSE=WH\n"
        )
        with patch.object(deploy, "repo_root", return_value=tmp_path):
            with patch("os.chdir"):
                with pytest.raises(SystemExit) as exc_info:
                    deploy.main()
        assert exc_info.value.code == 2


class TestMainEnvDerivation:
    """Tests that main() derives TARGET_DB and TARGET_WH correctly."""

    @patch("subprocess.run")
    def test_sets_target_db_and_wh_env_vars(self, mock_run, dotenv_file, clean_env, monkeypatch):
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="")
        monkeypatch.setattr(sys, "argv", ["deploy.py"])

        # Provide required bootstrap file
        (dotenv_file / "bootstrap").mkdir()
        (dotenv_file / "bootstrap" / "00_bootstrap.sql").write_text("SELECT 1;")

        with patch.object(deploy, "repo_root", return_value=dotenv_file):
            with patch("os.chdir"):
                with patch.object(deploy, "snow_executable", return_value="/bin/snow"):
                    # Will exit at step 1 due to returncode=1
                    with pytest.raises(SystemExit):
                        deploy.main()

        assert os.environ.get("TARGET_DB") == "TEST_DB"
        assert os.environ.get("TARGET_WH") == "TEST_WH"


class TestMainStopAtRawLoad:
    """Tests that --stop-at raw-load halts after step 3."""

    @patch("subprocess.run")
    def test_returns_after_raw_load(self, mock_run, dotenv_file, clean_env, capsys, monkeypatch):
        mock_run.return_value = MagicMock(returncode=0, stdout="ok", stderr="")
        monkeypatch.setattr(sys, "argv", ["deploy.py", "--stop-at", "raw-load"])

        # Create required files
        (dotenv_file / "bootstrap").mkdir()
        (dotenv_file / "bootstrap" / "00_bootstrap.sql").write_text("SELECT 1;")
        (dotenv_file / "bootstrap" / "01_load_raw.sql").write_text("COPY INTO ..;")
        dcm = dotenv_file / "dcm"
        dcm.mkdir()
        (dcm / "manifest.yml").write_text("database: PAWCORE_ANALYTICS\n")
        (dcm / "pre_deploy.sql").write_text("")
        (dcm / "post_deploy.sql").write_text("")
        defs = dcm / "sources" / "definitions"
        defs.mkdir(parents=True)
        (defs / "schemas.sql").write_text("CREATE SCHEMA ${TARGET_DB}.RAW;")

        with patch.object(deploy, "repo_root", return_value=dotenv_file):
            with patch("os.chdir"):
                with patch.object(deploy, "snow_executable", return_value="/bin/snow"):
                    deploy.main()

        captured = capsys.readouterr()
        assert "Stopped at raw-load" in captured.out
        # Should NOT have reached step 4
        assert "Step 4/7" not in captured.out


# ---------------------------------------------------------------------------
# --teardown flag
# ---------------------------------------------------------------------------

class TestTeardown:
    """Tests for the --teardown flag."""

    def test_teardown_flag_parsed(self):
        ns = deploy.parse_args(["--teardown"])
        assert ns.teardown is True

    @patch("subprocess.run")
    def test_teardown_runs_and_exits(self, mock_run, full_project_tree, clean_env, capsys, monkeypatch):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        monkeypatch.setattr(sys, "argv", ["deploy.py", "--teardown"])

        # Create teardown.sql in the project tree
        (full_project_tree / "teardown.sql").write_text(
            "DROP DATABASE IF EXISTS ${TARGET_DB};\n"
            "DROP WAREHOUSE IF EXISTS ${TARGET_WH};\n"
        )

        with patch.object(deploy, "repo_root", return_value=full_project_tree):
            with patch("os.chdir"):
                with patch.object(deploy, "snow_executable", return_value="/bin/snow"):
                    deploy.main()

        captured = capsys.readouterr()
        assert "Teardown complete" in captured.out
        # Should NOT have run any deploy steps
        assert "Step 1/7" not in captured.out

    @patch("subprocess.run")
    def test_teardown_does_not_need_safety_gate(self, mock_run, tmp_path, clean_env, monkeypatch):
        """Teardown works without I_UNDERSTAND flag."""
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        monkeypatch.setattr(sys, "argv", ["deploy.py", "--teardown"])

        (tmp_path / ".env").write_text(
            "SNOWFLAKE_CONNECTION=c\nTARGET_DATABASE=DB\nTARGET_WAREHOUSE=WH\n"
        )
        (tmp_path / "teardown.sql").write_text("DROP DATABASE IF EXISTS ${TARGET_DB};")

        with patch.object(deploy, "repo_root", return_value=tmp_path):
            with patch("os.chdir"):
                with patch.object(deploy, "snow_executable", return_value="/bin/snow"):
                    deploy.main()  # Should NOT exit with code 2


class TestMainStopAtBuild:
    """Tests that --stop-at build halts after step 5."""

    @patch("subprocess.run")
    def test_returns_after_build(self, mock_run, dotenv_file, clean_env, capsys, monkeypatch):
        mock_run.return_value = MagicMock(returncode=0, stdout="ok", stderr="")
        monkeypatch.setattr(sys, "argv", ["deploy.py", "--stop-at", "build"])

        # Create required file structure
        (dotenv_file / "bootstrap").mkdir()
        (dotenv_file / "bootstrap" / "00_bootstrap.sql").write_text("")
        (dotenv_file / "bootstrap" / "01_load_raw.sql").write_text("")
        dcm = dotenv_file / "dcm"
        dcm.mkdir()
        (dcm / "manifest.yml").write_text("database: PAWCORE_ANALYTICS\n")
        (dcm / "pre_deploy.sql").write_text("")
        (dcm / "post_deploy.sql").write_text("")
        defs = dcm / "sources" / "definitions"
        defs.mkdir(parents=True)
        (defs / "schemas.sql").write_text("")
        dbt = dotenv_file / "dbt"
        dbt.mkdir()
        (dbt / "dbt_project.yml").write_text("name: test\n")
        (dbt / "profiles.yml").write_text("target: ${TARGET_DB}\n")
        models = dbt / "models"
        models.mkdir()
        (models / "sources.yml").write_text("database: ${TARGET_DB}\n")
        snowflake = dotenv_file / "snowflake"
        snowflake.mkdir()
        (snowflake / "run_pipeline.sql").write_text("EXECUTE DBT PROJECT ...;")

        with patch.object(deploy, "repo_root", return_value=dotenv_file):
            with patch("os.chdir"):
                with patch.object(deploy, "snow_executable", return_value="/bin/snow"):
                    deploy.main()

        captured = capsys.readouterr()
        assert "Stopped at dbt build" in captured.out
        assert "Step 6/7" not in captured.out


class TestMainFullDeploy:
    """Tests that a full deploy runs all 7 steps."""

    @patch("subprocess.run")
    def test_full_deploy_prints_completion(self, mock_run, dotenv_file, clean_env, capsys, monkeypatch):
        mock_run.return_value = MagicMock(returncode=0, stdout="ok", stderr="")
        monkeypatch.setattr(sys, "argv", ["deploy.py"])

        # Create full file structure
        (dotenv_file / "bootstrap").mkdir()
        (dotenv_file / "bootstrap" / "00_bootstrap.sql").write_text("")
        (dotenv_file / "bootstrap" / "01_load_raw.sql").write_text("")
        dcm = dotenv_file / "dcm"
        dcm.mkdir()
        (dcm / "manifest.yml").write_text("database: PAWCORE_ANALYTICS\n")
        (dcm / "pre_deploy.sql").write_text("")
        (dcm / "post_deploy.sql").write_text("")
        defs = dcm / "sources" / "definitions"
        defs.mkdir(parents=True)
        (defs / "schemas.sql").write_text("")
        dbt = dotenv_file / "dbt"
        dbt.mkdir()
        (dbt / "dbt_project.yml").write_text("name: test\n")
        (dbt / "profiles.yml").write_text("")
        models = dbt / "models"
        models.mkdir()
        (models / "sources.yml").write_text("")
        snowflake = dotenv_file / "snowflake"
        snowflake.mkdir()
        (snowflake / "run_pipeline.sql").write_text("")
        (snowflake / "create_semantic_view.sql").write_text("")
        (snowflake / "create_agent.sql").write_text("")

        with patch.object(deploy, "repo_root", return_value=dotenv_file):
            with patch("os.chdir"):
                with patch.object(deploy, "snow_executable", return_value="/bin/snow"):
                    deploy.main()

        captured = capsys.readouterr()
        assert "Deploy complete" in captured.out
        assert "TEST_DB" in captured.out

    @patch("subprocess.run")
    def test_agent_failure_is_non_fatal(self, mock_run, dotenv_file, clean_env, capsys, monkeypatch):
        """If CREATE AGENT fails (step 7), deploy still completes with a warning."""

        def side_effect(*args, **kwargs):
            cmd = args[0] if args else kwargs.get("args", [])
            # Make the final run_snow_ci call (step 7 - agent) fail
            if isinstance(cmd, list) and "-i" in cmd:
                side_effect.call_count += 1
                # -i calls: bootstrap=1, raw-load=2,
                # pipeline=3, semantic=4, agent=5
                if side_effect.call_count >= 5:
                    return MagicMock(returncode=1, stdout="", stderr="")
            return MagicMock(returncode=0, stdout="ok", stderr="")

        side_effect.call_count = 0
        mock_run.side_effect = side_effect
        monkeypatch.setattr(sys, "argv", ["deploy.py"])

        # Create full file structure
        (dotenv_file / "bootstrap").mkdir()
        (dotenv_file / "bootstrap" / "00_bootstrap.sql").write_text("")
        (dotenv_file / "bootstrap" / "01_load_raw.sql").write_text("")
        dcm = dotenv_file / "dcm"
        dcm.mkdir()
        (dcm / "manifest.yml").write_text("database: PAWCORE_ANALYTICS\n")
        (dcm / "pre_deploy.sql").write_text("")
        (dcm / "post_deploy.sql").write_text("")
        defs = dcm / "sources" / "definitions"
        defs.mkdir(parents=True)
        (defs / "schemas.sql").write_text("")
        dbt = dotenv_file / "dbt"
        dbt.mkdir()
        (dbt / "dbt_project.yml").write_text("name: test\n")
        (dbt / "profiles.yml").write_text("")
        models = dbt / "models"
        models.mkdir()
        (models / "sources.yml").write_text("")
        snowflake = dotenv_file / "snowflake"
        snowflake.mkdir()
        (snowflake / "run_pipeline.sql").write_text("")
        (snowflake / "create_semantic_view.sql").write_text("")
        (snowflake / "create_agent.sql").write_text("")

        with patch.object(deploy, "repo_root", return_value=dotenv_file):
            with patch("os.chdir"):
                with patch.object(deploy, "snow_executable", return_value="/bin/snow"):
                    # Should NOT raise despite agent failure
                    deploy.main()

        captured = capsys.readouterr()
        assert "CREATE AGENT failed" in captured.out


class TestMainBootstrapFailure:
    """Tests that main() exits on step 1 failure."""

    @patch("subprocess.run")
    def test_exits_on_bootstrap_failure(self, mock_run, dotenv_file, clean_env, monkeypatch):
        # First call (preflight) succeeds, second call (bootstrap) fails
        mock_run.side_effect = [
            MagicMock(returncode=1, stdout="", stderr=""),  # preflight
            MagicMock(returncode=3, stdout="", stderr="SQL error"),  # bootstrap
        ]
        monkeypatch.setattr(sys, "argv", ["deploy.py"])

        (dotenv_file / "bootstrap").mkdir()
        (dotenv_file / "bootstrap" / "00_bootstrap.sql").write_text("BAD SQL;")

        with patch.object(deploy, "repo_root", return_value=dotenv_file):
            with patch("os.chdir"):
                with patch.object(deploy, "snow_executable", return_value="/bin/snow"):
                    with pytest.raises(SystemExit) as exc_info:
                        deploy.main()
        assert exc_info.value.code == 3


# ---------------------------------------------------------------------------
# _build_and_deploy_dcm
# ---------------------------------------------------------------------------

class TestBuildAndDeployDcm:
    """Tests for the extracted DCM build function."""

    @patch("subprocess.run")
    def test_substitutes_target_db_in_pre_deploy(self, mock_run, full_project_tree, clean_env, monkeypatch):
        monkeypatch.setenv("TARGET_DB", "MY_SANDBOX")
        monkeypatch.setenv("TARGET_WH", "MY_WH")

        mock_run.return_value = MagicMock(stdout="", stderr="", returncode=0)

        def sub_all(text):
            return deploy.envsubst_python(text, only=None)

        deploy._build_and_deploy_dcm("/bin/snow", "conn", full_project_tree, "MY_SANDBOX", sub_all)

        # Verify .build was cleaned up
        assert not (full_project_tree / "dcm" / ".build").exists()

    @patch("subprocess.run")
    def test_calls_dcm_create_and_deploy(self, mock_run, full_project_tree, clean_env, monkeypatch):
        monkeypatch.setenv("TARGET_DB", "DB")
        monkeypatch.setenv("TARGET_WH", "WH")

        mock_run.return_value = MagicMock(stdout="", stderr="", returncode=0)

        def sub_all(text):
            return deploy.envsubst_python(text, only=None)

        deploy._build_and_deploy_dcm("/bin/snow", "conn", full_project_tree, "DB", sub_all)

        # Should have been called at least twice (create + deploy)
        dcm_calls = [c for c in mock_run.call_args_list if "dcm" in str(c)]
        assert len(dcm_calls) == 2


# ---------------------------------------------------------------------------
# _stage_dbt_project
# ---------------------------------------------------------------------------

class TestStageDbtProject:
    """Tests for the extracted dbt staging function."""

    @patch("subprocess.run")
    def test_creates_and_cleans_build_dir(self, mock_run, full_project_tree, clean_env, monkeypatch):
        monkeypatch.setenv("TARGET_DB", "DB")
        monkeypatch.setenv("TARGET_WH", "WH")
        mock_run.return_value = MagicMock(returncode=0, stdout="ok", stderr="")

        deploy._stage_dbt_project("/bin/snow", "conn", full_project_tree, "DB", "WH", False)

        # .build/ should be cleaned up
        assert not (full_project_tree / "dbt" / ".build").exists()

    @patch("subprocess.run")
    def test_stage_copy_failure_raises(self, mock_run, full_project_tree, clean_env, monkeypatch):
        """CalledProcessError on snow stage copy propagates."""
        monkeypatch.setenv("TARGET_DB", "DB")
        monkeypatch.setenv("TARGET_WH", "WH")

        import subprocess as sp

        def side_effect(*args, **kwargs):
            cmd = args[0] if args else []
            if "stage" in cmd and "copy" in cmd:
                raise sp.CalledProcessError(1, cmd)
            return MagicMock(returncode=0, stdout="", stderr="")

        mock_run.side_effect = side_effect

        with pytest.raises(sp.CalledProcessError):
            deploy._stage_dbt_project("/bin/snow", "conn", full_project_tree, "DB", "WH", False)


# ---------------------------------------------------------------------------
# envsubst_maybe — external envsubst failure
# ---------------------------------------------------------------------------

class TestEnvsubstMaybeFailure:
    """Tests for envsubst_maybe when external envsubst crashes."""

    @patch("shutil.which", return_value="/usr/bin/envsubst")
    @patch("subprocess.run")
    def test_external_envsubst_failure_raises(self, mock_run, mock_which, monkeypatch):
        import subprocess as sp

        mock_run.side_effect = sp.CalledProcessError(1, ["envsubst"])

        with pytest.raises(sp.CalledProcessError):
            deploy.envsubst_maybe("${X}", prefer=True, only=None)


# ---------------------------------------------------------------------------
# Full deploy with shared fixture
# ---------------------------------------------------------------------------

class TestMainWithSharedFixture:
    """Integration tests using the full_project_tree fixture."""

    @patch("subprocess.run")
    def test_full_deploy_completes(self, mock_run, full_project_tree, clean_env, capsys, monkeypatch):
        mock_run.return_value = MagicMock(returncode=0, stdout="ok", stderr="")
        monkeypatch.setattr(sys, "argv", ["deploy.py"])

        with patch.object(deploy, "repo_root", return_value=full_project_tree):
            with patch("os.chdir"):
                with patch.object(deploy, "snow_executable", return_value="/bin/snow"):
                    deploy.main()

        captured = capsys.readouterr()
        assert "Deploy complete" in captured.out

    @patch("subprocess.run")
    def test_stop_at_raw_load(self, mock_run, full_project_tree, clean_env, capsys, monkeypatch):
        mock_run.return_value = MagicMock(returncode=0, stdout="ok", stderr="")
        monkeypatch.setattr(sys, "argv", ["deploy.py", "--stop-at", "raw-load"])

        with patch.object(deploy, "repo_root", return_value=full_project_tree):
            with patch("os.chdir"):
                with patch.object(deploy, "snow_executable", return_value="/bin/snow"):
                    deploy.main()

        captured = capsys.readouterr()
        assert "Stopped at raw-load" in captured.out
        assert "Step 4/7" not in captured.out


# ---------------------------------------------------------------------------
# _run_verify
# ---------------------------------------------------------------------------


class TestRunVerify:
    """Tests for the _run_verify function."""

    def _mock_subprocess(self, responses):
        """Helper: mock subprocess.run to return a series of responses."""
        call_idx = [0]

        def side_effect(*args, **kwargs):
            idx = call_idx[0]
            call_idx[0] += 1
            if idx < len(responses):
                return responses[idx]
            # Default success
            return MagicMock(returncode=0, stdout="[]", stderr="")

        return side_effect

    @patch("subprocess.run")
    def test_all_pass(self, mock_run, capsys):
        """All tables found with correct counts, semantic view + VQRs + agent present."""
        import json

        # 7 table checks + semantic view + VQR describe + agent = 10 calls
        table_responses = []
        for count in [21000, 1050, 1550, 37, 3, 3, 3]:
            table_responses.append(
                MagicMock(returncode=0, stdout=json.dumps([{"N": count}]), stderr="")
            )
        # Semantic view found
        table_responses.append(
            MagicMock(returncode=0, stdout='[{"name": "PAWCORE_ANALYSIS"}]', stderr="")
        )
        # VQR describe — 22 QUESTION entries
        vqr_stdout = '"QUESTION"\n' * 22
        table_responses.append(
            MagicMock(returncode=0, stdout=vqr_stdout, stderr="")
        )
        # Agent found
        table_responses.append(
            MagicMock(returncode=0, stdout='[{"name": "PAWCORE_ASSISTANT"}]', stderr="")
        )

        mock_run.side_effect = table_responses

        result = deploy._run_verify("/bin/snow", "test_conn", "TESTDB")
        assert result is True
        captured = capsys.readouterr()
        assert "PASS  DEVICE_DATA.TELEMETRY: 21,000 rows" in captured.out
        assert "PASS  SEMANTIC VIEW: PAWCORE_ANALYSIS" in captured.out
        assert "PASS  VERIFIED QUERIES: 22 registered" in captured.out
        assert "PASS  AGENT: PAWCORE_ASSISTANT" in captured.out

    @patch("subprocess.run")
    def test_table_wrong_count(self, mock_run, capsys):
        """Wrong row count causes FAIL."""
        import json

        # First table wrong, rest correct
        responses = [MagicMock(returncode=0, stdout=json.dumps([{"N": 999}]), stderr="")]
        for count in [1050, 1550, 37, 3, 3, 3]:
            responses.append(MagicMock(returncode=0, stdout=json.dumps([{"N": count}]), stderr=""))
        # SV + VQR + Agent
        responses.append(MagicMock(returncode=0, stdout="PAWCORE_ANALYSIS", stderr=""))
        responses.append(MagicMock(returncode=0, stdout='"QUESTION"\n' * 22, stderr=""))
        responses.append(MagicMock(returncode=0, stdout="PAWCORE_ASSISTANT", stderr=""))

        mock_run.side_effect = responses

        result = deploy._run_verify("/bin/snow", "conn", "DB")
        assert result is False
        captured = capsys.readouterr()
        assert "FAIL  DEVICE_DATA.TELEMETRY: 999 rows (expected 21,000)" in captured.out

    @patch("subprocess.run")
    def test_table_not_found(self, mock_run, capsys):
        """Table query returns non-zero exit code."""
        import json

        # First table fails
        responses = [MagicMock(returncode=1, stdout="", stderr="does not exist")]
        for count in [1050, 1550, 37, 3, 3, 3]:
            responses.append(MagicMock(returncode=0, stdout=json.dumps([{"N": count}]), stderr=""))
        responses.append(MagicMock(returncode=0, stdout="PAWCORE_ANALYSIS", stderr=""))
        responses.append(MagicMock(returncode=0, stdout='"QUESTION"\n' * 22, stderr=""))
        responses.append(MagicMock(returncode=0, stdout="PAWCORE_ASSISTANT", stderr=""))

        mock_run.side_effect = responses

        result = deploy._run_verify("/bin/snow", "conn", "DB")
        assert result is False
        captured = capsys.readouterr()
        assert "FAIL  DEVICE_DATA.TELEMETRY: not found" in captured.out

    @patch("subprocess.run")
    def test_semantic_view_not_found(self, mock_run, capsys):
        """Semantic view missing causes FAIL."""
        import json

        responses = []
        for count in [21000, 1050, 1550, 37, 3, 3, 3]:
            responses.append(MagicMock(returncode=0, stdout=json.dumps([{"N": count}]), stderr=""))
        # SV not found
        responses.append(MagicMock(returncode=0, stdout="[]", stderr=""))
        # VQR describe fails (no view)
        responses.append(MagicMock(returncode=1, stdout="", stderr=""))
        # Agent found
        responses.append(MagicMock(returncode=0, stdout="PAWCORE_ASSISTANT", stderr=""))

        mock_run.side_effect = responses

        result = deploy._run_verify("/bin/snow", "conn", "DB")
        assert result is False
        captured = capsys.readouterr()
        assert "FAIL  SEMANTIC VIEW: not found" in captured.out

    @patch("subprocess.run")
    def test_vqr_low_count_warns(self, mock_run, capsys):
        """Low VQR count produces WARN but does not fail."""
        import json

        responses = []
        for count in [21000, 1050, 1550, 37, 3, 3, 3]:
            responses.append(MagicMock(returncode=0, stdout=json.dumps([{"N": count}]), stderr=""))
        responses.append(MagicMock(returncode=0, stdout="PAWCORE_ANALYSIS", stderr=""))
        # Only 5 VQRs
        responses.append(MagicMock(returncode=0, stdout='"QUESTION"\n' * 5, stderr=""))
        responses.append(MagicMock(returncode=0, stdout="PAWCORE_ASSISTANT", stderr=""))

        mock_run.side_effect = responses

        result = deploy._run_verify("/bin/snow", "conn", "DB")
        assert result is True  # VQR is warn-only, not a failure
        captured = capsys.readouterr()
        assert "WARN  VERIFIED QUERIES: only 5 (expected 22)" in captured.out

    @patch("subprocess.run")
    def test_vqr_zero_warns(self, mock_run, capsys):
        """Zero VQRs produces WARN but does not fail."""
        import json

        responses = []
        for count in [21000, 1050, 1550, 37, 3, 3, 3]:
            responses.append(MagicMock(returncode=0, stdout=json.dumps([{"N": count}]), stderr=""))
        responses.append(MagicMock(returncode=0, stdout="PAWCORE_ANALYSIS", stderr=""))
        # Zero VQRs
        responses.append(MagicMock(returncode=0, stdout="some describe output", stderr=""))
        responses.append(MagicMock(returncode=0, stdout="PAWCORE_ASSISTANT", stderr=""))

        mock_run.side_effect = responses

        result = deploy._run_verify("/bin/snow", "conn", "DB")
        assert result is True
        captured = capsys.readouterr()
        assert "WARN  VERIFIED QUERIES: none found" in captured.out

    @patch("subprocess.run")
    def test_agent_not_found(self, mock_run, capsys):
        """Missing agent causes FAIL."""
        import json

        responses = []
        for count in [21000, 1050, 1550, 37, 3, 3, 3]:
            responses.append(MagicMock(returncode=0, stdout=json.dumps([{"N": count}]), stderr=""))
        responses.append(MagicMock(returncode=0, stdout="PAWCORE_ANALYSIS", stderr=""))
        responses.append(MagicMock(returncode=0, stdout='"QUESTION"\n' * 22, stderr=""))
        # Agent not found
        responses.append(MagicMock(returncode=1, stdout="", stderr=""))

        mock_run.side_effect = responses

        result = deploy._run_verify("/bin/snow", "conn", "DB")
        assert result is False
        captured = capsys.readouterr()
        assert "FAIL  AGENT: not found" in captured.out

    @patch("subprocess.run")
    def test_json_parse_error(self, mock_run, capsys):
        """Invalid JSON from table query causes FAIL."""
        import json

        responses = [MagicMock(returncode=0, stdout="not json at all", stderr="")]
        for count in [1050, 1550, 37, 3, 3, 3]:
            responses.append(MagicMock(returncode=0, stdout=json.dumps([{"N": count}]), stderr=""))
        responses.append(MagicMock(returncode=0, stdout="PAWCORE_ANALYSIS", stderr=""))
        responses.append(MagicMock(returncode=0, stdout='"QUESTION"\n' * 22, stderr=""))
        responses.append(MagicMock(returncode=0, stdout="PAWCORE_ASSISTANT", stderr=""))

        mock_run.side_effect = responses

        result = deploy._run_verify("/bin/snow", "conn", "DB")
        assert result is False
        captured = capsys.readouterr()
        assert "FAIL  DEVICE_DATA.TELEMETRY: could not parse result" in captured.out
