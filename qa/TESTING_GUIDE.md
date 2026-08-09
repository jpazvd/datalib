# Testing guide

How the datalib gate runs, what each suite asks, and the rules that keep the
record honest.

## Run it

From the repository root:

```
stata -b do qa/run_tests.do              # everything; appends test_history.txt
stata -b do qa/run_tests.do DOC          # one suite; does NOT touch the history
stata -b do qa/run_tests.do LIST         # what exists
powershell -File qa/verify_install.ps1   # INSTALL -- launches its own Stata
```

`INSTALL` cannot be `do`-ne from inside a Stata session, because it net-installs
the package into a scratch PLUS tree and needs a Stata of its own. Run it, then
run the gate: `run_tests.do` reads back `qa/logs/verify_install.log` and reports
the result as **external**. If it has never run, the gate says `not-run` and both
CI and the development repository's `scripts/verify.ps1` refuse the release.
(That script and the workflows below live in the development repository; they
are not part of the published package.)

## The suites

| Suite | File | Asks |
|---|---|---|
| **SMOKE** | `run_smoke.do` | does a fresh install behave |
| **CHECKERS** | `test_checkers.do` | do the checkers classify vintages |
| **CONFIG** | `test_config_seam.do` | does the config seam resolve |
| **CATALOG** | `test_catalog.do` | does the catalog scan and filter |
| **INSTALL** | `verify_install.ps1` | does the packaged install work |
| **DET** | `test_det.do` | pinned inputs, pinned answers |
| **INT** | `test_integration.do` | does the vendored `yaml` still satisfy us |
| **DOC** | `test_help_examples.do` | does the documentation match the code |

`DET` and `DOC` are the two layers `wbopendata-dev` runs: features, and
documentation validated against those features. `INT` exists because datalib
vendors `yaml` v2.0.0 pinned to an **unmerged branch**, re-shipping 14 `.ado`
files that collide with a user's own installation.

### A principled divergence

`wbopendata-dev` argues for **live** API tests, because it is data-access
infrastructure and its own docs note that "test failures do not necessarily
imply software defects". datalib is filesystem-based, so its equivalent is
**DET**: a synthetic library built by `datalib_makelib`, with pinned inputs and
pinned answers — McCullough's certified benchmarks rather than a live endpoint.
Stated here rather than left as a silent difference.

## Prerequisites

**None.** Every fixture is committed, so a clean clone runs the suites with
no build step and no `bash` on the PATH.

That is the point of the change. `CATALOG` used to read a tree built by
`qa/fixtures/build.sh`, and because `bash` is not on the PATH Stata's `shell`
inherits on Windows -- the only platform the gate runs on -- the suite reported
**SKIPPED** for years. Its assertions were untested as well as wrong. A fixture
that must be built before the suites work is a fixture the suites skip.

## Three rules that keep the record honest

Each of these exists because of a specific failure, not as a precaution.

**1. A suite is green only if its log carries the completion sentinel.**
Counting `PASS:` lines is not enough. On 2026-08-06 `test_checkers` was recorded
`11/11` in the old hand-written `qa/stata-gate.txt` while it was in fact
blocking forever inside `_dtlb_svycheck`. Batch Stata on Windows also hangs
*after* finishing, and a force-kill truncates the buffered log — so a killed run
and a finished one leave logs that look alike. The sentinel is what separates
"no result" from "good result". A suite without one is **NOT COMPLETED**, which
is recorded exactly like a failure.

**2. Stale logs are deleted before each suite runs.**
The same day, a log-path fallback picked up a file written the day before and
reported `test_config_seam` as "34 checks" when the real answer was 45. Every
suite now writes to `qa/logs/<suite>.log`, and the runner erases that file
before invoking the suite, so a missing log is visible instead of being quietly
replaced by an old one.

**3. `${datalib}` is cleared before the run, and restored after.**
The machine profile (`c:\ado\personal\profile.do`) calls `getuserconfig`, which
publishes `${datalib}` as the operator's real library — a network share here.
`_dtlb_mkdir` then probes it and blocks indefinitely. The suites build their own
fixture trees and none of them should be reading the operator's library.

## The history file

`qa/test_history.txt` is **appended** by `run_tests.do` on every full run,
recording the date, duration, branch, version, Stata flavour, per-suite results
and the verdict — including runs that were red or incomplete.

It replaced `qa/stata-gate.txt`, which was maintained by hand. The argument is
Gould's (2001): certification is cumulative evidence, and "tests are never
thrown away". A snapshot maintained by a person can drift from what actually
ran; an append-only log written by the runner cannot flatter itself.

Two gates read the **last record only**, since the file is append-only. Both
live in the **development repository** and are not shipped with the package,
so the paths below will not be present in a published copy:

- `.github/workflows/tests.yml` — validation only. GitHub's runners have no
  Stata licence, so CI never runs the suites; it checks that the recorded
  version matches `VERSION`, that the result is `GATE GREEN`, that `INSTALL` is
  not `not-run`, and that no suite is `incomplete` or `failed`.
- `.github/workflows/sync-to-public.yml` — the same checks, as a release gate.
- `scripts/verify.ps1` — the same checks, locally, before you tag.

Single-suite runs deliberately do **not** append: a partial run is not a gate
record.

## Adding a suite

1. Write `qa/test_<thing>.do`, taking the repo root as argument 1.
2. Log to `` `repo'/qa/logs/test_<thing>.log ``.
3. Emit `PASS: <ID> <description>` and `FAIL: <ID> <description>` at the start of
   a line, and end with `ALL CHECKS PASSED (<n> checks)`.
4. Add it to the four registry lists at the top of `qa/run_tests.do`.

A suite may report `SKIP: <reason>` when an optional prerequisite is absent; the
runner counts it as skipped rather than red, and the history says so.

## References

- Gould, W. 2001. Statistical software certification. *The Stata Journal*
  1(1): 29–50.
- McCullough, B. D. 1998. Assessing the reliability of statistical software:
  Part I. *The American Statistician* 52(4): 358–366.
