"""The public surface is declared, and the declaration is enforced.

``config/surface.yml`` declares what exists: every option of every public
command and every documented helper, plus the R and Python columns and the
``source_stage`` vocabulary. This module enforces it.

**What is actually being enforced, and what is not.** The rule people want is
"a parameter may not be added until it is documented". That ordering cannot be
tested -- a test sees a snapshot of the tree, not its history. What is tested is
the equivalent invariant: *at every commit, the implemented surface equals the
declared surface*. Declaring first then becomes the only way to land code,
because anything else fails here.

**Why this exists, concretely.** The draft SJ article documented four `datalib`
options that do not exist, seven stored results that do not exist, and a
`map_folders` command that is in neither ``src/`` nor ``datalib.pkg``, while
thirteen real options and four real commands went undocumented. Nothing caught
it because nothing could: prose and ``syntax`` were compared by reading.

**Why Stata is enforced from Python.** The Stata leg has no CI licence, but
``.ado`` and ``.sthlp`` are plain text (see :mod:`_stata_parse`), so Stata's
surface can be checked on every push -- it is otherwise the only completely
unguarded surface in the repository. ``qa/test_help_examples.do`` adds the
complementary live check that documented *examples* still run.

**Comparison semantics differ by language, on purpose.** Stata option order does
not constrain callers, so Stata is compared as a **set**. R and Python match
positionally, so those are compared as **ordered lists**.

Ported from unicef-drp/datalib-unicef-dev @ 0.9.34 ``python/tests/test_surface.py``.
Adapted, not copied: the paths differ (``src/`` not ``stata/src/``), this package
has no subcommand dispatcher so the ``stata_subcommands`` tests do not port, and
three sections are added for surfaces upstream does not have -- the fifteen
``_dtlb_*`` helpers, the vendored ``yaml`` family, and ``ibge``.
"""

from __future__ import annotations

import inspect
import re
import sys
from pathlib import Path

import pytest
import yaml

from _stata_parse import ado_options

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "python"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import datalib as dl  # noqa: E402  (needs the sys.path line above)

SURFACE = yaml.safe_load((ROOT / "config" / "surface.yml").read_text(encoding="utf-8"))
COMMANDS: dict = SURFACE["commands"]
ALIASES: dict = SURFACE["aliases"]
ALIAS_OPTIONS: dict = SURFACE["alias_options"]
HELPERS: dict = SURFACE["helpers"]
PIPELINES: dict = SURFACE["pipelines"]
VENDORED: dict = SURFACE["vendored"]

#: Every Stata name with a declared option set, whatever section it lives in.
ALL_STATA: dict[str, list[str]] = {
    **{k: v["stata"] for k, v in COMMANDS.items()},
    **{k: v["stata"] for k, v in ALIAS_OPTIONS.items()},
    **{k: v["stata"] for k, v in PIPELINES.items()},
    **HELPERS,
    **VENDORED["yaml"]["commands"],
}

#: Public = anything without a leading underscore. This is what a user types.
#: `yaml` is public and declared, but is a dispatcher with no `syntax` line, so
#: it has no option set and is named separately rather than given an empty one --
#: an empty list would read as "this command takes no options", which is false.
DISPATCHERS = {"yaml"}
PUBLIC_STATA = {k for k in ALL_STATA if not k.startswith("_")} | DISPATCHERS


def _ado_path(command: str) -> Path:
    hits = list((ROOT / "stata" / "src").glob(f"*/{command}.ado"))
    assert len(hits) == 1, f"expected exactly one {command}.ado, found {hits}"
    return hits[0]


# ------------------------------------------------------- Stata: code == declared


@pytest.mark.parametrize("command", sorted(ALL_STATA))
def test_stata_options_match_the_declaration(command: str) -> None:
    """Every option in the .ado's syntax is declared, and vice versa.

    Set comparison: a Stata `syntax` declaration does not order its options.
    """
    parsed = ado_options(_ado_path(command))
    assert parsed is not None, f"{command}.ado has no syntax line to check"
    declared = set(ALL_STATA[command])
    undeclared = sorted(set(parsed) - declared)
    phantom = sorted(declared - set(parsed))
    assert not undeclared, (
        f"{command}: option(s) {undeclared} exist in the .ado but are NOT declared "
        f"in config/surface.yml. Declare them there first -- that is the point of "
        f"the file."
    )
    assert not phantom, (
        f"{command}: option(s) {phantom} are declared in config/surface.yml but do "
        f"not exist in the .ado. Either the option was removed and the declaration "
        f"was not, or it was never implemented."
    )


