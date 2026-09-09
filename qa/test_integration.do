*===============================================================================
* qa/test_integration.do  --  INT family
*-------------------------------------------------------------------------------
* Does the VENDORED DEPENDENCY still satisfy what we need from it?
*
* datalib vendors the `yaml' package -- 14 .ado and 3 .sthlp re-shipped by
* datalib.pkg -- and _dtlb_catalog reads every per-survey datalib.yaml through
* it. That makes yaml a hard runtime dependency wearing the costume of a
* convenience.
*
* Three facts make this worth its own family, all from stata/src/y/VENDOR_NOTES.md:
*
*   1. The pin is to yaml v2.0.0 at commit e52d59f on branch `rr/sj-revision' --
*      an UNMERGED branch. yaml's own main/develop are at v1.5.1, so the pinned
*      commit is not reachable from any released ref.
*   2. The 14 vendored .ado files install into the PLUS tree and will COLLIDE
*      with a user's own -yaml- installation. Whichever resolves first wins.
*   3. The previous vendoring was taken from wbopendata-dev rather than from
*      yaml itself and drifted three minor versions behind without anyone
*      noticing -- the failure this family exists to make loud.
*
* The yaml-dev QA suite runs an INT family for the same reason in the opposite
* direction: it pins the frame-based query patterns that wbopendata and
* unicefdata depend on, so a yaml change cannot silently break its consumers.
* This is the consumer side of that same contract.
*
*   INT-01  the vendored yaml is present and is the pinned version
*   INT-02  the four operations _dtlb_catalog actually uses still work
*   INT-03  the frame-name prefixing contract holds
*   INT-04  the vendored tree carries no local modifications
*
* Run: stata -b do qa/test_integration.do [<repo-root>]
* Exit code: non-zero on any failure.
*===============================================================================

clear all
set more off
version 16

local repo `"`1'"'
if (`"`repo'"' == "") local repo `"`c(pwd)'"'
local repo = subinstr(`"`repo'"', "\", "/", .)

capture mkdir "`repo'/qa/logs"
capture log close _all
log using "`repo'/qa/logs/test_integration.log", replace text

adopath ++ "`repo'/stata/src/_"
adopath ++ "`repo'/stata/src/d"
adopath ++ "`repo'/stata/src/g"
adopath ++ "`repo'/stata/src/y"

global dtlb_int_n = 0

capture program drop chk
program define chk
    syntax , cond(string asis) [msg(string)]
    if !(`cond') {
        display as error `"FAIL: `msg'"'
        display as error `"      condition: `cond'"'
        exit 9
    }
    global dtlb_int_n = ${dtlb_int_n} + 1
    display as result `"PASS: `msg'"'
end

display as text _n "{hline 78}"
display as text "INT -- vendored yaml compatibility contract"
display as text "{hline 78}"

*===============================================================================
* INT-01 -- the dependency is present, and is the version we pinned.
*
* Version is read from the shipped file's own stamp rather than from
* VENDOR_NOTES.md, so a vendoring that updates the note but not the code (or the
* reverse) fails here instead of at a user's prompt.
*===============================================================================
capture which yaml
chk, cond(_rc==0) msg("INT-01a the vendored yaml command resolves")

local pinned "2.0.0"
tempname yfh
local yver ""
file open `yfh' using "`repo'/stata/src/y/yaml.ado", read text
file read `yfh' line
local i = 0
while (r(eof)==0) & (`i' < 12) {
    if (substr(trim(`"`macval(line)'"'),1,2)=="*!") {
        local stamp = trim(`"`macval(line)'"')
        if (regexm(`"`macval(stamp)'"', "([0-9]+\.[0-9]+\.[0-9]+)")) {
            local yver = regexs(1)
        }
    }
    local i = `i' + 1
    file read `yfh' line
}
file close `yfh'

chk, cond("`yver'"=="`pinned'") ///
    msg("INT-01b vendored yaml is the pinned version (`yver' vs `pinned')")

