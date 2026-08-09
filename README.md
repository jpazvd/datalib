# DATALIB

**`datalib` treats survey microdata as a versioned asset** — the operational
equivalent, for household surveys, of what version control did for code.

Research teams treat code as a versioned asset: committed, reviewed,
integrity-checked, citable. Data rarely gets the same discipline — microdata
typically lives on a shared drive, in a folder named by whoever last copied it,
with a citation buried in an e-mail thread. Yet a nationally representative
survey costs millions of dollars to field, while a re-analysis costs orders of
magnitude less: the highest-leverage intervention in empirical research is not
collecting more surveys but **sustaining more analyses per survey**.

`datalib` makes that possible by encoding the archive discipline as executable
code rather than undocumented researcher conventions. It organizes microdata in
the **IHSN / World Bank Microdata Library** folder standard — original **MASTER**
files (`CCC_YYYY_SSSS_vNN_M`, immutable) kept strictly separate from
**HARMONIZED** adaptations (`..._vNN_A_CLCT`) — and provides a unified interface
to deposit, discover, load, and validate survey-versions across countries and
vintages, with DDI/Dublin Core metadata generated at deposit time.

`datalib` is **in production use at the World Bank and at UNICEF**, and is
published for everyone else: national statistical offices, ministries, research
institutes, and any agency standing up an archive of its own. Nothing in it is
specific to either organisation — the folder standard is IHSN's, the code reads
its paths from configuration, and the two deployments differ only in what they
put on disk. Treat it as a **worked example of how to build a microdata
archive** as much as a package to install: the conventions are the point, and
they are legible whether or not you run this code. It fits research labs,
statistical agencies, microdata custodians and multi-investigator teams alike —
anyone who believes data deserves the same versioned, auditable handling that
code already gets.

## Quick start

`datalib` organizes survey microdata in the **IHSN / World Bank Microdata Library**
folder taxonomy and gives you the same three verbs in **Stata, Python, and R** —
with identical option names and values:

| | get (load by coordinates) | put (deposit, IHSN-enforced) | check (validate archive) |
|---|---|---|---|
| **Stata** | `datalib, country(BRA) year(2019) survey(MICS) vm(v01) clear` | `_dtlb_put, country(BRA) year(2023) survey(SAEB)` | `_dtlb_check, path("$datalib")` |
| **Python** | `datalib.get(country="BRA", year=2019, survey="MICS")` | `datalib.put(df, country="BRA", year=2023, survey="SAEB")` | `datalib.check()` |
| **R** | `dl_get(country = "BRA", year = 2019, survey = "MICS")` | `dl_put(df, country = "BRA", year = 2023, survey = "SAEB")` | `dl_check()` |

`put` is where the standard is enforced: it builds the IHSN folder skeleton, writes
DDI-Codebook + Dublin Core + codebook metadata, keeps **MASTER** (original, immutable)
and **HARMONIZED** (adaptations) in separate version folders, and validates the result.

> **On the Stata `vm()` option.** The master vintage is required and must carry
> its `v` prefix: `vm(v01)`, not `vm(01)`. Omitting `vm()` builds a path with an
> empty version segment (`BRA_2015_PNAD__M`) and fails with `r(601)`; `latest`
> does **not** supply a default. Note this differs from `_dtlb_idno`, which
> normalises `1`, `01`, `v01` and `V01` to the same vintage. Pinned by checks
> V24/V25 in the acceptance test below.

**Install**

```stata
* Stata
net install datalib, from(https://raw.githubusercontent.com/jpazvd/datalib/main/)
```
```bash
# Python (from a clone)
pip install -e python/
```
```r
# R (from a clone; packaging in progress)
source("R/R/datalib.R")
```

**Point it at a library.** Every command reads a library root, resolved in this
order and without touching the disk:

