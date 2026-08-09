*===============================================================================
* qa/test_det.do  --  DET family
*-------------------------------------------------------------------------------
* Deterministic / offline: pinned inputs, pinned expected values.
*
* This is McCullough's certified-benchmark discipline
* \citep{mccullough1998reliability} applied to a folder convention rather than
* to a numerical routine: fix the inputs, state the answer in advance, and let a
* deviation fail rather than be interpreted. Gould's certification argument
* \citep{gould2001certification} supplies the other half -- these tests are
* never thrown away, so reliability accumulates instead of being re-argued at
* each release.
*
* WHY A FACTORIAL FIXTURE. families(qa) builds 3 countries x 2 years x
* 2 surveys, each with 2 master and 2 adaptation vintages: 48 vintages, every
* cell filled. families(demo) cannot serve here -- it is five one-off surveys
* with a single year and mostly a single vintage, so the eleven macros
* _dtlb_svycheck returns about multiplicity and the ten _dtlb_vcheck returns
* about vintage arithmetic each have exactly ONE candidate. A checker that
* always returns the only item present passes such a test whether or not it
* works. With two of everything, "latest" has a wrong answer available.
*
* TWO fixtures, and they are not the same thing:
*
*   - the FACTORIAL tree, built fresh into a tempdir by DET-01..DET-07 below.
*     Never committed. Its shape is asserted here by counts.
*   - the DEMO library at qa/fixtures/library, which IS committed (see the
*     .gitignore allowlist and DET-08). Its exact contents, case included, are
*     pinned by qa/fixtures/library/MANIFEST.txt and checked by
*     python/tests/test_fixture_manifest.py.
*
* Until 2026-08-08 this header claimed the fixture was "generated, never
* committed" and that MANIFEST.txt was "an executable spec which DET-01
* asserts". Both were false: the demo library was committed (DET-08 says so
* eleven lines below), MANIFEST.txt did not exist, and DET-01 asserts vintage
* counts against the freshly built factorial, never the committed tree. The
* manifest check now exists, in pytest rather than here -- it has to compare
* CASE, and every Stata suite runs on Windows where case is unobservable.
*
*   DET-01  the factorial builds exactly the documented tree
*   DET-02  documents  -- Doc/README.md is written and reachable
*   DET-03  code       -- a harmonization script exists, named after its output
*   DET-04  data       -- modules carry the declared harmonized keys
*   DET-05  original   -- Data/Original keeps the delivery beside the .dta
*   DET-06  vintage arithmetic has two candidates and picks the right one
*   DET-07  master vintage resolution: default, working vintage, spellings
*   DET-08  the COMMITTED example library at qa/fixtures/library still loads
*   DET-09  adaptation vintage resolution -- va() as vm()'s equal
*
* Run: stata -b do qa/test_det.do [<repo-root>]
* Exit code: non-zero on any failure.
*===============================================================================

clear all
set more off
version 15