@pytest.mark.parametrize("command", sorted(ALL_STATA))
def test_declared_stata_options_are_mentioned_in_the_help(command: str) -> None:
    """Each declared option must appear in the command's help text.

    A *mention* check, deliberately weaker than the equality checks above. The
    help files use several conventions -- a formal ``{synopthdr}`` table in some,
    only the Syntax line in others -- and their prose legitimately names other
    commands' options, so demanding set equality against the markup produced
    false positives. The strict guarantee lives on ``surface.yml``, where it is
    reliable; this catches the case that actually harms a user: an option that
    exists and is documented nowhere.
    """
    if command in SURFACE.get("helpers_without_help", []):
        pytest.skip(f"{command} ships without a help page; declared exemption")

    pages = [_ado_path(command).with_suffix(".sthlp")]
    # A family documented on one collective page, declared as such. Upstream
    # does the same for its contract wrappers in datalib_api.sthlp.
    if command in VENDORED["yaml"]["commands"]:
        pages.append(ROOT / VENDORED["yaml"]["collective_help"])
    coll = SURFACE.get("collective_help") or {}
    if command in (coll.get("commands") or []):
        pages.append(ROOT / coll["page"])
    # An alias keeps its own help page, and that is where its options are
    # explained: datalib_config's configdir/edit live in getuserconfig.sthlp.
    # surface.yml declares the alias, so this is a stated relationship rather
    # than the test quietly widening its search until it passes.
    alias = ALIASES.get(command)
    if alias:
        pages.extend((ROOT / "stata" / "src").glob(f"*/{alias}.sthlp"))

    pages = [p for p in pages if p.is_file()]
    assert pages, f"{command} has no help page and no declared exemption"

    haystack: set[str] = set()
    for page in pages:
        haystack |= set(
            re.findall(r"[A-Za-z_][A-Za-z0-9_]*", page.read_text(encoding="utf-8").lower())
        )
    # Options whose documentation exists upstream but not in the copy vendored
    # here. Exempt by name, per command, so the list shrinks to nothing when the
    # vendored help is refreshed and cannot quietly absorb a new gap.
    known = set(VENDORED["yaml"].get("documented_upstream_only", {}).get(command, []))
    missing = sorted(
        o for o in ALL_STATA[command] if o.lower() not in haystack and o not in known
    )
    assert not missing, (
        f"{command}: declared option(s) {missing} are not mentioned anywhere in "
        f"the help text. Document them before shipping them."
    )


def test_every_public_ado_is_declared() -> None:
    """A new public command cannot appear without a surface.yml entry."""
    found = {
        p.stem for p in (ROOT / "stata" / "src").glob("*/*.ado") if not p.stem.startswith("_")
    }
    assert found == set(PUBLIC_STATA), (
        f"public .ado files and config/surface.yml disagree: "
        f"undeclared={sorted(found - set(PUBLIC_STATA))} "
        f"declared-but-absent={sorted(set(PUBLIC_STATA) - found)}"
    )


def test_every_stable_helper_is_declared() -> None:
    """The single-underscore layer is a promise; the double-underscore one is not.

    ``_dtlb_*`` is documented as "stable utilities that user code may call
    directly", so it is surface and is declared. ``__dtlb_*`` is documented as
    refactorable without notice, so declaring it would turn an explicit
    non-promise into a promise, and is deliberately not done.
    """
    found = {
        p.stem
        for p in (ROOT / "stata" / "src" / "_").glob("_dtlb_*.ado")
        if not p.stem.startswith("__")
    }
    assert found == set(HELPERS), (
        f"_dtlb_* helpers and config/surface.yml disagree: "
        f"undeclared={sorted(found - set(HELPERS))} "
        f"declared-but-absent={sorted(set(HELPERS) - found)}"
    )


