*===============================================================================
* qa/verify_install.do
*-------------------------------------------------------------------------------
* ACCEPTANCE TEST — does the SHIPPED package work for a real user?
*
* This is deliberately different from qa/run_smoke.do:
*
*   run_smoke.do     adds the repo's src/ to the adopath and tests the
*                    _dtlb_* internals in place. It proves the code is
*                    correct. It cannot detect packaging faults, because it
*                    never installs anything.
*
*   verify_install   performs a real -net install- from datalib.pkg into a
*                    throwaway directory and then runs ONLY from that
*                    install. It proves the thing a user receives works.
*                    It catches: files missing from the manifest, help files
*                    that do not ship, commands that resolve only because a
*                    developer had src/ on their path.
*
* It also exercises `datalib` itself — the main user-facing command — which
* run_smoke.do never calls.
*
* USAGE — prefer the wrapper, which sets up the scratch cwd for you:
*
*     powershell -File qa/verify_install.ps1          (from the repo root)
*
* To invoke this do-file directly, run Stata from a SCRATCH directory, not
* from the repo root: Stata puts "." on the adopath, so running here risks
* resolving code out of the working tree and defeating the point of the test.
* Pass the repo root as the only argument:
*
*     do <repo>/qa/verify_install.do "<repo>"
*
* Full write-up: the "Verify your install" section of the top-level README.
*
* Exit code 0 = all checks passed; 9 = a check failed.
*===============================================================================

args REPO

clear all
set more off
version 16

