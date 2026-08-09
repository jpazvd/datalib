*******************************************************
* _foldernav: Folder Navigation Utility
* Author: Joao Pedro Azevedo
* Co-author: Minh Cong Nguyen (World Bank)
*! Version: 1.1       Date: 2026-08-04
* Description:
* This program is designed to navigate through folder structures
* in the datalib repository, enabling the selection of subfolders
* based on the structure of the data collection.
*
* Provenance: ported from unicef-drp/datalib-unicef-dev @ v0.9.33 (a66b6b6)
* stata/src/_/_foldernav.ado. Generalized: none (the utility is generic).
* Before this port the program was defined inline at the bottom of
* _dtlb_load.ado and was never listed in datalib.pkg, so a clean net-install
* left datalib's three _foldernav calls unresolved until _dtlb_load had run
* once in the session. Extracting it fixes that load-order defect.
* Also carries the upstream r()-clobber fix (see the prevfoldr note below),
* with one correction to the upstream copy: its DOC section extracted `vm'
* with subinstr(...,"_","",.) instead of subinstr(...,"_"," ",.).
*******************************************************

capture program drop _foldernav
program define _foldernav, rclass

    version 15

    syntax  [varlist]                     ///
            [in] [if]                     ///
            [,                            ///
                country(string)           ///
                path(string)              ///
                subfoldr(string)          ///
                filename(string)          ///
            ]

    * The DATA / DOC / PROGRAMS sections resume from the folder the PREVIOUS
    * call left in r(subfoldr). Read it once, as a string: any rclass command
    * running between the two calls wipes r(), and -local x = r(subfoldr)- on a
    * missing result yields "." , which used to build "${datalib}/./Data/..."
    * and fail with a confusing r(601).
    local prevfoldr `"`r(subfoldr)'"'

    * Determine subfolder depth and structure
    local stubcnt = wordcount(subinstr("`subfoldr'", "_", " ",.))

    if (`stubcnt'==1) {
        local subfoldr = "`subfoldr'"
    }
    if (`stubcnt'==3) {
        local stub1  = word(subinstr("`subfoldr'", "_", " ",.),1)
        local subfoldr = "`stub1'/`subfoldr'"
    }
    if (`stubcnt'==5) {
        local stub1  = word(subinstr("`subfoldr'", "_", " ",.),1)
        local stub2  = word(subinstr("`subfoldr'", "_", " ",.),2)
        local stub3  = word(subinstr("`subfoldr'", "_", " ",.),3)
        local subfoldr = "`stub1'/`stub1'_`stub2'_`stub3'/`subfoldr'"
    }
    if (`stubcnt'==8) {
        local subfoldr = "`subfoldr'"
        local stub1  = word(subinstr("`subfoldr'", "_", " ",.),1)
        local stub2  = word(subinstr("`subfoldr'", "_", " ",.),2)
        local stub3  = word(subinstr("`subfoldr'", "_", " ",.),3)
        local subfoldr = "`stub1'/`stub1'_`stub2'_`stub3'/`subfoldr'"
    }

    * Set the path based on the provided or default value
    if ("`path'"=="") & ("`subfoldr'" == "") {
        local path "${datalib}/"
    }
    else if ("`path'"=="") & ("`subfoldr'" != "") {
        local path "${datalib}/`subfoldr'/"
    }
    else if ("`path'"!="") & ("`subfoldr'" != "") {
        local path "`path'/`subfoldr'/"
    }

    * Handle navigation for DATA subfolder
    if ("`subfoldr'"=="DATA") {
        local subfoldr `"`prevfoldr'"'
        if (`"`subfoldr'"'=="") | (`"`subfoldr'"'==".") {
            noi di as err `"{p}Cannot open DATA: the folder being navigated is no longer known.{p_end}"'
            noi di as err `"{p}The section links resume from the previous {bf:datalib} call. Re-run the navigation step (for example {bf:datalib, subfoldr(}{it:CCC_YYYY_SURVEY_vNN_M}{bf:)}) and click through again, or address the vintage directly with {bf:datalib, country() year() survey()}.{p_end}"'
            exit 198
        }
        local path "${datalib}/`subfoldr'/Data/Stata/"
        local list : dir "`path'" files "*.dta"

        local laststub = word(subinstr("`subfoldr'","/"," ",.),-1)
        local ctry  = word(subinstr("`laststub'","_"," ",.),1)
        local year  = word(subinstr("`laststub'","_"," ",.),2)
        local svy   = word(subinstr("`laststub'","_"," ",.),3)
        local vm    = word(subinstr("`laststub'","_"," ",.),4)
        local va    = word(subinstr("`laststub'","_"," ",.),6)
        local clct  = word(subinstr("`laststub'","_"," ",.),8)

        noi di in smcl _newline
        noi di in g in smcl "{hline}"
        foreach files in `list' {
            local module = subinstr(word(subinstr("`files'","_"," ",.),-1),".dta","",.)
            noi di in g in smcl `" {stata `"datalib, country(`ctry') year(`year') survey(`svy') vm(`vm') va(`va') collection(`clct') filename(`"`files'"') nomerge clear data "': {bf: `files'}} "'
        }

        noi di in g in smcl "{hline}"
        return add
        return local fullfoldr = "`subfoldr'/Data/Stata/"
        * Stop here. The generic navigation block below is guarded only by
        * ("`subfoldr'"!="DATA"), but this branch has already reassigned
        * subfoldr to the previous folder, so without this -exit- the guard
        * passes, an empty directory listing is printed under Data/Stata, and a
        * spurious r(subfoldr1) is returned (stubcnt is 1 here, from "DATA").
        * The click chain is unaffected: -return add- above already carries the
        * incoming r(subfoldr) into this call's return list, which is what the
        * next DOC/PROGRAMS click reads.
        exit
    }
    * Handle navigation for DOC subfolder
    if ("`subfoldr'"=="DOC") {
        local subfoldr `"`prevfoldr'"'
        if (`"`subfoldr'"'=="") | (`"`subfoldr'"'==".") {
            noi di as err `"{p}Cannot open DOC: the folder being navigated is no longer known.{p_end}"'
            noi di as err `"{p}The section links resume from the previous {bf:datalib} call. Re-run the navigation step (for example {bf:datalib, subfoldr(}{it:CCC_YYYY_SURVEY_vNN_M}{bf:)}) and click through again, or address the vintage directly with {bf:datalib, country() year() survey()}.{p_end}"'
            exit 198
        }
        local path "${datalib}/`subfoldr'/Doc/"
        local list : dir "`path'" files "*"

        local laststub = word(subinstr("`subfoldr'","/"," ",.),-1)
        local ctry  = word(subinstr("`laststub'","_"," ",.),1)
        local year  = word(subinstr("`laststub'","_"," ",.),2)
        local svy   = word(subinstr("`laststub'","_"," ",.),3)
        local vm    = word(subinstr("`laststub'","_"," ",.),4)
        local va    = word(subinstr("`laststub'","_"," ",.),6)
        local clct  = word(subinstr("`laststub'","_"," ",.),8)

        noi di in smcl _newline
        noi di in g in smcl "{hline}"
        foreach files in `list' {
            local module = subinstr(word(subinstr("`files'","_"," ",.),-1),".dta","",.)
            noi di in g in smcl `" {stata `"datalib, country(`ctry') year(`year') survey(`svy') vm(`vm') va(`va') collection(`clct') filename(`"`files'"') nomerge clear doc "': {bf: `files'}} "'
        }

        noi di in g in smcl "{hline}"
        return add
        return local fullfoldr = "`subfoldr'/Doc/"
        * See the note in the DATA branch. DOC was never excluded by the guard
        * below at all, so it always fell through before this -exit-.
        exit
    }
    * Handle navigation for PROGRAMS subfolder
    if ("`subfoldr'"=="PROGRAMS") {
        local subfoldr `"`prevfoldr'"'
        if (`"`subfoldr'"'=="") | (`"`subfoldr'"'==".") {
            noi di as err `"{p}Cannot open PROGRAMS: the folder being navigated is no longer known.{p_end}"'
            noi di as err `"{p}The section links resume from the previous {bf:datalib} call. Re-run the navigation step (for example {bf:datalib, subfoldr(}{it:CCC_YYYY_SURVEY_vNN_M}{bf:)}) and click through again, or address the vintage directly with {bf:datalib, country() year() survey()}.{p_end}"'
            exit 198
        }
        local path "${datalib}/`subfoldr'/Programs/"
        local list : dir "`path'" files "*"

        local laststub = word(subinstr("`subfoldr'","/"," ",.),-1)
        local ctry  = word(subinstr("`laststub'","_"," ",.),1)
        local year  = word(subinstr("`laststub'","_"," ",.),2)
        local svy   = word(subinstr("`laststub'","_"," ",.),3)
        local vm    = word(subinstr("`laststub'","_"," ",.),4)
        local va    = word(subinstr("`laststub'","_"," ",.),6)
        local clct  = word(subinstr("`laststub'","_"," ",.),8)

        noi di in smcl _newline
        noi di in g in smcl "{hline}"
        foreach files in `list' {
            local module = subinstr(word(subinstr("`files'","_"," ",.),-1),".dta","",.)
            noi di in g in smcl `" {stata `"datalib, country(`ctry') year(`year') survey(`svy') vm(`vm') va(`va') collection(`clct') filename(`"`files'"') nomerge clear programs "': {bf: `files'}} "'
        }

        noi di in g in smcl "{hline}"
        return add
        return local fullfoldr = "`subfoldr'/Programs/"
        * See the note in the DATA branch. PROGRAMS, like DOC, was never
        * excluded by the guard below.
        exit
    }


    * Navigate through folders and list available options
    if (`stubcnt'<=8) & ("`subfoldr'"!="DATA") {

        * List available folders in the specified path
        if ("`country'"=="") {
            local list : dir "`path'" dirs "*"
        }
        else {
            local list `"`country'"'
        }

        noi di in smcl _newline
        noi di in g in smcl "{hline}"
        foreach folders in `list' {
            local folders = upper("`folders'")
            noi di in g in smcl `" {stata `"datalib, subfoldr(`folders')"': {bf: `folders'}} "'
        }
        noi di in g in smcl "{hline}"

        * Return the selected subfolder
        return add
        return local subfoldr`stubcnt' = "`subfoldr'"
        return local subfoldr = "`subfoldr'"
    }

end

/*******************************************************
Version History

v1.1 (2026-08-04)
Extracted from _dtlb_load.ado into its own file and added to datalib.pkg, so
that a clean net-install resolves _foldernav without first running _dtlb_load.
Fixed the r()-clobber defect: the DATA / DOC / PROGRAMS sections read
r(subfoldr) after an intervening rclass call had already wiped r(), producing
"." and a confusing r(601); the previous folder is now captured once at entry
and each section fails with an actionable message when it is unavailable.

v1.0 (2024-03-21)
Initial release as an inline utility inside _dtlb_load.ado.
*******************************************************/
