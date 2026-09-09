"""Every `shell` invocation is declared, and the dangerous one is quoted per platform.

A `shell` line hands a string to the operating system's command interpreter. If
any part of that string came from outside the package -- a filename, an API
response, a user option -- then the interpreter's metacharacters are an
injection surface. This module keeps the list of such lines short and reviewed,
rather than discovered later by a user.

**Why this exists, concretely.** ``_dl_fileaction`` turns filenames into
clickable links, and its guard refused exactly one character, the double quote.
That guard was *correct*, and its header showed the work: it probed ``cmd``
against the real archive and established that ``&``, ``|``, ``>``, ``^`` and
``%`` are inert inside quotes, at a cost of 406 of 55,703 files. All true --
and all true only of ``cmd``. The same function's macOS and Linux branches built
``shell open "<path>"``, and POSIX ``sh`` expands ``$`` and backticks *inside*
double quotes. A file named ``$(id).csv`` in an archive would run ``id`` on
click. Nothing caught it because nothing looked: the helper shipped with no
behavioural test of any kind.

**What is enforced.** Two things, both cheap:

1. Every ``shell`` line in the shipped tree is named in :data:`DECLARED_SHELL_SITES`
   with the reason it is safe. A new one fails this module until someone writes
   that reason down, which is the point -- the review is forced at the moment the
   line is added, not at the moment it is exploited.
2. ``_dl_fileaction``'s POSIX branch single-quotes the path. This is the specific
   regression guard for the defect above: single quotes suppress every expansion,
   and the only character that escapes them is a single quote, which the branch
   refuses.

**Why a structural check rather than a behavioural one.** The branch is selected
by ``c(os)``, so on this Windows runner the POSIX path cannot execute at all --
and CI has no Stata licence in any case. Parsing the ``.ado`` is what is
available, and it is the same trade this repository already makes in
:mod:`test_surface` for the same reason.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]

#: Every `shell` invocation the package ships, and why each one is safe.
#:
#: Keyed by "<file>:<line>" is deliberately NOT done -- line numbers churn on
#: every edit above them, and a test that fails on unrelated edits gets
#: suppressed. Keyed by file, with the count, so moving a line is free and
#: ADDING one is not.
DECLARED_SHELL_SITES: dict[str, tuple[int, str]] = {
    "_dl_fileaction.ado": (
        2,
        "Hands a FILENAME to the OS opener, so the one site here that takes "
        "outside input. Guarded per platform: Windows double-quotes and refuses "
        'a double quote; POSIX single-quotes and refuses a single quote. See '
        "test_posix_branch_single_quotes_the_path below.",
    ),
    "__dtlb_api_read.ado": (
        1,
        "curl driven by a config FILE, precisely so that nothing user-controlled "
        "reaches the command line. Both paths on the line are Stata tempfiles.",
    ),
    "__dtlb_ipums_api_read.ado": (
        1,
        "Same config-file transport as __dtlb_api_read. Both paths are Stata "
        "tempfiles; the API key is written into the config, never argv.",
    ),
    "__dtlb_volstate.ado": (
        1,
        "`net use` with no arguments -- a fixed command with no interpolation. "
        "The only macro is a Stata tempfile for the redirect.",
    ),
}


def _shipped_ados() -> list[Path]:
    """Shipped .ado files, excluding the vendored yaml tree.

    `stata/src/y/` is vendored from another package and is not this package's
    contract to make claims about -- the same exclusion :mod:`test_error_taxonomy`
    makes, for the same reason.
    """
    return [p for p in sorted(ROOT.glob("stata/src/*/*.ado")) if p.parent.name != "y"]


def _shell_lines(path: Path) -> list[tuple[int, str]]:
    """Lines that actually invoke `shell`, ignoring comments and prose.

    Stata comments start with `*` at the top of a line or `//` anywhere, and
    this file's own headers discuss `shell` at length -- so a naive grep finds
    ten times more than exist.
    """
    out: list[tuple[int, str]] = []
    for i, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("*") or stripped.startswith("//"):
            continue
        code = line.split("//")[0]
        if re.search(r"(?<![A-Za-z_])shell(?![A-Za-z_])", code):
            out.append((i, stripped))
    return out


def test_every_shell_invocation_is_declared() -> None:
    """A `shell` line cannot be added without writing down why it is safe."""
    found = {p.name: len(sites) for p in _shipped_ados() if (sites := _shell_lines(p))}
    declared = {k: v[0] for k, v in DECLARED_SHELL_SITES.items()}

    undeclared = sorted(set(found) - set(declared))
    assert not undeclared, (
        f"file(s) invoke -shell- but are not declared in DECLARED_SHELL_SITES: "
        f"{undeclared}. Add an entry saying why the call is safe -- what part of "
        f"the string comes from outside the package, and what stops it reaching "
        f"the interpreter as syntax."
    )

    stale = sorted(set(declared) - set(found))
    assert not stale, (
        f"file(s) declared in DECLARED_SHELL_SITES no longer invoke -shell-: "
        f"{stale}. Delete the declaration."
    )

    miscounted = {
        name: (found[name], declared[name]) for name in found if found[name] != declared[name]
    }
    assert not miscounted, (
        f"-shell- invocation count changed (found, declared): {miscounted}. A new "
        f"call needs its own review; update the count once you have done it."
    )


@pytest.mark.parametrize("branch", ["windows", "posix"])
def test_fileaction_quotes_the_path_per_platform(branch: str) -> None:
    """The regression guard for the POSIX expansion defect.

    Windows gets double quotes because ``cmd`` has no single-quote semantics --
    it would pass the quotes through as part of the filename. POSIX gets single
    quotes because double quotes there do not stop ``$`` or backticks. Neither
    is a matter of taste, and swapping them silently reintroduces the defect.
    """
    text = (ROOT / "stata" / "src" / "_" / "_dl_fileaction.ado").read_text(encoding="utf-8")
    actions = [ln for _, ln in _shell_lines(ROOT / "stata" / "src" / "_" / "_dl_fileaction.ado")]
    assert len(actions) == 2, f"expected 2 shell actions in _dl_fileaction, got {actions}"

    if branch == "windows":
        win = [a for a in actions if "start" in a]
        assert len(win) == 1, f"no Windows -start- action found: {actions}"
        assert '"`fp\'"' in win[0], (
            f"the Windows action must DOUBLE-quote the path -- cmd passes single "
            f"quotes through as part of the filename: {win[0]}"
        )
        assert "char(34)" in text, (
            "the Windows branch double-quotes the path, so it must refuse a "
            "double quote -- that is the character that breaks out of it"
        )
    else:
        posix = [a for a in actions if "start" not in a]
        assert len(posix) == 1, f"no POSIX opener action found: {actions}"
        assert "'`fp''" in posix[0], (
            f"the POSIX action must SINGLE-quote the path. Double quotes do not "
            f"stop POSIX sh expanding $ or backticks, so a file named "
            f"$(id).csv would execute on click: {posix[0]}"
        )
        assert "char(39)" in text, (
            "the POSIX branch single-quotes the path, so it must refuse a single "
            "quote -- that is the only character that breaks out of it"
        )
