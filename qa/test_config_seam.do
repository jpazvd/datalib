*===============================================================================
* qa/test_config_seam.do
*-------------------------------------------------------------------------------
* The library-root resolver and the config reader.
*
* RESOLUTION (candidate selection, no disk access):
*   R1  root() wins over everything                              -> argument
*   R2  ${datalib} wins when no argument                         -> global
*   R3  DATALIB_ROOT wins when neither is set                    -> env
*   R4  the generic config file supplies the root                -> config_generic
*   R5  the package config file supplies it when the generic
*       file exists but its block carries no datalib: key        -> config_package
*   R6  the generic file wins when BOTH carry the key            -> config_generic
*   R7  a configured root is returned even when it does NOT
*       exist  -- THE safety property: an unreachable archive
*       must fail at the file operation, never drift elsewhere
*   R8  default mode does not mutate ${datalib} unless -set-
*
* DISCOVERY (disk, only when nothing at all is configured):
*   D1  a library beside the working directory is discovered     -> discovered
*   D2  candidates() is honoured, in order                       -> discovered
*   D3  a configured root is NEVER replaced by discovery
*   D4  nodiscover stops at stage 5
*   D5  the bundled demo is the last resort                      -> demo
*   D6  the demo is refused as a deposit target
*
* PARSING:
*   P1  quoted values, trailing comments, CRLF and a UTF-8 BOM
*   P2  a block for another user is not read
*
* WRITING (the only part of the seam that touches disk on purpose):
*   W1  create writes the file, making its directory
*   W2  create without root() leaves the root unset rather than guessing one
*   W3  create root() writes a root the reader resolves    -> config_generic
*   W4  create NEVER rewrites an existing block
*   W5  appending a block leaves earlier blocks intact
*   W6  root() without create is refused
*   W7  edit opens an existing file; it never creates one
*   W8  edit reports the path under -stata -b- instead of opening a window
*   W9  a config directory whose path contains a space round-trips
*   W10 edit opens an existing file even when this user has no block in it
*   W11 create's three outcomes are distinguishable (created/appended/unchanged)
*   W12 quietly silences the write paths without changing what they return
*
* NAVIGATION CLICK-STATE:
*   L6  a DATA/DOC/PROGRAMS click still resolves after an intervening rclass
*       command has wiped r(subfoldr) -- the case a file load creates
*   L7  a memo taken in another library is refused rather than reused
*
* THE VOLUME GUARD (every state is pre-set; no case waits on a network):
*   V1  a disconnected volume is skipped and marked dead
*   V2  a RECONNECTING volume is skipped on the same terms -- not waited on
*   V3  the caller is told which state it was
*   V4  a connected volume falls through the guard AND stops being dead --
*       the memo is not a one-way door
*   V5  the persisted record forgets that one volume, not the others
*   V6  an unclassifiable volume neither skips nor clears -- the fail-safe,
*       which is what keeps a best-effort OS test from hiding a library
*
* Run: stata -b do qa/test_config_seam.do [<repo-root>]
* Exit code: non-zero on any failure.
*===============================================================================

clear all
set more off
version 15