| # | Stage | Stata | R / Python |
|---|---|---|---|
| 1 | argument | `root()` | `root=` |
| 2 | global | `${datalib}` | — |
| 3 | environment | `DATALIB_ROOT` | `DATALIB_ROOT` |
| 4 | generic config | `~/.config/user_config.yml` → `datalib:` | same |
| 5 | package config | `~/.config/datalib_config.yml` → `datalib:` | same |

The first non-empty candidate wins and is returned **as given** — a configured
archive that is momentarily unreachable fails when a file is opened, rather than
resolving somewhere else whose numbers will not reconcile.

```stata
. datalib_root, root(F:/datalib) set     // pin it for the session
. datalib_root                            // and ask where it came from
```

**A configuration file is optional, not a prerequisite.** Run
[`getuserconfig`](src/g/getuserconfig.ado) and, if you have no file, it prints
the exact path and the two lines it needs with your username already filled in.
Or have it write them:

```stata
. getuserconfig, create root(F:/datalib)   // writes ~/.config/user_config.yml
. getuserconfig, edit                      // opens it
```

`create` is additive: it appends your block if the file already serves other
operators, and it never rewrites a block that exists, so it cannot move a root
your pipelines depend on. Only the Stata leg writes; R and Python read the same
two files.

**No archive to hand?** Build a synthetic one — the package ships the recipe, not
the data:

```stata
. datalib_makelib, families(demo) path(mydemo)
. datalib_root, root(mydemo) set
```

**Learn by running:** self-contained, temp-folder-safe examples in
[`examples/`](examples/) — one per language. The full specification is in
[`00_documentation/taxonomy.md`](00_documentation/taxonomy.md).

## Verify your install

Four Stata suites and a cross-language release gate. **Invoke them from the repo
root** — note the acceptance suite then relocates Stata to a scratch directory
itself, which is deliberate and explained below.

| Suite | Invoke | Question it answers | Needs |
|---|---|---|---|
| [`qa/run_smoke.do`](qa/run_smoke.do) | the do-file directly | Is the **code** correct? | Stata 16+ |
| [`qa/verify_install.ps1`](qa/verify_install.ps1) | **the wrapper**, not the do-file | Does the **package a user receives** work? | Stata 16+, PowerShell |
| [`qa/test_checkers.do`](qa/test_checkers.do) | the do-file, repo root as argument | Do the folder-name checkers and the vintage builder still behave? | Stata 15+ |
| [`qa/test_config_seam.do`](qa/test_config_seam.do) | the do-file, repo root as argument | Does the library root resolve — and refuse — as specified? | Stata 15+ |
| [`scripts/verify.ps1`](scripts/verify.ps1) | the release gate | Version manifest, Python, R, and whether the Stata record is current | PowerShell, Python, R |

Use the wrapper for the acceptance suite. It creates the scratch working
directory, clears any previous install root, and reads the verdict back out of
the log. Running [`qa/verify_install.do`](qa/verify_install.do) by hand works
too, but only if you start Stata from a scratch directory and pass the repo
root as an argument — the do-file's header explains why.

```stata
* Unit suite — 48 checks, runs the _dtlb_* internals in place
"C:\Program Files\Stata17\StataMP-64.exe" -b do qa/run_smoke.do
```

```powershell
# Acceptance suite — installs the package, then uses it as a user would
powershell -File qa/verify_install.ps1
# or point it at a different Stata:
powershell -File qa/verify_install.ps1 -Stata "C:\Program Files\Stata18\StataSE-64.exe"
```

The two are **not** redundant. `run_smoke.do` adds `src/` to the adopath and
tests the internals where they sit; it proves the code is right but cannot see
packaging faults, because it never installs anything. `verify_install` performs
a real `net install` from `datalib.pkg` into a throwaway directory, redirects
`PLUS` and `PERSONAL` there so nothing resolves from your existing setup, and
then runs **only from that install** — exercising `datalib` itself, which the
unit suite never calls.

That distinction is not theoretical. The acceptance suite is what caught the
`catalogs.yaml` gap below, and an earlier draft of it silently passed by
resolving a *previously installed* copy of `datalib` from the real `PLUS`
rather than the package under test.

