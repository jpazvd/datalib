*******************************************************
** ibge: import PNAD and PNADC files into datalib
* Author: Joao Pedro Azevedo
* Co-author: Minh Cong Nguyen (World Bank)
*! Version: 3.0.2       Date: <2026-08-09>
** Description:
* This program is designed to facilitate the process to import
* PNAD and PNADC files into the datalib repository.
* It requires access to the datazoom suite of programs.
*******************************************************

capture program drop ibge
program define ibge, rclass
    version 15
    syntax  [varlist]                  ///
            [in] [if]                     ///
            [,                            ///
                survey(string)            ///
                country(string)           ///
                year(string)              ///
                original(string)          ///
                saving(string)            ///
                english                   ///  
                ncomp                     ///
                comp81                    ///
                comp92                    ///
                idbas                     ///
                nid                       ///
                idrs                      ///
                norename                  ///
                clean                     ///
                overwrite                 ///
                path(string)            ///
                MODule(string)          ///
                MASter			        ///
                ADAPtation              ///
                collection(string)      ///
                harmonization(string)   ///
                vm(string)              ///
                va(string)              ///
                mkdir                   ///
                modules(string)         ///
                panel                   ///
                skipdatazoom            ///
                NOIsily                  ///
            ]
    *******************************************************
    * validate what we were asked for, BEFORE anything else
    *******************************************************
    * Placed above the datazoom guard on purpose. That guard exits when
    * datazoom is absent, so validation below it would be unreachable on every
    * machine that does not already have datazoom installed -- including every
    * machine on which these messages would otherwise be demonstrated. This
    * block reads locals only, so it costs nothing here.
    *
    * country() used to be declared and discarded: the two -_dtlb_mkdir- calls
    * below hardcoded BRA, so -ibge, country(XAA)- deposited into BRA without
    * comment. IBGE is Brazil's statistics institute and the DataZoom commands
    * are Brazilian, so BRA is the right destination -- but it must be stated,
    * not assumed silently.
    if ("`country'" == "") local country BRA
    local country = upper(strtrim("`country'"))
    if ("`country'" != "BRA") {
        noi di as err `"{p}ibge: {bf:country(`country')} is not available. This module wraps DataZoom's readers for Brazilian household surveys, so BRA is its only destination. Deposit another country's data with {bf:datalib_makelib} or {bf:_dtlb_put}.{p_end}"'
        exit 198
    }

    * survey() reached the dispatcher unchecked, so an unrecognised acronym fell
    * through every branch and returned silently having done nothing. Uppercase
    * here is safe: _dtlb_mkdir uppercases survey itself, the dispatcher tests
    * below wrap their argument in upper(), and the filename stub is built with
    * lower().
    local survey = upper(strtrim("`survey'"))
    if !inlist("`survey'", "PNAD", "PNADC", "PNADCANUAL") {
        noi di as err `"{p}ibge: {bf:survey(`survey')} is not recognised. Choose {bf:PNAD} or {bf:PNADC}.{p_end}"'
        exit 198
    }
    * PNADCANUAL reaches a branch that, until this release, could never execute:
    * it compared upper(survey) against the mixed-case literal "PNADCanual", so
    * no input matched. The literal is fixed below, but the branch has still
    * never run -- it calls datazoom_pnadcontinua_anual, nothing in qa/
    * exercises ibge, and no licence here can run it. Refusing it is honest;
    * shipping an untested path as though it worked is not.
    if ("`survey'" == "PNADCANUAL") {
        noi di as err `"{p}ibge: {bf:survey(PNADCANUAL)} is not yet supported. The annual-PNADC path exists but has never been executed, so it is gated rather than offered. See {bf:help ibge}.{p_end}"'
        exit 198
    }

    * THE PASS-THROUGH TO _dtlb_mkdir, which was declared and never completed.
    * path(), module(), master and adaptation are _dtlb_mkdir's own options, and
    * this command already forwards six of their siblings -- vm(), va(),
    * collection(), harmonization(), mkdir and overwrite. The four were declared
    * beside them and then dropped on the floor, so -ibge, master- deposited an
    * adaptation-less master request into a call that never heard of it.
    *
    * They are wired here rather than deleted precisely because the target
    * exists: deleting would have removed somebody's stated intent, and would
    * have forced the article to retract a claim it can now simply keep.
    if (`"`path'"' == "") local path `"${datalib}"'

    * panel deposits a PANEL adaptation of its own, so a second adaptation
    * would be passed twice (a Stata syntax error) and master would contradict
    * it outright. Refuse the combination rather than silently winning one of
    * them -- silently winning is the defect being repaired.
    if ("`panel'" != "" & ("`master'" != "" | "`adaptation'" != "")) {
        noi di as err `"{p}ibge: {bf:panel} already deposits a PANEL adaptation, so it cannot be combined with {bf:master} or {bf:adaptation}. Drop the flag, or run without {bf:panel}.{p_end}"'
        exit 198
    }

    *******************************************************
    * check if datazoom is installed
    *******************************************************
    cap which datazoom_social
    if (_rc != 0) {
        noi di as err "Datazoom is not installed. Please install it before running this program."
        exit 198
    }
    *******************************************************
    * enable option noisily
    *******************************************************
    if ("`noisily'" != "") {
        local noi "noisily"
    }
    else {
        local noi ""
    }
    *******************************************************
    * check if number of years is consistent with panel data option
    *******************************************************
    if ("`panel'" != "") {
        local yrcount = wordcount("`year'")
        if `yrcount' < 2 {
            noi di as err "Panel expects at least two rounds of PNADC."
            exit 198
        }
        if (wordcount(`"`idbas'  `idrs'  `nid'"') != 1) {
            noi di as err "Panel expects exactly one of: idbas, idrs, nid."
            exit 198
        }
        if ("`saving'" == "") {
            noi di as err "Saving path must be specified when Panel option is selected."
            exit 198
        }
    }
    *******************************************************
    * use makdir to find the path to save files
    *******************************************************
        if ("`saving'" == "") {
            _dtlb_mkdir, path(`path') country(`country') year(`year') survey(`survey') ///
                    vm(`vm') va(`va') collection(`collection') `mkdir' ///
                    module(`module') `master' `adaptation' ///
                    harmonization(`harmonization') `overwrite'
            if ("`vm'"!="") & ("`va'"=="") {
                local saving    "`r(data_M_stata)'"
                local flname    "`r(mast)'"
            }
            if ("`vm'"!="") & ("`va'"!="") {
                local saving    "`r(data_A_stata)'"
                local flname    "`r(adapt)'"
            }
            noi di "Saving path was not specified. Datalib folder convention will be used."
        }
        * check if files exist in destination folder
        local list : dir "`saving'/" files "bra*.dta"
        * if files exist in destination folder, ask if they should be overwritten
        if "`overwrite'" == "" {
            if wordcount(`"`list'"')==3 {
                noi di as err "All DTA Files already exist in destination folder. Select overwrite to replace."
                exit 198
            }
            if ("`modules'" == "") {
                foreach file in `list' {
                    local tmpmod = word(subinstr("`file'","_"," ",.),-1)
                    local modules "`modules' `tmpmod'"
                }
            }
        }
        * start datazoom wrapper
        if (upper("`survey'") == "PNAD") {
            if strpos("`modules'","pes")==0 {
                cap: datazoom_pnad, years(`year') ///
                    original(`original') ///
                    saving(`saving') ///
                    pes `english' ///
                    `ncomp' `comp81' `comp92'
                if (_rc!=0) {
                    noi di ""
                    noi di as err "Error in datazoom_pnad pes `ncomp' `comp81' `comp92'. datazoom_pnad, years(`year') original(`original') saving(`saving') pes `english' `ncomp' `comp81' `comp92'."
                    noi di ""
                }
            }
            if strpos("`modules'","dom")==0 {
                cap: datazoom_pnad, years(`year') ///
                    original(`original') ///
                    saving(`saving') ///
                    dom `english' ///
                    `ncomp' `comp81' `comp92'
                if (_rc!=0) {
                    noi di ""
                    noi di as err "Error in datazoom_pnad dom `ncomp' `comp81' `comp92'. datazoom_pnad, years(`year') original(`original') saving(`saving') dom `english' `ncomp' `comp81' `comp92'."
                    noi di ""
                }
            }
            if strpos("`modules'","both")==0 {
                cap: datazoom_pnad, years(`year') ///
                    original(`original') ///
                    saving(`saving') ///
                    both `english' ///
                    `ncomp' `comp81' `comp92'
                if (_rc!=0) {
                    noi di ""
                    noi di as err "Error in datazoom_pnad both `ncomp' `comp81' `comp92'. datazoom_pnad, years(`year') original(`original') saving(`saving') both `english' `ncomp' `comp81' `comp92'."
                    noi di ""
                }
            }
            * rename files to match naming convention
            if ("`norename'" == "") {
                local list : dir "`saving'/" files "*.dta"
                foreach file in `list' {
                    if (match("`file'","*pes*")==1) {
                        __dtlb_rename "`saving'" "`file'" "`flname'_pes.dta" "`overwrite'"
                    }
                    if (match("`file'","*dom*")==1) {
                        __dtlb_rename "`saving'" "`file'" "`flname'_dom.dta" "`overwrite'"
                    }
                    if ("`comp81'" != "") {
                        local comp "_comp81"
                    }
                    if ("`comp92'" != "") {
                        local comp "_comp92"
                    }
                    local svy "`survey'`year'`comp'.dta"
                    if (match("`file'",lower("`svy'"))==1) {
                        __dtlb_rename "`saving'" "`file'" "`flname'_both.dta" "`overwrite'"
                    }
                }
            }
        }
        if (upper("`survey'") == "PNADC") & ("`panel'" == "") {
            cap: datazoom_pnadcontinua, years(`year') ///
                original(`original') ///
                saving(`saving') ///
                `nid'  ///
                `english'
            if (_rc!=0) {
                noi di as err "Error in datazoom_pnadcontinua. datazoom_pnadcontinua, years(`year') original(`original') saving(`saving') `nid' `idbas' `idrs'."
                exit 198
            }
            * get name of wrksubfolder
            local wrkfolder "`r(folder)'"
            * Always surface datazoom outputs under `saving'; `clean'
            * only decides whether the (now empty) working subfolder is
            * also deleted.
            qui __dtlb_move_and_clean "`saving'/`wrkfolder'" "`saving'" "`overwrite'" "`clean'"
            * rename files to match naming convention
            if ("`norename'" == "") {
                local list : dir "`saving'/" files "*.dta"
                foreach file in `list' {
                    if (match("`file'","*trimestral*")==1) {
                        __dtlb_rename "`saving'" "`file'" "`flname'_tri.dta" "`overwrite'"
                    }
                }
            }
        }
        if (upper("`survey'") == "PNADC") & ("`panel'" != "") {
            if ("`skipdatazoom'" == "") {
                `noi' cap: datazoom_pnadcontinua, years(`year') ///
                    original(`original') ///
                    saving(`saving') ///
                    `idbas' `idrs' ///
                    `english'
                if (_rc!=0) {
                    noi di as err "Error in datazoom_pnadcontinua. datazoom_pnadcontinua, years(`year') original(`original') saving(`saving') `nid' `idbas' `idrs'."
                    exit 198
                }
            }
            * get name of wrksubfolder
            local wrkfolder "`r(folder)'"
            * rename files to match naming convention
            if ("`norename'" == "") {
                local stub "`idbas'`idrs'"
                local list : dir "`saving'/`wrkfolder'/" files "*.dta"
                di `"`list'"'
                if ("`overwrite'" == "overwrite") {
                    local replace replace
                    di "overwriting files"
                }
                if ("`idbas'" == "idbas") {
                    local paneltype = "painel_*_basic"
                }
                if ("`idrs'" == "idrs") {
                    local paneltype = "painel_*_rs"
                }
                qui foreach file in `list' {
                    if (match("`file'","*`paneltype'*")==1) {
                        * get year from dataset (mode year)
                        use "`saving'/`wrkfolder'/`file'", clear
                        noi di "file: `file'"
                        * COVID year exception
                        levelsof Ano
                        if match("`r(levels)'","2023 2024") {
                            local flnyear = 2024
                        }
                        else if match("`r(levels)'","2022 2023") {
                            local flnyear = 2022
                        }
                        else {
                            __dtlb_mode Ano
                            local flnyear = r(mode)
                        }
                        noi di "`flnyear'"
                        * move files from origin to datalib
                        * adaptation is the branch's own, not the caller's --
                        * the combination is refused above, so it cannot double.
                        _dtlb_mkdir, path(`path') country(`country') year(`flnyear') survey(PNADC) ///
                            vm(`vm') va(`va') collection(PANEL) adaptation `mkdir' ///
                            module(`module') ///
                            `overwrite'
                        if ("`vm'"!="") & ("`va'"=="") {
                            local tosaving    "`r(data_M_stata)'"
                            local flname    "`r(mast)'"
                        }
                        if ("`vm'"!="") & ("`va'"!="") {
                            local tosaving    "`r(data_A_stata)'"
                            local flname    "`r(adapt)'"
                        }
                        tempfile tmp
                        gen time = yq(Ano, Trimestre)
                        format time %tq
                        cap: egen id = group(idind)
                        if (_rc!=0) {
                            cap: egen id = group(ind_id)
                        }
                        save "`tmp'"
                        * new name
                        local newname  "`flname'_`stub'.dta"
                        local to "`tosaving'/`newname'"
                        local from = subinstr("`from'","/","\",.)
                        qui copy "`tmp'" "`to'", `replace'
                    }
                }
            }
            * delete pnadcontinua subfolder and its contents with no confirmation needed
            if ("`clean'" == "clean") {
                __dtlb_rmdir "`saving'/`wrkfolder'"
            }
        }
        if (upper("`survey'") == "PNADCANUAL") {
            datazoom_pnadcontinua_anual, years(`year') ///
                original(`original') ///
                saving(`saving') ///
                `english'
            * Always surface datazoom outputs under `saving' so the rename
            * loop below can find them; `clean' only decides whether the
            * (now empty) pnadcontinua subfolder is also deleted.
            qui __dtlb_move_and_clean "`saving'/pnadcontinua" "`saving'" "`overwrite'" "`clean'"
            * rename files to match naming convention
            if ("`norename'" == "") {
                local list : dir "`saving'/" files "*.dta"
                foreach file in `list' {
                    if (match("`file'","*anual*")==1) {
                        __dtlb_rename "`saving'" "`file'" "`flname'_anual.dta" "`overwrite'"
                    }
                }
            }
        }
        return local original "`original'"
        return local saving   "`saving'"
        return add
end


    /*******************************************************
    ** Usage Examples:
    ibge , survey(PNAD) year(1981) original("C:/data/IBGE_FTP_Download/PNAD/1981/Dados/") vm(01) english mkdir ncomp

    ibge , survey(PNAD) year(1981) original("C:/data/IBGE_FTP_Download/PNAD/1981/Dados/") vm(01) english mkdir adaptation comp81 va(01) collection(DTZ81)

    ibge , survey(PNAD) year(1981) original("C:/data/IBGE_FTP_Download/PNAD/1981/Dados/") vm(01) english mkdir adaptation comp81 va(01) collection(DTZ81) overwrite

    ibge , survey(PNAD) year(2001) original("C:/data/IBGE_FTP_Download/PNAD/2001/Dados/") vm(01) english mkdir adaptation comp81 va(01) collection(DTZ81) overwrite

    ibge , survey(PNAD) year(2001) original("C:/data/IBGE_FTP_Download/PNAD/2001/Dados/") vm(01) english mkdir adaptation comp92 va(01) collection(DTZ92) overwrite

    ibge , survey(PNAD) year(1981) original("C:/data/IBGE_FTP_Download/PNAD/1981/Dados/") vm(01) english mkdir adaptation comp81 va(01) collection(DTZ81)

    ibge , survey(PNAD) year(2009) original("C:\data\IBGE_FTP_Download\PNAD\reponderacao_2001_2009/2009/Dados")      vm(01) english mkdir adaptation comp92 va(01) collection(DTZ92)

    ibge , survey(PNAD) year(2001) original("C:\data\IBGE_FTP_Download\PNAD\reponderacao_2001_2009/2001/Dados") vm(01) english mkdir adaptation comp81 va(01) collection(DTZ81) overwrite

    ibge , survey(PNAD) year(2001) original("C:\data\IBGE_FTP_Download\PNAD\reponderacao_2001_2012/2001/Dados") vm(02) english mkdir adaptation comp81 va(01) collection(DTZ81) overwrite

    ibge , survey(PNAD) year(2009) original("C:\data\IBGE_FTP_Download\PNAD\reponderacao_2001_2012/2009/Dados") vm(02) english mkdir adaptation comp92 va(01) collection(DTZ92) overwrite

    ibge , survey(PNADC) year(2020) original("C:/data/IBGE_FTP_Download/PNADC/2020/") vm(01) english mkdir nid

    ibge , survey(PNADC) year(2018) original("C:/data/IBGE_FTP_Download/PNADC/2020/") vm(01) english mkdir nid


    datazoom_pnadcontinua, years( 2016 2017 )     ///
        original(C:\data\IBGE_FTP_Download\PNADC\Panel) ///
        saving(D:\) idrs

    datazoom_pnadcontinua, years( 2016  )     ///
        original(C:\data\IBGE_FTP_Download\PNADC\Panel) ///
        saving(c:\tmp) idrs

    datazoom_pnadcontinua, years( 2016 2017 1018) ///
        original(C:\data\IBGE_FTP_Download\PNADC\Panel) ///
        saving(D:\) idbas


    ibge , survey(PNADC) panel idbas ///
        year(2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024) ///
        original("C:/data/IBGE_FTP_Download/PNADC/Panel/") vm(01) va(01) english ///
        overwrite mkdir saving("C:/tmp") noisily


    ibge , survey(PNADC) panel idrs ///
        year(2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024) ///
        original("C:/data/IBGE_FTP_Download/PNADC/Panel/") vm(01) va(01) english ///
        overwrite mkdir saving("C:/tmp") noisily



/*******************************************************
** Version History and Feature Evolution of `ibge.ado`

** Version 1.0.0 - 2024-08-18
- Initial Release:
  - Introduced the `ibge.ado` program to facilitate importing PNAD files into the datalib repository.
  - Key Features:
    - Supported basic PNAD files using the `datazoom_pnad` command.
    - Provided options for specifying survey year, file paths, and parameters like `english`, `ncomp`, `comp81`, and `comp92`.
    - Included the `mkdir` option for creating directories according to the datalib folder structure.
    - Implemented initial file renaming conventions based on the module type (household or individual data).

** Version 1.0.1 - 2024-08-18
- Enhancements:
  - Added the `overwrite` option to allow users to overwrite existing files in the destination folder without manual deletion.

** Version 2.0.0 - 2024-08-18
- Major Update:
  - Added support for PNAD Contínua Anual data with the `PNADCanual` option.
  - Introduced the `both` option, enabling the merging of household (`dom`) and individual (`pes`) data modules into a single file.
  - Improved file handling, including advanced renaming based on the module type and survey type.
  - Enhanced cleanup process for temporary folders created during the import process.

** Version 3.0.0 - 2024-08-22
- Enhancements:
  - Added `mode.ado` to compute the mode of numeric variables.
  - Introduced support for panel data using the `panel` option with `IDRS` and `IDBAS` identifiers.
  - Expanded error handling and enhanced the `datazoom` integration to support noisily and skip options.
  - Improved validation for panel data, ensuring that the correct number of years is provided.

*******************************************************/



