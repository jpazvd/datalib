"""The committed demo fixture must match qa/fixtures/library/MANIFEST.txt exactly.

WHY THIS TEST EXISTS
--------------------
qa/test_det.do's header claimed the manifest was "an executable spec" that
"DET-01 asserts the builder still produces". It was not: MANIFEST.txt did not
exist, and DET-01 asserts vintage counts against a freshly built tree, never
the committed one. A drift check that nothing performs reads, in a diff, as
coverage -- which is worse than having no check at all.

It lives in pytest rather than in the Stata gate for one reason: CASE. Every
Stata suite runs on Windows, where the filesystem is case-insensitive, so
`XAA_2015_XHS_v01_M` and `xaa_2015_xhs_v01_m` both resolve and a case defect is
literally unobservable. Two conventions coexisted undetected for exactly that
reason. This test runs on Linux in CI and compares strings taken from the git
index -- not from the filesystem -- so it is case-exact on any platform.

Regenerate the manifest after changing the fixture:

    python python/tests/test_fixture_manifest.py --write
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
LIBRARY = "qa/fixtures/library"
MANIFEST = REPO / LIBRARY / "MANIFEST.txt"

#: Files legitimately living above the country/survey/vintage hierarchy.
ROOT_FILES = {".datalib"}

#: The vintage marker keeps a lower-case "v" for any number of digits.
VINTAGE_V = re.compile(r"_V(\d)")


def _tracked_paths() -> list[str]:
    """Paths git has recorded under the fixture, excluding the manifest itself.

    Read from the index, not the working tree: on a case-insensitive
    filesystem `os.listdir` reports whatever case the directory was first
    created with, which is the very thing that hid the original defect.
    """
    out = subprocess.check_output(
        ["git", "ls-files", "-z", LIBRARY], cwd=REPO, text=True
    )
    prefix = LIBRARY + "/"
    return sorted(
        p[len(prefix):]
        for p in out.split("\0")
        if p and p != f"{prefix}MANIFEST.txt"
    )


def _manifest_paths() -> list[str]:
    lines = MANIFEST.read_text(encoding="utf-8").splitlines()
    return sorted(
        line.strip()
        for line in lines
        if line.strip() and not line.lstrip().startswith("#")
    )


def test_manifest_exists() -> None:
    assert MANIFEST.is_file(), (
        f"{LIBRARY}/MANIFEST.txt is missing. It is referenced by "
        "qa/test_det.do, qa/README.md, qa/fixtures/README.md and .gitignore "
        "as the fixture's executable spec."
    )


def test_fixture_matches_manifest() -> None:
    """Exact set equality, case included."""
    tracked = _manifest_paths(), _tracked_paths()
    expected, actual = tracked

    missing = sorted(set(expected) - set(actual))
    extra = sorted(set(actual) - set(expected))

    # A pure case change shows up as one entry in each list. Call that out
    # explicitly: "missing X / extra x" is otherwise easy to misread as two
    # unrelated problems rather than one rename.
    case_only = sorted(
        (m, e)
        for m in missing
        for e in extra
        if m.lower() == e.lower()
    )

    detail = []
    if case_only:
        detail.append("CASE MISMATCH (manifest -> tracked):")
        detail += [f"  {m}\n  {e}" for m, e in case_only]
    plain_missing = [m for m in missing if not any(m == c[0] for c in case_only)]
    plain_extra = [e for e in extra if not any(e == c[1] for c in case_only)]
    if plain_missing:
        detail.append("IN MANIFEST BUT NOT TRACKED:")
        detail += [f"  {p}" for p in plain_missing]
    if plain_extra:
        detail.append("TRACKED BUT NOT IN MANIFEST:")
        detail += [f"  {p}" for p in plain_extra]

    assert not detail, (
        "the committed fixture has drifted from its manifest\n"
        + "\n".join(detail)
        + "\n\nIf the fixture change is intended, regenerate the manifest:\n"
        "  python python/tests/test_fixture_manifest.py --write"
    )


def test_naming_convention() -> None:
    """The three rules the checkers depend on, asserted rather than assumed."""
    offenders: list[str] = []
    for rel in _tracked_paths():
        parts = rel.split("/")

        # Only the library-root marker may be shallow. Anything else with
        # fewer than country/survey/vintage/... segments is a malformed
        # deposit, and must say so rather than raise IndexError on parts[2].
        if len(parts) < 4:
            if rel not in ROOT_FILES:
                offenders.append(f"{rel}  (too shallow: expected CCC/SURVEY/VINTAGE/...)")
            continue
        country, survey, vintage = parts[0], parts[1], parts[2]

        # Directory levels are canonical upper, except the vintage marker "v".
        # Normalise "_V<digit>" -> "_v<digit>": matching only "V0" would flag
        # a perfectly valid v10 vintage, and _dtlb_idno pads to exactly that
        # form ("output is always the padded lower-v form (v01, v10)").
        for level in (country, survey, vintage):
            if level != VINTAGE_V.sub(r"_v\1", level.upper()):
                offenders.append(f"{rel}  (directory not canonical: {level})")
                break

        # A dataset is named after its vintage, module token lower-case.
        name = parts[-1]
        if name.endswith(".dta") or (name.endswith(".do") and "Programs" in parts):
            stem = name.rsplit(".", 1)[0]
            if not stem.startswith(vintage):
                offenders.append(f"{rel}  (name does not start with '{vintage}')")
            else:
                module = stem[len(vintage):].lstrip("_")
                if module and module != module.lower():
                    offenders.append(f"{rel}  (module token not lower-case: {module})")

    assert not offenders, "fixture naming violations:\n" + "\n".join(
        f"  {o}" for o in sorted(set(offenders))
    )


def _write() -> None:
    body = "\n".join(_tracked_paths())
    text = MANIFEST.read_text(encoding="utf-8")
    header = "".join(
        line + "\n"
        for line in text.splitlines()
        if line.lstrip().startswith("#") or not line.strip()
    ).rstrip("\n")
    MANIFEST.write_text(header + "\n\n" + body + "\n", encoding="utf-8", newline="\n")
    print(f"rewrote {MANIFEST} ({len(_tracked_paths())} paths)")


if __name__ == "__main__":
    if "--write" in sys.argv:
        _write()
    else:
        print(__doc__)
