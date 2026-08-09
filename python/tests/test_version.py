"""The version manifest must agree across every surface that carries it.

VERSION at the repository root is the single source of truth. Six other files
repeat it, and a release where they disagree is worse than one where they are
all wrong together: an operator reading `datalib.ado`'s stamp, a `pip show`, and
`packageVersion("datalib")` would each get a different answer about what they
are running, and nothing would fail to tell them.
"""

import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
VERSION_FILE = ROOT / "VERSION"

SEMVER = re.compile(r"^\d+\.\d+\.\d+$")

#: (path, regex capturing the version) for every file that repeats VERSION.
SURFACES = [
    ("R/DESCRIPTION",             r"^Version:\s*(\S+)\s*$"),
    ("python/pyproject.toml",     r'^version\s*=\s*"([^"]+)"'),
    ("python/datalib/__init__.py", r'^__version__\s*=\s*"([^"]+)"'),
    ("src/d/datalib.ado",         r"^\*!\s*v(\d+\.\d+\.\d+)"),
    ("datalib.pkg",               r"^d\s+Version\s+(\S+)"),
    ("stata.toc",                 r"^d\s+Version\s+(\S+)"),
    # Not `^version:` alone -- that also matches `cff-version:`, which is the
    # schema version and never moves with a release.
    ("CITATION.cff",              r"^version:\s*['\"]?([^'\"\s]+)"),
]


def declared_version() -> str:
    assert VERSION_FILE.is_file(), "VERSION is missing at the repository root"
    return VERSION_FILE.read_text(encoding="utf-8").strip()


def test_version_file_is_semver():
    v = declared_version()
    assert SEMVER.match(v), f"VERSION must be MAJOR.MINOR.PATCH, got {v!r}"


@pytest.mark.parametrize("relpath,pattern", SURFACES,
                         ids=[s[0] for s in SURFACES])
def test_surface_matches_version_file(relpath, pattern):
    path = ROOT / relpath
    assert path.is_file(), f"{relpath} is missing"
    text = path.read_text(encoding="utf-8", errors="replace")
    m = re.search(pattern, text, flags=re.M)
    assert m, f"{relpath} carries no version matching {pattern!r}"
    assert m.group(1) == declared_version(), (
        f"{relpath} says {m.group(1)}, VERSION says {declared_version()}"
    )


def test_no_surface_is_silently_missing():
    """A file dropping its version line must fail loudly.

    The parametrised test above only checks files it is told about. This one
    guards the other direction: if someone removes the version line rather than
    changing it, the surface would simply stop being checked.
    """
    missing = []
    for relpath, pattern in SURFACES:
        text = (ROOT / relpath).read_text(encoding="utf-8", errors="replace")
        if not re.search(pattern, text, flags=re.M):
            missing.append(relpath)
    assert not missing, f"version line disappeared from: {missing}"
