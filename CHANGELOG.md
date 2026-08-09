# Changelog

All notable changes to **datalib** are documented in this file.
Format is based on [Keep a Changelog](https://keepachangelog.com/).
Commit hashes in the 2026-07-04 entry reference the mirror repo (jpazvd/datalib, branch `trip`), where that work was first committed before being ported here.

Entries are version-headed from v1.1.0 onwards; the date-headed entries below it are kept as they were written.

## v1.7.0 — 2026-08-08

One case, everywhere — and a fixture check that can actually fail.

### Fixed

- **Two folder-case conventions were coexisting undetected.**
  `datalib_makelib` created UPPER-case vintage directories
  (`XAA_2015_XHS_v01_M`) while `_dtlb_idno` reported lower-case ones
  (`xaa_2015_xhs_v01_m`) as `r(folder)`, and the committed demo fixture was
  lower-case because Windows preserves the case a path was first created
  with. Every suite passed, on both spellings, because the Stata gate runs
  only on Windows — where the filesystem is case-insensitive and the defect
  is literally unobservable.

  The on-disk form is now the canonical upper form throughout, identical to
  the NADA IDNo, so `r(folder) == r(idno)`. The case-translation seam
  (red-team item R-E) is retired: it described a translation that only one
  half of the package performed. `_dtlb_idno`'s parse mode still accepts
  either case, so archives laid out under the old convention keep resolving.

  Consequence for callers: `r(folder)` changes value. It is a single-
  underscore helper, but anything that hard-coded the lower-case form should
  be re-checked.

- **`qa/fixtures/library/MANIFEST.txt` did not exist.** Four files plus
  `.gitignore` referenced it, and `qa/test_det.do`'s header called it "an
  executable spec ... which DET-01 asserts the builder still produces".
  DET-01 asserts vintage counts against a freshly built factorial tree and
  never reads the committed one. A drift check that nothing performs reads
  as coverage in a diff, which is worse than no check.

  The manifest now exists and pins all 66 fixture paths, case included.

- **`qa/test_det.do`'s header contradicted itself**, calling the fixture
  "generated, never committed" eleven lines above DET-08, which tests "the
  COMMITTED example library". Rewritten to name the two distinct fixtures.

### Added

- **`python/tests/test_fixture_manifest.py`** — the drift check the old
  comment claimed. It compares the manifest against `git ls-files` rather
  than the filesystem, so it is case-exact on any platform, and it runs in
  pytest on Linux where a case regression is visible. Also asserts the three
  naming rules directly: canonical upper directories, dataset named after its
  vintage, module token lower-case. Verified to fail on a reintroduced
  lower-case path and pass when restored.

## v1.6.0 — 2026-08-08

A dead network drive no longer freezes Stata, and you can see which
configuration is in force.

### Fixed

- **An unreachable root no longer hangs the session.** `direxists()` on a
  disconnected share blocks on the OS, and root resolution walks several
  candidates — so one dead drive was not one pause but one *per candidate*,
  which is why Stata appeared frozen rather than slow. Observed with
  `${datalib}` set to `Z:/datalib` and the VPN down; a bare `ls` on the same
  share hung identically, so this is the operating system, not Stata.

  Stata cannot bound a filesystem call, so the first probe of a dead share
  still costs one OS timeout. What is fixed is everything after it:

  - **Per-volume memoisation.** A volume that fails once is skipped for the
    rest of the session, with a note saying so.
  - **`global datalib_offline 1`** skips any root not on the system drive
    *without touching it* — measured at 0.004s against a share that otherwise
    never returns.

### Added

- **`datalib_config, list`** reports every configuration source, which one is
  in force, and whether its root is reachable — using the memo rather than
  probing, so the command that explains a hang cannot itself hang. It also
  names the **package** answering to `datalib`: two installs can both provide
  the command and whichever is first on the adopath wins silently, which makes
  "which datalib am I running" as important as "which root".

## v1.5.0 — 2026-08-08

Modules describe their own structure, and `datalib` plans the join from that
description instead of from a hardcoded table.

### Added

- **`module_schema:` in `datalib.yaml`.** Each module declares its `level`,
  `keys`, `parent` and `parentkeys`. This is the AUTHORITY, and it is
  language-neutral, so the R and Python clients read the same declaration and
  the golden conformance cases stay comparable. The same fields are mirrored
  into `_dta` characteristics, which is what lets a `.dta` carried out of its
  folder still know how to be linked.
- **`_dtlb_modspec`** resolves a module's declaration through
  `yaml → char → legacy` and reports which stage answered, in `r(source)`. A
  resolver that will not say how it decided cannot be audited.
- **`_dtlb_mergeplan`** validates, orders and executes a multi-module join.
  Keys must exist as variables and must actually identify rows, checked
  against the data in hand — a declaration is a claim, not a fact.
- **`datalib_whence`** reports the provenance a dataset carries about itself.
  It also states, every time, what that provenance does *not* assert: chars
  record origin and survive `collapse`, so `datasignature` is the question to
  ask about values.
- **Hierarchical demo libraries.** `datalib_makelib, families(demo)` now builds
  a household survey (`household` + `roster`) and a four-level school
  assessment (`school` + `classroom` + `teacher` + `student`), from fictional
  countries in ISO 3166-1's user-assigned ranges.
- `r(mergeplan)`, `r(mergespec_source)`, `r(modules)`, `r(n_modules)`,
  `r(unmatched)`.

### Changed — behaviour

- **`module()` now defaults to every module of the vintage, joined.** It
  previously defaulted to a per-collection list that is empty for any master
  without a recognised collection, so a plain master load returned an **empty
  dataset with `rc 0` and no message**. That defect is why every example in the
  article named its module explicitly.
- **Unmatched rows are reported by name** — "42 row(s) in `roster` have no
  match in `household`" — rather than as a bare `_merge` tabulation. `strict`
  promotes it to an error.
- **Generated libraries deliver CSV first.** `Data/Original` holds the CSV
  delivery, `Programs/` holds a harmonization script **named after the file it
  generates**, and `Data/Stata` is that script's output. Adaptations carry no
  invented delivery: their input is the master, recorded in a `.provenance`
  file naming it.
- **Canonical case is uppercase except the survey module token**:
  `XAA_2015_XHS_v01_M_household.dta`.

### Fixed

- **A cross-platform break that Windows was hiding.** `_dtlb_load` built the
  path it loads with uppercase `_M`/`_A` literals while `_dtlb_catalog` skipped
  any survey folder that was not lowercase. The two only ever coexisted because
  Stata's `: dir` lowercases directory names on Windows and preserves them
  elsewhere — so on Linux or macOS one of them fails. Folder matching is now
  case-insensitive, which fixes the disagreement without making existing
  lowercase archives invisible.
- **Sibling levels are refused rather than multiplied.** `module(teacher
  student)` is many-to-many at `classroom`; joining it returns one row per pair,
  which looks exactly like data. It now errors, naming both modules and their
  common parent.

## v1.4.0 — 2026-08-06

`va()` becomes `vm()`'s equal, and the fixture bug that was hiding behind it.

### Added

- **`va()` resolves like `vm()`.** The adaptation vintage now defaults to the
  latest, accepts all four spellings (`1`, `01`, `v01`, `V01`), announces a
  choice made on the caller's behalf, and errors rather than building a path
  with an empty vintage slot. The two options sit on the same command: `vm(2)`
  resolved while `va(2)` did not, and a caller had no way to see why.
- **`r(adaptationvintage)` and `r(avintage_source)`**, symmetric with the master
  pair, so a script can branch on how the adaptation vintage was arrived at.
- **A named error for the working-vintage/adaptation interaction.** Adaptations
  are built off *published* masters, so a survey with a `vWRK` that is asked for
  an adaptation without an explicit `vm()` is requesting a folder that cannot
  exist. It now says that and lists the published masters, instead of failing
  with a bare "file not found".

### Fixed

- **`datalib_makelib` filled every adaptation vintage with the wrong filenames.**
  `_dl_mklib_vintage` parameterised the adaptation *directory* but hardcoded
  `v01` in the *file stem*, so a `v02` adaptation folder held files named
  `..._v01_a_...`. The directory appeared in `r(adaptationvintages)` while
  nothing in it could be loaded — and the checker asserting that list passed.
  This is the residue of the `_v01_a_` hardcoding that v1.3.0 only half fixed:
  the folder name was parameterised, the file name was not.

### Tests

- **DET-09a..h**, eight checks. They discriminate on *data*, not row counts:
  both adaptation vintages carry 120 household records, so N cannot tell them
  apart, but the vintages are seeded differently — `v01` sums `hh_size` to 556
  and `v02` to 541. A resolver returning the wrong vintage fails rather than
  passes quietly.
- **DET-09g** pins the fixture defect above: every adaptation file stem must
  match its folder. 24 directories checked.

## Unreleased

QA: one runner, an append-only record, and three rules that came from failures.

### Added

- **`qa/run_tests.do`** — the single entry point, with the house modes
  (`full` / `<SUITE>` / `LIST`) used by `yaml-dev`, `wbopendata-dev` and
  `unicefData-dev`. It **orchestrates the eight existing suites rather than
  inlining them**: datalib already holds ~190 checks written over a year, and
  rewriting working tests into a monolith to gain a file layout is the opposite
  of Gould's (2001) argument that tests are never thrown away.
- **`qa/test_history.txt`** — appended by the runner on every full run, with
  date, duration, branch, version, Stata flavour, per-suite results and verdict.
  Red and incomplete runs are recorded like any other.
- **`qa/_scanlog.do`** — the log reader, in Mata. A Stata log echoes the suite's
  own source, so a line containing the two characters `"'` closes the quote
  early and kills a macro-expanded parser with `too few quotes` (r 132). Mata
  reads the file as data, so no content can be mistaken for syntax.
- **`qa/TESTING_GUIDE.md`** — what each suite asks, the prerequisites, and why
  each rule below exists.

### Changed

- **`qa/stata-gate.txt` retired.** It was maintained by hand, and on 2026-08-06
  it recorded `test_checkers 11/11` for a run that never finished. Both
  workflows and `scripts/verify.ps1` now read the **last record** of the
  generated history, and additionally reject a run that is not `GATE GREEN`,
  that left `INSTALL` un-run, or that left any suite `incomplete`.
- **Every suite logs to `qa/logs/<suite>.log`.** They were split across three
  conventions, two of them CWD-relative, which is how a stale log from the
  previous day came to be reported as that day's result.
- **`INSTALL` is no longer invisible to the gate.** It launches its own Stata
  and cannot be `do`-ne, so the runner reads back its log and reports it as
  `external` — or `not-run`, which now blocks a release.

### Fixed

- **A QA run no longer inherits the operator's library.** The machine profile
  publishes `${datalib}` through `getuserconfig`; when that is a network share,
  `_dtlb_mkdir` probes it and blocks indefinitely. This is what made
  `test_checkers` look like a hang in code it never reached. The runner clears
  `${datalib}` for the run and restores it afterwards.
- **The fixture build now verifies its own result.** `shell` returns 0 whether
  or not the command it launched succeeded, so the first version reported
  success while creating nothing — `bash` is not on the PATH `shell` inherits on
  this machine, though `git` is. CATALOG is reported `SKIPPED`, with the command
  to run, rather than silently passed over.

### Known gaps

- `run_tests.do` cannot build the CATALOG fixtures where `bash` is unavailable
  to `shell`; it says so instead of failing quietly.
- The suites still keep their own `PASS:`/`FAIL:` conventions rather than a
  shared helper; the runner adapts to them. Unifying that is worth doing only if
  a suite is being rewritten anyway.

## v1.3.0 — 2026-08-06

Vintage resolution: a default, a working vintage, and a menu.

### Added

- **The working vintage, `vWRK`.** A folder named `<id>_vWRK_M` is the delivery
  **before a public release** — a real stage of the archive's lifecycle, not a
  scratch directory. Its precedence is deliberately asymmetric: it **wins the
  default** (asking for no particular vintage while a working copy exists almost
  always means you want it), but it **never overrides an explicit `vm()`**,
  because a pinned vintage is a reproducibility claim and silently substituting
  pre-release data would break the one promise the archive exists to keep. Pass
  the new **`wrk`** option to override deliberately. Loading it prints a louder
  notice than the numbered default, and `wrk` with no working vintage present is
  an error rather than a silent fall back.
- **`r(mastervintages)`, `r(adaptationvintages)`, `r(vintage)`,
  `r(vintage_source)`.** When a vintage is chosen *for* the caller, naming only
  the pick is half the story — you cannot tell whether it was the only option or
  one of five. The full menu is now returned, published deliveries and the
  working vintage together, and printed when there was a genuine choice.
- **One spelling rule for every vintage token**: `1`, `01`, `v01`, `V01` all mean
  `v01`; `wrk`, `WRK`, `vwrk`, `vWRK` all mean the working vintage. `_dtlb_idno`
  already accepted the numeric forms, so the two commands in the same package
  had disagreed about what a vintage looks like.
- **`qa/test_det.do` (DET, 29 checks)** and **`families(qa)`**, a complete
  factorial fixture — 3 countries x 2 years x 2 surveys, 2 master and 2
  adaptation vintages each, 48 vintages. `families(demo)` cannot support these
  tests: with one vintage present "latest" is right by default and a checker
  that returns the only item present passes whether or not it works.
- **`qa/test_help_examples.do` (DOC)** and **`qa/test_integration.do` (INT)**,
  adopting the QA families the sibling repositories already run.

### Fixed

- **`vm()` had no default at all.** Omitting it built a path with an empty
  vintage slot (`<ccc>_<yyyy>_<ssss>__M`) and could only fail with a bare "file
  not found" naming a directory that never existed. It now resolves to the
  latest vintage and says so.
- **`vm(01)` did not work either**: it built `..._01_M` against a folder named
  `..._v01_m`. `vm(v01)` was rejected outright with rc 100.
- **Every master load of a `household`- or `children`-named module failed with
  rc 100 after the data had already loaded.** `sort` ran against a key that is
  only defined for `HLT` and `DTZ` collections, so a master load reached it
  empty. The sibling blocks carried the equivalent guard; these two never did.
  Invisible until now because the missing `vm()` default failed first.
- **`_dl_mklib_survey` hardcoded `_v01_a_`**, so it could only ever build one
  adaptation vintage and `r(Anumvintages)` / `r(Alatestvintage)` were untestable
  by construction. New `adaptvintages()`, defaulting to `v01`.
- 24 help-file examples invoked the six **deprecated** command names scheduled
  for removal in v2.0 — half the clickable examples in the package taught
  commands we intend to delete.

### Known gaps

- `r(data<i>)` is not set on the `module()` path: the return sits in the
  `filename()` branch only, so the command's most obvious result is missing from
  its most common invocation.
- `va()` has none of the above — no default, no normalisation, no `wrk`
  handling.
- `_dtlb_put` advertises a `ddi` option its `syntax` does not have, and DDI /
  codebook generation exists only in the Python leg although `taxonomy.md`
  documents it as part of a deposit.

## v1.2.0 — 2026-08-06

`library()`: naming an archive on the command that reads it.

### Added

- **`datalib, library(`***path***`)`** names the archive for a call. It resolves
  through `datalib_root` in `find` mode, so a path that is not a library is
  refused up front with an actionable message rather than failing later as a bare
  *directory not found*, and it outranks `${datalib}`, `DATALIB_ROOT` and the
  configuration files.

  **Ported verbatim from `unicef-drp/datalib-unicef-dev` @ v0.9.33 (a66b6b6)**
  `stata/src/d/datalib.ado:123-157`, where the option already existed and worked.
  Verbatim because this package's naming rule is verbatim public names: a script
  written against either repository resolves its library the same way, and the two
  stay diffable. Upstream's neighbouring `explorer`/`update` options are *not*
  carried — they were out of scope for the v1.1.0 backport and nothing here needs
  them.

  Three properties came with the port that are easy to lose and silent when lost,
  so each is now pinned by a QA case (`qa/test_config_seam.do`, L1–L5):

  - The resolved root is **published to `${datalib}`**, deliberately. The clickable
    navigation links `_foldernav` writes carry no `library()` option, so the root
    has to persist or the next click would resolve somewhere else.
  - `datalib_root` is `rclass`, so resolving mid-command would wipe the click state
    the navigation carries in `r(subfoldr)`. The resolution is wrapped in
    `_return hold` / `_return restore`.
  - A validated library is **memoised** for the session, which keeps a slow network
    share off the critical path of every call; and a navigation click
    (`path()` + `subfoldr()`) does not re-resolve at all.

- **`datalib` now resolves the root itself** when nothing is configured. Calling it
  before setting `${datalib}` is no longer an error. This is what stops
  `datalib_root` being an orphan: before this release no `.ado` other than its own
  file ever called it, so its stage precedence, `find` validation and `require()`
  guard applied only if the operator invoked it by hand first.

### Changed

- `datalib.sthlp` documents `library()`, and states plainly what `path()` is: the
  **navigation-click base** that a generated link carries, not a way to override the
  archive root. The two coincide only on the first click from the top of a tree,
  which is why upstream added a second option rather than reusing `path()`.

## v1.1.0 — 2026-08-05

The configuration seam, a repository that carries no microdata, and the first CI.

### Added

- **A library-root resolver, in all three languages.** `datalib_root` /
  `resolve_root()` / `datalib_root()` resolve the root in a fixed order —
  argument, `${datalib}`, `DATALIB_ROOT`, then the `datalib:` key of
  `user_config.yml` and of `datalib_config.yml` — **without touching the disk**.
  The first non-empty candidate wins and is returned as given, so an archive
  that is momentarily unreachable fails at the file operation rather than
  resolving to a different library. `getuserconfig` / `datalib_config` read the
  two-file configuration; a configuration file is optional throughout.
  Backported from `unicef-drp/datalib-unicef-dev` @ v0.9.33 and generalized:
  no `Z:/` default and no directory probe of it, which is what made every Stata
  start-up touch a network share.
- **`getuserconfig, create` and `getuserconfig, edit`** (Stata only, ado v1.2.0)
  write the configuration file and open it. Both are additive: `create` writes
  `user_config.yml` when absent and appends the caller's block when that is what
  is missing, but never rewrites a block that already exists — so a second run
  cannot move a root that pipelines depend on, and it is safe in a start-up
  script. Without `root()` the `datalib:` key is written commented out rather
  than filled with a placeholder, because a path nobody chose would resolve
  happily and fail much later, at a `use`, as a missing file rather than as
  missing configuration. `edit` opens an existing file and never creates one;
  under `stata -b` it prints the path instead of opening a window. Neither
  touches `profile.do`. This is a reduced form of upstream's `init` / `profile` /
  `replace` / `edit` set: the destructive and machine-wide parts are left out.
- **Discovery, for the case where nothing is configured**: an eligible library
  near the working directory or in the operator's home, then a demo they have
  built. It is refused in batch runs, never fills `${datalib}`, and announces
  itself — a root nobody named must not arrive silently.
- **`datalib_makelib`** builds a complete synthetic library: the IHSN grammar,
  master and adaptation vintages, labelled datasets, `datalib.yaml` per vintage.
  `families()` reproduces the shapes this repository documents (`pnad`, `pnadc`,
  `saeb`, `mics`, `dhs`, and `demo`, which recreates the old example library
  exactly).
- **A version manifest.** `VERSION` is the single source of truth; seven other
  surfaces are checked against it by `python/tests/test_version.py`, including
  the new `CITATION.cff`.
- **The repository's first test CI** (`.github/workflows/tests.yml`): Python on
  Ubuntu and Windows × 3.10 and 3.12, R on both, plus the manifest guards and a
  job asserting the Stata gate record matches `VERSION`.
- **A per-file version-bump gate** (`.github/workflows/versioning-check.yml` +
  `scripts/check_versions.py`), adopted from `jpazvd/yaml-dev` and
  `jpazvd/wbopendata-dev` so the three repositories enforce one rule: a file you
  changed must carry a higher version than the base branch's copy. It is
  complementary to the manifest guards, which say nothing about whether an
  edited helper bumped its own stamp. Four adaptations were needed for this
  package's stamp and manifest formats; they are marked in the script.
- **A release gate.** `sync-to-public.yml` runs the manifest guards, checks that
  the tag is the version being shipped, and requires a green four-suite Stata
  record before publishing. `tests.yml` does not run on tags, so a tag push
  previously reached the public mirror with nothing having run on that ref.
- **`scripts/verify.ps1`**, the pre-release gate, and `qa/stata-gate.txt`, the
  record of the manual Stata runs that CI cannot perform.
- New Stata suites: `qa/test_checkers.do` (11) and `qa/test_config_seam.do` (40).
- **`CITATION.cff`**, so the public mirror renders a "Cite this repository"
  button and the citation version cannot drift from `VERSION`.

### Changed

- **This repository no longer contains microdata.** `examples/demo_library` is
  deleted — it is generated by `datalib_makelib, families(demo)`, which
  reproduces its inventory exactly — and the `.dta.zip` payloads under
  `01_data/011_stata` are untracked, living in a private Git LFS mirror that
  `scripts/pull-data.sh` fetches. A committed library could not have reached
  installed users anyway: `net install` places files in the PLUS tree by
  basename without preserving directories.
- **The package is named for what it is, not for one of its users.** `net install`
  announced "Access the UNICEF Microdata Library"; the Stata TOC, `datalib.pkg`,
  `R/DESCRIPTION` and `python/pyproject.toml` carried the same framing, and the
  language packages listed an institution as their author. The tool is in
  production at **both the World Bank and UNICEF** and is published for anyone
  else standing up an archive, so the metadata now says so and the packages are
  authored by people.
- **`python/datalib/metadata.py`'s DDI `producer` default is `"datalib"`**, was
  `"UNICEF datalib"`. Not cosmetic: that value is written into the metadata of
  every deposit made without an explicit `producer`, so the old default made
  each deposit assert an institution the depositor may have nothing to do with.
- **Minh Cong Nguyen (World Bank) added as co-author** across the package
  metadata, help files and citation record.
- `_foldernav` moved out of `_dtlb_load.ado` into its own file and is now in the
  package manifest. It had never shipped, so a clean install could not resolve
  the three calls `datalib` makes to it.
- Help files: `datalib.sthlp` now documents how the root is set, which it never
  did; 53 dead `{helpb}` links to pre-v1.0 names were repaired across 11 files;
  the read-only guard is documented on both write paths.

### Fixed

- `_dtlb_mkdir` built one of six sibling subfolders with the vintage marked `_A_`
  where `_M_` was meant, so `Data/Other` landed under a directory no resolver
  looks in.
- `_dtlb_svycheck`, `_dtlb_vcheck` and `_dtlb_adaptcheck` now normalise folder
  case before matching, and an adaptation name containing underscores yields its
  first token rather than the whole tail.
- `_foldernav`'s DATA, DOC and PROGRAMS sections no longer fall through into the
  generic navigation block, which emitted broken links for any subdirectory of
  `Doc/` or `Programs/`.
- `profile_datalib.do`: a dangling `else if`, and an unguarded `whereis github`
  that orphaned the following `else`.
- `qa/stata-gate.txt` was never tracked. Line 23 of `.gitignore` is a bare `*`
  and `qa/*.txt` was not allowlisted, so the record the release gate reads was a
  purely local artefact that no clone had.
## 2026-07-19

### Changed

- **Design-paper split into two self-contained folders** (executing the
  two-paper decision in `internal/paper_improvement_plan.md` §2.6 and
  `internal/paper2_multilang_plan.md`; combined `paper/` removed):
  - **`paper1_sj_stata/`** — the Stata Journal article. Trimmed to
    Stata-only per §2.6 Cuts A–D: `sec:platform` cut from 177 lines to a
    ~15-line companion-paper pointer (label kept — 14 inbound refs); the
    five forward-looking `[Planned]`/`[Background]` subsections
    (`sec:apifront`, `sec:wbrest`, `sec:nada`, `sec:dtlbrest`, `sec:audit`,
    327 lines) deleted and folded into the Roadmap; the six surviving
    inbound refs retargeted (two unrepointable clauses removed); software
    contribution 3 dropped (three→two, `\setcounter` fixed); abstract and
    keywords led Stata-first. 2,130 → 1,618 lines. No dangling refs — asserted
    by static validation when this was written, and since **confirmed by a real
    build**: TeX Live 2024, 32 pages, zero undefined references or citations.
    (The "no LaTeX toolchain here" note was wrong; TeX Live 2024 is installed.)
  - **`paper2_multilang/`** — the multi-language contract paper, as a
    **scaffold** (`datalib-contract.tex`) plus an **annotated outline**
    (`OUTLINE.md`): section-by-section arguments with an evidence ledger
    pinned to datalib-unicef v0.8.0, pre-drafted taxonomy/divergences
    tables, three recommended section additions (related work, worked
    example, limitations), the open-questions ledger, and a
    dependency-sorted writing order. The scaffold
    (`datalib-contract.tex`): framing, section skeleton, and
    the evidence inventory from the plan, with visible `\TODO{}` markers
    and `% TODO(datalib-unicef)` source comments wherever real material
    must be pulled from the deployment repo. Cites paper 1
    (`azevedo2026datalib`) for the convention; author block and host repo
    are deliberate placeholders (plan open questions 1–2 unresolved).
  - `.gitignore` whitelists both folders (the repo policy ignores
    `*.tex`/`.bib`/`.sty`/`.cls`/`.bst` outside a whitelisted paper dir);
    active `paper/…` references repointed at `paper1_sj_stata/…`
    (commit-pinned historical references left intact).

## 2026-07-18

### Added

- **`internal/datalib_multiprovider_plan.md`** — the MP plan: successor to
  the (now implemented) NADA-API plan, generalizing the `api://` read story
  into a provider-adapter architecture. Registry schema v2 (`adapter:`,
  `kind:`, `auth_env:`, `terms:`), a fixed adapter verb contract, and eight
  phases: MP-0 seam refactor, MP-1 Brazil dispatch unification (absorbs
  pipeline plan v1.1 — the Brazilian cases stay first-class in datalib-dev),
  MP-2 IPUMS extract lifecycle (IPUMS-International + IPUMS DHS), MP-3 DHS
  Program (ICF) discovery with honest gated-access hand-off, MP-4 NTLM /
  Windows-authenticated leg, MP-5 remote `api://` loads, MP-6 fixture and
  conformance expansion, MP-7 R/Python parity by contract (taxonomy.md
  extension + shared goldens). Stata-first throughout; ~28.5 person-days.
- **`internal/paper_improvement_plan.md`** — the design paper's improvement
  plan consolidated as a document (previously distributed across PR #12,
  `p0d_tracking.md`, and the paper's roadmap), with per-item status; the
  paper gained the §7.4 client-comparison table (`tab:nadaclients`) that
  closes PR #12's outstanding P2 item.
- **`examples/demo_library/`** — a committed five-survey demo archive
  (SYNTHETIC data + doc + code): BRA 2015 PNAD (v01/v02 masters + DTZ81
  adaptation), BRA 2021 SAEB, ZWE 2019 MICS (+ HLT adaptation), KEN 2014
  DHS, IND 2022 PLFS. 8 vintage folders, 13 labelled `.dta` files (~700 KB)
  with `data/original` CSV stand-ins, doc stubs, conversion programs, and
  `datalib.yaml` metadata incl. SHA-256 checksums; deterministic generator
  `build_demo.py` (a `SPEC` edit adds a survey). Wired into
  `qa/run_smoke.do` as checks S33–S36 (scan counts + YAML extraction);
  `.gitignore` whitelists the tree (plain `.dta` is not LFS-routed — only
  `*.dta.zip` is).

**NADA-API improvement plan v1 implemented** (NA-1 … NA-8 of
`internal/datalib_nada_improvement_plan.md`) — the read story of the `api://`
backend the design paper's §8.7 commits to, all against the plan's locked
decisions D-1 … D-5.

### Added

- **Multi-catalog registry (NA-1)** — `src/registry/catalogs.yaml` (bundled
  fallback, `wb` + `ihsn`) and the canonical `docs/catalogs.yaml` (to be
  served via GitHub Pages at `https://jpazvd.github.io/datalib-dev/catalogs.yaml`;
  enable in repo Settings → Pages → `main`/`docs`). New
  `_dtlb_catalogregistry` resolves user override → 24h cache → canonical
  fetch → bundled fallback, reports `r(source)`, validates `auth_type`
  fail-closed, and gates user-override auth entries behind one-time
  `acceptauth` consent logged to `~/.datalib/audit.log` (R-A, R-B).
- **Transport + auth split (NA-2, NA-7)** — `__dtlb_api_read` (GET over
  `file://` fixtures or `http(s)://`; auth-header dispatch happens in this
  one funnel: `x-api-key` → `X-API-KEY`, `bearer` → `Authorization: Bearer`;
  Stata ≥16 guard on the network path with a clear message; default UA
  `datalib/0.9 (Stata <v>)`, `user_agent(browser)` for WAF-blocked hosts —
  header-bearing calls shell out to curl, since pure-Stata `copy` cannot set
  request headers); `__dtlb_credential` (`DATALIB_TOKEN` env var →
  `${datalib_token}` global → clear 198); `__dtlb_userhome` (literal-string
  `c(os)` dispatch, `os()` test override — R-L).
- **Extensions probe (NA-3)** — `__dtlb_extensions_probe` (`GET <host>/info`;
  404 = "no extensions", never an error; session-cached). Named per the R-K
  mitigation: it is feature detection for datalib's own REST extras, not
  "capability negotiation" with upstream NADA.
- **IDNo funnel (NA-4)** — `_dtlb_idno`: bidirectional folder ↔ IDNo
  translation (build + parse, case-insensitive in, canonical out, vintage
  forms `1/01/v01/V01`), the single point of case translation (R-E).
- **REST catalog read (NA-5, NA-6)** — `_dtlb_catalog, list catalog(<short>)`
  populates the catalog frame from a NADA search with **capped pagination**
  (`ps=100`, one page by default, `r(more_pages_available)`, `all` +
  `max_rows(5000)` with progress every 5 pages — the explicit IMP-4
  pushback); rows parse through `_dtlb_idno` (non-conforming idnos kept with
  structural columns blank); new `files` subcommand wraps
  `data_files/{idno}` returning frame `dtlb_files` **and** `r()` shortcuts
  for the first ≤5 files plus `n_files`/`total_bytes`/`has_stata` (D-4).
  Minimal `__dtlb_json` extractor for the NADA response shapes. First help
  file for `_dtlb_catalog`.
- **Fixture-backed smoke suite (NA-8)** — committed NADA API goldens under
  `qa/fixtures/api/` (inventoried in `qa/fixtures/spec.yaml`) exercised by
  `qa/run_smoke.do`: 32 checks across all NA components via the `file://`
  transport (same code paths, no network). Runs as a manual pre-release gate
  alongside `qa/test_catalog.do` (hosted CI has no Stata license, so the
  plan's `test.yml` leg is deferred with the P0d CI item).

### Changed

- `datalib.pkg` ships the new commands, help files, and the bundled
  `catalogs.yaml`; `.gitignore` whitelists `qa/fixtures/api/**` and ignores
  the smoke-test scratch homes; `src/registry/README.md` and `qa/README.md`
  document the registry seam and the two fixture sets.

### Deferred (per the plan)

- NA-9 release-time live diff, auto-pagination, and the variables/dictionary
  endpoint (v1.5); ETag caching and `__dtlb_*` promotions (v2). See the
  plan's §8 tables.

## 2026-07-04

Three workstreams: hardening the **INEP SAEB downloader** (and fetching SAEB 2023);
starting **Phase 6 — IHSN/DDI documentation & conformance**; and prototyping a
**cross-language `datalib` accessor** (Stata / Python / R) over a shared taxonomy spec.

### Added

- **Stata `_dtlb_put`** — generic deposit command (the write side of the trio): builds
  the IHSN skeleton, writes `<version>[_module].dta`, preserves `Data/Original`, guards
  MASTER immutability, and gates on `_dtlb_check`. (`afde357`)
- **Python package** — `pyproject.toml` (pip-installable) + pytest suite (6 tests, all
  passing). (`1393a2c`)
- **R package** — `DESCRIPTION`/`NAMESPACE` + testthat tests; sources moved under `R/R/`. (`3c96e6d`)
- **Cross-language parity contract** in `docs/taxonomy.md` — canonical option names and
  values shared identically across Stata / Python / R. (`4c822ad`)
- **`docs/taxonomy.md`** — the shared datalib/IHSN specification: folder taxonomy,
  MASTER/HARMONIZED separation, path resolution, and the `get`/`put`/`check` contract
  implemented identically in Stata, Python, and R. (`d8ff746`)
- **Python `datalib` package** (`python/datalib/`) — `get()`/`put()`/`check()` over the
  IHSN archive. `put()` builds the skeleton, writes `<version>[_module].dta`, generates
  DDI + Dublin Core + codebook, and enforces MASTER immutability + MASTER/HARMONIZED
  separation; root from `DATALIB_ROOT`; `.dta` via pyreadstat. Verified end-to-end. (`62e4320`)
- **R `datalib` prototype** (`R/datalib.R`) — `dl_get()`/`dl_put()`/`dl_check()` mirroring
  the Python reference; resolves identical paths and validates the same archive
  (verified cross-language). (`0ea5282`)

- **`_ihsncheck.ado`** (+ `_ihsncheck.sthlp`) — IHSN structural conformance
  validator. Scans a datalib root, checks every survey/version folder against the
  IHSN template built by `_mkdir`, and **enforces MASTER (`_M`) vs HARMONIZED
  (`_A_CLCT`) separation** (a `_A_` file inside a `_M` folder, or vice-versa, is a
  violation). Case-insensitive; returns `r(violations)/r(surveys)/r(master)/r(harmonized)`;
  `strict` exits 459 for pipeline gating. (`53ce8fd`)
- **`02_programs/src/py/generate_ddi.py`** — IHSN metadata generator. From a Stata
  `.dta` (read via `pyreadstat`) it emits **DDI-Codebook 2.5 XML**, **Dublin Core
  XML**, and a human-readable **`_codebook.md`**, parsing country/year/survey/version
  from the IHSN filename and tagging each file MASTER or HARMONIZED. (`8e353c6`)
- **`UPDATE_PLAN.md`** — full-repo review synthesis + 7-phase update plan; documents
  the `F:/data` (raw staging) vs `F:/datalib` (curated IHSN archive) split and the
  MASTER/HARMONIZED separation requirement. (`273e596`)
- **SAEB 2023** added to `download-inep-saeb-microdata.py` — `microdados_saeb_2023.zip`
  (student microdata, single file in 2023) + `..._2023_educacao_infantil.zip`. (`b2ab625`)
- **`02_programs/src/py/README.md`** — documents the microdata download scripts:
  usage, `F:/data` destination, incremental/retry behavior, SAEB edition coverage
  1995–2023, and the SAEB 2025 status (not yet released). (`7adcf59`)

### Changed

- **Namespaced internal Stata helpers with `_dtlb_`** — renamed `_ihsncheck` →
  `_dtlb_check` (avoids collisions with generic names); legacy engine helpers
  (`_dlw`/`_mkdir`/…) scheduled for the same treatment in the Phase-2 refactor. (`afde357`)
- **`.gitignore`** now whitelists package manifests (`pyproject.toml`, `DESCRIPTION`,
  `NAMESPACE`, `*.toml`). (`4c822ad`)
- **SAEB downloader hardened** (`download-inep-saeb-microdata.py`): retry flaky INEP
  downloads up to 5× with backoff + connect/read timeouts (the server resets large
  transfers, `ConnectionResetError 10054`), removing partial files before each retry
  and returning `None` on final failure so a corrupt archive is never unzipped; skip
  extraction when a target folder is already populated (fully incremental re-runs);
  256 KB read chunks. (`e0f1ced`)

### Fixed

- **SAEB download destination** moved `C:/data` → `F:/data/INEP_Microdata/saeb`
  (`download-inep-saeb-microdata.py`), matching where the data tree lives on this
  setup and off the nearly-full C: drive. (`5729d60`)

### Data (not tracked in git)

- Downloaded **SAEB 2023** microdata to `F:/data/INEP_Microdata/saeb`
  (`microdados_saeb_2023.zip`, 661 MB, + educação infantil), extracting the
  grade-5/grade-9 student CSVs. Existing editions 1995–2021 (~21.8 GB) left untouched.
