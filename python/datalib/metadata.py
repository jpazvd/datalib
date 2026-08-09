"""datalib.metadata: IHSN DDI-Codebook 2.5 + Dublin Core + codebook.md generation.

Reads a Stata .dta via pyreadstat and writes, into the survey's version folder:
    <stem>.ddi.xml   DDI-Codebook 2.5
    <stem>.dc.xml    Dublin Core
    Doc/<stem>_codebook.md
The study id / kind (MASTER vs HARMONIZED) is read from the *version folder* name
so a per-module data file (<version>_<module>.dta) is handled correctly.
"""
import os
from datetime import date
import xml.etree.ElementTree as ET

import pyreadstat

from .taxonomy import parse_id

DDI_NS = "ddi:codebook:2_5"
DC_NS = "http://purl.org/dc/elements/1.1/"


def _sub(parent, tag, text=None, **attrs):
    el = ET.SubElement(parent, tag, {k: str(v) for k, v in attrs.items()})
    if text is not None:
        el.text = str(text)
    return el


def _version_dir_of(datapath):
    """.../<version>/Data/Stata/file.dta -> .../<version>"""
    return os.path.dirname(os.path.dirname(os.path.dirname(datapath.replace("\\", "/"))))


def write_metadata(datapath, producer="datalib", title=None):
    datapath = datapath.replace("\\", "/")
    vdir = _version_dir_of(datapath)
    info = parse_id(os.path.basename(vdir))
    if info is None:
        raise ValueError(f"not an IHSN version folder: {vdir}")

    stem = os.path.splitext(os.path.basename(datapath))[0]
    _, meta = pyreadstat.read_dta(datapath, metadataonly=True)
    title = title or f"{info['svy']} {info['year']}, {info['ctry']}"
    kind = "Harmonized" if info["harmonized"] else "Master"
    if info["harmonized"]:
        kind += f" (collection {info['clct']})"

    labels = dict(zip(meta.column_names, meta.column_labels or []))
    vtypes = getattr(meta, "readstat_variable_types", {}) or {}
    vallabs = getattr(meta, "variable_value_labels", {}) or {}
    nrows = getattr(meta, "number_rows", None)

    # ---- DDI-Codebook ----
    ET.register_namespace("", DDI_NS)
    cb = ET.Element(f"{{{DDI_NS}}}codeBook", version="2.5")
    std = _sub(cb, f"{{{DDI_NS}}}stdyDscr")
    cit = _sub(std, f"{{{DDI_NS}}}citation")
    ts = _sub(cit, f"{{{DDI_NS}}}titlStmt")
    _sub(ts, f"{{{DDI_NS}}}titl", title)
    _sub(ts, f"{{{DDI_NS}}}IDNo", os.path.basename(vdir))
    _sub(_sub(cit, f"{{{DDI_NS}}}prodStmt"), f"{{{DDI_NS}}}producer", producer)
    summ = _sub(_sub(std, f"{{{DDI_NS}}}stdyInfo"), f"{{{DDI_NS}}}sumDscr")
    _sub(summ, f"{{{DDI_NS}}}nation", info["ctry"])
    _sub(summ, f"{{{DDI_NS}}}collDate", info["year"], event="single")
    _sub(summ, f"{{{DDI_NS}}}dataKind", kind)
    fdsc = _sub(cb, f"{{{DDI_NS}}}fileDscr", ID="F1")
    ftxt = _sub(fdsc, f"{{{DDI_NS}}}fileTxt")
    _sub(ftxt, f"{{{DDI_NS}}}fileName", os.path.basename(datapath))
    dim = _sub(ftxt, f"{{{DDI_NS}}}dimensns")
    _sub(dim, f"{{{DDI_NS}}}caseQnty", nrows if nrows is not None else "")
    _sub(dim, f"{{{DDI_NS}}}varQnty", len(meta.column_names))
    ddsc = _sub(cb, f"{{{DDI_NS}}}dataDscr")
    for i, name in enumerate(meta.column_names, 1):
        is_str = "string" in str(vtypes.get(name, "")).lower()
        var = _sub(ddsc, f"{{{DDI_NS}}}var", ID=f"V{i}", name=name, files="F1",
                   intrvl="discrete" if (is_str or name in vallabs) else "contin")
        if labels.get(name):
            _sub(var, f"{{{DDI_NS}}}labl", labels[name])
        for val, lab in (vallabs.get(name) or {}).items():
            cat = _sub(var, f"{{{DDI_NS}}}catgry")
            _sub(cat, f"{{{DDI_NS}}}catValu", val)
            _sub(cat, f"{{{DDI_NS}}}labl", lab)
        _sub(var, f"{{{DDI_NS}}}varFormat", type="character" if is_str else "numeric")
    ET.indent(cb, space="  ")
    ddi_path = f"{vdir}/{stem}.ddi.xml"
    ET.ElementTree(cb).write(ddi_path, encoding="utf-8", xml_declaration=True)

    # ---- Dublin Core ----
    ET.register_namespace("dc", DC_NS)
    dc = ET.Element(f"{{{DC_NS}}}metadata")
    _sub(dc, f"{{{DC_NS}}}title", title)
    _sub(dc, f"{{{DC_NS}}}identifier", os.path.basename(vdir))
    _sub(dc, f"{{{DC_NS}}}type", "Dataset")
    _sub(dc, f"{{{DC_NS}}}coverage", info["ctry"])
    _sub(dc, f"{{{DC_NS}}}date", info["year"])
    _sub(dc, f"{{{DC_NS}}}publisher", producer)
    _sub(dc, f"{{{DC_NS}}}description", f"{kind} version {os.path.basename(vdir)}.")
    ET.indent(dc, space="  ")
    dc_path = f"{vdir}/{stem}.dc.xml"
    ET.ElementTree(dc).write(dc_path, encoding="utf-8", xml_declaration=True)

    # ---- codebook.md ----
    os.makedirs(f"{vdir}/Doc", exist_ok=True)
    lines = [
        f"# Codebook - {stem}", "",
        f"- **Kind:** {kind}",
        f"- **Country:** {info['ctry']} | **Year:** {info['year']} | **Survey:** {info['svy']}",
        f"- **Observations:** {nrows if nrows is not None else 'n/a'}"
        f" | **Variables:** {len(meta.column_names)}", "",
        "| # | Variable | Label | Type | Value labels |",
        "|---|----------|-------|------|--------------|",
    ]
    for i, name in enumerate(meta.column_names, 1):
        typ = "str" if "string" in str(vtypes.get(name, "")).lower() else "num"
        vl = vallabs.get(name) or {}
        vtxt = "; ".join(f"{k}={v}" for k, v in list(vl.items())[:6])
        lbl = (labels.get(name) or "").replace("|", "\\|")
        lines.append(f"| {i} | `{name}` | {lbl} | {typ} | {vtxt} |")
    cb_path = f"{vdir}/Doc/{stem}_codebook.md"
    with open(cb_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")

    return {"ddi": ddi_path, "dc": dc_path, "codebook": cb_path}
