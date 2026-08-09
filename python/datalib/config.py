"""datalib configuration: resolve the curated archive root.

RESOLUTION is pure candidate selection, in this order, and touches no disk:

    argument -> DATALIB_ROOT -> config_generic -> config_package

The first non-empty candidate wins and is returned as given. It is never
probed for existence and never overridden by a later stage. That is the safety
property the whole seam is built around: an archive that is momentarily
unreachable -- a VPN down, a drive unmapped, a typo in the config -- comes back
as the operator's own path and fails at the file operation, rather than
silently resolving to a different library whose numbers will not reconcile.

The two configuration files are read block-by-block, never merged: the root
comes from the FIRST file whose block for this user carries a non-empty
``datalib`` key.

    ~/.config/user_config.yml      -> stage "config_generic"
    ~/.config/datalib_config.yml   -> stage "config_package"

Isolation hooks, so tests and scripts need not touch a real home directory:

    DATALIB_CONFIG      pin exactly one file; the fallback is off
    DATALIB_CONFIG_DIR  search the two-file list in another directory

The stage names are byte-identical across the Stata, R and Python legs. What
the three do NOT promise is an identical spelling of the path: Stata returns
the literal string, R normalises through ``fs::path_norm``, and this module
returns a ``Path``. The contract pins the resolved directory, not its bytes.
"""

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from .errors import (ConfigFileNotFound, DatalibError, DatalibRootNotSet,
                     UserBlockNotFound)

ENV_VAR = "DATALIB_ROOT"
ENV_CONFIG = "DATALIB_CONFIG"
ENV_CONFIG_DIR = "DATALIB_CONFIG_DIR"

GENERIC_FILE = "user_config.yml"
PACKAGE_FILE = "datalib_config.yml"

#: Keys read from a user block. Only ``datalib`` is meaningful to this package;
#: the rest are passed through so one file can serve sibling tools.
BLOCK_KEYS = ("githubFolder", "teamsRoot", "zDrive", "zDriveUNC", "datalib")


@dataclass(frozen=True)
class UserConfig:
    """One operator's block, as read from one file."""

    user: str
    file: Optional[Path] = None
    githubFolder: str = ""
    teamsRoot: str = ""
    zDrive: str = ""
    zDriveUNC: str = ""
    datalib: str = ""


@dataclass(frozen=True)
class RootResolution:
    """A resolved root and where it came from."""

    root: Optional[Path]
    source_stage: str
    source_file: Optional[Path] = None


def _home() -> Path:
    """The operator's home, USERPROFILE first so Windows agrees with Stata."""
    return Path(os.environ.get("USERPROFILE") or os.environ.get("HOME") or "~")


def _config_dir(configdir=None) -> Path:
    if configdir:
        return Path(configdir)
    env_dir = os.environ.get(ENV_CONFIG_DIR)
    if env_dir:
        return Path(env_dir)
    return _home() / ".config"


def _config_file_list(config=None, configdir=None):
    """The files to search, in order.

    ``config`` (or ``DATALIB_CONFIG``) pins a single file and turns the
    fallback off entirely -- that is what makes a golden case hermetic.
    """
    if config:
        return [Path(config)]
    env_file = os.environ.get(ENV_CONFIG)
    if env_file:
        return [Path(env_file)]
    base = _config_dir(configdir)
    return [base / GENERIC_FILE, base / PACKAGE_FILE]


def _stage_for(path) -> str:
    return "config_generic" if Path(path).name == GENERIC_FILE else "config_package"


def _parse(path: Path, user: str) -> Optional[UserConfig]:
    """Read one user's block from one file, or None if it has none."""
    try:
        import yaml
    except ImportError as exc:  # pragma: no cover - dependency is declared
        raise DatalibError(
            "pyyaml is required to read datalib configuration files"
        ) from exc

    try:
        text = path.read_text(encoding="utf-8-sig")  # tolerate a UTF-8 BOM
    except OSError:
        return None

    doc = yaml.safe_load(text) or {}
    if not isinstance(doc, dict):
        return None
    block = doc.get(user)
    if not isinstance(block, dict):
        return None

    values = {k: str(block.get(k) or "") for k in BLOCK_KEYS}
    return UserConfig(user=user, file=path, **values)


def getuserconfig(user=None, config=None, configdir=None) -> UserConfig:
    """Read this operator's configuration block.

    The full block comes from the first file that has one; the ``datalib`` key
    from the first file whose block carries a non-empty one. Those can be
    different files, which is the whole point of the two-file fallback.
    """
    user = user or os.environ.get("USERNAME") or os.environ.get("USER") or ""
    files = _config_file_list(config, configdir)

    seen_any = False
    block = None
    root, root_file = "", None

    for path in files:
        if not path.is_file():
            continue
        seen_any = True
        parsed = _parse(path, user)
        if parsed is None:
            continue
        if block is None:
            block = parsed
        if not root and parsed.datalib:
            root, root_file = parsed.datalib, path

    if not seen_any:
        raise ConfigFileNotFound(
            f"No configuration file found at: {files[0]}. "
            f"A template lives in the repository under config/{GENERIC_FILE}. "
            f"datalib does not require one: the root can also come from the "
            f"root argument or ${ENV_VAR}."
        )
    if block is None:
        raise UserBlockNotFound(
            f"Configuration found at {files[0]}, but it has no block for user "
            f"'{user}'."
        )

    if root and root_file is not None and root != block.datalib:
        # block and root came from different files: report the root's file
        block = UserConfig(
            user=block.user,
            file=root_file,
            githubFolder=block.githubFolder,
            teamsRoot=block.teamsRoot,
            zDrive=block.zDrive,
            zDriveUNC=block.zDriveUNC,
            datalib=root,
        )
    return block


def resolve_root(root=None, *, user=None, config=None, configdir=None,
                 report=False):
    """Resolve the library root. See the module docstring for the order."""
    if root:
        res = RootResolution(Path(root), "argument")
        return res if report else res.root

    env_root = os.environ.get(ENV_VAR)
    if env_root:
        res = RootResolution(Path(env_root), "env")
        return res if report else res.root

    try:
        block = getuserconfig(user=user, config=config, configdir=configdir)
    except (ConfigFileNotFound, UserBlockNotFound):
        block = None

    if block is not None and block.datalib:
        stage = _stage_for(block.file) if block.file else "config_generic"
        res = RootResolution(Path(block.datalib), stage, block.file)
        return res if report else res.root

    raise DatalibRootNotSet(
        f"datalib root not set; pass root=..., set ${ENV_VAR}, or add a "
        f"'datalib' key to your block in ~/.config/{GENERIC_FILE} "
        f"(template: config/{GENERIC_FILE})."
    )


# --- back-compatible surface -------------------------------------------------
def get_root(root=None):
    """Return the archive root as a forward-slashed string.

    Kept exactly as it behaved before the configuration seam -- same return
    shape, and ``DatalibRootNotSet`` still satisfies ``except ValueError`` --
    so existing callers are unaffected while gaining the config stages.
    """
    resolved = resolve_root(root)
    return str(resolved).replace("\\", "/").rstrip("/")


# the contract names, matching the R and Stata legs
datalib_config = getuserconfig
datalib_root = resolve_root
