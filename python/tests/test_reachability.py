"""Every shipped .ado is reachable: a public command, or called by one.

THE QUESTION THIS ANSWERS

`net install` puts every file in `datalib.pkg` onto a user's ado-path. A file
that nothing calls and nobody can type is not neutral there -- it occupies a
name in the shared PLUS directory, `which` finds it, tab-completion offers it,
and a reader auditing what they installed has to work out what it is for.

So each shipped `.ado` must be one of:

  PUBLIC      declared in config/surface.yml (a command a user types)
  CALLED      named inside another shipped .ado
  DECLARED    listed in surface.yml's `unreachable:` with a reason

The third is not a loophole. A dispatcher's target, a command reached only
through `datalib , <option>`, or a routine invoked by a string built at
runtime are all genuinely unreachable by grep and genuinely fine -- but each
should say so once, by name, rather than the check being loosened until it
passes.

WHAT THIS DELIBERATELY DOES NOT DO

It does not parse Stata. A call is "the command name appears as a word in
another file", which over-approximates: a name in a comment counts. That
direction is the safe one -- it can only fail to flag something, never flag
something that is genuinely used. A stricter parser would need to model
`gettoken` dispatch, `capture noisily \`cmd'`, and names assembled from macros,
and would produce false alarms, which is how a check gets disabled.
"""

from __future__ import annotations

import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
SURFACE = yaml.safe_load((ROOT / "config" / "surface.yml").read_text(encoding="utf-8"))


def shipped_ados() -> dict[str, Path]:
    """Every .ado datalib.pkg actually installs, by command name."""
    pkg = (ROOT / "datalib.pkg").read_text(encoding="utf-8")
    out: dict[str, Path] = {}
    for m in re.finditer(r"^[fF]\s+(\S+\.ado)\s*$", pkg, re.M):
        p = ROOT / m.group(1)
        if p.is_file():
            out[p.stem] = p
    return out


def public_names() -> set[str]:
    names: set[str] = set()
    names |= set(SURFACE["commands"])
    names |= set(SURFACE.get("alias_options") or {})
    names |= set(SURFACE.get("aliases", {}).values())
    names |= set(SURFACE.get("helpers") or {})
    names |= set(SURFACE.get("pipelines") or {})
    vend = SURFACE.get("vendored", {}).get("yaml", {})
    names |= set(vend.get("commands") or {})
    names.add("yaml")
    return names


def test_every_shipped_ado_is_public_or_called() -> None:
    ados = shipped_ados()
    public = public_names()
    declared = set(SURFACE.get("unreachable") or {})

    # One pass over the corpus; a name "called" if it appears as a whole word in
    # any OTHER shipped file.
    corpus: dict[str, str] = {
        name: p.read_text(encoding="utf-8", errors="replace") for name, p in ados.items()
    }

    orphans = []
    for name in sorted(ados):
        if name in public or name in declared:
            continue
        called = any(
            re.search(rf"(?<![A-Za-z0-9_]){re.escape(name)}(?![A-Za-z0-9_])", text)
            for other, text in corpus.items()
            if other != name
        )
        if not called:
            orphans.append(name)

    assert not orphans, (
        "shipped .ado file(s) that are neither declared public nor called by any "
        f"other shipped file: {orphans}\n"
        "Each lands on a user's ado-path where nothing can reach it. Either wire "
        "it up, drop it from datalib.pkg, or declare it under `unreachable:` in "
        "config/surface.yml with the reason."
    )


def test_declared_unreachable_entries_are_still_shipped() -> None:
    """An exemption that outlives its file is a comment pretending to be a rule."""
    ados = shipped_ados()
    stale = sorted(n for n in (SURFACE.get("unreachable") or {}) if n not in ados)
    assert not stale, (
        f"declared unreachable in config/surface.yml but no longer shipped: {stale}. "
        f"Delete the declaration."
    )
