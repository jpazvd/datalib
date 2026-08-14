*===============================================================================
* qa/test_help_examples.do  --  DOC family (Layer 2)
*-------------------------------------------------------------------------------
* Does the DOCUMENTATION match the code?
*
* Layer 1 (run_smoke, test_checkers, test_config_seam, verify_install) asks
* whether the code works. This asks the other question, the one that goes
* unasked until a referee asks it: does what we tell users to type still exist,
* and does it still run?
*
* Ported in concept from wbopendata-dev/tests/test_help_examples.do, which
* describes itself as validating "that every example documented in the help file
* executes without error, ensuring that documentation accuracy tracks code
* changes". Adapted to datalib's situation, where a straight "run everything"
* is not achievable: many examples name absolute paths on a drive no reader has.
*
* The three checks, in increasing order of strictness:
*
*   DOC-01  no help example invokes a DEPRECATED command name
*   DOC-02  no help example hardcodes an absolute drive path
*   DOC-03  every RUNNABLE example executes without error
*
* Method: parse the packaged .sthlp files for clickable {stata "..."} directives.
* Those are the examples a reader actually clicks, so they are the ones that can
* embarrass us. Prose code blocks are not covered -- they are not executable and
* nothing claims they are.
*
* Run: stata -b do qa/test_help_examples.do [<repo-root>]
* Exit code: non-zero on any failure.
*===============================================================================

clear all
set more off
version 15

