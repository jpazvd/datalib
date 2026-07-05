"""datalib access layer: get / put / check over the IHSN archive."""
import os
import re
import shutil

try:
    import pyreadstat
except ImportError:  # pragma: no cover
    pyreadstat = None

from . import taxonomy as tx
from .config import get_root


def _need_pyreadstat():
    if pyreadstat is None:
        raise ImportError("pyreadstat is required: pip install pyreadstat")


def _subdirs(path):
    return [d for d in os.listdir(path) if os.path.isdir(os.path.join(path, d))] \
        if os.path.isdir(path) else []


# --------------------------------------------------------------------------- get
def get(country, year, survey, module=None, collection=None,
        vm=1, va=1, latest=False, root=None, metadata=False):
    """Load a dataset from the datalib archive as a pandas DataFrame.

    MASTER by default; HARMONIZED when ``collection`` is given. With
    ``latest=True`` the highest available version is resolved automatically.
    Returns ``df`` (or ``(df, meta)`` when ``metadata=True``).
    """
    _need_pyreadstat()
    root = get_root(root)
    if latest:
        vdir = tx.find_latest_version(root, country, year, survey, collection)
        if vdir is None:
            raise FileNotFoundError(
                f"no {'harmonized ' + collection if collection else 'master'} version "
                f"for {tx.survey_id(country, year, survey)} under {root}")
        path = tx.data_file_for(vdir, module)
    else:
        path = tx.data_file(root, country, year, survey, module, vm, collection, va)
    if not os.path.isfile(path):
        raise FileNotFoundError(f"dataset not found: {path}")
    df, meta = pyreadstat.read_dta(path)
    return (df, meta) if metadata else df


# --------------------------------------------------------------------------- put
def put(data, country, year, survey, module=None, collection=None,
        vm=1, va=1, root=None, original=None, overwrite=False,
        ddi=True, strict=True, label=None,
        column_labels=None, value_labels=None):
    """Deposit a pandas DataFrame into the datalib archive, IHSN-compliant.

    - MASTER (no ``collection``): original data as provided - immutable once archived.
    - HARMONIZED (``collection=...``): an adaptation, written to its own sibling folder.

    Builds the IHSN skeleton, writes ``<version>[_<module>].dta``, optionally copies
    the raw ``original`` file into ``Data/Original`` (master only), generates DDI +
    Dublin Core + codebook, then validates conformance. Returns the written path.

    Guardrails: refuses to overwrite an already-archived file unless ``overwrite=True``
    (MASTER data is immutable - bump ``vm``/``va`` for a new version instead).
    """
    _need_pyreadstat()
    root = get_root(root)
    vdir = tx.version_dir(root, country, year, survey, vm, collection, va)
    ver = os.path.basename(vdir)

    # IHSN skeleton
    for sub in tx.SKELETON:
        os.makedirs(f"{vdir}/{sub}", exist_ok=True)

    name = ver + (f"_{module}" if module else "") + ".dta"
    target = f"{vdir}/Data/Stata/{name}"

    if os.path.exists(target) and not overwrite:
        kind = "HARMONIZED" if collection else "MASTER"
        raise FileExistsError(
            f"{kind} file already archived: {target}\n"
            f"  {kind} data is immutable - bump the version (vm=/va=) or pass overwrite=True.")

    pyreadstat.write_dta(data, target, file_label=label or ver,
                         column_labels=column_labels,
                         variable_value_labels=value_labels)

    # Preserve the raw original (master deposits only)
    if original and not collection and os.path.isfile(original):
        shutil.copy2(original, f"{vdir}/Data/Original/{os.path.basename(original)}")

    if ddi:
        from .metadata import write_metadata
        write_metadata(target)

    if strict:
        v = check(root=root, country=country,
                  survey=tx.survey_id(country, year, survey))
        if v:
            raise RuntimeError("IHSN conformance failed after put:\n  " + "\n  ".join(v))

    return target


# ------------------------------------------------------------------------- check
def check(root=None, country=None, survey=None):
    """Validate the archive; return a list of violation strings ([] == conformant).

    Enforces the IHSN skeleton and MASTER (_M) vs HARMONIZED (_A_) separation.
    Mirrors the Stata command ``_dtlb_check``.
    """
    root = get_root(root)
    viol = []
    countries = [country.upper()] if country else _subdirs(root)
    for c in countries:
        cdir = f"{root}/{c}"
        surveys = [survey] if survey else _subdirs(cdir)
        for s in surveys:
            sdir = f"{cdir}/{s}"
            if not os.path.isdir(sdir):
                continue
            if not re.match(r"^[A-Z]{3}_\d{4}_[A-Z0-9]+$", s.upper()):
                viol.append(f"{s}: survey name not CCC_YYYY_SSSS")
            has_master = False
            for v in _subdirs(sdir):
                vdir = f"{sdir}/{v}"
                info = tx.parse_id(v)
                if info is None:
                    viol.append(f"{s}/{v}: version name not IHSN-conformant")
                    continue
                if not info["harmonized"]:
                    has_master = True
                for sub in tx.SKELETON:
                    if not os.path.isdir(f"{vdir}/{sub}"):
                        viol.append(f"{s}/{v}: missing /{sub}")
                stata_dir = f"{vdir}/Data/Stata"
                if os.path.isdir(stata_dir):
                    for f in os.listdir(stata_dir):
                        if not f.lower().endswith(".dta"):
                            continue
                        has_a = "_a_" in f.lower()
                        if not info["harmonized"] and has_a:
                            viol.append(f"{s}/{v}: HARMONIZED (_A_) file in MASTER folder -> {f}")
                        if info["harmonized"] and not has_a:
                            viol.append(f"{s}/{v}: non-harmonized file in HARMONIZED folder -> {f}")
            if not has_master:
                viol.append(f"{s}: no MASTER (_M) version")
    return viol
