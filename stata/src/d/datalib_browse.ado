*******************************************************************************
* datalib_browse
*! v1.10.0 11Aug2026               by Joao Pedro Azevedo (UNICEF)
*!                                  and Minh Cong Nguyen (World Bank)
* Browse the catalogue in the Results window: country by library, then survey
* by country, then the three things a vintage actually is.
*
*   datalib_browse                       country x library
*   datalib_browse, country(CCC)         survey  x year, for one country
*   datalib_browse, country(CCC) survey(SSSS)
*                                        vintage x target -- DATA, CODE, DOC
*
* Every cell is a link, so the depth is reached by clicking rather than by
* retyping. Each render prints a breadcrumb, because the Results window is not
* a widget: clicking issues a NEW command whose output lands below the last
* one, and a screen of table with no heading is indistinguishable from the
* screen above it.
*
* Depths 1 and 2 are rendered by _dtlb_show. Depth 3 -- the vintage view -- is
* drawn HERE, by _dtlb_browse_targets at the foot of this file, which emits its
* own -display as text- table and never calls _dtlb_show. This header used to
* claim rendering was delegated entirely and that the command drew nothing
* itself; the manuscript copied that claim into a status table, which is how
* it was caught.
*******************************************************************************

program define datalib_browse, rclass
    version 16

    syntax [,                   ///
                country(string) ///
                survey(string)  ///
                year(string)    ///
                LIBrary(string) ///
                SEARCH(string)  ///
                rescan          ///
                NOLinks         ///
            ]

    local country = upper(strtrim("`country'"))
    local survey  = upper(strtrim("`survey'"))

    // ---- the catalogue, scanned once per session unless asked otherwise ----
    * library() NAMES a different library, so it must rescan: reusing a frame
    * built from the previous root would answer confidently about the wrong
    * archive. The help says it forces a rescan; before this it only did so
    * when the frame happened to be missing.
    capture frame dtlb_catalog: describe, short
    if (_rc | "`rescan'"!="" | `"`library'"'!="") {
        if (`"`library'"'!="") datalib_root, root(`"`library'"') find set
        quietly _dtlb_catalog, scan
    }

    // ---- filter into a working frame, so the catalogue is never mutated ----
    capture frame drop dtlb_browse
    frame copy dtlb_catalog dtlb_browse

    // Drilling and searching both narrow the frame, but they are not the same
    // fact. Rows dropped by drilling into XAA are not "hidden" -- the reader
    // asked for XAA. Only the SEARCH hides something the reader did not
    // exclude, so only that is counted and reported.
    local hidden 0
    frame dtlb_browse {
        if ("`country'"!="") quietly keep if country == "`country'"
        if ("`survey'"!="")  quietly keep if survey  == "`survey'"
        if ("`year'"!="")    quietly keep if year    == real("`year'")
        quietly count
        local before = r(N)
        if (`"`search'"'!="") {
            local s = lower(`"`search'"')
            quietly keep if strpos(lower(country), "`s'")  ///
                          | strpos(lower(survey), "`s'")   ///
                          | strpos(lower(modules), "`s'")  ///
                          | strpos(lower(adaptation), "`s'")
        }
        quietly count
        local after  = r(N)
        local hidden = `before' - `after'
    }

    // A filtered view that looks like a full one is the same class of defect
    // as a green gate that never ran, so the count of what was hidden is
    // stated rather than left to be inferred.
    _dtlb_browse_crumb, country(`country') survey(`survey') hidden(`hidden')

    frame dtlb_browse: quietly count
    if (r(N)==0) {
        display as error "  nothing matches -- widen the filter"
        capture frame drop dtlb_browse
        * Still return. A caller that branches on r(depth) or r(hidden) should
        * not have to know that the empty case exits early -- the help
        * advertises these unconditionally, so they exist unconditionally.
        return scalar depth  = cond("`country'"=="", 1, cond("`survey'"=="", 2, 3))
        return scalar hidden = `hidden'
        return scalar nrows  = 0
        return scalar ncols  = 0
        exit 0
    }

    // ---- depth 1: the whole library ---------------------------------------
    if ("`country'"=="") {
        _dtlb_show, frame(dtlb_browse) format(matrix)       ///
            row(country) col(library)                       ///
            title("Countries by library") `nolinks'         ///
            linkcmd("datalib_browse, country(@row)")
        local depth 1
    }

    // ---- depth 2: one country ---------------------------------------------
    else if ("`survey'"=="") {
        _dtlb_show, frame(dtlb_browse) format(matrix)       ///
            row(survey) col(year)                           ///
            title("`country' -- surveys by year") `nolinks' ///
            linkcmd("datalib_browse, country(`country') survey(@row)")
        local depth 2
    }

    // ---- depth 3: one survey -- the three things a vintage is -------------
    else {
        _dtlb_browse_targets, country(`country') survey(`survey') `nolinks'
        local depth 3
    }

    local nr = r(nrows)
    local nc = r(ncols)
    capture frame drop dtlb_browse

    return scalar depth  = `depth'
    return scalar hidden = `hidden'
    return scalar nrows  = `nr'
    return scalar ncols  = `nc'
end


*===============================================================================
* Breadcrumb. Cheap, and the difference between a navigable trail and a
* scrollback of similar-looking tables.
*===============================================================================
program define _dtlb_browse_crumb
    version 16
    syntax , [country(string) survey(string) hidden(integer 0)]

    local crumb `"{stata datalib_browse:datalib}"'
    if ("`country'"!="") {
        local crumb `"`crumb' {c |} {stata datalib_browse, country(`country'):`country'}"'
    }
    if ("`survey'"!="") {
        local crumb `"`crumb' {c |} `survey'"'
    }
    display as text _n "  `crumb'"
    if (`hidden' > 0) {
        display as text "  {res:`hidden'} row" cond(`hidden'==1,"","s") " hidden by the filter"
    }
