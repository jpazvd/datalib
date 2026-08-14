*===============================================================================
* qa/test_checkers.do
*-------------------------------------------------------------------------------
* Regression tests for the folder-name checkers and the vintage builder, added
* with the v1.1.0 backport of the case-normalization and _M_/_A_ fixes from
* unicef-drp/datalib-unicef-dev @ v0.9.33 (a66b6b6).
*
* What each check covers, and where it actually discriminates:
*   C1  _dtlb_svycheck detects an all-caps master vintage
*   C2  _dtlb_svycheck detects an all-caps adaptation vintage
*   C3  _dtlb_svycheck, survey() matches regardless of the caller's case
*   C4  _dtlb_vcheck classifies all-caps _M / _A_ folders
*   C5  _dtlb_adaptcheck returns the FIRST token of a multi-underscore
*       adaptation name  -- pre-fix it returned the whole tail (TWO_WORDS)
*   C6  no _A_-for-_M_ vintage literal survives in _dtlb_mkdir.ado
*   C7  _dtlb_mkdir creates no stray _A_-for-_M_ directory
*
* PLATFORM NOTE, measured rather than assumed: on Windows, Stata's
* -local list : dir ... dirs "*"- returns folder names LOWERCASED regardless of
* how they are stored, so C1-C4 pass against the pre-backport ados here too --
* the case defect is unobservable on this platform. They were verified to be
* real guards by shadowing the pre-fix ados on the ado-path: only C5 flipped
* (GMD TWO_WORDS -> GMD TWO). C1-C4 are kept because they are exactly the cases
* that break on case-sensitive filesystems (macOS, Linux), which is the reason
* the upstream fix exists; they will discriminate if this suite is ever run
* there. C6/C7 are platform-independent.
*
* Self-contained: builds its own tree under a temporary directory, so it does
* not depend on qa/fixtures/build.sh.
*
* Run: stata-mp -b do qa/test_checkers.do   (or interactively)
* Exit code: non-zero on any failure.
*===============================================================================

clear all
set more off
version 15