Expected results:

| Suite | Expected |
|---|---|
| `qa/run_smoke.do` | 48 pass, 0 fail |
| `qa/verify_install.ps1` | 41 pass, 0 fail |
| `qa/test_checkers.do` | 11 pass |
| `qa/test_config_seam.do` | 26 pass |
| `pytest python/tests` | 87 passed, 52 skipped |
| R `testthat` | 29 assertions |

Anything else is a regression.

The Python and R suites also run in CI ([`.github/workflows/tests.yml`](.github/workflows/tests.yml)) on Ubuntu and Windows. **The Stata suites cannot**: the runners have no licence, and batch Stata on Windows returns no usable exit code. They are a manual gate: run [`qa/run_tests.do`](qa/run_tests.do), which appends the result to [`qa/test_history.txt`](qa/test_history.txt). CI, the release workflow and `scripts/verify.ps1` all **fail** when the last recorded run is older than `VERSION`, is not `GATE GREEN`, or left a suite unfinished — rather than pretending they ran. See [`qa/TESTING_GUIDE.md`](qa/TESTING_GUIDE.md).

### Packaging non-obvious: shipping non-`.ado` files

If you add a data file to `datalib.pkg` — a registry, a schema, a lookup
table — use a **capital `F`**, not a lowercase `f`:

```text
f src/_/_dtlb_catalog.ado        <- code: lowercase f
F src/registry/catalogs.yaml     <- data: capital F
```

Lowercase `f` installs only extensions Stata recognises (`.ado`, `.sthlp`,
`.scheme`, `.style`). Everything else — `.yaml`, `.yml`, `.toml`, `.txt`,
`.dta` — is **silently discarded, while `net install` still returns `rc=0`**.
No error, no warning; the file simply never arrives. Capital `F` ships the
file whatever its extension, and it still lands in the letter-subdirectory
where `findfile` resolves it.

Both behaviours were verified with probe packages. This is the same approach
`wbopendata.pkg` uses for its four `_wbopendata_*.yaml` files.

The consequence of getting it wrong is quiet: `catalogs.yaml` was listed with
lowercase `f` and never shipped, so `_dtlb_catalogregistry`'s bundled offline
fallback had no file to find in an installed copy. `run_smoke.do` could not
see it, because it runs from the repo where the relative-path fallback
resolves. Check V2b of the acceptance suite now guards against a recurrence.

## Scripts

Shell scripts in `scripts/` automate common workflows. Run them from the repo root:

| Script                 | Purpose                                                  |
|------------------------|----------------------------------------------------------|
| `scripts/pull-data.sh` | Fetch the `.dta.zip` archives from the private LFS mirror and unzip them locally |
| `scripts/verify.ps1`   | Pre-release gate: version manifest, Python, R, and the Stata record |
| `scripts/verify_r.R`   | Runs the R suite and prints one machine-readable line (used by the gate and by CI) |

### Data setup (`pull-data.sh`)