def test_vendored_yaml_subcommands_match_the_commands() -> None:
    """`yaml <sub>` and `yaml_<sub>` are the same list, spelled two ways."""
    subs = set(VENDORED["yaml"]["subcommands"])
    cmds = {k[len("yaml_"):] for k in VENDORED["yaml"]["commands"]}
    assert subs == cmds, (
        f"yaml subcommands and yaml_* commands disagree: "
        f"only-subcommand={sorted(subs - cmds)} only-command={sorted(cmds - subs)}"
    )


# --------------------------------------------------- Python and R: code == declared


@pytest.mark.parametrize(
    "command", sorted(c for c in COMMANDS if COMMANDS[c]["python"])
)
def test_python_signature_matches_the_declaration(command: str) -> None:
    """Ordered: Python matches positionally.

    The Python leg does not carry the ``datalib`` name -- its load verb is
    ``datalib.get`` -- so the declaration is checked against the function the
    ``python_name`` mapping points at. That mapping is itself part of the
    divergence this file records.
    """
    name = {"datalib": "get"}.get(command, command)
    fn = getattr(dl, name, None)
    assert fn is not None, f"datalib.{name} is declared but not exported"
    actual = list(inspect.signature(fn).parameters)
    assert actual == COMMANDS[command]["python"], (
        f"{command} -> datalib.{name}: signature {actual} != declared "
        f"{COMMANDS[command]['python']}"
    )


def test_r_namespace_exports_the_declared_commands() -> None:
    """Every command with a non-empty R column must be exported from NAMESPACE."""
    ns = (ROOT / "R" / "NAMESPACE").read_text(encoding="utf-8")
    exported = set(re.findall(r"^export\(([^)]+)\)", ns, re.M))
    # datalib's R counterpart is dl_get, for the same reason as Python's get.
    wanted = {
        {"datalib": "dl_get"}.get(c, c)
        for c, v in COMMANDS.items()
        if v["r"]
    }
    missing = sorted(wanted - exported)
    assert not missing, f"declared in surface.yml but not exported from R: {missing}"


# ------------------------------------------------------- packaging and versions


def test_every_src_file_is_in_the_pkg_manifest() -> None:
    """net install ships only what datalib.pkg lists as an `f` entry."""
    pkg = (ROOT / "datalib.pkg").read_text(encoding="utf-8")
    listed = {
        Path(m.group(1).strip()).name for m in re.finditer(r"^[fF]\s+(.+)$", pkg, re.M)
    }
    on_disk = {
        p.name for p in (ROOT / "stata" / "src").glob("*/*") if p.suffix in {".ado", ".sthlp"}
    }
    # A file may be deliberately withheld from the manifest, but only if it
    # says so here with a reason. Silence is the failure this catches.
    withheld = set(SURFACE.get("not_shipped", {}))
    # Directories withheld wholesale carry their reason at directory level --
    # the vendored yaml tree, un-vendored from the package when it pushed the
    # file count past Stata's 100-file `net install` limit.
    withheld_dirs = set(SURFACE.get("not_shipped_dirs") or {})
    on_disk = {
        p.name for p in (ROOT / "stata" / "src").glob("*/*")
        if p.suffix in {".ado", ".sthlp"} and p.parent.name not in withheld_dirs
    }
    missing = sorted(on_disk - listed - withheld)
    assert not missing, (
        f"file(s) under src/ are not listed in datalib.pkg and would not be "
        f"installed: {missing}. If that is deliberate, declare it under "
        f"not_shipped in config/surface.yml with the reason."
    )
    stale = sorted(withheld & listed)
    assert not stale, (
        f"file(s) declared not_shipped in config/surface.yml ARE in datalib.pkg: "
        f"{stale}. Delete the declaration."
    )


def test_source_stages_are_documented_in_the_help() -> None:
    """datalib_root's provenance vocabulary is a documented return value."""
    page = (ROOT / "stata" / "src" / "d" / "datalib_root.sthlp").read_text(encoding="utf-8")
    missing = [s for s in SURFACE["source_stages"] if s not in page]
    assert not missing, (
        f"source_stage value(s) {missing} are declared but not named in "
        f"datalib_root.sthlp"
    )
