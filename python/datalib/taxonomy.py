"""datalib / IHSN taxonomy: names and path resolution (language-agnostic core).

Folder template (as built by _mkdir.ado / the IHSN & WB Microdata Library):

    <root>/<CCC>/<CCC_YYYY_SSSS>/<version>/Data/Stata/<version>[_<module>].dta

where <version> is one of
    CCC_YYYY_SSSS_vMM_M                 MASTER      (original data as provided)
    CCC_YYYY_SSSS_vMM_M_vAA_A_CLCT      HARMONIZED  (adaptation/collection CLCT)

The same rules are implemented identically in the Stata and R packages; this
module is the reference. See 00_documentation/taxonomy.md.
"""
import os
import re

ID_RE = re.compile(
    r"^(?P<ctry>[A-Za-z]{3})_(?P<year>\d{4})_(?P<svy>[A-Za-z0-9]+)"
    r"_v(?P<vm>\d+)_M(?:_v(?P<va>\d+)_A_(?P<clct>[A-Za-z0-9]+))?$"
)

# The vintage folder plan, plan "default". CANONICAL definition lives in
# config/folderplan.yml and is shared with the Stata and R legs;
# tests/test_folderplan.py asserts this copy equals it.
SKELETON = [
    "Data", "Data/Original", "Data/Stata", "Data/SPSS", "Data/R", "Data/Other",
    "Doc", "Doc/Questionnaires", "Doc/Reports", "Doc/Technical", "Programs",
]


def survey_id(country, year, survey):
    """CCC_YYYY_SSSS."""
    return f"{country.upper()}_{int(year):04d}_{survey.upper()}"


def version_name(country, year, survey, vm=1, collection=None, va=1):
    """Version-folder name. HARMONIZED iff ``collection`` is given, else MASTER."""
    base = f"{survey_id(country, year, survey)}_v{int(vm):02d}_M"
    if collection:
        return f"{base}_v{int(va):02d}_A_{collection.upper()}"
    return base


def parse_id(stem):
    """Parse a version-folder id -> dict, or None if it does not conform."""
    m = ID_RE.match(stem)
    if not m:
        return None
    d = m.groupdict()
    d["harmonized"] = d["clct"] is not None
    d["kind"] = "harmonized" if d["harmonized"] else "master"
    return d


def version_dir(root, country, year, survey, vm=1, collection=None, va=1):
    sid = survey_id(country, year, survey)
    ver = version_name(country, year, survey, vm, collection, va)
    return f"{root}/{country.upper()}/{sid}/{ver}"


def data_file(root, country, year, survey, module=None, vm=1, collection=None, va=1):
    """Full path to the Stata data file for a given version."""
    vdir = version_dir(root, country, year, survey, vm, collection, va)
    ver = os.path.basename(vdir)
    name = ver + (f"_{module}" if module else "") + ".dta"
    return f"{vdir}/Data/Stata/{name}"


def data_file_for(vdir, module=None):
    """Data file path for an explicit version folder (used with find_latest)."""
    ver = os.path.basename(vdir.rstrip("/"))
    name = ver + (f"_{module}" if module else "") + ".dta"
    return f"{vdir}/Data/Stata/{name}"


def find_latest_version(root, country, year, survey, collection=None):
    """Return the version-folder path with the highest vMM (and vAA if harmonized)."""
    sid = survey_id(country, year, survey)
    sdir = f"{root}/{country.upper()}/{sid}"
    if not os.path.isdir(sdir):
        return None
    best = None
    for name in os.listdir(sdir):
        info = parse_id(name)
        if not info:
            continue
        if collection:
            if not info["harmonized"] or info["clct"].upper() != collection.upper():
                continue
            key = (int(info["vm"]), int(info["va"]))
        else:
            if info["harmonized"]:
                continue
            key = (int(info["vm"]), 0)
        if best is None or key > best[0]:
            best = (key, f"{sdir}/{name}")
    return best[1] if best else None