if `"`REPO'"' == "" {
    display as error "verify_install: pass the repo root, e.g."
    display as error `"    do qa/verify_install.do "C:/GitHub/myados/datalib-dev""'
    exit 198
}
local REPO = subinstr(`"`REPO'"', "\", "/", .)
if substr(`"`REPO'"', -1, 1) == "/" local REPO = substr(`"`REPO'"', 1, length(`"`REPO'"') - 1)

capture confirm file "`REPO'/datalib.pkg"
if _rc {
    display as error "verify_install: no datalib.pkg under `REPO' — wrong path?"
    exit 198
}

capture log close _all
capture mkdir "`REPO'/qa/logs"
log using "`REPO'/qa/logs/verify_install.log", replace text

*-- provenance stamp -----------------------------------------------------------
* This script launches its own Stata, so qa/run_tests.do cannot run it; the
* runner scores INSTALL by reading this log back off disk. That means a log
* left over from an OLDER version is indistinguishable from one just written
* -- and on 2026-08-08 exactly that happened: the gate reported "INSTALL
* external 41 checks, EXTERNAL PASS" from a log written before the demo
* fixture was rebuilt, while a fresh run failed V18 and V19.
*
* So stamp the version this run actually tested. run_tests.do refuses a log
* whose stamp is missing or does not equal VERSION, which turns "I cannot
* vouch for when this was written" into something checkable.
tempname vfh
local PKGVERSION "unknown"
capture file open `vfh' using "`REPO'/VERSION", read text
if (_rc==0) {
    file read `vfh' vline
    local PKGVERSION = strtrim(`"`vline'"')
    file close `vfh'
}
display as text "DATALIB-INSTALL-VERSION: `PKGVERSION'"

*-- counters -------------------------------------------------------------------
* Legal global names: Stata rejects names beginning with an underscore.
global dtlb_v_pass = 0
global dtlb_v_fail = 0
global dtlb_v_failed_list ""

* A failing check RECORDS and CONTINUES rather than aborting the run.
* This is a diagnostic, not a gate: aborting on the first failure hides
* every later check, and the most useful output is the full picture of what
* works and what does not. The script still exits non-zero at the end.
capture program drop vcheck
program define vcheck
    syntax , cond(string asis) [msg(string)]
    if !(`cond') {
        global dtlb_v_fail = ${dtlb_v_fail} + 1
        global dtlb_v_failed_list `"${dtlb_v_failed_list}|`msg'"'
        display as error `"FAIL: `msg'"'
        display as error `"      condition: `cond'"'
        exit
    }
    global dtlb_v_pass = ${dtlb_v_pass} + 1
    display as result `"PASS: `msg'"'
end

display _newline as text "{hline 78}"
display as text "datalib ACCEPTANCE TEST — install, then use as a user would"
display as text "repo: `REPO'"
display as text "{hline 78}"

*===============================================================================
display _newline as text "SECTION 1 — install the package the way a user does"
*===============================================================================

* Throwaway install root. Never the repo, never the user's real PLUS.
local TMP = subinstr(`"`c(tmpdir)'"', "\", "/", .)
if substr(`"`TMP'"', -1, 1) == "/" local TMP = substr(`"`TMP'"', 1, length(`"`TMP'"') - 1)
local INST "`TMP'/datalib_verify_ado"
local EMPTY "`TMP'/datalib_verify_empty"

capture mkdir "`INST'"
capture mkdir "`EMPTY'"

* ---------------------------------------------------------------------------
* HERMETIC ISOLATION — the whole test depends on this.
*
* -net set ado- alone is NOT enough: it sets where net install WRITES, but
* leaves the adopath pointing at the user's real PLUS and PERSONAL. A machine
* with datalib already installed (this one had
* C:/Users/<u>/ado/plus/d/datalib.ado) then resolves the OLD installed copy,
* every check passes, and the test silently proves nothing about the package
* being built. The first draft of this file had exactly that bug.
*
* -sysdir set- redirects both the write and the read, so the only datalib
* Stata can see is the one we just installed.
* ---------------------------------------------------------------------------
sysdir set PLUS     "`INST'"
sysdir set PERSONAL "`EMPTY'"
net set ado "`INST'"

display as text "  PLUS     -> `c(sysdir_plus)'"
display as text "  PERSONAL -> `c(sysdir_personal)'"

capture noisily net install datalib, from("`REPO'") replace
local rc_install = _rc
vcheck, cond(`rc_install' == 0) msg("V1 net install datalib succeeds from the repo")

* Every f-entry in datalib.pkg must now exist under the install root. net
* install files by leading character, so datalib.ado lands in <root>/d/.
* Rather than model that layout, confirm each basename is findable.
* Stata's net install ships only certain extensions. Verified empirically on
* 2026-07-19 with a probe package offering nine: .ado .sthlp .scheme .style
* install; .yaml .yml .toml .txt .dta are SILENTLY DROPPED -- net install
* still returns rc=0, with no error and no warning. So a manifest can promise
* a file that never arrives, and nothing complains.
*
* Split the check accordingly: a missing .ado/.sthlp is a packaging error;
* a missing .yaml is that Stata-drops-it behaviour, which needs reporting
* separately because the fix is different (rename to a shipping extension).
local missing_code  0
local dropped_ext   0
local checked       0
local dropped_names ""

tempname fh
file open `fh' using "`REPO'/datalib.pkg", read text
file read `fh' line
while r(eof) == 0 {
    if substr(`"`macval(line)'"', 1, 2) == "f " {
        local relpath = strtrim(substr(`"`macval(line)'"', 3, .))
        local base = substr(`"`relpath'"', strrpos(`"`relpath'"', "/") + 1, .)
        local dot  = strrpos(`"`base'"', ".")
        local ext  = lower(substr(`"`base'"', `dot' + 1, .))

        capture findfile `"`base'"'
        local notfound = (_rc != 0)

        if `notfound' {
            if inlist("`ext'", "ado", "sthlp", "scheme", "style") {
                display as error "  MISSING (should have installed): `base'"
                local missing_code = `missing_code' + 1
            }
            else {
                display as error "  DROPPED by net install (.`ext' not a shipping extension): `base'"
                local dropped_ext = `dropped_ext' + 1
                local dropped_names `"`dropped_names' `base'"'
            }
        }
        local checked = `checked' + 1
    }
    file read `fh' line
}
file close `fh'

display as text "  manifest entries: `checked' | missing code files: `missing_code' | dropped by extension: `dropped_ext'"
vcheck, cond(`missing_code' == 0) ///
    msg("V2 every .ado/.sthlp in datalib.pkg installs (`checked' manifest entries)")

if `dropped_ext' > 0 {
    display as error "  -> these are listed in datalib.pkg but CANNOT ship:`dropped_names'"
    display as error "     Stata's net install silently discards them (rc still 0)."
    display as error "     Fix: rename to a shipping extension and update the lookups,"
    display as error "     or stop listing them in the manifest and document the gap."
}
vcheck, cond(`dropped_ext' == 0) ///
    msg("V2b no manifest entry is silently discarded by net install")

*===============================================================================
display _newline as text "SECTION 2 — commands resolve from the INSTALL, not the repo"
*===============================================================================

* The point of the whole exercise: if these resolve to `REPO'/src/... then we
* are testing the working tree, not the package, and every later check is
* meaningless.
* Use -findfile-, not -which-: -which- prints the path but does not reliably
* set r(fn), so an assertion built on it compares against an empty string and
* passes vacuously. -findfile- returns the path in r(fn).
* Also capture r(fn) BEFORE calling vcheck -- any program call clears r().
capture findfile datalib.ado
local rc_which = _rc
local whereis `"`r(fn)'"'
local whereis = subinstr(`"`whereis'"', "\", "/", .)

vcheck, cond(`rc_which' == 0) msg("V3 datalib resolves")
display as text "  datalib resolved to: `whereis'"

* Assert POSITIVELY that it came from our scratch install. A negative test
* ("not from the repo") would still pass if it resolved from the user's real
* PLUS, which is the contamination this test is built to rule out.
*
* Compare on the leaf marker rather than the full path: c(tmpdir) hands back
* the 8.3 short form (C:/Users/JPAZEV~1/...) while -which- returns the long
* form (C:/Users/jpazevedo/...), so a whole-path comparison fails on Windows
* even when the file is exactly where we put it.
vcheck, cond(strpos(lower(`"`whereis'"'), "datalib_verify_ado") > 0) ///
    msg("V4 datalib resolves from the scratch install, not the repo or the real PLUS")

foreach c in _dtlb_catalog _dtlb_idno _dtlb_load yaml {
    capture which `c'
    vcheck, cond(_rc == 0) msg("V5 `c' ships and resolves")
}

* The vendored yaml must be the version we expect. Again: grab r(fn) before
* any program call.
capture findfile yaml_get.ado
local yg `"`r(fn)'"'
local yver ""
if `"`yg'"' != "" {
    tempname yh
    capture file open `yh' using `"`yg'"', read text
    if _rc == 0 {
        file read `yh' yline
        while r(eof) == 0 & "`yver'" == "" {
            if substr(`"`macval(yline)'"', 1, 2) == "*!" local yver `"`macval(yline)'"'
            file read `yh' yline
        }
        file close `yh'
    }
}
display as text "  vendored yaml: `yver'"
vcheck, cond(strpos(`"`yver'"', "2.0.0") > 0) ///
    msg("V6 vendored yaml is v2.0.0 (scalar-leaf lookups; see src/y/VENDOR_NOTES.md)")

* The four internal helpers must ship too. They live in src/_ upstream, so a
* yaml*.ado glob misses them -- which is how they went unvendored from
* 2026-04-28 to 2026-07-19 while yaml_read called all four.
foreach h in _yaml_collapse _yaml_fastread _yaml_mataread _yaml_tokenize_line {
    capture which `h'
    vcheck, cond(_rc == 0) msg("V6b helper `h' ships (yaml_read calls it)")
}

* _foldernav must resolve from the install on its own. Until it was extracted
* (_foldernav 1.1, shipped in datalib v1.1.0) it was defined inline at the
* bottom of _dtlb_load.ado and carried no manifest entry,
* so -datalib- (which calls it three times) could only reach it after
* _dtlb_load had already run once in the session. -which- is the honest test:
* it asks the ado-path, so it fails if the file is missing from the package
* even when some earlier command happens to have defined the program.
capture which _foldernav
vcheck, cond(_rc == 0) msg("V6c _foldernav ships as its own ado (datalib calls it before _dtlb_load)")

* The configuration seam is only useful if all of it ships. Each of these is
* reached from datalib_root, and a missing one fails ONLY on a clean install --
* the class of defect the packaging section of the README exists to catch.
foreach c in datalib_root datalib_config getuserconfig datalib_makelib ///
             _dl_islib _dl_demo _dl_isdemo _dl_require_stage {
    capture which `c'
    vcheck, cond(_rc == 0) msg("V6d config seam ships: `c'")
}

*===============================================================================
display _newline as text "SECTION 3 — the catalog, against the demo library"
*===============================================================================

* Build the library with the INSTALLED datalib_makelib rather than reading one
* out of the repository. Two things are being tested at once: the catalog and
* loader behaviour below, and the fact that a user who has only run
* -net install- can produce a working library at all. A committed library would
* test neither -- and would mean shipping microdata, which this package does
* not do.
tempfile demostub
local demobase = subinstr("`demostub'", "\", "/", .)
capture mkdir "`demobase'_demo"
local DEMO "`demobase'_demo/datalib"
capture noisily datalib_makelib, path("`DEMO'") families(demo) quietly
vcheck, cond(_rc == 0) msg("V7 datalib_makelib builds a library from the install")

quietly _dtlb_catalog, scan path("`DEMO'")
vcheck, cond(r(n_versions) == 8 & r(n_masters) == 6 & r(n_adaptations) == 2) ///
    msg("V8 scan finds 8 versions = 6 masters + 2 adaptations")

frame dtlb_catalog {
    quietly count
    vcheck, cond(r(N) == 8) msg("V9 catalog frame holds 8 rows")

    quietly count if country == "XAA"
    vcheck, cond(r(N) == 4) msg("V10 country stored uppercase (XAA has 4 rows)")

    quietly count if has_yaml == 1 & producer != ""
    vcheck, cond(r(N) == 5) msg("V11 YAML producer populated on all 5 masters carrying datalib.yaml")

    quietly count if has_yaml == 1 & license != ""
    vcheck, cond(r(N) == 5) msg("V12 YAML license populated on all 5")

    quietly count if modules != ""
    vcheck, cond(r(N) == 5) msg("V13 YAML modules list populated on all 5")
}

quietly _dtlb_catalog, list country(XAA)
vcheck, cond(r(N) == 4) msg("V14 catalog list filters by country")

*===============================================================================
display _newline as text "SECTION 4 — identifier round-trip"
*===============================================================================

* Build mode is implied by passing the components -- there is no build option.
* Everything here is -capture-d: an uncaught error aborts the whole do-file
* and silently skips every later section, which is how the first draft never
* reached sections 5 and 6.
capture quietly _dtlb_idno, country(XAA) year(2015) survey(XHS) version(v01)
local rc15 = _rc
local built "`r(idno)'"
vcheck, cond(`rc15' == 0 & "`built'" == "XAA_2015_XHS_v01_M") ///
    msg("V15 idno build from components -> XAA_2015_XHS_v01_M")

capture quietly _dtlb_idno, parse("XAA_2015_XHS_v01_M")
local rc16 = _rc
local parsed "`r(idno)'"
vcheck, cond(`rc16' == 0 & "`parsed'" == "XAA_2015_XHS_v01_M") ///
    msg("V16 idno parse is case-insensitive")

*===============================================================================
display _newline as text "SECTION 5 — load a dataset with the datalib command"
*===============================================================================

* This is the command a user actually types, and the one run_smoke.do never
* exercises. Point ${datalib} at the demo tree and load a module.
*
* No -master- option: datalib declares MASter in its syntax but rejects it at
* runtime with "Option master not currently supported." Loading the master is
* the default, so it is simply omitted here.
global datalib "`DEMO'"

* The master-version option is vm(), not version(). Two gotchas, both worth
* knowing before writing docs against this command:
*   - omit vm() entirely and the path is built with an empty version segment
*     (XAA_2015_XHS__M), failing with r(601);
*   - pass vm(01) and you get XAA_2015_XHS_01_M -- the literal string is
*     interpolated, so the "v" prefix must be supplied by the caller.
* _dtlb_idno normalises 1 / 01 / v01 / V01 to the same vintage; datalib does
* not. See V24 below, which pins that inconsistency.
capture noisily datalib, country(XAA) year(2015) survey(XHS) module(household) vm(v01)
local rc_load = _rc
vcheck, cond(`rc_load' == 0) msg("V17 datalib loads a master module without error")

* Read r(N) into a local before the next program call clears r().
quietly count
local nobs = r(N)
display as text "  observations loaded: `nobs'"
* 120 households, per Data/Original/raw_household.csv in the generated demo
* tree. Until 2026-08-08 this asserted 500 observations and a person-module
* variable list (pid age sex educ_years employed income) that the demo family
* stopped producing when the fixture was rebuilt around household/roster.
* It went unnoticed because the gate scores INSTALL from whatever
* qa/logs/verify_install.log happens to be on disk, and that log was stale --
* see the freshness guard in qa/run_tests.do.
vcheck, cond(`nobs' == 120) msg("V18 loaded dataset has the expected 120 observations")

* Real columns from the source .dta, proving actual data was loaded rather
* than an empty shell.
local ok19 1
foreach v in hhid region urban hh_size hh_weight {
    capture confirm variable `v'
    if _rc local ok19 0
}
vcheck, cond(`ok19' == 1) msg("V19 all 5 household-module variables present (hhid region urban hh_size hh_weight)")

* NOTE — deliberately NOT asserting ctrycode/year provenance columns here.
* Those belong to the datalib-unicef contract. In this generic codebase
* _dtlb_load only generates them inside the merge branches
* (if match("sort_household_hhmembers", ...)), so a single-module load does
* not produce them. Asserting them would be importing another repo's contract
* and would fail for a correct reason, which is worse than not testing it.
capture confirm variable ctrycode
local has_prov = (_rc == 0)
display as text "  provenance columns on this single-module path: ctrycode present = `has_prov' (0 expected here)"

* --- vintage normalisation: a documented inconsistency ------------------------
* _dtlb_idno accepts 1 / 01 / v01 / V01 and normalises them to one vintage.
* datalib's vm() does not -- it interpolates the string straight into the
* path, so vm(01) builds ..._01_M and fails while vm(v01) succeeds.
* Pinned here so the difference is visible rather than folklore; flip the
* expectation if datalib is ever changed to normalise.
capture _dtlb_idno, country(XAA) year(2015) survey(XHS) version(01)
local idno_01 "`r(idno)'"
capture _dtlb_idno, country(XAA) year(2015) survey(XHS) version(v01)
local idno_v01 "`r(idno)'"
vcheck, cond("`idno_01'" == "`idno_v01'" & "`idno_01'" != "") ///
    msg("V24 _dtlb_idno normalises 01 and v01 to the same identifier")

* V25 USED TO ASSERT THE BUG. It read "datalib vm() requires the v prefix --
* vm(01) fails where _dtlb_idno would normalise", and passed because vm(01)
* returned 601: the loader built `..._01_M' against a folder named `..._v01_M'.
* That is a test encoding a defect as the contract, so fixing the defect broke
* it -- which is the test doing its job on the way out. v1.3.0 gives every
* vintage token one spelling rule, so the two commands now agree.
clear
capture datalib, country(XAA) year(2015) survey(XHS) module(household) vm(01)
local rc_bare = _rc
clear
capture datalib, country(XAA) year(2015) survey(XHS) module(household) vm(v01)
local rc_pref = _rc
display as text "  datalib vm(01) rc=`rc_bare' ; vm(v01) rc=`rc_pref' (both should be 0)"
vcheck, cond(`rc_bare' == 0 & `rc_pref' == 0) ///
    msg("V25 datalib vm() accepts 01 and v01 alike, as _dtlb_idno does")

*===============================================================================
display _newline as text "SECTION 6 — api:// read path (offline, file:// fixtures)"
*===============================================================================

capture __dtlb_api_read using "file://`REPO'/qa/fixtures/api/catalog/find_by_idno/XAA_2015_XHS_v01_M.json"
local rc21   = _rc
local st21   = r(status_code)
local body21 `"`r(body_path)'"'
vcheck, cond(`rc21' == 0 & `st21' == 200) msg("V21 api read returns 200 on a file:// fixture")
vcheck, cond(`"`body21'"' != "") msg("V22 api read leaves a body file the caller can read")
capture erase `"`body21'"'

capture __dtlb_api_read using "file://`REPO'/qa/fixtures/api/catalog/find_by_idno/NOPE.json"
local st23 = r(status_code)
vcheck, cond(`st23' == 404) msg("V23 missing fixture maps to 404, not an error")

*===============================================================================
display _newline as text "{hline 78}"
display as text "SUMMARY"
display as text "{hline 78}"
display as text "  passed : ${dtlb_v_pass}"
display as text "  failed : ${dtlb_v_fail}"
display as text "  install root: `INST'"

if ${dtlb_v_fail} == 0 {
    display _newline as result "ACCEPTANCE PASSED — the installed package works."
    display as text "{hline 78}"
    log close
    exit 0
}

display _newline as error "ACCEPTANCE FAILED — ${dtlb_v_fail} check(s) did not pass:"
local flist `"${dtlb_v_failed_list}"'
while strpos(`"`flist'"', "|") > 0 {
    local flist = substr(`"`flist'"', strpos(`"`flist'"', "|") + 1, .)
    local nxt = strpos(`"`flist'"', "|")
    if `nxt' > 0 local one = substr(`"`flist'"', 1, `nxt' - 1)
    else         local one `"`flist'"'
    if `"`one'"' != "" display as error "    - `one'"
    if `nxt' == 0 continue, break
}
display as text "{hline 78}"

log close
exit 9
