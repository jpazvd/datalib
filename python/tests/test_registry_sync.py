"""The two catalogs.yaml copies must not drift.

`stata/src/registry/catalogs.yaml` is the canonical registry that ships in the
package; `docs/catalogs.yaml` is the copy served over GitHub Pages that
`_dtlb_catalogregistry` fetches over the network. They are read by the same
parser, so a difference between them means an operator gets a different answer
depending on whether the network was reachable -- the worst kind of divergence,
because it is invisible until it matters.

PAYLOAD identity, not byte identity. The two files deliberately carry different
header comments: one describes itself as the canonical copy, the other as the
bundled offline fallback. Those comments are accurate and worth keeping, so the
check compares what the parser sees, not what the bytes say.
"""

from pathlib import Path

import pytest

yaml = pytest.importorskip("yaml")

ROOT = Path(__file__).resolve().parents[2]
CANONICAL = ROOT / "stata" / "src" / "registry" / "catalogs.yaml"
SERVED = ROOT / "docs" / "catalogs.yaml"


def strip_comments(path: Path):
    """Content lines only: no comments, no blank lines, no trailing spaces."""
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.split("#", 1)[0].rstrip()
        if stripped:
            out.append(stripped)
    return out


def require_both():
    """Skip where only one copy exists.

    The public mirror ships `src/` but not `docs/`, so the served copy is simply
    absent there and "the two agree" is not a claim that can be made. Skipping is
    right; asserting would fail the shipped suite on arrival for a condition the
    mirror cannot satisfy. In this repository both are present and the checks
    below run for real.
    """
    if not CANONICAL.is_file():
        pytest.skip("no canonical registry in this tree")
    if not SERVED.is_file():
        pytest.skip("no served copy in this tree (expected in the public mirror)")


def test_canonical_registry_exists():
    assert CANONICAL.is_file(), f"{CANONICAL} is missing"


def test_parsed_content_is_identical():
    require_both()
    a = yaml.safe_load(CANONICAL.read_text(encoding="utf-8"))
    b = yaml.safe_load(SERVED.read_text(encoding="utf-8"))
    assert a == b, (
        "stata/src/registry/catalogs.yaml and docs/catalogs.yaml parse differently. "
        "The served copy and the bundled fallback must describe the same "
        "catalogs, or the answer depends on whether the network was up."
    )


def test_content_lines_are_identical():
    """Catches drift the YAML parser would forgive.

    Key order, duplicate keys and formatting differences all survive
    `safe_load` comparison. Comparing comment-stripped lines catches an edit
    applied to one copy and not the other even when both still parse the same.
    """
    require_both()
    assert strip_comments(CANONICAL) == strip_comments(SERVED), (
        "the two catalogs.yaml copies differ outside their header comments"
    )