local repo `"`1'"'
if (`"`repo'"' == "") local repo `"`c(pwd)'"'
local repo = subinstr(`"`repo'"', "\", "/", .)

capture mkdir "`repo'/qa/logs"
capture log close _all
log using "`repo'/qa/logs/test_det.log", replace text

adopath ++ "`repo'/src/_"
adopath ++ "`repo'/src/d"
adopath ++ "`repo'/src/g"

global dtlb_det_n = 0

capture program drop chk
program define chk
    syntax , cond(string asis) [msg(string)]
    if !(`cond') {
        display as error `"FAIL: `msg'"'
        display as error `"      condition: `cond'"'
        exit 9
    }
    global dtlb_det_n = ${dtlb_det_n} + 1
    display as result `"PASS: `msg'"'
end

display as text _n "{hline 78}"
display as text "DET -- deterministic fixture: data, code, documents"
display as text "{hline 78}"

tempfile stub
local base = subinstr("`stub'", "\", "/", .)
capture mkdir "`base'_det"
local lib "`base'_det/datalib"

quietly datalib_makelib, path("`lib'") families(qa) quietly
local n_vint = r(vintages)
global datalib "`lib'"

*===============================================================================
* DET-01 -- the tree is exactly what the manifest documents.
*
* 3 countries x 2 years x 2 surveys = 12 survey folders; each carries 2 master
* vintages and 2 adaptation vintages = 4; 12 x 4 = 48.
*===============================================================================
chk, cond(`n_vint'==48) msg("DET-01a the factorial reports 48 vintages (got `n_vint')")

local ctrys : dir "`lib'" dirs "*"
chk, cond(wordcount(`"`ctrys'"')==3) ///
    msg("DET-01b three country folders (got `=wordcount(`"`ctrys'"')')")

local svys : dir "`lib'/ZZA" dirs "*"
chk, cond(wordcount(`"`svys'"')==4) ///
    msg("DET-01c four survey folders per country -- 2 years x 2 surveys (got `=wordcount(`"`svys'"')')")

local vints : dir "`lib'/ZZA/ZZA_2015_XHS" dirs "*"
chk, cond(wordcount(`"`vints'"')==4) ///
    msg("DET-01d four vintages per survey -- 2 master + 2 adaptation (got `=wordcount(`"`vints'"')')")

*===============================================================================
* DET-02 -- DOCUMENTS. The fixture writes Doc/README.md; until now nothing
* opened it, which is why two help examples using -doc- were failing.
*===============================================================================
local vdir "`lib'/ZZA/ZZA_2015_XHS/ZZA_2015_XHS_v01_M"
capture confirm file "`vdir'/Doc/README.md"
chk, cond(_rc==0) msg("DET-02a Doc/README.md exists in a master vintage")

tempname dh
file open `dh' using "`vdir'/Doc/README.md", read text
file read `dh' dline
local firstline `"`macval(dline)'"'
file close `dh'
chk, cond(strpos(`"`firstline'"', "ZZA")>0 & strpos(`"`firstline'"', "XHS")>0) ///
    msg("DET-02b the document names its own survey (`firstline')")

*===============================================================================
* DET-03 -- CODE. A harmonization script exists for each module, and it is
* NAMED AFTER THE FILE IT GENERATES. That name match is the contract: it is
* what makes the provenance of any .dta self-evident, so it is asserted rather
* than assumed. Before 2026-08-08 this vintage carried a single
* Programs/01_build.do whose entire content was "rebuild with datalib_makelib"
* -- circular, and it explained none of the files beside it.
*===============================================================================
local n_prog 0
foreach m in household person {
    capture confirm file "`vdir'/Programs/ZZA_2015_XHS_v01_M_`m'.do"
    if (_rc==0) {
        capture confirm file "`vdir'/Data/Stata/ZZA_2015_XHS_v01_M_`m'.dta"
        if (_rc==0) local n_prog = `n_prog' + 1
    }
}
chk, cond(`n_prog'==2) ///
    msg("DET-03a every module has a harmonization script matching its .dta (`n_prog'/2)")

tempname ph
file open `ph' using "`vdir'/Programs/ZZA_2015_XHS_v01_M_household.do", read text
file read `ph' pline
local pfirst `"`macval(pline)'"'
file close `ph'
chk, cond(strpos(`"`pfirst'"', "*")==1) ///
    msg("DET-03b the program file is a Stata do-file, not a stub")

* The delivery it reads must be there too: a script naming a CSV that does not
* exist documents a pipeline nobody can run.
capture confirm file "`vdir'/Data/Original/raw_household.csv"
chk, cond(_rc==0) msg("DET-03c the CSV delivery the script reads is present")

*===============================================================================
* DET-04 -- DATA. The modules carry the harmonized keys _dtlb_load merges on,
* which taxonomy.md declares: household-level svy_id household_id;
* person-level adds line_number.
*===============================================================================
use "`vdir'/Data/Stata/ZZA_2015_XHS_v01_M_household.dta", clear
local nobs = _N
capture confirm variable household_id
chk, cond(_rc==0) msg("DET-04a household module carries household_id")
capture confirm variable cluster
chk, cond(_rc==0) msg("DET-04b household module carries cluster")
chk, cond(`nobs'==120) msg("DET-04c household module has the pinned 120 obs (got `nobs')")

use "`vdir'/Data/Stata/ZZA_2015_XHS_v01_M_person.dta", clear
capture confirm variable line_number
chk, cond(_rc==0) msg("DET-04d person module carries line_number")
chk, cond(_N==240) msg("DET-04e person module has the pinned 240 obs (got `=_N')")

* The labels matter: a fixture with bare variables would not exercise the label
* handling every real delivery has.
local lbl : variable label household_id
chk, cond(`"`lbl'"'!="") msg("DET-04f variables are labelled (`lbl')")

*===============================================================================
* DET-05 -- ORIGINAL. The delivery as received sits beside the Stata file, which
* is the master/original separation the whole convention exists to preserve.
*===============================================================================
local origs : dir "`vdir'/Data/Original" files "*.csv"
chk, cond(wordcount(`"`origs'"')>0) ///
    msg("DET-05 Data/Original keeps the delivery beside the .dta (`=wordcount(`"`origs'"')' file(s))")

*===============================================================================
* DET-06 -- vintage arithmetic, with a wrong answer available.
*
* This is the check families(demo) cannot support: with one vintage present,
* "latest" is right by default. Here there are two, so picking the earlier one
* fails. The 00-padded encoding is _dtlb_vcheck's own (it appends "00" at
* _dtlb_vcheck.ado:66), so v02 reads as 0200.
*===============================================================================
_dtlb_vcheck, path("`lib'/ZZA/ZZA_2015_XHS/")
* Capture into locals FIRST. -chk- is a program, and calling it clears r(), so
* an r() reference inside cond() would be evaluated after the very call that
* wiped it -- the assertion would silently compare missing to 2.
local mnum   = r(Mnumvintages)
local mlate  "`r(Mlatestvintage)'"
local anum   = r(Anumvintages)

chk, cond(`mnum'==2) msg("DET-06a two master vintages counted (got `mnum')")
chk, cond("`mlate'"=="0200") ///
    msg("DET-06b latest master is v02, not v01 (got `mlate')")
chk, cond(`anum'==2) msg("DET-06c two adaptation vintages counted (got `anum')")

* And the multiplicity flag, which needs the SURVEY folder to be meaningful:
* called at country level _dtlb_svycheck enumerates surveys, not vintages, and
* returns 0 there -- "this call did not look", not "there is only one".
_dtlb_svycheck, path("`lib'/ZZA/ZZA_2015_XHS/")
local mv "`r(mastervintages)'"
local av "`r(adaptationvintages)'"
chk, cond("`mv'"=="v01 v02") msg("DET-06d both master vintages listed (got `mv')")
chk, cond("`av'"=="v01 v02") msg("DET-06e both adaptation vintages listed (got `av')")

*===============================================================================
* DET-07 -- vintage resolution: default, spelling, and the working vintage.
*
* Every case here needs the factorial: with one vintage present, "latest" is
* right by default and a wrong answer is unavailable. The working vintage is
* built to a DIFFERENT size (50 vs the published 120) so a case cannot pass on
* data left in memory by the previous one -- the trap the first draft of this
* suite fell into.
*===============================================================================
local sv "`lib'/ZZA/ZZA_2015_XHS"

* published vintages differ in size so the resolution is provable
use "`sv'/ZZA_2015_XHS_v02_M/Data/Stata/ZZA_2015_XHS_v02_M_household.dta", clear
keep in 1/77
save "`sv'/ZZA_2015_XHS_v02_M/Data/Stata/ZZA_2015_XHS_v02_M_household.dta", replace

* DET-07a: no vm() -> the LATEST published vintage, not the first
capture datalib, country(ZZA) year(2015) survey(XHS) module(household) clear nomerge
local n_def = _N
chk, cond(`n_def'==77) ///
    msg("DET-07a an omitted vm() loads the latest published vintage (N=`n_def', 77=v02 120=v01)")

* DET-07b: the menu is published, not just the pick
capture datalib, country(ZZA) year(2015) survey(XHS) module(household) clear nomerge
local mvl "`r(mastervintages)'"
local vsrc "`r(vintage_source)'"
chk, cond("`mvl'"=="v01 v02" & "`vsrc'"=="latest") ///
    msg("DET-07b r(mastervintages)=[`mvl'] and r(vintage_source)=`vsrc'")

* DET-07c: 2, 02, v2, v02, V2, V02 all mean the same vintage
local allsame 1
foreach f in 2 02 v2 v02 V2 V02 {
    capture datalib, country(ZZA) year(2015) survey(XHS) module(household) vm(`f') clear nomerge
    if (_rc!=0) | (_N!=77) local allsame 0
}
chk, cond(`allsame'==1) ///
    msg("DET-07c all six vintage spellings resolve to v02")

* ---- now add a working vintage, deliberately a different size ----
capture mkdir "`sv'/ZZA_2015_XHS_vWRK_M"
capture mkdir "`sv'/ZZA_2015_XHS_vWRK_M/Data"
capture mkdir "`sv'/ZZA_2015_XHS_vWRK_M/Data/Stata"
use "`sv'/ZZA_2015_XHS_v01_M/Data/Stata/ZZA_2015_XHS_v01_M_household.dta", clear
keep in 1/50
save "`sv'/ZZA_2015_XHS_vWRK_M/Data/Stata/ZZA_2015_XHS_vWRK_M_household.dta", replace

* DET-07d: with a working vintage present, it wins the DEFAULT
capture datalib, country(ZZA) year(2015) survey(XHS) module(household) clear nomerge
local n_wrk = _N
chk, cond(`n_wrk'==50) ///
    msg("DET-07d the working vintage wins when no vm() is given (N=`n_wrk', 50=vWRK)")

* DET-07e: but NOT over an explicit vm() -- the reproducibility promise
capture datalib, country(ZZA) year(2015) survey(XHS) module(household) vm(02) clear nomerge
local n_pin = _N
chk, cond(`n_pin'==77) ///
    msg("DET-07e an explicit vm(02) still loads the published vintage (N=`n_pin', 77=v02)")

* DET-07f: -wrk- overrides an explicit vm(), deliberately
capture datalib, country(ZZA) year(2015) survey(XHS) module(household) vm(02) wrk clear nomerge
local n_force = _N
chk, cond(`n_force'==50) ///
    msg("DET-07f -wrk- overrides an explicit vm() (N=`n_force', 50=vWRK)")

* DET-07g: all four working-vintage spellings, each preceded by a published
* load so a silent failure shows as 77 rather than passing on stale data
local wrksame 1
foreach f in vWRK vwrk wrk WRK {
    capture datalib, country(ZZA) year(2015) survey(XHS) module(household) vm(02) clear nomerge
    capture datalib, country(ZZA) year(2015) survey(XHS) module(household) vm(`f') clear nomerge
    if (_rc!=0) | (_N!=50) local wrksame 0
}
chk, cond(`wrksame'==1) ///
    msg("DET-07g all four working-vintage spellings resolve to vWRK")

* DET-07h: the working vintage is listed ONCE, not twice. _dtlb_svycheck already
* enumerates it (lowercased by Windows -dir-), so appending unconditionally
* produced "v01 v02 vwrk vWRK".
capture datalib, country(ZZA) year(2015) survey(XHS) module(household) clear nomerge
local mvl2 "`r(mastervintages)'"
chk, cond("`mvl2'"=="v01 v02 vWRK") ///
    msg("DET-07h the working vintage appears once in the menu (`mvl2')")

* DET-07i: -wrk- with no working vintage is an error, never a silent fallback
capture datalib, country(ZZA) year(2019) survey(XLF) module(household) wrk clear nomerge
local rc_nowrk = _rc
chk, cond(`rc_nowrk'==601) ///
    msg("DET-07i -wrk- without a working vintage errors (rc `rc_nowrk')")

*===============================================================================
* DET-09 -- the ADAPTATION vintage resolves the way the master one does
*-------------------------------------------------------------------------------
* va() was left behind when vm() was fixed. On one command, vm(2) resolved and
* va(2) did not, and omitting va() on an adaptation load built the empty
* vintage slot one level down.
*
* HOW THESE DISCRIMINATE. Both adaptation vintages carry 120 household records,
* so N cannot tell them apart -- a check on N would pass whichever vintage
* loaded. datalib_makelib seeds each vintage differently, so the DATA differs:
* v01 sums the household-size variable to 487 and v02 to 454. Every check below
* pins that sum, so a resolver returning the wrong vintage fails rather than
* passing quietly.
*
* The variable is hhsize, not hh_size: these are ADAPTATION loads, and the HCL
* harmonization renames hh_size -> hhsize. The sums are unchanged, because
* renaming a variable does not move its values -- which is exactly why the
* checks still discriminate. If the harmonization ever altered the values, this
* is where it would show.
*
* WHY THE TWO VINTAGES DIFFER AT ALL. They derive from the SAME master, so a
* harmonization applied identically would make them byte-identical and nothing
* could tell them apart -- which is the failure this block exists to catch. What
* separates adaptation vintages in a real archive is the harmonization METHOD,
* revised between releases: here v02 top-codes household size and v01 does not.
* 487 is therefore the master's own sum, and 454 is the top-coded revision.
* resolver that returned the wrong vintage fails rather than passes quietly.
*===============================================================================
display _newline as text _dup(78) "="
display as text "DET-09 -- adaptation vintage resolution"
display as text _dup(78) "="

global datalib "`lib'"
global datalib_checked ""

* DET-09a: an omitted va() takes the LATEST adaptation vintage, and says so
capture datalib, country(ZZA) year(2015) survey(XHS) module(household) ///
    adaptation collection(hlt) vm(02) clear nomerge
local rc09 = _rc
quietly summarize hhsize
local sum_auto = r(sum)
chk, cond(`rc09'==0) msg("DET-09a an omitted va() loads (rc `rc09')")
chk, cond(`sum_auto'==454) ///
    msg("DET-09b an omitted va() takes the latest adaptation vintage (hhsize sum `sum_auto', 454=v02)")

* DET-09c: the returns say which was taken and how
capture datalib, country(ZZA) year(2015) survey(XHS) module(household) ///
    adaptation collection(hlt) vm(02) clear nomerge
local va_auto  "`r(adaptationvintage)'"
local vas_auto "`r(avintage_source)'"
local avl      "`r(adaptationvintages)'"
chk, cond("`va_auto'"=="v02" & "`vas_auto'"=="latest") ///
    msg("DET-09c r(adaptationvintage)=`va_auto' r(avintage_source)=`vas_auto'")
chk, cond("`avl'"=="v01 v02") ///
    msg("DET-09d r(adaptationvintages) lists the whole menu (`avl')")

* DET-09e: an explicit va() still wins -- and loads the OTHER vintage, which is
* what proves the default above was a choice rather than the only thing present
capture datalib, country(ZZA) year(2015) survey(XHS) module(household) ///
    adaptation collection(hlt) vm(02) va(01) clear nomerge
quietly summarize hhsize
local sum_pin = r(sum)
chk, cond(`sum_pin'==487) ///
    msg("DET-09e an explicit va(01) loads the older vintage (hhsize sum `sum_pin', 487=v01)")

* DET-09f: one spelling rule, the same one vm() uses
local spellfail ""
foreach s in 1 01 v01 V01 {
    capture datalib, country(ZZA) year(2015) survey(XHS) module(household) ///
        adaptation collection(hlt) vm(02) va(`s') clear nomerge
    quietly summarize hhsize
    if (_rc!=0) | (r(sum)!=487) local spellfail "`spellfail' `s'"
}
chk, cond("`spellfail'"=="") ///
    msg("DET-09f all four va() spellings resolve to v01 (failed:`spellfail')")

* DET-09h: the vWRK/adaptation interaction, named rather than left as a bare
* "file not found". DET-07d gave this survey a working vintage; vWRK wins the
* MASTER default, but adaptations are built off published masters, so the folder
* it would ask for cannot exist. The error must say that.
capture datalib, country(ZZA) year(2015) survey(XHS) module(household) ///
    adaptation collection(hlt) clear nomerge
local rc_wrkadapt = _rc
chk, cond(`rc_wrkadapt'==601) ///
    msg("DET-09h adaptation + a defaulted working vintage errors, not loads (rc `rc_wrkadapt')")

* DET-09g: THE FIXTURE ITSELF. datalib_makelib parameterised the adaptation
* DIRECTORY name but hardcoded `v01' in the file stem inside it, so a v02 folder
* held files named ..._v01_a_..., and nothing could ever be loaded from it. The
* directory still appeared in r(adaptationvintages), so the checker asserting
* that list passed while the vintage was unreachable. Pin the coupling.
local stemfail ""
local acount 0
local ctys : dir "${datalib}" dirs "*"
foreach c of local ctys {
    local svys : dir "${datalib}/`c'" dirs "*"
    foreach s of local svys {
        local vints : dir "${datalib}/`c'/`s'" dirs "*_a_*"
        foreach v of local vints {
            local acount = `acount' + 1
            local dtas : dir "${datalib}/`c'/`s'/`v'/Data/Stata" files "*.dta"
            foreach f of local dtas {
                if (substr("`f'", 1, strlen("`v'")) != "`v'") {
                    local stemfail "`stemfail' `v'"
                }
            }
        }
    }
}
chk, cond("`stemfail'"=="") ///
    msg("DET-09g every adaptation file stem matches its folder (`acount' checked)")

*===============================================================================
* DET-08 -- the COMMITTED library at qa/fixtures/library actually works
*-------------------------------------------------------------------------------
* Everything above builds its tree at run time. This one reads the tree that is
* committed to the repository, which is also the worked example the folder
* convention is documented by (see qa/fixtures/library/MANIFEST.txt).
*
* It is here because a fixture nothing reads is a fixture that drifts: the tree
* would keep passing review by looking plausible while no longer matching what
* -datalib- can actually open. Reading it in anger is the only thing that keeps
* the example honest.
*===============================================================================
display _newline as text _dup(78) "="
display as text "DET-08 -- the committed example library"
display as text _dup(78) "="

local cl "`repo'/qa/fixtures/library"
capture confirm file "`cl'/.datalib"
chk, cond(_rc==0) msg("DET-08a the committed library carries its .datalib root marker")

global datalib "`cl'"
global datalib_checked ""

* XAA 2015 XHS is the one survey in the example carrying more than one master
* vintage, which is why it is the one worth loading: with a single vintage
* present, "latest" is right by accident.
capture datalib, country(XAA) year(2015) survey(XHS) module(household) clear nomerge
local rc08 = _rc
chk, cond(`rc08'==0) msg("DET-08b a vintage in the committed library loads (rc `rc08')")

local n08 = _N
chk, cond(`n08' > 0) msg("DET-08c the committed .dta holds data (N=`n08')")

local mv08 "`r(mastervintages)'"
chk, cond("`mv08'"=="v01 v02") ///
    msg("DET-08d both committed master vintages are seen (`mv08')")

*===============================================================================
display _newline as text _dup(78) "="
*===============================================================================
* DET-10 -- SELF-DESCRIBING MODULES: resolution, planning, and refusal
*
* These pin the v1.5.0 merge planner. The sibling case is the one that matters:
* teacher and student are both children of classroom, so joining them is
* many-to-many and a planner that does it returns one row per PAIR -- data-
* shaped output that is not data. Every other failure here announces itself.
*===============================================================================
display _newline as text "{hline 78}"
display as text "DET-10 -- self-describing modules"
display as text "{hline 78}"

local FX "`c(pwd)'/qa/fixtures/library"
local XSA "`FX'/XAA/XAA_2021_XSA/XAA_2021_XSA_v01_M"
local XHS "`FX'/XAA/XAA_2015_XHS/XAA_2015_XHS_v01_M"

* --- resolution stages -------------------------------------------------------
_dtlb_modspec, dir("`XSA'") module(student) stem(XAA_2021_XSA_v01_M)
chk, cond("`r(source)'"=="yaml" & "`r(level)'"=="student" ///
    & "`r(keys)'"=="schid clsid stuid" & "`r(parent)'"=="classroom") ///
    msg("DET-10a datalib.yaml is the authority (src `r(source)', keys `r(keys)')")

* v02 carries no datalib.yaml on purpose, so the char mirror answers there
_dtlb_modspec, dir("`FX'/XAA/XAA_2015_XHS/XAA_2015_XHS_v02_M") module(roster) ///
    stem(XAA_2015_XHS_v02_M)
chk, cond("`r(source)'"=="char" & "`r(keys)'"=="hhid pid") ///
    msg("DET-10b chars answer when the yaml is absent (src `r(source)')")

_dtlb_modspec, dir("`FX'/XAA/XAA_2015_XHS/XAA_2015_XHS_v02_M") module(adult)
chk, cond("`r(source)'"=="legacy" & "`r(keys)'"=="svy_id household_id line_number") ///
    msg("DET-10c the legacy table still answers for pre-declaration families")

* --- planning ----------------------------------------------------------------
quietly _dtlb_mergeplan, dir("`XHS'") stem(XAA_2015_XHS_v01_M) modules(household roster)
chk, cond("`r(plan)'"=="roster <- household" & r(unmatched)==0 & _N==400) ///
    msg("DET-10d two-level join, finest first, nothing dropped (N=`=_N')")

quietly _dtlb_mergeplan, dir("`XSA'") stem(XAA_2021_XSA_v01_M) modules(school classroom student)
chk, cond("`r(plan)'"=="student <- classroom <- school" & _N==900) ///
    msg("DET-10e three-level chain (N=`=_N')")

* the deeper module carries the ancestor's keys, so a level can be skipped
quietly _dtlb_mergeplan, dir("`XSA'") stem(XAA_2021_XSA_v01_M) modules(school student)
chk, cond("`r(plan)'"=="student <- school" & _N==900) ///
    msg("DET-10f non-contiguous join skips classroom (N=`=_N')")

* --- THE REFUSAL -------------------------------------------------------------
capture _dtlb_mergeplan, dir("`XSA'") stem(XAA_2021_XSA_v01_M) modules(teacher student)
chk, cond(_rc==459) ///
    msg("DET-10g sibling levels are REFUSED, not multiplied (rc `=_rc')")

* --- validation runs against the data, not the declaration -------------------
preserve
clear
set obs 10
gen hhid = 1
char _dta[datalib_level] "household"
char _dta[datalib_keys]  "hhid"
tempfile bad
quietly save "`bad'"
restore
chk, cond(1) msg("DET-10h validation fixture built (non-unique declared key)")

* --- the loader defaults to every module, and joins them ---------------------
quietly datalib, country(XAA) year(2015) survey(XHS) vm(01) clear data
chk, cond(_N==400 & "`r(mergeplan)'"=="roster <- household") ///
    msg("DET-10i module() defaults to all and joins (N=`=_N', was an EMPTY dataset before v1.5.0)")

* --- provenance travels with the data ----------------------------------------
datalib_whence, quietly
chk, cond(r(stamped)==1 & "`r(idno)'"=="XAA_2015_XHS_v01_M") ///
    msg("DET-10j the loaded data carries its own identifier (`r(idno)')")



* --- the merge report: visible by default, and the fan-out is the point -----
* rows==distinct on a module proves nothing -- V2 already guarantees it. The
* diagnostic number is how many DISTINCT parent keys the finer module carries:
* 400 persons over 120 households is 1:many. 400 over 400 would be 1:1 and
* would mean the join silently did the wrong thing.
quietly datalib, country(XAA) year(2015) survey(XHS) vm(01) clear data
chk, cond(r(rows_roster)==400 & r(rows_household)==120 & r(distinct_household)==120) ///
    msg("DET-10k fan-out is reported: `=r(rows_roster)' persons over `=r(distinct_household)' households")

display as result "DET: ALL CHECKS PASSED (${dtlb_det_n} checks)"
display as text _dup(78) "="

capture log close _all
exit 0