# datalib

Survey microdata as a versioned asset · command: `datalib` · Stata · Python · R

**`datalib` treats survey microdata the way version control treats code** —
committed, reviewed, integrity-checked, citable.

Research teams treat code as a versioned asset. Data rarely gets the same
discipline: microdata typically lives on a shared drive, in a folder named by
whoever last copied it, with its citation buried in an e-mail thread. Yet a
nationally representative survey costs millions of dollars to field while a
re-analysis costs orders of magnitude less, so the highest-leverage intervention
in empirical research is not collecting more surveys but **sustaining more
analyses per survey**.

`datalib` makes that possible by encoding the archive discipline as executable
code rather than undocumented convention. It organizes microdata in the
[IHSN](https://www.ihsn.org/) / World Bank Microdata Library folder standard —
original **master** vintages (`CCC_YYYY_SSSS_vNN_M`, immutable) kept strictly
separate from **harmonized adaptations** (`..._vNN_M_vMM_A_HHHH`) — and gives
one interface to deposit, discover, load and validate survey-versions across
countries and vintages.

`datalib` is **in production use at the World Bank and at UNICEF**, and is
published for everyone else: national statistical offices, ministries, research
institutes, and any agency standing up an archive of its own. Nothing in it is
specific to either organization — the folder standard is IHSN's, the code reads
its paths from configuration, and the two deployments differ only in what they
put on disk. Treat it as a **worked example of how to build a microdata
archive** as much as a package to install: the conventions are the point, and
they are legible whether or not you run this code.

## Contents

- [Quick start](#quick-start)
- [Point it at a library](#point-it-at-a-library)
- [Data organization convention](#data-organization-convention)
- [Verify your install](#verify-your-install)
- [Documentation](#documentation)
- [Which repository is canonical](#which-repository-is-canonical)
- [Citation](#citation)

## Quick start

The same three verbs in **Stata, Python and R**, with identical option names and
values:

| | get — load by coordinates | put — deposit, IHSN-enforced | check — validate an archive |
|---|---|---|---|
| **Stata** | `datalib, country(BRA) year(2019) survey(MICS) clear` | `_dtlb_put, country(BRA) year(2023) survey(SAEB)` | `_dtlb_check, path("$datalib")` |
| **Python** | `datalib.get(country="BRA", year=2019, survey="MICS")` | `datalib.put(df, country="BRA", year=2023, survey="SAEB")` | `datalib.check()` |
| **R** | `dl_get(country = "BRA", year = 2019, survey = "MICS")` | `dl_put(df, country = "BRA", year = 2023, survey = "SAEB")` | `dl_check()` |

`put` is where the standard is enforced: it builds the folder skeleton, keeps
master and harmonized vintages in separate folders, and validates the result.

**DDI-Codebook and Dublin Core are written at deposit time by the Python leg
only** (`put(..., ddi=True)`, on by default). The Stata and R deposits build the
tree and validate it, and write no metadata files. Closing that gap is tracked;
until it does, do not read the table above as three equivalent implementations
of the same deposit.

**Vintages.** `vm()` names the master vintage and `va()` the adaptation vintage.
All of `1`, `01`, `v01` and `V01` mean the same thing, as do `wrk`, `WRK`,
`vwrk` and `vWRK` for the working vintage. **Omit `vm()` and the latest vintage
loads and is announced**, so a log records which delivery produced the numbers.

**Install**

```stata
* Stata
net install datalib, from(https://raw.githubusercontent.com/jpazvd/datalib/main/)
```

`datalib` reads a vintage's `datalib.yaml` without help, but richer YAML
metadata in the catalog needs the `yaml` parser, which is an **optional
dependency** — install it if you want it:

```stata
net install yaml, from(https://raw.githubusercontent.com/jpazvd/yaml/main/)
```
```bash
# Python (from a clone)
pip install -e python/
```
```r
# R (from a clone; packaging in progress)
source("R/R/datalib.R")
```

**No archive to hand?** Build a synthetic one — the package ships the recipe,
not the data:

```stata
. datalib_makelib, families(demo) path(mydemo)
. datalib_root, root(mydemo) set
. datalib, country(XAA) year(2015) survey(XHS) clear
```

**Learn by running:** self-contained, temp-folder-safe examples in
[`examples/`](examples/) — one per language.

## Point it at a library

Every command reads a library root, resolved in this order and **without
touching the disk**:

| # | Stage | Stata | R / Python |
|---|---|---|---|
| 1 | argument | `root()`, or `library()` on `datalib` | `root=` |
| 2 | global | `${datalib}` | — |
| 3 | environment | `DATALIB_ROOT` | `DATALIB_ROOT` |
| 4 | generic config | `~/.config/user_config.yml` → `datalib:` | same |
| 5 | package config | `~/.config/datalib_config.yml` → `datalib:` | same |

The first non-empty candidate wins and is returned **as given**. A configured
archive that is momentarily unreachable therefore fails when a file is opened,
rather than resolving somewhere else whose numbers will not reconcile.

```stata
. datalib_root, root(F:/datalib) set     // pin it for the session
. datalib_root                           // and ask where it came from
```

**A configuration file is optional, not a prerequisite.** Run
[`getuserconfig`](stata/src/g/getuserconfig.ado) and, if you have no file, it prints
the exact path and the two lines it needs with your username already filled in.
Or have it write them:

```stata
. getuserconfig, create root(F:/datalib)   // writes ~/.config/user_config.yml
. getuserconfig, edit                      // opens it
```

`create` is additive: it appends your block if the file already serves other
operators, and never rewrites a block that exists, so it cannot move a root your
pipelines depend on. Only the Stata leg writes; R and Python read the same two
files.

## Data organization convention

Three words are used precisely throughout, and mean one thing each:

| term | what it names | example |
|---|---|---|
| **folder** | the three named levels of the tree | country folder, survey folder, vintage folder |
| **subfolder** | the fixed structure inside a vintage folder | `Data/Stata/`, `Doc/Reports/` |
| **filename** | anything that is not a folder | `TJK_2009_TLSS_v01_M_hl.dta` |

> The 2014 source note this convention comes from calls the *vintage* level a
> "sub-folder". This repository deliberately reserves **subfolder** for the
> `Data/`, `Doc/` and `Programs/` structure, and calls the version level a
> **vintage folder**.

```text
datalib/                                          # library root
└── CCC/                                          # country folder (ISO-3; also WLD, ECA)
    └── CCC_YYYY_SSSS/                            # survey folder (YYYY = year collection STARTED)
        ├── CCC_YYYY_SSSS_vNN_M/                  # master vintage folder (data as received)
        │   ├── Data/
        │   │   ├── Original/                     # raw, as received — NEVER modified
        │   │   ├── Stata/                        # .dta — what the loader reads
        │   │   ├── SPSS/                         # .sav
        │   │   ├── R/                            # .rds / .RData
        │   │   └── Other/                        # formats without a folder of their own
        │   ├── Doc/
        │   │   ├── Questionnaires/               # questionnaires (PDF, XLS, …)
        │   │   ├── Reports/                      # survey reports, papers, briefs
        │   │   └── Technical/                    # code lists, manuals, sampling, maps
        │   └── Programs/                         # entry, editing, tabulation, analysis
        │
        └── CCC_YYYY_SSSS_vNN_M_vMM_A_HHHH/       # adaptation vintage folder (harmonized)
            ├── Data/{Original,Stata,SPSS,R,Other}/
            ├── Doc/{Questionnaires,Reports,Technical}/
            └── Programs/
```

Every subfolder is created **even when it has no content** — an empty
`Doc/Technical/` asserts "we looked, there is none", which is information. The
plan is defined once, in [`config/folderplan.yml`](config/folderplan.yml), and
shared by all three languages; `_dtlb_folderplan` resolves it for the Stata leg.

### Naming the folders

**Survey folder** — `CCC_YYYY_SSSS`

- **CCC** ISO-3166 alpha-3 country code (`ZWE`, `ALB`, `TJK`; or `WLD` / a regional code)
- **YYYY** survey year, four digits — the year data collection *started*
- **SSSS** survey acronym (`MICS`, `DHS`, `LSMS`, `PNAD`, …)

**Master vintage folder** — `CCC_YYYY_SSSS_v01_M`

- `v01_M` version 01, **M** for master: the full dataset, typically as provided
  by the country
- Later versions are `v02_M`, `v03_M`, … Earlier versions are **kept, never
  replaced** — a published vintage is immutable.

**Adaptation vintage folder** — `CCC_YYYY_SSSS_v01_M_v01_A_HLT`

- **A** for adaptation, `HHHH` for the collection (`HLT`, `IPUMS`, `ECAPOV`,
  `GLAD`, …)
- The `vNN` *before* `_A` is the master it was built from; the one *after* is the
  adaptation's own version. Adaptation vintages are numbered **within** a
  master, so `v02_M_v01_A_HLT` is the first HLT built on master 2 and says
  nothing about HLT under master 1.

**Example** — `TJK_2009_TLSS_v01_M_v01_A_HLT` is the Tajikistan 2009 Living
Standards Survey, master v01, HLT adaptation v01.

The full specification is
[`00_documentation/taxonomy.md`](00_documentation/taxonomy.md).

## Verify your install

Eight Stata suites behind one runner, plus the cross-language legs. **Invoke
from the repository root.**

```stata
* Every suite; appends the result to qa/test_history.txt
. do qa/run_tests.do
```

```powershell
# Acceptance: installs the package, then uses it as a user would
powershell -File qa/verify_install.ps1
# or point it at a different Stata:
powershell -File qa/verify_install.ps1 -Stata "C:\Program Files\Stata18\StataSE-64.exe"
```

Expected, as of v1.11.0:

| Suite | Question it answers | Expected |
|---|---|---|
| `SMOKE` | Is the code correct? | 48 checks |
| `CHECKERS` | Do the folder-name checkers and vintage builder behave? | 11 |
| `CONFIG` | Does the library root resolve — and refuse — as specified? | 54 |
| `CATALOG` | Does the catalog frame build and filter? | 7 |
| `INSTALL` | Does the **package a user receives** work? | 41 |
| `DET` | Deterministic behavior over a synthetic library | 68 |
| `INT` | Does the vendored `yaml` coexist with a user's own? | 9 |
| `DOC` | Do the documented examples still run? | 3 |
| | **total** | **241, `GATE GREEN`** |
| `pytest python/tests` | | 214 passed, 26 skipped |

Anything else is a regression.

`SMOKE` and `INSTALL` are **not** redundant, and the difference is the point.
`run_smoke.do` adds `src/` to the adopath and tests the internals where they
sit: it proves the code is right but cannot see packaging faults, because it
never installs anything. `verify_install` performs a real `net install` from
`datalib.pkg` into a throwaway directory, redirects `PLUS` and `PERSONAL` there
so nothing resolves from your existing setup, and runs **only from that
install**.

That distinction is not theoretical. `INSTALL` is what caught a registry file
that was listed in the manifest in a way that silently discarded it, and — more
recently — a helper added to `src/` and never registered, which every other gate
passed while the installed package was broken.

The Python and R suites also run in CI
([`.github/workflows/tests.yml`](.github/workflows/tests.yml)) on Ubuntu and
Windows. **The Stata suites cannot**: the runners have no license, and batch
Stata on Windows returns no usable exit code. They are a manual gate whose
result is written to [`qa/test_history.txt`](qa/test_history.txt), and CI fails
when the last recorded run is older than `VERSION`, is not `GATE GREEN`, or left
a suite unfinished — rather than pretending it ran. See
[`qa/TESTING_GUIDE.md`](qa/TESTING_GUIDE.md).

## Documentation

| | |
|---|---|
| `help datalib` | the command surface, in Stata |
| [`00_documentation/taxonomy.md`](00_documentation/taxonomy.md) | the folder and naming specification |
| [`config/surface.yml`](config/surface.yml) | every option of every public command, in all three languages — machine-readable, and enforced by a test |
| [`config/folderplan.yml`](config/folderplan.yml) | what a vintage folder contains |
| [`examples/`](examples/) | runnable, one per language |
| [`CHANGELOG.md`](CHANGELOG.md) | what changed and why |

## Which repository is canonical

There are two development repositories, and they are not copies of one another.

| | Repository | Holds |
|---|---|---|
| **Generic** | `jpazvd/datalib-dev` → public mirror [`jpazvd/datalib`](https://github.com/jpazvd/datalib) | the package: the folder grammar, the resolver, the checkers, the three language legs |
| **Deployment** | `unicef-drp/datalib-unicef-dev` | one organization's configuration, drive topology and pipelines on top of it |

**Generic work belongs here and flows down.** Anything true of an archive
regardless of who runs it — a folder rule, a resolution stage, a checker, a bug
fix — lands here first. A deployment repository carries only what is specific to
it: which drives exist, which surveys are acquired, which credentials apply.

Public names are kept **verbatim** across ports, so the two repositories'
conformance cases stay diffable and a divergence shows up as a diff rather than
as two suites that merely look similar. Every ported file names its origin in a
provenance header.

## Citation

See [`CITATION.cff`](CITATION.cff). A draft design paper (Azevedo & Nguyen,
working draft) gives the full rationale.

## License

**MIT** — see [`LICENSE`](LICENSE). Copyright is held by João Pedro Azevedo and
Minh Cong Nguyen as individuals.

[`NOTICE`](NOTICE) states three things the license text itself does not:

- **No institutional endorsement.** This is not a product of, nor endorsed by,
  UNICEF or the World Bank Group. Affiliations shown anywhere in this repository
  are for identification only. That the software is used at those institutions
  is a fact about where it runs, not a claim of institutional backing.
- **Provided as is**, without warranty or support of any kind, and with no
  obligation to maintain, update or assist.
- **The license covers the software, not the data.** Survey microdata a user
  places into an archive built with this package belongs to the producers who
  collected it and keeps whatever terms they attach. This repository ships no
  real microdata — the only datasets in it are synthetic, generated from fixed
  distributions with a pinned seed.

`NOTICE` is separate rather than appended to `LICENSE` so the license stays
byte-standard MIT and automated detection recognizes it.
