# qa — smoke tests

Acceptance checks for `datalib`'s components. **There is no build step**: every
fixture is committed, so a clean clone can run the suites immediately. Each
`test_*.do` exercises the code under test and asserts against pinned counts
from the synthetic fixtures.

Two fixture sets live under `qa/fixtures/`:

- `library/` — the **filesystem** fixture: a complete datalib library of 8
  vintages across four fictional countries, committed and read by
  `test_catalog.do` and others. Its exact contents are pinned by
  `library/MANIFEST.txt`.
- `api/` — the **NADA API** goldens (small text JSON): committed and reviewed
  like code, inventoried in `fixtures/spec.yaml`, used by `run_smoke.do`
  through the `file://` transport (same code paths as the network, no
  network).

## Running locally

### Step 1 — nothing to build

There is no fixture build step. `qa/fixtures/library/` is **committed**: a
complete library of 8 vintages (6 masters + 2 adaptations) across four
fictional countries, 5 of them carrying `datalib.yaml`. See
`qa/fixtures/library/MANIFEST.txt`.

`qa/fixtures/build.sh` used to generate an uncommitted tree here. It was
retired: it named directories after real countries while holding invented
numbers, and `bash` is not on the PATH Stata's `shell` inherits on Windows, so
the suite that depended on it reported SKIPPED on the only platform the gate
runs on.

### Step 2 — run a test in Stata

**Interactive (recommended):**

```stata
. cd "C:/GitHub/myados/datalib-dev"
. do qa/test_catalog.do
```

**Batch (Windows):**

```bash
"/c/Program Files/Stata17/StataMP-64.exe" /e do qa/test_catalog.do
# log written to qa/test_catalog.log
```

**Batch (macOS / Linux):**

```bash
stata-mp -b do qa/test_catalog.do
```

### Step 3 — clean up

The committed fixtures are read, never written, and the suites that build a
tree do so under Stata's temporary directory, which goes with the session.

Two things are left behind here, both gitignored: `qa/fixtures/_tmp_home*/`,
the throwaway HOME directories `run_smoke.do` creates for the config-seam
checks, and `qa/logs/`. Delete them freely; nothing reads them between runs.

## Test files

| File | Tests | Expected |
|---|---|---|
| `test_catalog.do` | `_dtlb_catalog` scan/list/clear; YAML metadata extraction | 7 |
| `run_smoke.do` | api:// backend (NA-1..NA-8): `_dtlb_catalogregistry`, `__dtlb_userhome`, `__dtlb_credential`, `_dtlb_idno`, `__dtlb_api_read`, `__dtlb_extensions_probe`, `_dtlb_catalog` REST `list`/`files` — plus a scan of a library **generated** by `datalib_makelib, families(demo)` | 48 |
| `verify_install.do` | acceptance: installs the package and uses it as a user would (run it through `verify_install.ps1`) | 41 |
| `test_checkers.do` | the folder-name checkers and the vintage builder, after the v1.1.0 fixes | 11 |
| `test_config_seam.do` | library-root resolution, discovery, every guard that keeps discovery safe, and the `create`/`edit` writer | 40 |

`run_smoke.do` builds the demo library it scans, rather than reading one out of
the repository: `examples/demo_library` was deleted in v1.1.0, and generating it
means the suite also proves the generator works.

`test_checkers.do` and `test_config_seam.do` take the repo root as an argument,
so they can run from a scratch directory whose `profile.do` shadows a machine
profile that would otherwise block batch Stata:

```bash
stata-mp -b do <repo>/qa/test_config_seam.do <repo>
```

`run_smoke.do` needs no fixture build (the API goldens are committed); run it
from the repo root the same way as `test_catalog.do`:

```bash
stata-mp -b do qa/run_smoke.do    # log: qa/run_smoke.log
```

Hosted CI cannot run the **Stata** suites (no Stata license — the same
constraint that keeps the datalib-unicef Stata conformance leg local), so they
are **manual pre-release gates**. CI does now exist for the rest:
`.github/workflows/tests.yml` runs the Python and R suites on Ubuntu and
Windows, plus the version, stamp and registry guards.

Run them through [`run_tests.do`](run_tests.do), which appends every run to
[`test_history.txt`](test_history.txt) -- red and incomplete runs included. See
[TESTING_GUIDE.md](TESTING_GUIDE.md).

That record is not ceremonial: `scripts/verify.ps1` and both workflows **fail**
when the last run is older than `VERSION`, is not `GATE GREEN`, left `INSTALL`
un-run, or left a suite unfinished. A release cannot quietly ship without
somebody having run the suites CI cannot.

It replaced a hand-written `stata-gate.txt` on 2026-08-06, after that file
recorded a suite `11/11` which had in fact hung and never completed.

## What `test_catalog.do` asserts

1. **Test 1 — scan counts** — fixture yields 8 versions = 6 master + 2 adaptation
2. **Test 2 — unfiltered list** returns all 8 rows
3. **Test 3 — filtered list** `country(XAA)` returns 4 rows (xhs v01_m, v02_m, v01_a_hcl; xsa v01_m)
4. **Test 4 — multi-filter** `country(XAA) year(2015) survey(XHS)` returns 3 rows (v01_m, v02_m, v01_m_v01_a_hcl)
5. **Test 5 — schema** `has_yaml == 1` for the 5 v01 masters that carry `datalib.yaml`
6. **Test 6 — YAML extraction** — `producer` field populated for those 5 rows when `yaml_read` is on the ado-path
7. **Test 7 — clear** drops the frame cleanly

Exit code 0 on success, 9 on any assertion failure.

## Why nothing shells out to `bash`

`shell bash "..."` from a do-file run via `StataMP-64.exe /e` hangs in some
Windows batch configurations, and `bash` is not on the PATH Stata's `shell`
inherits on Windows even when `git` is. That is why the fixtures are committed
rather than generated: a suite whose prerequisite cannot run on the only
platform the gate runs on is a suite that reports SKIPPED forever.
