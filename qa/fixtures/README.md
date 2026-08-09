# qa/fixtures

Synthetic `${datalib}` trees and HTTP goldens for testing. Nothing here
describes a real person, household, country or survey programme.

## What is here

| | | |
|---|---|---|
| `library/` | **committed** | a complete datalib library; the shared fixture most suites read |
| `api/` | **committed** | NADA API response goldens, read over `file://` |
| `spec.yaml` | committed | maps each API endpoint to its golden file |
| `_tmp_home*/` | generated | throwaway HOME directories for the config-seam suite |

## `library/` — the shared fixture

Generated once by

```stata
datalib_makelib, path(qa/fixtures/library) families(demo)
```

and committed, so a clean clone can run the gate with **no build step**. See
`library/MANIFEST.txt` for the full anatomy: what a country-year-survey looks
like on disk, the three naming rules every checker depends on, and the
`module_schema:` declarations that let `datalib` plan a merge from the data.

    XAA/xaa_2015_xhs      v01 master, v02 master, v01 adaptation (hcl)
    XAA/xaa_2021_xsa      1 master — the four-level school hierarchy
    XBB/xbb_2019_xhs      1 master
    QMA/qma_2014_xlf      1 master
    ZZA/zza_2022_xhs      v01 master, v01 adaptation (hcl)

    8 vintages = 6 masters + 2 adaptations; 5 carry datalib.yaml.

The shape exercises: several countries; master + adaptation pairs; a
multi-version master (`xaa_2015_xhs` has v01 and v02, so `latest` resolution
has a wrong answer available); mixed YAML availability, since `v02` and the
adaptations deliberately carry none, keeping the folder-name-parsing fallback
covered; and a genuine hierarchy, including the `teacher`/`student` sibling
pair that a merge planner has to refuse.

### The countries and surveys are fictional, deliberately

Codes come from ISO 3166-1's four permanently *user-assigned* alpha-3 ranges
(`AAA–AAZ`, `QMA–QZZ`, `XAA–XZZ`, `ZZA–ZZZ`) — the three-letter shape every
checker expects, with collision against a real country impossible.

    XAA Arcadia   XBB Borduria   QMA Ruritania   ZZA Syldavia
    XHS household survey   XSA school assessment   XLF labour force survey

An earlier fixture used BRA PNAD, ETH MICS/DHS and COL. Real names on invented
numbers invite exactly one mistake: someone quoting a figure from a test
fixture as though it described Brazil.

## Retired: `build.sh` and `_tmp_datalib`

`qa/fixtures/build.sh` used to generate an uncommitted `_tmp_datalib/` tree,
and `test_catalog.do` read it. Both are gone. Two reasons:

1. It created directories named after real countries holding invented numbers.
2. It could not run where the gate runs. `bash` is not on the PATH that Stata's
   `shell` inherits on Windows — even though `git` is — so `test_catalog`
   reported **SKIPPED** on the only platform the gate executes on. Its
   assertions were therefore untested as well as wrong.

`datalib_makelib, families(qa)` supersedes it for anything needing a larger
tree: a 3 × 2 × 2 factorial with two master and two adaptation vintages per
cell (48 vintages), where every dimension has at least two members so "latest"
has a wrong answer available. `qa/test_det.do` builds that tree itself.

## Running against the fixture

```stata
. global datalib "qa/fixtures/library"
. _dtlb_catalog, scan
. _dtlb_catalog, list country(XAA)
```

`qa/test_catalog.do` is the suite that exercises it.

## Why `library/` is committed when `.dta` files normally are not

A pre-commit hook in the development repository requires `.dta` files to be
`.dta.zip`, because real microdata must not be tracked. (The hook itself is
not part of the published package.) This fixture is exempt
by design: every byte of it is generated from a pinned seed, it totals ~350 KB,
and it is reproducible by re-running the command above. A fixture that must be
built before the suites work is a fixture the suites skip.
