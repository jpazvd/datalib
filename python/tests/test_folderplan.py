"""One folder plan, held across all three languages.

``config/folderplan.yml`` is the canonical definition of what a vintage folder
contains. It is deliberately NOT read at runtime by any leg: ``config/`` is not
in ``datalib.pkg``, so an installed Stata user does not have it, and a creation
path should not depend on a YAML parse to know where to put a file. Each leg
carries a transcribed copy, and this module asserts the copies equal the YAML.

That is the same arrangement upstream uses for ``collections.yml`` -- canonical
file, bundled copy, equality test -- and it is what the six copies this
replaced did not have. They had already drifted in two ways that nothing could
catch:

  * ``datalib_makelib`` built no ``Data/Other``, while every other creator did
  * none of the six built ``Doc/Questionnaires``, ``Doc/Reports`` or
    ``Doc/Technical``, which Annex 1 of the ECAPOV Harmonization Guideline --
    the origin document for this convention -- specifies

A test that only checked the legs against each other would have passed on both.
Checking them against the *specification* is the point.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "python"))
PLAN = yaml.safe_load((ROOT / "config" / "folderplan.yml").read_text(encoding="utf-8"))


#: Read from the YAML rather than hard-coded, so a change to `default_plan`
#: cannot leave this suite passing while the legs build a different tree.
DEFAULT_PLAN: str = PLAN["default_plan"]


def expected(plan_name: str | None = None, kind: str = "master") -> list[str]:
    """The leaves the YAML specifies, parents first."""
    spec = PLAN["plans"][plan_name or DEFAULT_PLAN]
    if kind == "adaptation" and "adaptation" in spec:
        spec = {**spec, **spec["adaptation"]}
    out = ["Data"]
    out += [f"Data/{d}" for d in spec["data"]]
    out.append("Doc")
    out += [f"Doc/{d}" for d in spec["doc"]]
    out.append("Programs")
    return out


def test_the_declared_default_plan_exists() -> None:
    """default_plan must name a plan that is actually defined."""
    assert DEFAULT_PLAN in PLAN["plans"], (
        f"default_plan is {DEFAULT_PLAN!r}, which is not in plans: "
        f"{sorted(PLAN['plans'])}"
    )


def test_the_yaml_specifies_annex1_doc_subfolders() -> None:
    """The reason this file exists, asserted rather than assumed.

    Pinned deliberately: if someone trims the Doc/ leaves back out, the defect
    this whole change fixes returns silently, and every leg would still agree
    with every other leg.
    """
    doc = PLAN["plans"][DEFAULT_PLAN]["doc"]
    assert doc == ["Questionnaires", "Reports", "Technical"], doc
    assert PLAN["plans"]["ihsn2014"]["doc"] == ["Questionnaires", "Reports", "Technical"]


def test_structural_parents_are_never_plan_leaves() -> None:
    """Data/, Doc/ and Programs/ are structural; a plan names what goes under."""
    for name, spec in PLAN["plans"].items():
        leaves = list(spec["data"]) + list(spec["doc"])
        leaves += list(spec.get("adaptation", {}).get("data", []))
        leaves += list(spec.get("adaptation", {}).get("doc", []))
        for leaf in leaves:
            assert leaf not in PLAN["structural"], f"{name}: {leaf} is structural"
            assert "/" not in leaf and "\\" not in leaf and ".." not in leaf, (
                f"{name}: {leaf!r} is a path, not a leaf. The library root is "
                f"normally a network share, so a name carrying a path would "
                f"write outside the vintage folder."
            )


def test_python_copy_matches_the_yaml() -> None:
    from datalib.taxonomy import SKELETON

    assert list(SKELETON) == expected(), (
        f"python/datalib/taxonomy.py SKELETON != config/folderplan.yml\n"
        f"  python: {list(SKELETON)}\n"
        f"  yaml:   {expected()}"
    )


def test_r_copy_matches_the_yaml() -> None:
    text = (ROOT / "R" / "R" / "datalib.R").read_text(encoding="utf-8")
    m = re.search(r"DATALIB_SKELETON\s*<-\s*c\((.*?)\)", text, re.S)
    assert m, "DATALIB_SKELETON not found in R/R/datalib.R"
    got = re.findall(r'"([^"]+)"', m.group(1))
    assert got == expected(), (
        f"R/R/datalib.R DATALIB_SKELETON != config/folderplan.yml\n"
        f"  R:    {got}\n"
        f"  yaml: {expected()}"
    )


@pytest.mark.parametrize(
    "plan,kind",
    [("default", "master"), ("ihsn2014", "master"), ("ihsn2014", "adaptation"),
     ("minimal", "master")],
)
def test_stata_copy_matches_the_yaml(plan: str, kind: str) -> None:
    """_dtlb_folderplan.ado transcribes the YAML; check every branch of it.

    Parsed from the .ado's source rather than run, because the Stata leg has no
    CI licence -- the same reason test_surface.py checks Stata from Python.
    qa/test_det.do covers the live behaviour.
    """
    text = (ROOT / "stata" / "src" / "_" / "_dtlb_folderplan.ado").read_text(encoding="utf-8")

    # Each branch is `if ("`plan'"=="NAME") { local p_data "..." local p_doc "..." }`,
    # with the adaptation override nested inside the ihsn2014 branch.
    branch = re.search(
        rf'"`plan\'"=="{plan}"\)\s*\{{(.*?)\n    \}}', text, re.S
    )
    assert branch, f"no {plan} branch in _dtlb_folderplan.ado"
    body = branch.group(1)
    # The adaptation override is NESTED inside the plan branch, so a master
    # read must exclude it: taking the last `local p_data` in the whole branch
    # returned the adaptation's Data/Harmonized for ihsn2014/master.
    nested = re.search(r'"`kind\'"=="adaptation"\)\s*\{(.*?)\n        \}', body, re.S)
    if kind == "adaptation":
        if nested:
            body = nested.group(1)
    elif nested:
        body = body[: nested.start()] + body[nested.end():]

    def leaves(macro: str) -> list[str]:
        hits = re.findall(rf'local {macro}\s+"([^"]*)"', body)
        return hits[-1].split() if hits else []

    got = ["Data"] + [f"Data/{d}" for d in leaves("p_data")]
    got += ["Doc"] + [f"Doc/{d}" for d in leaves("p_doc")] + ["Programs"]
    assert got == expected(plan, kind), (
        f"_dtlb_folderplan.ado {plan}/{kind} != config/folderplan.yml\n"
        f"  stata: {got}\n"
        f"  yaml:  {expected(plan, kind)}"
    )


def test_no_leg_still_carries_its_own_copy() -> None:
    """The literal must not reappear beside the shared plan.

    Names the six sites that had one, so a reviewer can see the list shrink
    rather than take "converged" on trust.
    """
    converged = [
        "stata/src/_/_dtlb_mkdir.ado",
        "stata/src/_/_dtlb_put.ado",
        "stata/src/_/_dtlb_ipums_extract.ado",
        "stata/src/d/datalib_makelib.ado",
    ]
    offenders = []
    for rel in converged:
        text = (ROOT / rel).read_text(encoding="utf-8", errors="replace")
        # A creation literal is a mkdir naming a Data/ leaf. Path constructors
        # like `"`vdir'/Data/Stata/`fname'.dta"` are NOT plans and stay.
        for m in re.finditer(r"mkdir\s+\"[^\"]*/Data/(Original|Stata|Other)\"", text):
            offenders.append(f"{rel}: {m.group(0)}")
    assert not offenders, (
        "the folder-plan literal is back beside the shared plan:\n  "
        + "\n  ".join(offenders)
    )
