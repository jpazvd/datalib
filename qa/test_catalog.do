*===============================================================================
* qa/test_catalog.do
* -------------------------------------------------------------------------------
* Smoke tests for _dtlb_catalog. Builds the fixture tree and exercises:
*   1. scan returns expected counts
*   2. list returns full set
*   3. list filtered by country
*   4. list filtered by country+year+survey
*   5. clear drops frame
*   6. YAML parsing populates producer/license/modules where present
*
* Run: stata-mp -b do qa/test_catalog.do  (or interactively)
* Exit code: non-zero on any test failure.
*===============================================================================

clear all
set more off
version 16

* Explicit log so we don't depend on /b vs /e default-log behaviour
capture log close _all
capture mkdir "qa/logs"
log using "qa/logs/test_catalog.log", replace text

*-- environment ----------------------------------------------------------------
local repo "`c(pwd)'"
adopath ++ "`repo'/src/_"
adopath ++ "`repo'/src/d"
adopath ++ "`repo'/src/i"
adopath ++ "`repo'/src/y"

*-- fixtures -------------------------------------------------------------------
* The COMMITTED library, not the bash-built _tmp_datalib this suite used to
* read. That tree required `bash qa/fixtures/build.sh` to have been run, and
* Stata's -shell- cannot reach bash on Windows, so this suite skipped silently
* on the very platform the gate runs on. qa/fixtures/library needs no build
* step, which is half the reason it is committed.
global datalib "`repo'/qa/fixtures/library"
capture local _probe : dir "${datalib}/XAA" dirs "*"
if _rc {
    display as error "qa/fixtures/library is missing or not a directory."
    exit 9
}

*-- helper: assert ------------------------------------------------------------
program drop _all
program define check
    syntax , cond(string) [msg(string)]
    quietly count if `cond'
    if r(N) != _N {
        display as error "FAIL: `msg' (cond: `cond')"
        exit 9
    }
    display as result "PASS: `msg'"
end

*===============================================================================
* TEST 1 — scan returns expected counts
*===============================================================================
display _newline as text _dup(80) "="
display as text "TEST 1 — scan"
display as text _dup(80) "="

_dtlb_catalog, scan

assert r(n_versions) == 8
assert r(n_masters) == 6
assert r(n_adaptations) == 2
display as result "PASS: scan returned 8 versions = 6 masters + 2 adaptations"

*===============================================================================
* TEST 2 — list (unfiltered) returns all rows
*===============================================================================
display _newline as text _dup(80) "="
display as text "TEST 2 — list unfiltered"
display as text _dup(80) "="

_dtlb_catalog, list
assert r(N) == 8
display as result "PASS: list returned all 8 rows"

*===============================================================================
* TEST 3 — list filtered by country(XAA)
*===============================================================================
display _newline as text _dup(80) "="
display as text "TEST 3 — list country(XAA)"
display as text _dup(80) "="

_dtlb_catalog, list country(XAA)
assert r(N) == 4
display as result "PASS: XAA returned 4 rows (xhs v01_m, v02_m, v01_a_hcl; xsa v01_m)"

*===============================================================================
* TEST 4 — list filtered by country+year+survey
*===============================================================================
display _newline as text _dup(80) "="
display as text "TEST 4 — list country(XAA) year(2015) survey(XHS)"
display as text _dup(80) "="

_dtlb_catalog, list country(XAA) year(2015) survey(XHS)
assert r(N) == 3
display as result "PASS: XAA 2015 XHS returned 3 rows (v01_m, v02_m, v01_m_v01_a_hcl)"

*===============================================================================
* TEST 5 — frame schema correctness
*===============================================================================
display _newline as text _dup(80) "="
display as text "TEST 5 — frame schema"
display as text _dup(80) "="

frame change dtlb_catalog
describe
quietly count if has_yaml == 1
assert r(N) == 5
display as result "PASS: 5 rows have has_yaml=1 (the v01 masters; v02 and the adaptations carry none)"

*===============================================================================
* TEST 6 — YAML metadata extraction (if yaml_read available)
*===============================================================================
display _newline as text _dup(80) "="
display as text "TEST 6 — YAML metadata extraction"
display as text _dup(80) "="

capture which yaml_read
if _rc == 0 {
    quietly count if !missing(producer) & producer != ""
    if r(N) >= 2 {
        display as result "PASS: YAML producer field populated for `r(N)' rows"
    }
    else {
        display as error "FAIL: expected >=2 rows with producer, got `r(N)'"
        exit 9
    }
}
else {
    display as text "SKIP: yaml_read not available (test 6 skipped)"
}

frame change default

*===============================================================================
* TEST 7 — clear
*===============================================================================
display _newline as text _dup(80) "="
display as text "TEST 7 — clear"
display as text _dup(80) "="

_dtlb_catalog, clear
capture frame change dtlb_catalog
assert _rc != 0
display as result "PASS: clear dropped the frame"

*===============================================================================
* DONE
*===============================================================================
display _newline as result _dup(80) "="
display as result "ALL TESTS PASSED"
display as result _dup(80) "="

*-- cleanup: nothing to do. The fixture is committed, not generated, so this
*-- suite creates no tree to remove. (It once pointed at qa/fixtures/clean.sh,
*-- retired with build.sh.)

log close
