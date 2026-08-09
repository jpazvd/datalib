"""Golden cases for library-root resolution (CFG-01 .. CFG-11).

Every case pins the configuration directory, so none of them can read the
operator's real ~/.config, and none leaves anything behind.
"""

import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from datalib.config import (ENV_CONFIG, ENV_CONFIG_DIR, ENV_VAR,  # noqa: E402
                            RootResolution, UserConfig, get_root,
                            getuserconfig, resolve_root)
from datalib.errors import (ConfigFileNotFound, DatalibRootNotSet,  # noqa: E402
                            UserBlockNotFound)

USER = "tester"


def write(path: Path, text: str, bom: bool = False) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    encoding = "utf-8-sig" if bom else "utf-8"
    path.write_text(text, encoding=encoding)
    return path


@pytest.fixture(autouse=True)
def clean_env(monkeypatch):
    """No ambient root or config may leak into a golden case."""
    for var in (ENV_VAR, ENV_CONFIG, ENV_CONFIG_DIR):
        monkeypatch.delenv(var, raising=False)


@pytest.fixture
def generic_only(tmp_path):
    write(tmp_path / "user_config.yml", f"{USER}:\n  datalib: F:/from_generic\n")
    return tmp_path


@pytest.fixture
def package_only(tmp_path):
    write(tmp_path / "datalib_config.yml", f"{USER}:\n  datalib: F:/from_package\n")
    return tmp_path


@pytest.fixture
def both_files(tmp_path):
    write(tmp_path / "user_config.yml", f"{USER}:\n  datalib: F:/from_generic\n")
    write(tmp_path / "datalib_config.yml", f"{USER}:\n  datalib: F:/from_package\n")
    return tmp_path


def test_cfg01_argument_wins(both_files):
    """CFG-01 an explicit argument outranks everything."""
    res = resolve_root("F:/explicit", user=USER, configdir=both_files, report=True)
    assert res.source_stage == "argument"
    assert str(res.root) == str(Path("F:/explicit"))


def test_cfg02_env_beats_files(both_files, monkeypatch):
    """CFG-02 the environment variable outranks both files."""
    monkeypatch.setenv(ENV_VAR, "F:/from_env")
    res = resolve_root(user=USER, configdir=both_files, report=True)
    assert res.source_stage == "env"


def test_cfg03_generic_file(generic_only):
    """CFG-03 the generic file supplies the root."""
    res = resolve_root(user=USER, configdir=generic_only, report=True)
    assert res.source_stage == "config_generic"
    assert str(res.root) == str(Path("F:/from_generic"))


def test_cfg04_package_file(package_only):
    """CFG-04 the package file supplies it when the generic one is absent."""
    res = resolve_root(user=USER, configdir=package_only, report=True)
    assert res.source_stage == "config_package"


def test_cfg05_generic_wins_when_both(both_files):
    """CFG-05 with both present, the generic file wins; blocks never merge."""
    res = resolve_root(user=USER, configdir=both_files, report=True)
    assert res.source_stage == "config_generic"
    assert str(res.root) == str(Path("F:/from_generic"))


def test_cfg06_key_presence_not_file_presence(tmp_path):
    """CFG-06 THE key case: the generic file exists but carries no datalib key,
    so resolution falls through to the package file rather than giving up."""
    write(tmp_path / "user_config.yml", f"{USER}:\n  githubFolder: C:/GitHub\n")
    write(tmp_path / "datalib_config.yml", f"{USER}:\n  datalib: F:/from_package\n")
    res = resolve_root(user=USER, configdir=tmp_path, report=True)
    assert res.source_stage == "config_package"
    assert str(res.root) == str(Path("F:/from_package"))


def test_cfg07_empty_value_counts_as_absent(tmp_path):
    """CFG-07 an empty datalib: value is absent, not an empty root."""
    write(tmp_path / "user_config.yml", f"{USER}:\n  datalib:\n")
    write(tmp_path / "datalib_config.yml", f"{USER}:\n  datalib: F:/from_package\n")
    res = resolve_root(user=USER, configdir=tmp_path, report=True)
    assert res.source_stage == "config_package"


