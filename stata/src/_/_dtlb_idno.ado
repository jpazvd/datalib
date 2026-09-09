*******************************************************************************
* _dtlb_idno
*! v1.7.0  08Aug2026               by Joao Pedro Azevedo (UNICEF)
*!                                  and Minh Cong Nguyen (World Bank)
* Bidirectional folder <-> IDNo translation for the IHSN study identifier.
*
* One case, everywhere. NADA catalogs index the UPPER form
* (BRA_2015_PNAD_v01_M, with a lowercase "v") and datalib's on-disk folders
* use that SAME form, so r(folder) == r(idno).
*
* Until v1.7.0 folders were lowercased here, and this command was the single
* point of case translation (red-team item R-E). That seam was retired
* because it never held: -datalib_makelib- created UPPER folders while this
* command reported lower ones, and both passed CI only because Windows
* filesystems are case-insensitive. Two conventions that disagree are worse
* than either one, and a translation nobody can observe on the platform the
* gate runs on cannot be tested. r(folder) is kept as a caller-facing alias.
*
* Parse mode still accepts EITHER case on input, so archives laid out under
* the old lowercase convention keep resolving.
*
* Build mode:
*   _dtlb_idno, country(BRA) year(2015) survey(PNAD) version(v01) ///
*               [adaptation(DTZ81) aversion(v01)]
*   -> r(idno) = "BRA_2015_PNAD_v01_M[_v01_A_DTZ81]"
*      r(folder) = the on-disk folder name (identical to r(idno))
* Version inputs accept 1 / 01 / v01 / V01 (contract-v1 forms); output is
* always the padded lower-v form (v01, v10).
*
* Parse mode (case-insensitive input):
*   _dtlb_idno, parse("bra_2015_pnad_v01_m_v01_a_dtz81")
*   -> r(country)=BRA r(year)=2015 r(survey)=PNAD r(version)=v01
*      r(kind)=adaptation r(adaptation)=DTZ81 r(aversion)=v01
*      plus canonical r(idno) and r(folder)
* Non-conforming identifiers exit 198 (callers that meet free-text NADA
* idnos wrap the call in -capture- and treat failure as "unparsed").
*
* Stable helper (single-underscore tier).
* NA-4 of internal/datalib_nada_improvement_plan.md.
*******************************************************************************

program define _dtlb_idno, rclass
    version 15

    syntax [, country(string) year(string) survey(string) version(string) ///
              adaptation(string) aversion(string) parse(string)]

    // =======================================================================
    // parse mode
    // =======================================================================
    if `"`parse'"' != "" {
        if "`country'`year'`survey'`version'`adaptation'`aversion'" != "" {
            display as error "parse() cannot be combined with the build options"
            exit 198
        }
        local in = upper(strtrim(`"`parse'"'))

        if regexm("`in'", "^([A-Z][A-Z][A-Z])_([0-9][0-9][0-9][0-9])_([A-Z0-9]+)_V([0-9]+)_M_V([0-9]+)_A_([A-Z0-9]+)$") {
            local _c  = regexs(1)
            local _y  = regexs(2)
            local _s  = regexs(3)
            local _v  = regexs(4)
            local _av = regexs(5)
            local _h  = regexs(6)
            local kind "adaptation"
        }
        else if regexm("`in'", "^([A-Z][A-Z][A-Z])_([0-9][0-9][0-9][0-9])_([A-Z0-9]+)_V([0-9]+)_M$") {
            local _c  = regexs(1)
            local _y  = regexs(2)
            local _s  = regexs(3)
            local _v  = regexs(4)
            local _av ""
            local _h  ""
            local kind "master"
        }
        else {
            display as error `"cannot parse study identifier: `parse'"'
            display as error "  expected CCC_YYYY_SSSS_vNN_M[_vNN_A_HHHH] (any case)"
            exit 198
        }

        local vfmt  = "v" + string(real("`_v'"), "%02.0f")
        local avfmt = cond("`_av'" == "", "", "v" + string(real("`_av'"), "%02.0f"))

        return local country    "`_c'"
        return scalar year      = real("`_y'")
        return local survey     "`_s'"
        return local version    "`vfmt'"
        return local kind       "`kind'"
        return local adaptation "`_h'"
        return local aversion   "`avfmt'"

        local idno "`_c'_`_y'_`_s'_`vfmt'_M"
        if "`kind'" == "adaptation" local idno "`idno'_`avfmt'_A_`_h'"
        return local idno   "`idno'"
        return local folder   "`idno'"
        exit
    }

    // =======================================================================
    // build mode
    // =======================================================================
    local country = upper(strtrim("`country'"))
    local survey  = upper(strtrim("`survey'"))
    local year    = strtrim("`year'")

    if !regexm("`country'", "^[A-Z][A-Z][A-Z]$") {
        display as error "country() must be a three-letter ISO code (got: `country')"
        exit 198
    }
    if !regexm("`year'", "^[0-9][0-9][0-9][0-9]$") {
        display as error "year() must be a four-digit year (got: `year')"
        exit 198
    }
    if !regexm("`survey'", "^[A-Z0-9]+$") {
        display as error "survey() must be alphanumeric (got: `survey')"
        exit 198
    }

    __dtlb_idno_vnorm, value(`"`version'"') what(version)
    local vfmt "`s(vnorm)'"

    local avfmt ""
    local adaptation = upper(strtrim("`adaptation'"))
    if "`adaptation'" != "" {
        if !regexm("`adaptation'", "^[A-Z0-9]+$") {
            display as error "adaptation() must be alphanumeric (got: `adaptation')"
            exit 198
        }
        if `"`aversion'"' == "" {
            display as error "aversion() is required when adaptation() is given"
            display as error "  (identifiers are exact: the adaptation vintage is never guessed)"
            exit 198
        }
        __dtlb_idno_vnorm, value(`"`aversion'"') what(aversion)
        local avfmt "`s(vnorm)'"
    }
    else if `"`aversion'"' != "" {
        display as error "aversion() requires adaptation()"
        exit 198
    }
    sreturn clear

    local idno "`country'_`year'_`survey'_`vfmt'_M"
    if "`adaptation'" != "" local idno "`idno'_`avfmt'_A_`adaptation'"

    return local country    "`country'"
    return scalar year      = real("`year'")
    return local survey     "`survey'"
    return local version    "`vfmt'"
    return local kind       = cond("`adaptation'" == "", "master", "adaptation")
    return local adaptation "`adaptation'"
    return local aversion   "`avfmt'"
    return local idno       "`idno'"
    return local folder     "`idno'"
end


*===============================================================================
* __dtlb_idno_vnorm : normalise a vintage input (1 / 01 / v01 / V01 -> v01)
*===============================================================================
program define __dtlb_idno_vnorm, sclass
    version 15
    syntax , value(string) what(string)

    local v = lower(strtrim(`"`value'"'))
    if substr("`v'", 1, 1) == "v" local v = substr("`v'", 2, .)
    if !regexm("`v'", "^[0-9]+$") {
        display as error "`what'() must be a vintage number: 1, 01, v01, or V01 (got: `value')"
        exit 198
    }
    local n = real("`v'")
    if `n' < 1 {
        display as error "`what'() must be 1 or greater (got: `value')"
        exit 198
    }
    sreturn local vnorm = "v" + string(`n', "%02.0f")
end