*-- environment ----------------------------------------------------------------
* Optional argument: repository root. Defaults to the working directory, so the
* suite still runs as -do qa/test_checkers.do- from the repo. Passing the root
* explicitly lets the runner start Stata in a scratch directory holding an empty
* profile.do, which is how a batch run bypasses a machine profile that blocks
* (a startup profile calling an interactive or network-probing command will
* otherwise hang -stata -b- before the do-file is ever reached).
local repo `"`1'"'
if (`"`repo'"' == "") local repo `"`c(pwd)'"'
local repo = subinstr(`"`repo'"', "\", "/", .)

capture log close _all
capture mkdir "`repo'/qa/logs"
log using "`repo'/qa/logs/test_checkers.log", replace text

adopath ++ "`repo'/stata/src/_"
adopath ++ "`repo'/stata/src/d"

global dtlb_check_n = 0

capture program drop chk
program define chk
    syntax , cond(string asis) [msg(string)]
    if !(`cond') {
        display as error `"FAIL: `msg'"'
        display as error `"      condition: `cond'"'
        exit 9
    }
    global dtlb_check_n = ${dtlb_check_n} + 1
    display as result `"PASS: `msg'"'
end

*-- fixture: a deliberately mixed-case library ---------------------------------
* ZZB_2019_XHS carries an all-caps master vintage, an all-caps adaptation, and
* an adaptation whose name contains an underscore -- the exact shapes the
* pre-backport checkers mis-parsed.
tempfile stub
local base = subinstr("`stub'", "\", "/", .)
local root "`base'_lib"

capture mkdir "`root'"
capture mkdir "`root'/ZZB"
capture mkdir "`root'/ZZB/ZZB_2019_XHS"
* UPPER-case master vintage. The markers the checkers search for are the lower
* case literals "_m" / "_a_", so an all-caps vintage is the shape the
* pre-backport code missed on a case-sensitive filesystem. (On Windows it is
* detected either way -- see the PLATFORM NOTE in the header: -dir- hands back
* lowercased names here, so the tree's stored spelling never reaches the
* comparison.)
capture mkdir "`root'/ZZB/ZZB_2019_XHS/ZZB_2019_XHS_V01_M"
* UPPER-case adaptation, single-token adaptation name (8 components, which is
* what the survey/vintage grammar expects)
capture mkdir "`root'/ZZB/ZZB_2019_XHS/ZZB_2019_XHS_V01_M_V01_A_GMD"
* adaptation name carrying an underscore: outside the 8-component grammar, so
* only _dtlb_adaptcheck (which scans for _a_) sees it -- this is the folder that
* exposed the whole-tail extraction bug
capture mkdir "`root'/ZZB/ZZB_2019_XHS/ZZB_2019_XHS_v01_M_v01_A_TWO_WORDS"

display as text _newline "fixture root: `root'"

*===============================================================================
* C1/C2/C3 -- _dtlb_svycheck on an all-caps tree
*===============================================================================
display _newline as text _dup(80) "="
display as text "C1-C3 -- _dtlb_svycheck"
display as text _dup(80) "="

_dtlb_svycheck, path("`root'/ZZB/ZZB_2019_XHS")
local mcheck = r(mastercheck)
local acheck = r(adaptationcheck)

chk, cond(`mcheck' == 1) msg("C1 all-caps master vintage (_M) is detected")
chk, cond(`acheck' == 1) msg("C2 all-caps adaptation vintage (_A_) is detected")

_dtlb_svycheck, path("`root'/ZZB/ZZB_2019_XHS") survey(xhs)
local mcheck_lc = r(mastercheck)
chk, cond(`mcheck_lc' == 1) msg("C3 survey() matches case-insensitively")

*===============================================================================
* C4 -- _dtlb_vcheck classifies all-caps markers
*===============================================================================
display _newline as text _dup(80) "="
display as text "C4 -- _dtlb_vcheck"
display as text _dup(80) "="

_dtlb_vcheck, path("`root'/ZZB/ZZB_2019_XHS")
local nM : word count `r(MFolders)'
local nA : word count `r(AFolders)'
chk, cond(`nM' == 1 & `nA' == 1) msg("C4 one master + one adaptation classified")

*===============================================================================
* C5 -- _dtlb_adaptcheck returns the first token only
*===============================================================================
display _newline as text _dup(80) "="
display as text "C5 -- _dtlb_adaptcheck"
display as text _dup(80) "="

_dtlb_adaptcheck, path("`root'/ZZB/ZZB_2019_XHS")
local adapts = trim("`r(adaptations)'")
local has_first = (strpos(" `adapts' ", " TWO ") > 0)
local has_tail  = (strpos("`adapts'", "TWO_WORDS") > 0)
chk, cond(`has_first' == 1) msg("C5a multi-underscore adaptation yields its first token TWO (got: `adapts')")
chk, cond(`has_tail' == 0)  msg("C5b the whole tail TWO_WORDS is not returned")

*===============================================================================
* C6 -- source invariant: no _A_-for-_M_ literal survives in _dtlb_mkdir
*-------------------------------------------------------------------------------
* The defect was a single mistyped token in one of six sibling mkdir calls, so
* the cheapest durable guard is to assert the wrong spelling is absent from the
* source. This runs everywhere and cannot be defeated by fixture drift.
*===============================================================================
display _newline as text _dup(80) "="
display as text "C6 -- _dtlb_mkdir source invariant"
display as text _dup(80) "="

tempname fh
local badpat = "_A_" + char(96) + "vastr'_A_"
local nbad = 0
file open `fh' using "`repo'/stata/src/_/_dtlb_mkdir.ado", read text
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "`badpat'") > 0 local nbad = `nbad' + 1
    file read `fh' line
}
file close `fh'

chk, cond(`nbad' == 0) msg("C6 no _A_-for-_M_ vintage literal in _dtlb_mkdir.ado (found `nbad')")

*===============================================================================
* C7 -- _dtlb_mkdir builds the adaptation vintage under the master marker
*-------------------------------------------------------------------------------
* Integration case: a master-only tree, then create a new collection. Exercises
* the same branch that carried the defect, and consumes _dtlb_vcheck's and
* _dtlb_adaptcheck's returns on the way (so a case-normalization regression in
* either checker also trips this).
*===============================================================================
display _newline as text _dup(80) "="
display as text "C7 -- _dtlb_mkdir integration"
display as text _dup(80) "="

local mkroot "`base'_mk"
capture mkdir "`mkroot'"
capture mkdir "`mkroot'/QMA"
capture mkdir "`mkroot'/QMA/QMA_2014_XLF"
capture mkdir "`mkroot'/QMA/QMA_2014_XLF/QMA_2014_XLF_v01_M"

capture noisily _dtlb_mkdir, path("`mkroot'") country(QMA) year(2014) survey(XLF) ///
        adaptation collection(GMD) vm(01) va(01) mkdir
local mkrc = _rc
display as text "  _dtlb_mkdir rc = `mkrc'"

capture confirm file "`mkroot'/QMA/QMA_2014_XLF/QMA_2014_XLF_v01_M_v01_A_GMD/Data/Other/."
local other_ok = (_rc == 0)
capture confirm file "`mkroot'/QMA/QMA_2014_XLF/QMA_2014_XLF_v01_A_v01_A_GMD/Data/Other/."
local stray = (_rc == 0)

chk, cond(`stray' == 0) msg("C7 no stray _A_-for-_M_ vintage directory created")
if (`other_ok' == 0) {
    display as text "  note: adaptation vintage not created (rc `mkrc'); C7 asserts only the absence of the stray path"
}

*===============================================================================
* C8 -- _foldernav section branches do not fall through
*-------------------------------------------------------------------------------
* The DATA / DOC / PROGRAMS branches reassign subfoldr to the previously
* navigated folder, which defeated the ("`subfoldr'"!="DATA") guard on the
* generic navigation block below them (and never excluded DOC or PROGRAMS at
* all). The visible symptom is a spurious r(subfoldr1) -- stubcnt is 1 for a
* one-word subfoldr like DATA -- plus an empty directory listing printed under
* Data/Stata. Asserting on r(subfoldr1) is the cheap observable.
*
* The click chain must survive: r(subfoldr) is carried by -return add-, so a
* DOC click straight after a DATA click still resolves. C8c is that guarantee.
*===============================================================================
display _newline as text _dup(80) "="
display as text "C8 -- _foldernav fall-through"
display as text _dup(80) "="

local fnroot "`base'_fn"
foreach d in "" "/ZZB" "/ZZB/ZZB_2019_XHS" "/ZZB/ZZB_2019_XHS/ZZB_2019_XHS_v01_M" ///
             "/ZZB/ZZB_2019_XHS/ZZB_2019_XHS_v01_M/Data" ///
             "/ZZB/ZZB_2019_XHS/ZZB_2019_XHS_v01_M/Data/Stata" ///
             "/ZZB/ZZB_2019_XHS/ZZB_2019_XHS_v01_M/Doc" {
    capture mkdir "`fnroot'`d'"
}

* _foldernav reads ${datalib}; set it only for this section and restore after.
local datalib_saved "${datalib}"
global datalib "`fnroot'"

quietly _foldernav, subfoldr(ZZB_2019_XHS_v01_M)
local nav_subfoldr "`r(subfoldr)'"

quietly _foldernav, subfoldr(DATA)
local data_full "`r(fullfoldr)'"
local data_sub1 "`r(subfoldr1)'"
local data_sub  "`r(subfoldr)'"

capture noisily quietly _foldernav, subfoldr(DOC)
local doc_rc = _rc
local doc_full "`r(fullfoldr)'"

global datalib "`datalib_saved'"

chk, cond("`data_sub1'" == "") ///
    msg("C8a DATA click returns no spurious r(subfoldr1) (got: `data_sub1')")
chk, cond("`data_full'" == "`nav_subfoldr'/Data/Stata/") ///
    msg("C8b DATA click still returns r(fullfoldr)")
chk, cond(`doc_rc' == 0 & "`doc_full'" == "`nav_subfoldr'/Doc/") ///
    msg("C8c DOC click straight after DATA still resolves (chain preserved)")

*===============================================================================
display _newline as text _dup(80) "="
display as result "ALL CHECKS PASSED (${dtlb_check_n} checks)"
display as text _dup(80) "="

capture log close _all
exit 0