def test_cfg08_nothing_configured_raises(tmp_path):
    """CFG-08 nothing anywhere is an error, not a guess."""
    with pytest.raises(DatalibRootNotSet):
        resolve_root(user=USER, configdir=tmp_path)


def test_cfg09_config_env_pins_one_file(both_files, monkeypatch):
    """CFG-09 DATALIB_CONFIG pins one file and turns the fallback off."""
    monkeypatch.setenv(ENV_CONFIG, str(both_files / "datalib_config.yml"))
    res = resolve_root(user=USER, report=True)
    assert res.source_stage == "config_package"


def test_cfg10_config_dir_env(both_files, monkeypatch):
    """CFG-10 DATALIB_CONFIG_DIR redirects the search, fallback preserved."""
    monkeypatch.setenv(ENV_CONFIG_DIR, str(both_files))
    res = resolve_root(user=USER, report=True)
    assert res.source_stage == "config_generic"


def test_cfg11_unreachable_root_is_returned_unchanged(tmp_path):
    """CFG-11 the safety property: a configured root that does not exist comes
    back as given. It must fail at the file operation, never drift elsewhere."""
    missing = "F:/definitely/not/here"
    write(tmp_path / "user_config.yml", f"{USER}:\n  datalib: {missing}\n")
    res = resolve_root(user=USER, configdir=tmp_path, report=True)
    assert str(res.root) == str(Path(missing))
    assert res.source_stage == "config_generic"


def test_bom_is_tolerated(tmp_path):
    """A UTF-8 BOM must not hide the first block; PowerShell writes one."""
    write(tmp_path / "user_config.yml", f"{USER}:\n  datalib: F:/after_bom\n",
          bom=True)
    res = resolve_root(user=USER, configdir=tmp_path, report=True)
    assert str(res.root) == str(Path("F:/after_bom"))


def test_reserved_keys_pass_through(tmp_path):
    """Sibling-tool keys are parsed and published, never used."""
    write(tmp_path / "user_config.yml",
          f"{USER}:\n  githubFolder: C:/GitHub\n  datalib: F:/lib\n")
    block = getuserconfig(user=USER, configdir=tmp_path)
    assert isinstance(block, UserConfig)
    assert block.githubFolder == "C:/GitHub"
    assert block.datalib == "F:/lib"


def test_missing_config_file_raises_typed_error(tmp_path):
    with pytest.raises(ConfigFileNotFound):
        getuserconfig(user=USER, configdir=tmp_path)


def test_missing_user_block_raises_typed_error(tmp_path):
    write(tmp_path / "user_config.yml", "somebodyelse:\n  datalib: F:/theirs\n")
    with pytest.raises(UserBlockNotFound):
        getuserconfig(user=USER, configdir=tmp_path)


def test_get_root_back_compat(tmp_path, monkeypatch):
    """get_root keeps its old contract: forward slashes, no trailing slash,
    and the error is still catchable as ValueError.

    The empty DATALIB_CONFIG_DIR is not decoration. get_root now falls through
    to the configuration stages, so on a machine that HAS a ~/.config it would
    resolve rather than raise -- which is the seam working, and exactly why the
    case has to name its own config directory to stay hermetic.
    """
    monkeypatch.setenv(ENV_VAR, "F:\\some\\where\\")
    assert get_root() == "F:/some/where"

    monkeypatch.delenv(ENV_VAR, raising=False)
    monkeypatch.setenv(ENV_CONFIG_DIR, str(tmp_path))
    with pytest.raises(ValueError):
        get_root()


def test_report_returns_a_dataclass(tmp_path):
    write(tmp_path / "user_config.yml", f"{USER}:\n  datalib: F:/lib\n")
    res = resolve_root(user=USER, configdir=tmp_path, report=True)
    assert isinstance(res, RootResolution)
    assert res.source_file is not None
    # without report=True the bare path comes back, as callers expect
    bare = resolve_root(user=USER, configdir=tmp_path)
    assert isinstance(bare, Path)
