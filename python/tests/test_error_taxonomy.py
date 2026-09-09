"""Every error code the package exits with is a declared one.

``config/error_taxonomy.csv`` is ported from unicef-drp/datalib-unicef-dev
``tests/error_taxonomy.csv`` and extended with the codes this repository
actually uses. It names each return code, says what it means, and gives the R
condition classes and Python exception the other legs raise for the same
condition -- so "the same failure" is a checkable claim across three languages
rather than three independent conventions that happen to agree today.

WHAT THIS ENFORCES, AND WHAT IT CANNOT

Enforced: every literal ``exit <n>`` in ``src/`` uses a code the taxonomy
declares. That catches a new code invented in passing, which is how a
vocabulary of five becomes a vocabulary of twelve nobody can list.

Not enforced: that each site picks the RIGHT code. 198 covers 159 of the 200-odd
exits here, and some of those are surely "not found" or "would clobber" wearing
198's clothes. Narrowing them is a reading task, not a test, and it is worth
doing separately -- a caller cannot branch on a code that means seven things.

The vendored ``src/y`` tree is exempt: its codes belong to jpazvd/yaml, and
this package does not get to redefine another package's error contract by
vendoring it.
"""

from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TAXONOMY = ROOT / "config" / "error_taxonomy.csv"

#: Not an error: `exit 0` is a normal early return, and Stata treats a bare
#: `exit` the same way.
NOT_AN_ERROR = {0}


#: How a code comes to be raised. `exit` is our own code raising the condition;
#: `propagated` is a Stata built-in raising it on our behalf -- `use` without
#: `clear` giving rc 4. `both` is a condition Stata raises AND we pre-empt with
#: our own check, which is rc 4's real situation: `datalib_index` refuses before
#: touching memory so the message can name the option that fixes it.
#:
#: The distinction decides which way a code is checked, so it is not decoration:
#: `exit` and `both` must have a literal site a grep can find, `propagated` must
#: NOT have one.
SOURCES = {"exit", "propagated", "both"}
RAISED_HERE = {"exit", "both"}


def declared_codes(sources: set[str] | None = None) -> dict[int, str]:
    """Declared codes, optionally only those raised in the declared ways."""
    out: dict[int, str] = {}
    with TAXONOMY.open(encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            if sources is not None and row["source"].strip() not in sources:
                continue
            for tok in row["stata_rc"].split():
                out[int(tok)] = row["error_name"]
    return out


def exits_in_src() -> dict[int, list[str]]:
    """Every literal `exit <n>` outside the vendored tree, by code."""
    found: dict[int, list[str]] = {}
    for p in sorted(ROOT.glob("stata/src/*/*.ado")):
        if p.parent.name == "y":          # vendored yaml: not our contract
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        for i, line in enumerate(text.splitlines(), 1):
            # Comment lines do not raise anything. Stata comments open with *
            # (or *! for a stamp) and //, and this package's headers discuss
            # exit codes in prose constantly -- _dtlb_ipums_api_read documents
            # its own contract that way. Counting those would invent uses, and
            # an invented use silently satisfies the unused-code test for a
            # code nothing actually raises. (Copilot, PR #99.)
            stripped = line.lstrip()
            if stripped.startswith(("*", "//")):
                continue
            m = re.search(r"\bexit\s+(\d+)\b", line)
            if m:
                found.setdefault(int(m.group(1)), []).append(f"{p.name}:{i}")
    return found


def test_every_exit_code_is_declared() -> None:
    declared = declared_codes()
    used = exits_in_src()
    undeclared = {
        code: sites
        for code, sites in used.items()
        if code not in declared and code not in NOT_AN_ERROR
    }
    assert not undeclared, (
        "return code(s) used in src/ but absent from config/error_taxonomy.csv:\n"
        + "\n".join(
            f"  exit {c}  at {', '.join(s[:3])}{' ...' if len(s) > 3 else ''}"
            for c, s in sorted(undeclared.items())
        )
        + "\nAdd it to the taxonomy with a name and a meaning, or use an existing code."
    )


def test_taxonomy_declares_nothing_unused() -> None:
    """A declared code with no site is a contract nobody honours.

    A warning in prose, an assertion here: the taxonomy is meant to describe
    this package, and an entry that no longer fires should be deleted rather
    than left to suggest a behaviour that no longer exists.
    """
    declared = declared_codes(RAISED_HERE)
    used = set(exits_in_src())
    # Only codes we raise ourselves are expected to have a literal site. A
    # purely `propagated` one is raised by a Stata built-in on our behalf and no
    # grep of ours will find it, which is exactly why it has to be declared
    # rather than discovered.
    unused = sorted(c for c in declared if c not in used)
    assert not unused, (
        f"code(s) declared in config/error_taxonomy.csv that no .ado exits with: "
        f"{ {c: declared[c] for c in unused} }. Delete them, or wire them up."
    )


def test_propagated_codes_have_no_literal_site() -> None:
    """The converse check, and the one whose absence let a declaration rot.

    `propagated` buys an exemption from the check above -- "no literal site is
    expected here" -- so a code wearing that label while raising itself is a
    declaration nobody is checking. Exactly that happened: rc 4 was declared
    `propagated`, then `datalib_index` arrived with a literal `exit 4` and
    nothing objected, because the only test looked for MISSING sites and never
    for UNEXPECTED ones.

    An exemption has to be checked in both directions or it is just a hole.
    """
    declared = declared_codes({"propagated"})
    used = exits_in_src()
    surprises = {c: sorted(set(used[c])) for c in declared if c in used}
    assert not surprises, (
        f"code(s) declared 'propagated' in config/error_taxonomy.csv -- meaning a "
        f"Stata built-in raises them for us -- but raised literally in our own "
        f"code: { {declared[c]: v for c, v in surprises.items()} }. If we now "
        f"raise it ourselves too, the source is 'both'."
    )


def test_the_taxonomy_is_well_formed() -> None:
    with TAXONOMY.open(encoding="utf-8", newline="") as fh:
        rows = list(csv.DictReader(fh))
    assert rows, "error_taxonomy.csv is empty"
    for r in rows:
        assert r["error_name"], f"row with no error_name: {r}"
        assert r["stata_rc"].strip(), f"{r['error_name']}: no stata_rc"
        for tok in r["stata_rc"].split():
            assert tok.isdigit(), f"{r['error_name']}: non-numeric rc {tok!r}"
        assert r["source"].strip() in SOURCES, (
            f"{r['error_name']}: source must be 'exit' (our code raises it), "
            f"'propagated' (a Stata built-in raises it for us), or 'both' (a "
            f"built-in raises it and we also pre-empt it), got {r['source']!r}"
        )
        assert r["meaning"].strip(), (
            f"{r['error_name']}: no meaning. A code without one is a number, and "
            f"the point of the file is that a reader can tell them apart."
        )
    names = [r["error_name"] for r in rows]
    assert len(names) == len(set(names)), f"duplicate error_name in the taxonomy: {names}"