*===============================================================================
* INT-02 -- the four operations _dtlb_catalog actually calls.
*
* Not "yaml works" in the abstract: exactly the calls at _dtlb_catalog.ado:326,
* :338, :341, :344. If yaml changes any of these, the catalog scanner loses its
* metadata silently -- capture wraps every one of them there.
*===============================================================================
tempfile stub
local base = subinstr("`stub'", "\", "/", .)
capture mkdir "`base'_int"
local yml "`base'_int/datalib.yaml"

tempname w
file open `w' using "`yml'", write replace text
file write `w' "country: XAA" _n
file write `w' "year: 2015" _n
file write `w' "survey: XHS" _n
file write `w' "producer: IBGE" _n
file write `w' "license: CC-BY-4.0" _n
file write `w' "modules:" _n
file write `w' "  - dom" _n
file write `w' "  - pes" _n
file close `w'

local stem "dtlb_int_tmp"
capture frame drop yaml_`stem'
capture quietly yaml read using "`yml'", frame(`stem') replace
chk, cond(_rc==0) msg("INT-02a yaml read using ..., frame() replace  (rc `=_rc')")

capture quietly yaml get producer, frame(`stem')
local got_producer `"`r(value)'"'
chk, cond(_rc==0 & `"`got_producer'"'=="IBGE") ///
    msg("INT-02b yaml get producer returns r(value) (got '`got_producer'')")

capture quietly yaml get license, frame(`stem')
local got_license `"`r(value)'"'
chk, cond(_rc==0 & `"`got_license'"'=="CC-BY-4.0") ///
    msg("INT-02c yaml get license returns r(value) (got '`got_license'')")

capture quietly yaml list modules, frame(`stem')
chk, cond(_rc==0) msg("INT-02d yaml list modules succeeds (rc `=_rc')")

*===============================================================================
* INT-03 -- the frame-name prefixing contract.
*
* _dtlb_catalog.ado:320-322 hardcodes this: it passes the RAW stem to yaml read
* and then addresses `yaml_<stem>' when dropping the frame. If yaml ever stopped
* prefixing -- or started double-prefixing -- the scanner would leak a frame per
* survey and drop the wrong one. The yaml SJ referee raised this exact ambiguity
* (whether callers supply the logical name or the prefixed one), so it is not a
* hypothetical corner.
*===============================================================================
capture frame drop yaml_`stem'
capture quietly yaml read using "`yml'", frame(`stem') replace
capture confirm frame yaml_`stem'
chk, cond(_rc==0) ///
    msg("INT-03a a raw stem yields the yaml_-prefixed frame the scanner drops")

* And it must be idempotent: passing the already-prefixed name must not produce
* yaml_yaml_<stem>.
capture frame drop yaml_`stem'
capture quietly yaml read using "`yml'", frame(yaml_`stem') replace
capture confirm frame yaml_yaml_`stem'
chk, cond(_rc!=0) ///
    msg("INT-03b prefixing is idempotent -- no yaml_yaml_ frame is created")

*===============================================================================
* INT-04 -- no local modifications to the vendored tree.
*
* VENDOR_NOTES.md states the copy is byte-identical to upstream and that the
* previous vendoring drifted three minor versions without being noticed. A local
* edit is how that starts, so assert the claim the notes make: every vendored
* file still carries the upstream stamp, and none has been re-stamped to a
* datalib version.
*===============================================================================
tempname vh0
file open `vh0' using "`repo'/VERSION", read text
file read `vh0' dlver
file close `vh0'
local dlver = trim(`"`macval(dlver)'"')
local dlver = subinstr("`dlver'", ".", "\.", .)

local yados : dir "`repo'/stata/src/y" files "*.ado"
local n_y   = 0
local n_bad = 0
local bad   ""
foreach f of local yados {
    local n_y = `n_y' + 1
    tempname vh
    local hdr ""
    file open `vh' using "`repo'/stata/src/y/`f'", read text
    file read `vh' line
    local j = 0
    while (r(eof)==0) & (`j' < 10) {
        if (substr(trim(`"`macval(line)'"'),1,2)=="*!") {
            if (`"`hdr'"'=="") local hdr = trim(`"`macval(line)'"')
        }
        local j = `j' + 1
        file read `vh' line
    }
    file close `vh'
    * A vendored file carrying datalib's own version would mean someone edited
    * and re-stamped it in place. Read VERSION rather than hardcoding it: the
    * first draft pinned "1.2.0", which silently stopped detecting anything the
    * moment this package moved to 1.3.0 -- a guard that quietly retires itself
    * one release after it is written.
    if regexm(`"`macval(hdr)'"', "`dlver'") {
        local n_bad = `n_bad' + 1
        local bad `"`bad' "`f'""'
    }
}
if (`n_bad' > 0) {
    display as error "  Vendored files re-stamped with a datalib version:"
    foreach b of local bad {
        display as error "    `b'"
    }
}
chk, cond(`n_bad'==0) ///
    msg("INT-04 no vendored yaml file carries a datalib stamp (`n_y' checked)")

capture frame drop yaml_`stem'

*===============================================================================
display _newline as text _dup(78) "="
display as result "INT: ALL CHECKS PASSED (${dtlb_int_n} checks)"
display as text _dup(78) "="

capture log close _all
exit 0
