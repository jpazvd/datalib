*! run_tests.do
*! datalib QA runner
*! Date: 09Aug2026
*===============================================================================
* qa/run_tests.do  --  the one entry point to the Stata gate
*-------------------------------------------------------------------------------
* Modes, matching the house runner in yaml-dev/qa/run_tests.do:
*
*   do qa/run_tests.do                 run every suite, append test_history.txt
*   do qa/run_tests.do SMOKE           run one suite by name (history not touched)
*   do qa/run_tests.do LIST            print the suites and their families
*
* WHY THIS ORCHESTRATES RATHER THAN INLINES
*
* yaml-dev's runner carries all 34 of its checks in one file. datalib already
* has eight suites holding ~190 checks, written over a year and each one
* self-contained. Rewriting them into a monolith would throw away working tests
* to gain a file layout -- the opposite of Gould (2001), whose certification
* argument is that tests are never thrown away and reliability is cumulative.
* So this runs the suites that exist and reports on them.
*
* THREE THINGS THE SUITES DO THAT SHAPE THIS FILE
*
*   1. Each calls -clear all-, which drops globals, programs and matrices. So no
*      state is kept in globals or helper programs across a suite: the tallies
*      below live in LOCALS, which belong to this do-file and survive.
*   2. Each calls -capture log close _all-, which would close a log this runner
*      opened. So the runner keeps no Stata log; it writes its own transcript
*      with -file write-.
*   3. Each -exit-s non-zero on failure. So every suite is invoked under
*      -capture-, and the runner reads the RESULT OUT OF THE SUITE'S LOG rather
*      than trusting a return code -- batch Stata on Windows does not give a
*      usable one anyway.
*
* A SUITE IS GREEN ONLY IF ITS LOG CARRIES THE COMPLETION SENTINEL.
*
* This is the whole point of reading the log. On 2026-08-06 test_checkers was
* recorded green in qa/stata-gate.txt while it was in fact blocking forever
* inside _dtlb_svycheck: the machine profile (c:\ado\personal\profile.do) calls
* -getuserconfig-, which publishes ${datalib} as the operator's real library --
* a network share. A killed run and a finished run leave logs that look alike,
* because batch Stata on Windows ALSO hangs after completing and a force-kill
* truncates the buffered tail. Counting PASS lines alone would have called that
* run green. Requiring the sentinel is what makes "no result" different from
* "good result", and NOT COMPLETED is recorded in the history like any other
* failure.
*
* The same incident is why the runner neutralises ${datalib} before starting:
* the suites build their own fixture trees and none of them should be reading
* the operator's library.
*
* Run from the repository root.
*===============================================================================

version 16
set more off