Neither the `.dta` files nor the `.dta.zip` archives they come from are stored in this repository. The archives live in a **private Git LFS mirror** (see [Where the payloads live](#where-the-payloads-live) below); this script fetches them from there and unzips them locally. After cloning, or whenever the data files are missing or outdated:

```bash
bash scripts/pull-data.sh
```

This fetches the archives from the LFS mirror described below and unzips them into `01_data/011_stata/`. **Neither the `.dta` files nor the `.dta.zip` archives are tracked in this repository** — it carries code, documentation and history, and no microdata at all. The script keeps a cache clone (default `~/.datalib/archive-mirror`) so repeated runs cost one fetch rather than a full re-download, and it refuses to copy a file that is still an LFS pointer, because a 130-byte pointer landing where a dataset should be looks like success and reads like corruption.

### Where the payloads live

The `.dta.zip` archives are mirrored to a **private Gitea repository, `jpazvd/datalib-dev` on the CORISCO host**, which holds them in Git LFS. Paths match this repository exactly (`01_data/011_stata/…`), so a file can be located from either side.

The split is deliberate. These are survey microdata: large, and redistributable only under the producers' terms, so they do not belong in a repository that is mirrored publicly. GitHub stays canonical for code, documentation and history; the mirror keeps the payloads versioned and backed up rather than loose on a disk.

Nothing enforces the correspondence — the two repositories are linked by convention only, which is why it is written down here and in the mirror's own README. To fetch the data you need read access to that Gitea instance and `git-lfs` installed; `git clone` alone yields pointer files, and `git lfs pull` fetches the blobs.

## Provenance, and which way changes flow

There are two development repositories, and they are not copies of one another.

| | Repository | Holds |
|---|---|---|
| **Generic** | `jpazvd/datalib-dev` **on GitHub** → public mirror `jpazvd/datalib` | the package: the folder grammar, the resolver, the checkers, the three language legs |
| **Deployment** | `unicef-drp/datalib-unicef-dev` **on GitHub** | one organisation's configuration, drive topology and pipelines on top of it |

Both are code repositories on GitHub. The `jpazvd/datalib-dev` **on the CORISCO
Gitea host**, described under [Where the payloads live](#where-the-payloads-live),
is a third thing that happens to share this repository's name: it holds only the
data payloads in Git LFS and carries no code or history of its own.

**Generic work belongs here and flows down.** Anything that is true of an
archive regardless of who runs it — a folder rule, a resolution stage, a
checker, a bug fix — lands in this repository first. A deployment repository
carries only what is specific to it: which drives exist, which surveys are
acquired, which credentials apply.

Honest history, because the direction was not always this one. The
configuration seam that this package resolves roots with — and the golden cases
that pin it — was **built in the UNICEF deployment repository first and
backported here at v1.1.0**, from its v0.9.33.

| Language | Reads the config | Resolves the root |
|---|---|---|
| Stata | `getuserconfig`, `datalib_config` (alias) | `datalib_root` |
| R | `datalib_config()` | `datalib_root()` |
| Python | `getuserconfig()`, `datalib_config()` | `datalib_root()`, `resolve_root()` |

`datalib_config` and `datalib_root` are the pair that exists in all three, which
is what makes a script's intent portable between them. The extra names are each
leg's own idiom, not gaps: `resolve_root()` is Python-only and returns the
resolution as a value rather than reporting it.

The port was generalized on the way: the `Z:/`
default and the directory probe that went with it are deployment topology, not
contract, and a start-up that touches a network share blocks `stata -b`
outright when the share is slow or absent. Every ported file names its origin
in a provenance header, so the lineage is readable at the file rather than
inferred from this paragraph.

Public names were kept **verbatim** across the port — the same command names,
the same `source_stage` strings, the same case identifiers and path literals in
the conformance suites. That is what makes the two repositories' golden cases
diffable: a divergence shows up as a diff rather than as two suites that merely
look similar. The two repositories share ancestry on GitHub, but they are
reconciled by **content-level ports with provenance headers, never by merging
the fork pair**.

## Data workflow: datalib
The storage of data and other materials in Datalib is organized by country. One folder has been created for each country. The folder name is the ISO 3-letter code for each country, as spelled in the WDI and available through the wbopendata command in Stata3. As some datasets are multi-country, the following folders were also created:
* WLD: for datasets containing data from countries belonging to more than one region
* HLT: for datasets containing data from countries belonging to more than one country from HLT
If necessary, folders for other regions can be created here too. One folder will then be created for each survey. This folder name will be as follows:

CCC_YYYY_SSSS

where
* CCC = WDI country code (3 letters) (capitalized)
* YYYY = survey year (4 digits); we use the year when data collection started
* SSSS = survey acronym (e.g., MICS, DHS, LSMS, CWIQ, HBS, etc) (capitalized)

For instance, the folder for the HBS 2005 from Albania will be ALB_2005_HBS. For multi-country datasets, CCC will be WLD (World) or ECA.
One survey may have more than one version of the dataset. So under the survey folder, we will have as many sub-folders as we have versions. Even when we only have one version, we will create the sub-folder. The sub-folder name will identify the version.
The subfolder name will be as follows:

CCC_YYYY_SSSS_ vNN _M_vNN_A_HHHH

Where
* CCC = WDI country code (3 letters) (capitalized)
* YYYY = survey year; we use the year when data collection started
* SSSS = survey acronym (e.g., MICS, DHS, LSMS, CWIQ, HBS, etc) (capitalized)
* vNN_M = the “M” comes from Master file. The Master file is the full dataset, typically as provided by the country. vNN is the version name; NN is a sequential number; it will always start with 01 and when a newer version is available it should be named v02, then v03 etc. The description of the version will be found in the DDI metadata. Note that when a new version comes, the previous one(s) must be kept too.
* vNN_A_HHHH = “A” for Adaptations, and "CLCT" or “HHHH” for the name of the collection or adaptation. These are often subsets of the data, such as harmonized datasets; in our case, for now, the adaptions we have are ECAPOV, SILC and HOI. This part of the code will only appear when it’s not the original data, and it will be the name of the source folder where this data is being stored. The vNN follows the same rule as the numbering for original data, but this one refers for the version of the adaptation.
For instance, the harmonized dataset produced by PREM for the ECAPOV project using the Tajikistan Living Standards Survey of 2009 would be named “TJK_2009_TLSS_v01_M_v01_A_ECAPOV” (See figure 1). This sub-folder name is where we will store the Nesstar file (the Nesstar filename will be the same as the name of the folder), as well as the DDI and the Dublin Core XML files. All other materials (data in Stata or other format, documents, programs) will be stored in sub-folders as described below.

In the master version folder (in the case described, TJK_2009_TLSS_v01_M), we will create the following folders:

* “Data” to store the data files.
  * “Data\Original”: Under “Data” one sub-folder “Original” is created to store the dataset as received. This dataset will always be kept unchanged (i.e. in whatever format we receive it). If necessary, additional sub-folders can be created (for instance, if the original dataset is provided in multiple formats).
  * “Data\Stata”: For every survey, we will store the data in Stata format. This Stata files will be the ones obtained by exporting the microdata from the Nesstar file. The variable/value labels will thus be strictly identical to what we find in the Nesstar file.
  * “Data\Other”: Optionally, we can also save the data files in other formats (e.g., SPSS or ASCII). Again, this will have to correspond exactly to the data stored in the Nesstar file.

* “Doc” to store the document files.
  * “Doc\Questionnaires” to store all questionnaires (in PDF, XLS or other). Sub-folders can be created is needed.
  * “Doc\Reports” to store the survey reports (and related, such as PPT presentations, papers, briefs, etc). Sub-folders can be created is needed.
  * “Doc\Technical” to store all technical documents (code lists, interviewer’s manuals, sampling description, etc) and other materials such as photos, maps, etc. Sub-folders can be created is needed.

* “Programs” to store all programs: data entry, editing, tabulation, analysis. Sub-folders can be created if needed.
Note that all folders will be created, even if we do not have content for them (see Figure 2 for an example using Tajikistan 2009 TLSS).

How to name and organize the do files
For each country (CCC) and each year (YYYY), GMD generates up to four datasets starting from the original survey (see Annex I for further details) using the format:

CCC_YYYY_SurveyName_vnn_M_vmm_A_GMD_i 

where:
* vnn 		(nn=01, 02, … ) stands for the version of the master file;
* vmm 	(mm=01, 02, …) stands for the version of the harmonization, as there can be revisions after the first release;
* i	denotes the specific GMD dataset, and in particular: 
  * i=adult 	    Contains basic information collected for adults in the household;
  * i=children 	    Contains basic information collected for children in the household;
  * i=hhmembers 	Contains basic information collected for hhmembers in the household;
  * i=household 	Contains basic information collected for household;