end


*===============================================================================
* Depth 3. A vintage on disk is three things, and the menu is a menu over all
* three -- someone opening a survey they did not build needs the harmonization
* script and the README at least as often as the dataset.
*===============================================================================
program define _dtlb_browse_targets, rclass
    version 16
    syntax , country(string) survey(string) [NOLinks]

    // {hline N} fills columns 1..N and puts the junction at N+1, so a stub of
    // width 29 needs {hline 29} to land the junction under the header's bar at
    // column 30. Off-by-two here is visible as a kinked table.
    local stub 29
    frame dtlb_browse {
        local nrows 0
        display as text ""
        display as text "  vintage" _col(`=`stub'+1') "{c |}  DATA   CODE    DOC"
        display as text "{hline `stub'}{c +}{hline 22}"

        quietly levelsof year, local(years) clean
        foreach y of local years {
            quietly levelsof version if year==`y', local(vers) clean
            foreach v of local vers {
                quietly levelsof kind if year==`y' & version=="`v'", local(kinds) clean
                foreach k of local kinds {
                    quietly count if year==`y' & version=="`v'" & kind=="`k'"
                    if (r(N)==0) continue

                    // An adaptation is NOT reachable with vm() alone -- that
                    // loads the master underneath it. It needs its own
                    // vintage and family, or every adaptation row in this
                    // menu would silently open the wrong file.
                    local coord "country(`country') year(`y') survey(`survey') vm(`v')"
                    if ("`k'"=="master") {
                        local tag "`v'_M"
                    }
                    else {
                        quietly levelsof adaptation if year==`y' & version=="`v'" & kind=="`k'", local(fam) clean
                        quietly levelsof aversion   if year==`y' & version=="`v'" & kind=="`k'", local(av)  clean
                        local fam : word 1 of `fam'
                        local av  : word 1 of `av'
                        local tag "`v'_M_`av'_A_`fam'"
                        local coord "`coord' va(`av') collection(`fam') adaptation"
                    }
                    local lbl "`y' `tag'"
                    local nrows = `nrows' + 1

                    local line ""
                    local at `=`stub'+4'
                    foreach t in data programs doc {
                        local shown = cond("`t'"=="programs", "CODE", upper("`t'"))
                        local cmd "datalib, `coord' `t' clear"
                        if ("`nolinks'"=="") local txt `"{stata `cmd':`shown'}"'
                        else                 local txt "`shown'"
                        local line `"`line' _col(`at') `"`txt'"'"'
                        local at = `at' + 7
                    }
                    display as text "  `lbl'" _col(`=`stub'+1') "{c |}" `line'
                }
            }
        }
        display as text "{hline `stub'}{c BT}{hline 22}"
    }

    return scalar nrows = `nrows'
    return scalar ncols = 3
end