local repo `"`1'"'
if (`"`repo'"' == "") local repo `"`c(pwd)'"'
local repo = subinstr(`"`repo'"', "\", "/", .)

capture log close _all
capture mkdir "`repo'/qa/logs"
log using "`repo'/qa/logs/test_config_seam.log", replace text

adopath ++ "`repo'/src/_"
adopath ++ "`repo'/src/d"
adopath ++ "`repo'/src/g"

global dtlb_cfg_n = 0

capture program drop chk
program define chk
    syntax , cond(string asis) [msg(string)]
    if !(`cond') {
        display as error `"FAIL: `msg'"'
        display as error `"      condition: `cond'"'
        exit 9
    }
    global dtlb_cfg_n = ${dtlb_cfg_n} + 1
    display as result `"PASS: `msg'"'
end

* Hermetic: every case pins the config directory with configdir()/config(), so
* the operator's own ~/.config is never read, and clears the global + env.
capture program drop reset_env
program define reset_env
    global datalib ""
end

tempfile stub
local base = subinstr("`stub'", "\", "/", .)

*-- a config directory with both files -----------------------------------------
local cfgdir "`base'_cfg"
capture mkdir "`cfgdir'"
local me = c(username)

tempname fh
file open `fh' using "`cfgdir'/user_config.yml", write replace text
file write `fh' "# generic config" _n
file write `fh' "`me':" _n
file write `fh' `"  githubFolder: "C:/GitHub""' _n
file write `fh' "  datalib: F:/from_generic   # trailing comment" _n
file write `fh' "otheruser:" _n
file write `fh' "  datalib: F:/from_other" _n
file close `fh'

file open `fh' using "`cfgdir'/datalib_config.yml", write replace text
file write `fh' "`me':" _n
file write `fh' "  datalib: F:/from_package" _n
file close `fh'

*-- a config dir whose generic file has the block but NO datalib key ------------
local cfgdir2 "`base'_cfg2"
capture mkdir "`cfgdir2'"
file open `fh' using "`cfgdir2'/user_config.yml", write replace text
file write `fh' "`me':" _n
file write `fh' `"  githubFolder: "C:/GitHub""' _n
file close `fh'
file open `fh' using "`cfgdir2'/datalib_config.yml", write replace text
file write `fh' "`me':" _n
file write `fh' "  datalib: F:/from_package" _n
file close `fh'

*-- an empty config dir (nothing configured at all) -----------------------------
local cfgdir0 "`base'_cfg0"
capture mkdir "`cfgdir0'"

*===============================================================================
display _newline as text _dup(80) "="
display as text "R1-R3 -- argument / global / env"
display as text _dup(80) "="

reset_env
datalib_root, root(F:/explicit) configdir("`cfgdir'")
chk, cond("`r(source_stage)'"=="argument" & "`r(root)'"=="F:/explicit") ///
    msg("R1 root() wins (stage `r(source_stage)')")

reset_env
global datalib "F:/from_global"
datalib_root, configdir("`cfgdir'")
chk, cond("`r(source_stage)'"=="global" & "`r(root)'"=="F:/from_global") ///
    msg("R2 global wins when no argument (stage `r(source_stage)')")

* R3: DATALIB_ROOT cannot be set from inside a Stata session, so the env stage
* is exercised by the R and Python golden cases rather than here. What CAN be
* checked is that the stage sits between the global and the config files: with
* no global set, resolution falls through to the config file below.

*===============================================================================
display _newline as text _dup(80) "="
display as text "R4-R6 -- the two-file config fallback"
display as text _dup(80) "="

reset_env
datalib_root, configdir("`cfgdir'")
chk, cond("`r(source_stage)'"=="config_generic" & "`r(root)'"=="F:/from_generic") ///
    msg("R4 generic config supplies the root (got `r(root)' via `r(source_stage)')")

reset_env
datalib_root, configdir("`cfgdir2'")
chk, cond("`r(source_stage)'"=="config_package" & "`r(root)'"=="F:/from_package") ///
    msg("R5 key-presence falls through to the package file (got `r(root)' via `r(source_stage)')")

reset_env
datalib_root, config("`cfgdir'/user_config.yml")
chk, cond("`r(source_stage)'"=="config_generic") ///
    msg("R6 config() pins one file, fallback off")

*===============================================================================
display _newline as text _dup(80) "="
display as text "R7-R8 -- the safety property, and purity"
display as text _dup(80) "="

reset_env
datalib_root, configdir("`cfgdir'")
chk, cond("`r(root)'"=="F:/from_generic") ///
    msg("R7 a configured-but-absent root is returned as given, not replaced")

reset_env
datalib_root, root(F:/explicit) configdir("`cfgdir'")
chk, cond("${datalib}"=="") msg("R8a default mode leaves the global untouched")
datalib_root, root(F:/explicit) configdir("`cfgdir'") set
chk, cond("${datalib}"=="F:/explicit") msg("R8b -set- fills the global")
reset_env

*===============================================================================
display _newline as text _dup(80) "="
display as text "D1-D4 -- discovery"
display as text _dup(80) "="

* a real library beside a working directory
local proj "`base'_proj"
capture mkdir "`proj'"
capture mkdir "`proj'/datalib"
capture mkdir "`proj'/datalib/ZZB"
capture mkdir "`proj'/datalib/ZZB/ZZB_2019_XHS"

reset_env
datalib_root, configdir("`cfgdir0'") candidates("`proj'") discover quietly
chk, cond("`r(source_stage)'"=="discovered" & r(descended)==1) ///
    msg("D2 candidates() discovers <cand>/datalib (stage `r(source_stage)', descended `r(descended)')")

reset_env
global datalib "F:/configured"
datalib_root, configdir("`cfgdir0'") candidates("`proj'") discover quietly
chk, cond("`r(source_stage)'"=="global" & "`r(root)'"=="F:/configured") ///
    msg("D3 discovery never replaces a configured root")

reset_env
capture datalib_root, configdir("`cfgdir0'") nodiscover
chk, cond(_rc==198) msg("D4 nodiscover stops at stage 5 (rc `=_rc')")

*===============================================================================
display _newline as text _dup(80) "="
display as text "D5-D6 -- the demo stage and the read-only marker"
display as text _dup(80) "="

* No demo ships with the package: it is generated on demand, and nothing is
* created on a read path. So with nothing configured and no demo built, the
* resolver must fail rather than resolve -- and say how to get one.
reset_env
capture datalib_root, configdir("`cfgdir0'") discover quietly
chk, cond(_rc==198) ///
    msg("D5a with nothing configured and no demo built, resolution fails (rc `=_rc')")

* A generated library is recognised as synthetic but is NOT read-only: it is the
* operator's copy, in their directory, and depositing into it is the point.
local genlib "`base'_gendemo/datalib"
capture mkdir "`base'_gendemo"
datalib_makelib, path("`genlib'") families(demo) quietly
_dl_isdemo "`genlib'"
chk, cond(r(demo)==1 & r(readonly)==0) ///
    msg("D5b a generated library is marked synthetic but writable")

* The read-only marker is what write commands actually consult, and it is read
* from anywhere at or below the library, not compared as a path string.
tempname rh
file open `rh' using "`genlib'/.datalib", write append text
file write `rh' "readonly: 1" _n
file close `rh'

_dl_isdemo "`genlib'"
chk, cond(r(readonly)==1) msg("D6a the read-only marker is honoured")

_dl_isdemo "`genlib'/XAA/XAA_2015_XHS/XAA_2015_XHS_v01_M/Data/Stata"
chk, cond(r(readonly)==1) ///
    msg("D6b the guard holds deep inside the tree, not just at its root")

reset_env
global datalib "`genlib'"
capture _dtlb_mkdir, path("`genlib'") country(ZZB) year(2019) survey(XHS) vintage master mkdir
chk, cond(_rc==198) msg("D6c deposits into a read-only library are refused (rc `=_rc')")
reset_env

*===============================================================================
display _newline as text _dup(80) "="
display as text "P1-P2 -- parsing"
display as text _dup(80) "="

reset_env
getuserconfig, configdir("`cfgdir'") quietly
chk, cond("`r(githubFolder)'"=="C:/GitHub") msg("P1a quoted value parsed without its quotes")
chk, cond("`r(datalib)'"=="F:/from_generic") msg("P1b trailing comment stripped")

reset_env
getuserconfig, configdir("`cfgdir'") user(otheruser) quietly
chk, cond("`r(datalib)'"=="F:/from_other") msg("P2 the named user's block is read")

*-- BOM + CRLF ------------------------------------------------------------------
local cfgdir3 "`base'_cfg3"
capture mkdir "`cfgdir3'"
file open `fh' using "`cfgdir3'/user_config.yml", write replace text
file write `fh' `"`=uchar(65279)'`me':"' _n
file write `fh' "  datalib: F:/after_bom" _n
file close `fh'

reset_env
getuserconfig, configdir("`cfgdir3'") quietly
chk, cond("`r(datalib)'"=="F:/after_bom") msg("P1c a UTF-8 BOM does not hide the first block")

*===============================================================================
display _newline as text _dup(80) "="
display as text "G -- the guards that keep discovery safe"
display as text _dup(80) "="

* G5: a root nobody named must never reach the global. -clear all- does not drop
* globals, so one such write would be sticky for the whole session and would be
* read by the deposit path.
reset_env
datalib_root, configdir("`cfgdir0'") candidates("`base'_gendemo") discover quietly set
local g5_stage "`r(source_stage)'"
chk, cond("${datalib}"=="" & inlist("`g5_stage'","discovered","demo")) ///
    msg("G5 -set- refuses to publish a `g5_stage' root to the global")
reset_env

* G6: batch runs do not discover unless asked. This suite runs under -stata -b-,
* so the default path here IS the batch path -- which is what makes the check
* meaningful rather than hypothetical.
reset_env
capture datalib_root, configdir("`cfgdir0'")
local batch_rc = _rc
chk, cond("`c(mode)'"!="batch" | `batch_rc'==198) ///
    msg("G6 batch refuses discovery without -discover- (mode `c(mode)', rc `batch_rc')")

* G4: a configuration that exists but yields no root is a mistake, not an empty
* stage. Falling through here is how a typo'd key becomes a confident resolution
* somewhere else entirely.
local cfgdir4 "`base'_cfg4"
capture mkdir "`cfgdir4'"
file open `fh' using "`cfgdir4'/user_config.yml", write replace text
file write `fh' "`me':" _n
file write `fh' "  datalib_root: F:/typo_in_the_key" _n
file close `fh'

reset_env
capture datalib_root, configdir("`cfgdir4'") discover
chk, cond(_rc==198) msg("G4 a config block with no datalib: key errors, never falls through (rc `=_rc')")

* G4b: a file that exists but has no block for this user is also an error
local cfgdir5 "`base'_cfg5"
capture mkdir "`cfgdir5'"
file open `fh' using "`cfgdir5'/user_config.yml", write replace text
file write `fh' "somebodyelse:" _n
file write `fh' "  datalib: F:/not_yours" _n
file close `fh'

reset_env
capture datalib_root, configdir("`cfgdir5'") discover
chk, cond(_rc==198) msg("G4b a config with no block for this user errors (rc `=_rc')")

* G11: a script can assert what it ran against.
reset_env
capture datalib_root, root(F:/explicit) require(configured)
chk, cond(_rc==0) msg("G11a require(configured) passes for a named root")
reset_env
capture datalib_root, configdir("`cfgdir0'") discover quietly require(configured)
chk, cond(_rc==198) msg("G11b require(configured) rejects an unconfigured root (rc `=_rc')")
reset_env

*===============================================================================
display _newline as text _dup(80) "="
display as text "W1-W8 -- the writer: -create- and -edit-"
display as text _dup(80) "="

* The one part of the seam that touches disk on purpose. Every case here is
* about what it must NOT do: never overwrite a block, never invent a root,
* never create a file from -edit-.

local wdir "`base'_w1"

* W1: create makes both the directory and the file.
reset_env
getuserconfig, create configdir("`wdir'") user(alice) quietly
capture confirm file "`wdir'/user_config.yml"
chk, cond(_rc==0) msg("W1 create writes user_config.yml, making its directory")

* W2: with no root(), the key is written commented out. A placeholder that
* parsed would fill ${datalib} with a directory nobody chose, and the failure
* would surface at a -use- rather than here.
reset_env
getuserconfig, configdir("`wdir'") user(alice) quietly
chk, cond(`"`r(datalib)'"'=="" & "`r(source_stage)'"=="unset" & "${datalib}"=="") ///
    msg("W2 create without root() leaves the root unset, not guessed")

* W3: create root() writes a root the reader then resolves.
reset_env
getuserconfig, create configdir("`wdir'") user(bob) root(F:/datalib) quietly
getuserconfig, configdir("`wdir'") user(bob) quietly
chk, cond("`r(datalib)'"=="F:/datalib" & "`r(source_stage)'"=="config_generic") ///
    msg("W3 create root() resolves via config_generic")

* W4: create never rewrites a block that is already there. This is what makes
* it safe to put in a start-up script: a second run cannot move a root that
* pipelines already depend on.
reset_env
getuserconfig, create configdir("`wdir'") user(bob) root(Q:/must_not_win) quietly
getuserconfig, configdir("`wdir'") user(bob) quietly
chk, cond("`r(datalib)'"=="F:/datalib") ///
    msg("W4 create leaves an existing block alone (still `r(datalib)')")

* W5: appending bob's block did not disturb alice's.
reset_env
capture getuserconfig, configdir("`wdir'") user(alice) quietly
chk, cond(_rc==0 & `"`r(datalib)'"'=="") ///
    msg("W5 an appended block leaves earlier blocks intact")

* W6: root() is meaningless without create, and saying so beats ignoring it.
reset_env
capture getuserconfig, configdir("`wdir'") user(bob) root(F:/x) quietly
chk, cond(_rc==198) msg("W6 root() without create is refused (rc `=_rc')")

* W7: edit opens an existing file; it is not a second way to create one.
reset_env
capture getuserconfig, edit configdir("`base'_w7") user(bob) quietly
local w7_rc = _rc
capture confirm file "`base'_w7/user_config.yml"
chk, cond(`w7_rc'==601 & _rc!=0) ///
    msg("W7 edit on a missing file errors and creates nothing (rc `w7_rc')")

* W8: -doedit- opens a window a batch run can neither show nor close. This
* suite runs under -stata -b-, so this is the batch path, not a hypothetical.
reset_env
capture getuserconfig, edit configdir("`wdir'") user(bob)
chk, cond("`c(mode)'"!="batch" | (_rc==0 & `"`r(edited)'"'!="")) ///
    msg("W8 edit in batch reports the path instead of opening an editor")

* W9: a home directory with a SPACE in it. "C:/Users/First Last" is ordinary on
* Windows, and it is exactly what a -foreach ... in- over the two candidate
* paths would tear in half, since that command splits its list on spaces.
local wsp "`base'_w9 with space"
reset_env
getuserconfig, create configdir("`wsp'") user(dave) root(F:/spaced) quietly
getuserconfig, configdir("`wsp'") user(dave) quietly
chk, cond("`r(datalib)'"=="F:/spaced") ///
    msg("W9 a config directory containing a space round-trips")

* W10: edit falls back to a file that exists but has no block for this user --
* which is the file you would want opened, in order to add one.
reset_env
capture getuserconfig, edit configdir("`wsp'") user(erin)
chk, cond(_rc==0 & `"`r(edited)'"'!="") ///
    msg("W10 edit opens an existing file even with no block for this user")

* W11: the three outcomes of -create- are distinguishable. r(created) names a
* file this call WROTE; returning it after a no-op would make "your block was
* already there" look identical to "I just wrote it".
local wact "`base'_w11"
reset_env
getuserconfig, create configdir("`wact'") user(frank) root(F:/one) quietly
chk, cond("`r(action)'"=="created" & `"`r(created)'"'!="") ///
    msg("W11a a new file reports action=created with r(created) set")
reset_env
getuserconfig, create configdir("`wact'") user(gina) root(F:/two) quietly
chk, cond("`r(action)'"=="appended" & `"`r(created)'"'!="") ///
    msg("W11b a new block in an existing file reports action=appended")
reset_env
getuserconfig, create configdir("`wact'") user(frank) root(F:/ignored) quietly
chk, cond("`r(action)'"=="unchanged" & `"`r(created)'"'=="") ///
    msg("W11c a no-op reports action=unchanged and returns no r(created)")

* W12: -quietly- silences the reporting on the write paths too. Under -stata -b-
* the edit branch prints instead of opening, and that print has to obey the
* option like every other message the command emits.
reset_env
quietly getuserconfig, edit configdir("`wact'") user(frank) quietly
chk, cond(`"`r(edited)'"'!="") ///
    msg("W12 edit still answers with r(edited) when quietly silences it")

reset_env

*===============================================================================
display _newline as text _dup(80) "="
display as text "L1-L7 -- datalib, library(): resolution and click-state"
display as text _dup(80) "="

* Ported from unicef-drp/datalib-unicef-dev @ v0.9.33 (a66b6b6). These cases pin
* the three behaviours that are easy to break and silent when broken.

adopath ++ "`repo'/src/i"

local liblib "`base'_lib"
capture mkdir "`liblib'"
quietly datalib_makelib, path("`liblib'/datalib") families(demo) quietly

* L1: library() resolves and PUBLISHES the root. Publishing is the point, not a
* side effect -- the navigation links this command writes carry no library()
* option, so without it the next click would resolve somewhere else.
global datalib ""
global datalib_checked ""
capture noisily datalib, library("`liblib'/datalib") country(XAA) year(2015) survey(XHS) clear
chk, cond(`"${datalib}"'!="") ///
    msg("L1 library() publishes the resolved root to the datalib global")

* L2: and memoises it, so a slow network share is not re-probed every call.
chk, cond(`"${datalib_checked}"'==`"${datalib}"') ///
    msg("L2 the validated root is memoised for the session")

* L3: a bad library() is refused up front by datalib_root's find mode, rather
* than surfacing later as a bare "directory not found" from the loader.
global datalib ""
global datalib_checked ""
capture datalib, library("`base'_no_such_library") country(XAA) year(2015) survey(XHS) clear
chk, cond(_rc==198) msg("L3 a library() that is not a library is refused (rc `=_rc')")

* L4: datalib_root is rclass, so resolving mid-command would wipe the click
* state the navigation carries in r(subfoldr). The preamble holds and restores
* r() around the call; this is the case that regresses silently if that is lost.
*
* It has to be the subfoldr() branch: on the country() branch `subfoldr' is
* empty by construction (_foldernav.ado:205-206 returns it verbatim), so
* r(subfoldr) is legitimately "" there and would prove nothing. subfoldr()
* WITHOUT path() also still triggers the resolution, which is what makes this
* the case where hold/restore actually matters.
global datalib "`liblib'/datalib"
global datalib_checked ""
quietly datalib, subfoldr(XAA)
chk, cond(`"`r(subfoldr)'"'!="") ///
    msg("L4 r(subfoldr) survives the resolution (the _return hold contract)")

* L5: a call that supplies BOTH path() and subfoldr() must not re-resolve --
* that pair is the guard's condition, and it is how a caller says "I have already
* decided which tree this is; just list it".
*
* Note for whoever reads this next: the SMCL links _foldernav emits carry
* subfoldr() ALONE (see _foldernav.ado:200) -- they deliberately carry no path()
* and no library(), which is exactly why the resolved root has to be published to
* ${datalib} rather than scoped to one call. So this case pins the guard, not the
* click path; a real click goes through the resolution branch above.
global datalib "`liblib'/datalib"
global datalib_checked "SENTINEL"
quietly capture datalib, subfoldr(XAA) path("`liblib'/datalib")
chk, cond(`"${datalib_checked}"'=="SENTINEL") ///
    msg("L5 path()+subfoldr() together skip the resolution (the guard)")

* L6 -- a section click still resolves AFTER an intervening rclass command.
*
* This is the case the r(subfoldr) chain could not carry. Sibling clicks work
* only because each relays the incoming r(subfoldr) forward with -return add-,
* so the chain is exactly one command deep; a file load in between wipes it,
* and the DOC / PROGRAMS links die at the point they are most useful -- someone
* has just opened the data and now wants the README beside it.
*
* -datalib_root- stands in for the loader here: any rclass command clears r(),
* and this one is hermetic and instant. The assertion that matters is the FIRST
* one -- r(subfoldr) really is gone -- because without it L6 would pass on a
* chain that was never broken.
global datalib "`liblib'/datalib"
global datalib_checked "`liblib'/datalib"
global dtlb_navfoldr ""
global dtlb_navroot  ""
quietly datalib, subfoldr(XAA_2015_XHS_v01_M)
quietly datalib_root, root("`liblib'/datalib")
chk, cond(`"`r(subfoldr)'"'=="") ///
    msg("L6a an intervening rclass command really does wipe r(subfoldr)")

capture noisily datalib, subfoldr(DOC)
chk, cond(_rc==0) ///
    msg("L6b a DOC click still resolves after it (rc `=_rc')")

* L7 -- the memo is scoped to the library it was taken in. A folder is only
* meaningful inside its own library, so pointing datalib somewhere else must
* not resume from a folder that belongs to the old tree. Refusing to guess is
* the whole reason the root is remembered beside the folder.
global datalib "`liblib'"
global datalib_checked "`liblib'"
capture noisily datalib, subfoldr(DOC)
chk, cond(_rc==198) ///
    msg("L7 a memo from another library is refused, not reused (rc `=_rc')")

global dtlb_navfoldr ""
global dtlb_navroot  ""

reset_env
global datalib_checked ""

*===============================================================================
display _newline as text _dup(80) "="
display as text "V1-V6 -- the volume guard: which OS states make _dl_islib skip"
display as text _dup(80) "="

* This guard is what keeps -datalib- from waiting out the operating system's
* own timeout on a dead network share (measured: 366.90 seconds for one call).
* Every case below is hermetic: the volume state is PRE-SET, so guard (1b)
* never shells out, and no case reaches -direxists- -- which is the point, since
* a test that probed a real drive letter would be exactly the wait we removed.
*
* Q: is used because it is conventionally unmapped; nothing here depends on
* that, as no case gets far enough to touch it.

reset_env

* Redirect the persisted dead-volume memo at a tempfile, and mark it loaded so
* guard (0) does not read the operator's real one. Without this the suite writes
* to ~/.datalib/offline_volumes.txt: proving V2 red (guard reverted) lets the
* case fall through to the probe, which records the failure permanently. A test
* that leaves a drive letter in the operator's persistent state is a test that
* can make their library invisible tomorrow.
tempfile memo
global dtlb_deadmemo_file  = subinstr("`memo'", "\", "/", .)
global dtlb_deadmemo_loaded 1

* V1 -- disconnected: skip, and remember it for the rest of the session so the
* remaining candidates on that volume are not probed either.
global dtlb_volstate_Q "disconnected"
global dtlb_dead_Q     ""
quietly _dl_islib "Q:/no_such_library"
chk, cond("`r(skipped_unreachable)'"=="1" & "${dtlb_dead_Q}"=="1") ///
    msg("V1 a disconnected volume is skipped and marked dead")

* V2 -- reconnecting: the state the guard did not know. Windows reports it
* while a share is coming back, and a drive in that state still blocks on
* touch, so it must be dropped on the same terms as a disconnected one.
* Before the fix __dtlb_volstate answered "unknown" here and the fail-safe
* path let the probe through.
global dtlb_volstate_Q "reconnecting"
global dtlb_dead_Q     ""
quietly _dl_islib "Q:/no_such_library"
chk, cond("`r(skipped_unreachable)'"=="1" & "${dtlb_dead_Q}"=="1") ///
    msg("V2 a reconnecting volume is skipped and marked dead, not waited on")

global dtlb_volstate_Q "reconnecting"
global dtlb_dead_Q     ""
quietly _dl_islib "Q:/no_such_library"
chk, cond("`r(volstate)'"=="reconnecting") ///
    msg("V3 the caller is told WHICH state it was, not just that it skipped")

* V4 -- the fail-safe, and the one state that is allowed to CANCEL a memo.
*
* "connected" is not merely permission to fall through; it is evidence that a
* record saying otherwise is stale, so it clears the dead flag. Before this the
* memo was a one-way door: guard (0) reloaded the record, guard (1b) asked the
* OS, was told the drive was fine, and guard (2) skipped it anyway. A share
* that went offline once during a VPN outage stayed invisible for good, and the
* message read "No datalib library at:" for a mounted, healthy directory named
* datalib -- which is what happened to S: on the author's machine.
*
* Q: is unmapped, so this case does reach -direxists- and returns fast on a
* letter with no mapping. Nothing here waits on a network.
tempname vh
file open `vh' using "${dtlb_deadmemo_file}", write text replace
file write `vh' "Q" _n
file write `vh' "W" _n
file close `vh'

global dtlb_volstate_Q "connected"
global dtlb_dead_Q     "1"
quietly _dl_islib "Q:/no_such_library"
chk, cond("${dtlb_dead_Q}"=="" & "`r(skipped_unreachable)'"=="") ///
    msg("V4 a connected volume falls through the guard and stops being dead")

* V5 -- W must survive. Other volumes on that list may still be dead, and their
* record is still worth having. Rewriting the file rather than truncating it is
* the difference between forgetting one drive and forgetting all of them.
local kept ""
file open `vh' using "${dtlb_deadmemo_file}", read text
file read `vh' vline
while (r(eof)==0) {
    local vv = strtrim(`"`macval(vline)'"')
    local kept `"`kept' `vv'"'
    file read `vh' vline
}
file close `vh'
local kept = strtrim("`kept'")
chk, cond("`kept'"=="W") ///
    msg("V5 the record forgets that volume and keeps the others (kept:`kept')")

* V6 -- "unknown" is the answer __dtlb_volstate gives when it cannot classify
* what the OS said: a shell it could not run, a status word in a language it
* does not know. It must fall THROUGH the skip -- a wrong answer there hides a
* reachable library, which is worse than a slow one -- and it must NOT clear a
* memo either, because it is no evidence about the drive at all. Proven without
* a probe by letting guard (2) answer: reaching it proves the volstate guard
* declined, and its answering at all proves the flag was left standing.
global dtlb_volstate_Q "unknown"
global dtlb_dead_Q     "1"
quietly _dl_islib "Q:/no_such_library"
chk, cond("`r(skipped_dead)'"=="1" & "`r(skipped_unreachable)'"=="") ///
    msg("V6 an unclassifiable volume neither skips nor clears (fail-safe)")

* Forgetting all of this is -datalib_config, retryvolumes-, which clears both
* dtlb_volstate_<L> and dtlb_dead_<L> for A-Z (datalib_config.ado:85-88). It is
* not exercised here: it erases the operator's real ~/.datalib/offline_volumes.txt,
* and __dtlb_userhome reads USERPROFILE, which a do-file cannot redirect.
global dtlb_volstate_Q ""
global dtlb_dead_Q     ""

*===============================================================================
display _newline as text _dup(80) "="
display as result "ALL CHECKS PASSED (${dtlb_cfg_n} checks)"
display as text _dup(80) "="

capture log close _all
exit 0