*-- where we are ---------------------------------------------------------------
local repo = subinstr(`"`c(pwd)'"', "\", "/", .)

*-- mode -----------------------------------------------------------------------
* Anything that is not LIST is taken as a suite name, so a typo runs nothing and
* says so rather than silently running everything.
local target = trim(upper(`"`0'"'))

*-- the registry ---------------------------------------------------------------
* name | file | families | what it asks
* Kept in four parallel lists rather than a matrix because these are strings and
* -clear all- inside a suite would drop a matrix.
local S_name  `" "SMOKE" "CHECKERS" "CONFIG" "CATALOG" "INSTALL" "DET" "INT" "DOC" "'
local S_file  `" "run_smoke" "test_checkers" "test_config_seam" "test_catalog" "verify_install" "test_det" "test_integration" "test_help_examples" "'
local S_fam   `" "NA-1..NA-8" "C1..C8" "R/D/P/W/L" "CAT-1..CAT-6" "V1..V25" "DET-01..07" "INT-01..04" "DOC-01..03" "'
local S_asks  `" "do the internals behave in place" "do the checkers classify vintages" "does the config seam resolve" "does the catalog scan and filter" "does the packaged install work" "pinned inputs, pinned answers" "does the vendored yaml still satisfy us" "does the documentation match the code" "'

*-- INSTALL is driven by PowerShell, not by -do- --------------------------------
* qa/verify_install.ps1 launches its own Stata to net-install into a scratch
* PLUS tree, so it cannot be -do-ne from inside this session. It is listed here
* because leaving it out of the registry is how it would drift out of the gate.
* Its LOG is read back and classified on the same evidence as every other suite
* -- external pass, failed, incomplete, or not-run -- so an install that ran and
* failed is never mistaken for one that simply has not run yet.

*===============================================================================
* LIST
*===============================================================================
if ("`target'"=="LIST") {
    di as text _n "{hline 78}"
    di as text "datalib QA suites"
    di as text "{hline 78}"
    di as text ""
    local i = 0
    foreach nm of local S_name {
        local i = `i' + 1
        local fl : word `i' of `S_file'
        local fm : word `i' of `S_fam'
        local ak : word `i' of `S_asks'
        local ext ".do"
        if ("`nm'"=="INSTALL") local ext ".ps1   (run separately)"
        di as result "  `nm'" _col(14) as text "qa/`fl'`ext'"
        di as text   "" _col(14) "{it:`fm'}  --  `ak'"
    }
    di as text ""
    di as text "  do qa/run_tests.do <NAME>    run one suite"
    di as text "  do qa/run_tests.do           run all, and append qa/test_history.txt"
    di as text "{hline 78}"
    exit 0
}

*-- validate a named target before doing any work -------------------------------
if ("`target'"!="") {
    local ok 0
    foreach nm of local S_name {
        if ("`target'"=="`nm'") local ok 1
    }
    if (!`ok') {
        di as error "Unknown suite: `target'"
        di as error "Run: do qa/run_tests.do LIST"
        exit 198
    }
}

*===============================================================================
* SETUP
*===============================================================================
capture mkdir "`repo'/qa/logs"

local histfile "`repo'/qa/test_history.txt"

* The operator's library must not leak into a suite. See the header: this single
* line is what stops the profile-published network path from turning a QA run
* into an indefinite block.
* Both are remembered, not just the first. ${datalib_checked} is the memo that
* records which root has already been validated on disk; dropping it without
* restoring means the next -datalib- call in this session re-probes the root --
* and if that root is the network share described above, the re-probe is exactly
* the thing that hangs.
local dl_before  `"${datalib}"'
local dlc_before `"${datalib_checked}"'
global datalib ""
global datalib_checked ""

* Package version, read from VERSION rather than from any one stamp.
local dlver "unknown"
capture confirm file "`repo'/VERSION"
if (_rc==0) {
    tempname vh
    file open `vh' using "`repo'/VERSION", read text
    file read `vh' dlver
    file close `vh'
    local dlver = trim(`"`macval(dlver)'"')
}

* Branch. -shell- is wrapped because a locked-down machine may refuse it, and a
* missing branch name is worth less than a failed run.
local branch "(unknown)"
capture {
    tempfile gb
    shell git -C "`repo'" rev-parse --abbrev-ref HEAD > "`gb'" 2>&1
    tempname gbh
    file open `gbh' using "`gb'", read text
    file read `gbh' branch
    file close `gbh'
    local branch = trim(`"`macval(branch)'"')
}
if (`"`branch'"'=="") local branch "(unknown)"

*-- fixtures -------------------------------------------------------------------
* CATALOG used to read a tree BUILT by qa/fixtures/build.sh rather than a
* committed one, and this block tried to build it. Both are gone as of the
* self-describing-modules work: build.sh generated directories named after real
* countries (BRA, COL, ETH) holding invented numbers, and the build step could
* never run here anyway -- -bash- is not on the PATH -shell- inherits on
* Windows even though -git- is, so CATALOG reported SKIPPED on the only
* platform the gate runs on. It now reads qa/fixtures/library, which is
* committed, fictional, and needs no build step.

*-- the log reader -------------------------------------------------------------
* Sourced rather than defined inline: every suite calls -clear all-, which drops
* Mata functions AND programs, so a program that redefines it would not survive
* either. A file on disk does. Same reason yaml-dev keeps _define_helpers.do.
qui do "`repo'/qa/_scanlog.do"

local start_time = c(current_time)
local start_date = c(current_date)

di as text _n "{hline 78}"
di as text "datalib QA runner"
di as text "{hline 78}"
di as text "  repo    : `repo'"
di as text "  version : `dlver'"
di as text "  branch  : `branch'"
di as text "  stata   : `c(stata_version)' `c(flavor)' (`c(os)')"
di as text "  started : `start_date' `start_time'"
if (`"`dl_before'"'!="") {
    di as text "  note    : \${datalib} was set to `dl_before'; cleared for this run"
}
if ("`target'"!="") di as text "  target  : `target'"
di as text "{hline 78}"

*===============================================================================
* RUN
*===============================================================================
local n_suite   = 0
local n_green   = 0
local n_red     = 0
local n_sep     = 0
local n_skip    = 0
local checks    = 0
local failed    ""
local summary   ""

local i = 0
foreach nm of local S_name {
    local i = `i' + 1
    local fl : word `i' of `S_file'

    if ("`target'"!="" & "`target'"!="`nm'") continue

    *-- INSTALL cannot run from here; say so, do not guess --------------------
    * It cannot be -do-ne from here, but its log can be READ -- and saying
    * nothing about it is how a gate goes green having never installed the
    * package. So report what the log says, labelled EXTERNAL to make clear
    * this runner did not produce it and cannot vouch for when it was written.
    if ("`nm'"=="INSTALL") {
        local n_suite = `n_suite' + 1
        di as text _n "{hline 78}"
        di as text "SUITE `nm'  (qa/verify_install.ps1)"
        di as text "{hline 78}"
        local ilog "`repo'/qa/logs/verify_install.log"
        local s_pass = 0
        local s_fail = 0
        local s_done = 0
        local s_skip = 0
        local s_ids  ""
        local haslog 0
        capture confirm file "`ilog'"
        if (_rc==0) {
            local haslog 1
            mata: dtlb_scanlog("`ilog'")
        }

        * FRESHNESS. Scoring a log this runner did not produce is only sound
        * if the log says what it tested. Before 2026-08-08 it did not, and
        * the gate went green on a log written several versions earlier while
        * a fresh run failed two checks. verify_install.do now prints
        * DATALIB-INSTALL-VERSION; a log without it, or with the wrong one,
        * is treated as not-run rather than as evidence.
        local istale 0
        local iver "none"
        if (`haslog') {
            tempname ifh
            local iline ""
            * Match only at position 1, so the ECHOED command line
            * (`. display as text "DATALIB-INSTALL-VERSION: ..."') is skipped.
            * That line carries both quotes and a backtick macro reference, and
            * feeding it through substr() in a compound-quoted context fails
            * with "too few quotes" -- found by running this guard.
            * Logs are CRLF on Windows, so strip char(13) before comparing.
            file open `ifh' using "`ilog'", read text
            file read `ifh' iline
            while r(eof)==0 {
                local iclean = subinstr(`"`macval(iline)'"', char(13), "", .)
                if (substr(`"`iclean'"', 1, 24) == "DATALIB-INSTALL-VERSION:") {
                    local iver = strtrim(substr(`"`iclean'"', 25, .))
                    continue, break
                }
                file read `ifh' iline
            }
            file close `ifh'
            if ("`iver'" != "`dlver'") local istale 1
        }

        * An install that RAN AND FAILED is not the same fact as one that never
        * ran, and collapsing the two would let the gate go green over a broken
        * install -- 'not-run' is counted as separate, not as red. So classify
        * on the same evidence as every other suite: FAIL lines, then sentinel.
        if (!`haslog') {
            local n_sep = `n_sep' + 1
            di as text "  NOT RUN -- launches its own Stata, so run it yourself:"
            di as text "      powershell -File qa/verify_install.ps1"
            local summary `"`summary' "`nm'|not-run|0|0""'
        }
        else if (`istale') {
            local n_sep = `n_sep' + 1
            di as text "  STALE -- log records version `iver', VERSION is `dlver'."
            di as text "           Re-run it: powershell -File qa/verify_install.ps1"
            local summary `"`summary' "`nm'|not-run|0|0""'
        }
        else if (`s_fail' > 0) {
            local n_red  = `n_red' + 1
            local checks = `checks' + `s_pass'
            di as error "  EXTERNAL FAIL -- `s_pass' passed, `s_fail' failed:`s_ids'"
            local failed `"`failed' `nm'"'
            local summary `"`summary' "`nm'|failed|`s_pass'|`s_fail'""'
        }
        else if (!`s_done') {
            local n_red  = `n_red' + 1
            local checks = `checks' + `s_pass'
            di as error "  EXTERNAL INCOMPLETE -- `s_pass' checks logged, no ACCEPTANCE line"
            local failed `"`failed' `nm'(incomplete)"'
            local summary `"`summary' "`nm'|incomplete|`s_pass'|0""'
        }
        else {
            local n_green = `n_green' + 1
            local checks  = `checks' + `s_pass'
            di as result "  EXTERNAL PASS -- `s_pass' checks, from a previous"
            di as text   "                  powershell -File qa/verify_install.ps1"
            local summary `"`summary' "`nm'|external|`s_pass'|0""'
        }
        continue
    }

    local n_suite = `n_suite' + 1
    local slog "`repo'/qa/logs/`fl'.log"

    di as text _n "{hline 78}"
    di as text "SUITE `nm'  (qa/`fl'.do)"
    di as text "{hline 78}"

    * A stale log from a previous run is indistinguishable from this run's
    * output once we start parsing, so delete it first. This is the other half
    * of the 2026-08-06 incident: a fallback that found an older log reported a
    * suite green from a file written the day before.
    capture erase "`slog'"

    capture noisily do "`repo'/qa/`fl'.do" "`repo'"
    local suite_rc = _rc

    * The suite cleared everything on its way in, so re-establish what the
    * runner needs. Locals survived; globals, programs and Mata did not.
    global datalib ""
    global datalib_checked ""
    qui do "`repo'/qa/_scanlog.do"

    *-- read the verdict out of the log --------------------------------------
    local s_pass = 0
    local s_fail = 0
    local s_done = 0
    local s_skip = 0
    local s_ids  ""
    * Parsed in MATA, deliberately. A Stata log echoes the suite's own source,
    * which is full of backticks and compound quotes: the moment a line holding
    * the two characters {c 34}' reaches a macro-expanded string expression like
    * -local l = trim(`"`macval(line)'"')-, it closes the quote early and the
    * runner dies with "too few quotes" (r 132). Mata reads the file as data --
    * no macro expansion, so no content can be mistaken for syntax.
    capture confirm file "`slog'"
    if (_rc!=0) {
        di as error "  NO LOG at `slog'"
    }
    else {
        mata: dtlb_scanlog("`slog'")
    }

    *-- classify --------------------------------------------------------------
    * Green requires BOTH: the sentinel present AND no FAIL line. Either alone
    * is not enough -- a suite can print the sentinel from a -display- echo, and
    * a suite can end with zero FAILs simply by never reaching the end.
    if (`s_done' & `s_fail'==0) {
        local n_green = `n_green' + 1
        local checks  = `checks' + `s_pass'
        di as result "  PASSED  -- `s_pass' checks"
        local summary `"`summary' "`nm'|passed|`s_pass'|0""'
    }
    else if (`s_fail' > 0) {
        local n_red = `n_red' + 1
        local checks = `checks' + `s_pass'
        di as error  "  FAILED  -- `s_pass' passed, `s_fail' failed:`s_ids'"
        local failed `"`failed' `nm'"'
        local summary `"`summary' "`nm'|failed|`s_pass'|`s_fail'""'
    }
    else if (`s_skip') {
        local n_skip = `n_skip' + 1
        di as text   "  SKIPPED -- a prerequisite is absent, not a failure of the code"
        local summary `"`summary' "`nm'|skipped|`s_pass'|0""'
    }
    else {
        local n_red = `n_red' + 1
        local checks = `checks' + `s_pass'
        di as error  "  NOT COMPLETED -- `s_pass' checks logged, no completion line (rc `suite_rc')"
        di as error  "     The suite stopped before finishing. This is NOT a pass."
        local failed `"`failed' `nm'(incomplete)"'
        local summary `"`summary' "`nm'|incomplete|`s_pass'|0""'
    }
}

*-- put the operator's library back ---------------------------------------------
global datalib         `"`dl_before'"'
global datalib_checked `"`dlc_before'"'

*===============================================================================
* SUMMARY
*===============================================================================
local end_time = c(current_time)

local sh = real(substr("`start_time'",1,2))
local sm = real(substr("`start_time'",4,2))
local ss = real(substr("`start_time'",7,2))
local eh = real(substr("`end_time'",1,2))
local em = real(substr("`end_time'",4,2))
local es = real(substr("`end_time'",7,2))
local dur = (`eh'*3600+`em'*60+`es') - (`sh'*3600+`sm'*60+`ss')
if (`dur' < 0) local dur = `dur' + 86400
local dur_str = string(floor(`dur'/60)) + "m " + string(mod(`dur',60)) + "s"

di as text _n "{hline 78}"
di as text "SUMMARY"
di as text "{hline 78}"
foreach s of local summary {
    tokenize `"`s'"', parse("|")
    local tail ""
    if ("`7'"!="0" & "`7'"!="") local tail ", `7' failed"
    di as text "  `1'" _col(16) "`3'" _col(30) "`5' checks`tail'"
}
di as text ""
di as text "  suites  : `n_suite'   green `n_green'   red `n_red'   skipped `n_skip'   separate `n_sep'"
di as text "  checks  : `checks'"
di as text "  duration: `dur_str'"
di as text ""
* A suite that never ran is not a suite that passed. Reporting GREEN while
* INSTALL has never been executed is the same flattery this whole file exists to
* remove, so an un-run suite yields GATE INCOMPLETE -- which every consumer
* rejects, because they require the words GATE GREEN exactly.
local verdict "GATE GREEN"
if (`n_sep' > 0) local verdict "GATE INCOMPLETE"
if (`n_red' > 0) local verdict "GATE RED"

if ("`verdict'"=="GATE GREEN") {
    di as result "  GATE GREEN"
}
else if ("`verdict'"=="GATE INCOMPLETE") {
    di as error "  GATE INCOMPLETE -- `n_sep' suite(s) never ran"
    di as text  "  INSTALL runs separately:  powershell -File qa/verify_install.ps1"
}
else {
    di as error "  GATE RED -- `failed'"
}
di as text "{hline 78}"

*===============================================================================
* HISTORY
*===============================================================================
* Appended, never rewritten, and a failed or incomplete run is recorded exactly
* like a green one. That is the point of keeping a history rather than a
* snapshot: qa/stata-gate.txt was maintained by hand and could therefore say
* green about a run nobody watched finish.
*
* Single-suite runs do not append -- a partial run is not a gate record.
if ("`target'"=="") {
    local sep "=============================================================================="
    tempname hh
    capture file open `hh' using "`histfile'", write append text
    if (_rc==0) {
        file write `hh' _n "`sep'" _n
        file write `hh' "Test Run:  `start_date'" _n
        file write `hh' "Started:   `start_time'" _n
        file write `hh' "Ended:     `end_time'" _n
        file write `hh' "Duration:  `dur_str'" _n
        file write `hh' "Branch:    `branch'" _n
        file write `hh' "Version:   `dlver'" _n
        file write `hh' "Stata:     `c(stata_version)' `c(flavor)' (`c(os)')" _n
        file write `hh' "Suites:    `n_suite' run, `n_green' green, `n_red' red, `n_skip' skipped, `n_sep' separate" _n
        file write `hh' "Checks:    `checks'" _n
        foreach s of local summary {
            tokenize `"`s'"', parse("|")
            file write `hh' "  - " %-10s "`1'" " " %-12s "`3'" " `5' checks" _n
        }
        file write `hh' "Result:    `verdict'" _n
        if ("`verdict'"=="GATE RED") {
            file write `hh' "Failed:   `failed'" _n
        }
        * Per-suite logs only. The runner opens no log of its own -- the first
        * suite's -log close _all- would close it -- so under -stata /e do- the
        * console transcript is whatever Stata writes beside the invocation.
        file write `hh' "Logs:      qa/logs/<suite>.log" _n
        file write `hh' "`sep'" _n
        file close `hh'
        di as text "History appended: qa/test_history.txt"
    }
    else {
        di as error "Could not append `histfile' (rc `=_rc')"
    }
}
else {
    di as text "(single-suite run -- history not appended)"
}

if ("`verdict'"!="GATE GREEN") exit 9
exit 0
