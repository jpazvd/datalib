*! _dtlb_check v0.1  |  datalib / UNICEF  |  IHSN structural conformance validator
*!
*! Validates a datalib survey archive against the IHSN / World Bank Microdata
*! Library folder template and ENFORCES the separation between MASTER (_M,
*! original data as provided) and HARMONIZED (_A_CLCT, adaptation/collection)
*! version folders.
*!
*! Template checked (per version folder), as created by _dtlb_mkdir.ado:
*!     CCC_YYYY_SSSS/
*!         CCC_YYYY_SSSS_vNN_M/                     <- MASTER (required)
*!             Data/{Original,Stata,Other}  Doc  Programs
*!         CCC_YYYY_SSSS_vNN_M_vNN_A_CLCT/          <- HARMONIZED (0+)
*!             Data/{Original,Stata,Other}  Doc  Programs
*!
*! Syntax:
*!     _dtlb_check , Path(string) [ Country(string) Survey(string) STRICT ]
*!
*! Returns: r(violations) r(surveys) r(master) r(harmonized)
*! With -strict-, exits with error 459 if any violation is found (use in pipelines).

program define _dtlb_check, rclass
    version 15
    syntax , Path(string) [ Country(string) Survey(string) STRICT ]

    * Required skeleton per version folder
    local reqtop  "Data Doc Programs"
    local reqdata "Original Stata Other"

    * Root must exist
    mata: st_local("pex", strofreal(direxists("`path'")))
    if (`pex' == 0) {
        di as err "IHSN check: datalib root not found -> `path'"
        exit 601
    }

    local nviol = 0
    local nsurvey = 0
    local nmaster = 0
    local nadapt = 0

    * Countries to scan
    if ("`country'" != "") local countries `"`country'"'
    else                   local countries : dir "`path'" dirs "*"

    di as txt _n "{hline 72}"
    di as txt "IHSN conformance check : `path'"
    di as txt "{hline 72}"

    foreach c of local countries {
        local cpath "`path'/`c'"
        mata: st_local("cex", strofreal(direxists("`cpath'")))
        if (`cex' == 0) continue

        if ("`survey'" != "") local surveys `"`survey'"'
        else                  local surveys : dir "`cpath'" dirs "*"

        foreach s of local surveys {
            local spath "`cpath'/`s'"
            local ++nsurvey

            * Survey folder name must be CCC_YYYY_SSSS
            if (!ustrregexm(upper("`s'"), "^[A-Z]{3}_[0-9]{4}_[A-Z0-9]+$")) {
                di as err "  [X] `s' : survey folder name is not CCC_YYYY_SSSS"
                local ++nviol
            }

            local versions : dir "`spath'" dirs "*"
            local svymaster = 0

            foreach v of local versions {
                local vpath "`spath'/`v'"

                * Classify the version folder
                local isMaster = ustrregexm(upper("`v'"), "_V[0-9]+_M$")
                local isAdapt  = ustrregexm(upper("`v'"), "_V[0-9]+_M_V[0-9]+_A_[A-Z0-9]+$")

                if (`isMaster')      local ++svymaster
                if (`isMaster')      local ++nmaster
                else if (`isAdapt')  local ++nadapt
                else {
                    di as err "  [X] `s'/`v' : version name not IHSN-conformant (expect *_vNN_M or *_vNN_M_vNN_A_CLCT)"
                    local ++nviol
                }

                * Required top-level subfolders
                foreach t of local reqtop {
                    local hit : dir "`vpath'" dirs "`t'"
                    if (`"`hit'"' == "") {
                        di as err "  [X] `s'/`v' : missing required folder /`t'"
                        local ++nviol
                    }
                }

                * Required Data/ subfolders (guard: only if Data exists)
                local hasData : dir "`vpath'" dirs "Data"
                if (`"`hasData'"' != "") {
                    foreach d of local reqdata {
                        local hit : dir "`vpath'/Data" dirs "`d'"
                        if (`"`hit'"' == "") {
                            di as err "  [X] `s'/`v' : missing required folder /Data/`d'"
                            local ++nviol
                        }
                    }

                    * MASTER vs HARMONIZED separation: inspect Data/Stata payload
                    local hasStata : dir "`vpath'/Data" dirs "Stata"
                    if (`"`hasStata'"' != "") {
                        local dtas : dir "`vpath'/Data/Stata" files "*.dta"
                        foreach f of local dtas {
                            local fn = subinstr(`"`f'"', `"""', "", .)
                            if (`isMaster' & strpos(upper("`fn'"), "_A_")) {
                                di as err "  [X] `s'/`v' : HARMONIZED data (_A_) inside a MASTER folder -> `fn'"
                                local ++nviol
                            }
                            if (`isAdapt' & !strpos(upper("`fn'"), "_A_")) {
                                di as err "  [X] `s'/`v' : non-harmonized file inside a HARMONIZED folder -> `fn'"
                                local ++nviol
                            }
                        }
                    }
                }
            }

            * Every survey must have at least one MASTER
            if (`svymaster' == 0) {
                di as err "  [X] `s' : no MASTER (_M) version folder found"
                local ++nviol
            }
        }
    }

    di as txt "{hline 72}"
    di as txt "surveys: " as res `nsurvey' as txt "   master: " as res `nmaster' ///
        as txt "   harmonized: " as res `nadapt'
    if (`nviol' == 0) di as res "PASS : IHSN-conformant (0 violations)"
    else              di as err "FAIL : `nviol' violation(s)"
    di as txt "{hline 72}"

    return scalar violations = `nviol'
    return scalar surveys    = `nsurvey'
    return scalar master     = `nmaster'
    return scalar harmonized = `nadapt'

    if (`nviol' > 0 & "`strict'" != "") {
        di as err "IHSN check failed under -strict-."
        exit 459
    }
end