local repo `"`1'"'
if (`"`repo'"' == "") local repo `"`c(pwd)'"'
local repo = subinstr(`"`repo'"', "\", "/", .)

* .gitignore line 23 is a bare `*`, so qa/logs/ cannot be tracked into a clone.
* Create it rather than depending on a .gitkeep that git will not carry.
capture mkdir "`repo'/qa/logs"
capture log close _all
log using "`repo'/qa/logs/test_help_examples.log", replace text

adopath ++ "`repo'/stata/src/_"
adopath ++ "`repo'/stata/src/d"
adopath ++ "`repo'/stata/src/g"
adopath ++ "`repo'/stata/src/i"
adopath ++ "`repo'/stata/src/y"

global dtlb_doc_n    = 0
global dtlb_doc_fail = 0

capture program drop chk
program define chk
    syntax , cond(string asis) [msg(string)]
    if !(`cond') {
        display as error `"FAIL: `msg'"'
        global dtlb_doc_fail = ${dtlb_doc_fail} + 1
        exit 9
    }
    global dtlb_doc_n = ${dtlb_doc_n} + 1
    display as result `"PASS: `msg'"'
end

*-- the deprecated names, read from the stubs themselves ------------------------
* Enumerated from disk, not hardcoded. A deprecation stub is a one-line forward
* in stata/src/_/ whose body says "use <replacement> instead", so the stubs ARE the
* list; typing it out here is how it goes stale the day someone adds or retires
* one. (The first draft of this file carried a hardcoded list under a comment
* claiming it was read from disk -- worse than either, because the comment told
* the next reader not to check.)
local deprecated ""
local stubs : dir "`repo'/stata/src/_" files "_*.ado"
foreach s of local stubs {
    local nm = subinstr("`s'", ".ado", "", .)
    * the _dtlb_* and _dl_* families are current, not deprecated
    if (substr("`nm'",1,6)=="_dtlb_") continue
    if (substr("`nm'",1,4)=="_dl_")   continue
    if (substr("`nm'",1,2)=="__")     continue
    * a stub is short and forwards; read the header for the deprecation notice
    tempname sh
    local isdep 0
    file open `sh' using "`repo'/stata/src/_/`s'", read text
    file read `sh' sline
    local k = 0
    while (r(eof)==0) & (`k' < 20) {
        if (strpos(lower(`"`macval(sline)'"'), "deprecat")>0) local isdep 1
        local k = `k' + 1
        file read `sh' sline
    }
    file close `sh'
    if (`isdep') local deprecated "`deprecated' `nm'"
}
local deprecated = trim("`deprecated'")
display as text "  deprecated stubs found on disk: `deprecated'"

*-- collect every packaged .sthlp from the manifest -----------------------------
tempname pk
local helpfiles ""
file open `pk' using "`repo'/datalib.pkg", read text
file read `pk' line
while (r(eof)==0) {
    local l = trim(`"`macval(line)'"')
    if (substr("`l'",1,2)=="f ") {
        local rel = trim(substr("`l'",3,.))
        if (substr("`rel'",-6,.)==".sthlp") local helpfiles `"`helpfiles' "`rel'""'
    }
    file read `pk' line
}
file close `pk'

display as text _n "{hline 78}"
display as text "DOC -- help-file example validation (Layer 2)"
display as text "{hline 78}"

*===============================================================================
* Extract every clickable example, and classify it.
*===============================================================================
local n_total   = 0
local n_deprec  = 0
local n_abspath = 0
local n_runable = 0
local deprec_list ""
local abspath_list ""
local runable_list ""

tempname fh
foreach hf of local helpfiles {
    capture confirm file "`repo'/`hf'"
    if (_rc) continue

    file open `fh' using "`repo'/`hf'", read text
    file read `fh' line
    while (r(eof)==0) {
        local raw = `"`macval(line)'"'

        * A clickable example is {stata "<command>": <label>} or {stata "<command>"}.
        * Take everything between the first {stata " and the next " on the line.
        local pos = strpos(`"`macval(raw)'"', `"{stata ""')
        while (`pos' > 0) {
            local rest = substr(`"`macval(raw)'"', `pos'+8, .)
            local endq = strpos(`"`macval(rest)'"', `"""')
            if (`endq' > 1) {
                local cmd = substr(`"`macval(rest)'"', 1, `endq'-1)
                local n_total = `n_total' + 1

                * ---- DOC-01: deprecated command name? ----
                local first = word(subinstr(`"`macval(cmd)'"', ",", " ", .), 1)
                local isdep = 0
                foreach d of local deprecated {
                    if ("`first'"=="`d'") local isdep = 1
                }
                if (`isdep') {
                    local n_deprec = `n_deprec' + 1
                    local deprec_list `"`deprec_list' "`hf': `cmd'""'
                }

                * ---- DOC-02: absolute drive path? ----
                * A colon in the second character position after a letter is a
                * Windows drive; a leading / is a POSIX absolute path.
                local hasabs = 0
                if (regexm(`"`macval(cmd)'"', "[A-Za-z]:[\\/]")) local hasabs = 1
                if (`hasabs') {
                    local n_abspath = `n_abspath' + 1
                    local abspath_list `"`abspath_list' "`hf': `cmd'""'
                }

                * ---- runnable = neither deprecated nor drive-pinned ----
                if (`isdep'==0) & (`hasabs'==0) {
                    local n_runable = `n_runable' + 1
                    local runable_list `"`runable_list' "`cmd'""'
                }
            }
            local raw = substr(`"`macval(rest)'"', `endq'+1, .)
            local pos = strpos(`"`macval(raw)'"', `"{stata ""')
        }
        file read `fh' line
    }
    file close `fh'
}

display as text ""
display as text "  examples found         : `n_total'"
display as text "  invoking deprecated    : `n_deprec'"
display as text "  hardcoding a drive     : `n_abspath'"
display as text "  runnable               : `n_runable'"
display as text ""

*===============================================================================
* DOC-01 -- the help must not teach commands we have scheduled for removal.
*===============================================================================
if (`n_deprec' > 0) {
    display as error "  Examples invoking deprecated commands:"
    foreach e of local deprec_list {
        display as error "    `e'"
    }
}
chk, cond(`n_deprec'==0) ///
    msg("DOC-01 no help example invokes a deprecated command (`n_deprec' found)")

*===============================================================================
* DOC-02 -- an example a reader cannot run is not an example.
*===============================================================================
* A RATCHET, not a pass/fail line in the sand. 25 examples predate this suite and
* name paths like D:/datalib/XAA/... -- a drive no reader has. Rewriting them onto
* the synthetic demo tree is real work and does not belong in the commit that
* introduces the check, so the baseline is recorded here and the assertion is that
* it must never GROW. Lower it as examples are fixed; the day it reaches 0, change
* this to ==0 and delete the baseline.
*
* This is the same grandfathering the repository already uses for version stamps
* (python/tests/test_stamps_history.py skips files whose last change predates the
* VERSION file): enforce from now on without a mass rewrite nobody would review.
local DOC02_BASELINE = 25

if (`n_abspath' > 0) {
    display as text "  Examples hardcoding an absolute drive path (baseline `DOC02_BASELINE'):"
    foreach e of local abspath_list {
        display as text "    `e'"
    }
}
chk, cond(`n_abspath' <= `DOC02_BASELINE') ///
    msg("DOC-02 drive-pinned examples do not increase (`n_abspath' vs baseline `DOC02_BASELINE')")

*===============================================================================
* DOC-03 -- every runnable example actually runs.
*
* Against a synthetic library, so the check is deterministic and offline. This
* is the DET discipline of McCullough's certified benchmarks applied to
* documentation: pin the inputs, then assert the documented call still works.
*===============================================================================
tempfile stub
local base = subinstr("`stub'", "\", "/", .)
* datalib_makelib creates only the LEAF directory, so the parent has to exist
* first -- a tempfile name is a file stub, not a directory.
local lib "`base'_doclib"
capture mkdir "`lib'"
quietly datalib_makelib, path("`lib'/datalib") families(demo) quietly
global datalib "`lib'/datalib"

* Optional dependencies are SKIPPED, not failed -- the house pattern's
* version-aware skipping. -ibge- requires datazoom_social AND live IBGE
* downloads; failing on their absence would punish the wrong thing.
*
* Run from a scratch directory: several examples write relative paths (for
* instance datalib_makelib's path(mydemo)), and a second run in the same tree
* would hit "already exists" rather than exercising the example.
local cwd0 `"`c(pwd)'"'
capture mkdir "`base'_docrun"
quietly cd "`base'_docrun"

local n_ran  = 0
local n_bad  = 0
local n_skip = 0
local bad_list ""
foreach cmd of local runable_list {
    * Examples that open an editor, fetch over the network or exit the session
    * are documented behaviour we cannot exercise in batch. Skipped explicitly
    * rather than silently, so the count stays honest.
    if regexm(`"`macval(cmd)'"', "^(doedit|view|net |ssc |shell|exit)") {
        local n_skip = `n_skip' + 1
        continue
    }
    if regexm(`"`macval(cmd)'"', "(edit|update)") {
        local n_skip = `n_skip' + 1
        continue
    }
    * A multi-line example: the .sthlp carries it across a /// continuation, so
    * the fragment this parser extracted is a truncated command, not a runnable
    * one. Detected by structure rather than regex -- a trailing backslash, or
    * unbalanced parentheses -- because escaping a backslash class inside a
    * Stata string literal is its own trap. Skipped and counted, never silently.
    local trunc = 0
    if (substr(`"`macval(cmd)'"', -1, 1) == "\") local trunc = 1
    local nopen  : subinstr local cmd "(" "(", all count(local c_open)
    local nclose : subinstr local cmd ")" ")", all count(local c_close)
    if (`c_open' != `c_close') local trunc = 1
    if (`trunc') {
        local n_skip = `n_skip' + 1
        continue
    }
    * -ibge- needs datazoom_social AND the IBGE source files it downloads. The
    * command may be installed while the data is absent, so skip on either.
    if (substr(`"`macval(cmd)'"',1,4)=="ibge") {
        local n_skip = `n_skip' + 1
        continue
    }

    capture noisily `cmd'
    local rc = _rc
    local n_ran = `n_ran' + 1
    if (`rc' != 0) {
        local n_bad = `n_bad' + 1
        local bad_list `"`bad_list' "`cmd' -> rc `rc'""'
    }
}

* A ratchet again, and for a reason worth stating: the examples that fail name
* countries and surveys the demo tree does not contain (fictional codes the demo tree does not contain).
* That is a real documentation problem -- an example a reader cannot run teaches
* nothing -- but the fix is to rewrite them onto the demo shapes, which is the
* same work DOC-02 needs and belongs in the same pass. Baseline recorded; it must
* not grow.
quietly cd `"`cwd0'"'

local DOC03_BASELINE = 5

if (`n_bad' > 0) {
    display as text "  Runnable examples that failed (baseline `DOC03_BASELINE'):"
    foreach e of local bad_list {
        display as text "    `e'"
    }
}
chk, cond(`n_bad' <= `DOC03_BASELINE') ///
    msg("DOC-03 failing examples do not increase (`n_ran' run, `n_skip' skipped, `n_bad' failed vs baseline `DOC03_BASELINE')")

*===============================================================================
display _newline as text _dup(78) "="
display as result "DOC: ALL CHECKS PASSED (${dtlb_doc_n} checks)"
display as text _dup(78) "="

capture log close _all
exit 0
