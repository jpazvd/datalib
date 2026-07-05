*******************************************************************************
* _dtlb_catalog
*! v 0.1.0  28Apr2026                by Joao Pedro Azevedo (UNICEF)
* Build and query a frame of all surveys/versions in a datalib tree.
*
* Subcommands (mutually exclusive — pass exactly one):
*   scan   : walk ${datalib} (or path()), build frame `dtlb_catalog`
*   list   : print rows from the catalog, optionally filtered
*   clear  : drop the frame
*
* The frame schema is one row per master OR adaptation version with fields:
*   country (str3) year (int) survey (str10) version (str3) kind (str10)
*   adaptation (str10) aversion (str3) path (str244) has_yaml (byte)
*   producer (str80) license (str10) modules (str120)
*
* If the YAML library (yaml_read) is on the ado-path, master-folder
* `datalib.yaml` files are parsed for producer/license/modules. Otherwise
* those columns stay empty and only structural fields (parsed from folder
* names) are populated.
*
* Step 3 of the v1 restructuring plan.
*******************************************************************************

program define _dtlb_catalog, rclass
    version 16

    syntax [,                       ///
                SCAN                ///
                LIST                ///
                CLEAR               ///
                path(string)        ///
                country(string)     ///
                year(integer 0)     ///
                survey(string)      ///
            ]

    // Exactly-one subcommand validation
    local n_subcmds = 0
    foreach c in scan list clear {
        if "``c''" != "" local ++n_subcmds
    }
    if `n_subcmds' == 0 {
        display as error "specify one of: scan, list, clear"
        exit 198
    }
    if `n_subcmds' > 1 {
        display as error "options scan, list, clear are mutually exclusive"
        exit 198
    }

    if "`scan'" != "" {
        _dtlb_catalog_scan, path("`path'")
        return scalar n_versions    = r(n_versions)
        return scalar n_masters     = r(n_masters)
        return scalar n_adaptations = r(n_adaptations)
        return local  path          = r(path)
    }
    else if "`list'" != "" {
        _dtlb_catalog_list, country("`country'") year(`year') survey("`survey'")
        return scalar N = r(N)
    }
    else if "`clear'" != "" {
        capture frame drop dtlb_catalog
    }
end


*===============================================================================
* _dtlb_catalog_scan : walk tree, build frame
*===============================================================================
program define _dtlb_catalog_scan, rclass
    version 16
    syntax [, path(string)]

    // Resolve path
    if "`path'" == "" {
        if "${datalib}" == "" {
            display as error "neither path() nor \${datalib} is set"
            exit 198
        }
        local path "${datalib}"
    }
    // Normalise backslashes so dir-listing works cross-platform
    local path = subinstr("`path'", "\", "/", .)
    // Probe directory by listing it; missing dir -> error from `: dir`
    capture local _probe : dir "`path'" dirs "*"
    if _rc {
        display as error "datalib path does not exist or is not a directory: `path'"
        exit 601
    }

    // Probe for YAML library availability (graceful degradation)
    capture which yaml_read
    local has_yaml_lib = (_rc == 0)

    // (Re-)create frame
    capture frame drop dtlb_catalog
    frame create dtlb_catalog                                       ///
        str3 country     int year      str10 survey                 ///
        str3 version     str10 kind    str10 adaptation             ///
        str3 aversion    str244 path   byte has_yaml                ///
        str80 producer   str10 license str120 modules

    local n_versions    = 0
    local n_masters     = 0
    local n_adaptations = 0

    // ----- walk: country -> survey -> version ----------------------
    local countries : dir "`path'" dirs "*"
    foreach c of local countries {
        // ISO3 must be 3 uppercase letters
        if !regexm("`c'", "^[A-Z][A-Z][A-Z]$") continue

        local cdir "`path'/`c'"
        local surveys : dir "`cdir'" dirs "*"
        foreach s of local surveys {
            // survey folder: ccc_yyyy_ssss (lowercase)
            if !regexm("`s'", "^[a-z][a-z][a-z]_[0-9][0-9][0-9][0-9]_[a-z0-9]+$") continue

            local sdir "`cdir'/`s'"
            local versions : dir "`sdir'" dirs "*"
            foreach v of local versions {
                _dtlb_catalog_parse_version, name("`v'") country("`c'")
                if `r(parsed)' == 0 continue

                local _kind       = "`r(kind)'"
                local _year       = `r(year)'
                local _survey     = "`r(survey)'"
                local _version    = "`r(version)'"
                local _aversion   = "`r(aversion)'"
                local _adaptation = "`r(adaptation)'"

                local vdir "`sdir'/`v'"

                // YAML detection (master folders only)
                local has_yaml = 0
                local _producer ""
                local _license ""
                local _modules ""
                if "`_kind'" == "master" {
                    capture confirm file "`vdir'/datalib.yaml"
                    if _rc == 0 {
                        local has_yaml = 1
                        if `has_yaml_lib' {
                            capture _dtlb_catalog_read_yaml, file("`vdir'/datalib.yaml")
                            if _rc == 0 {
                                local _producer "`r(producer)'"
                                local _license  "`r(license)'"
                                local _modules  "`r(modules)'"
                            }
                        }
                    }
                }

                // Append row
                frame dtlb_catalog {
                    local newrow = _N + 1
                    set obs `newrow'
                    replace country     = "`c'"           in `newrow'
                    replace year        = `_year'         in `newrow'
                    replace survey      = "`_survey'"     in `newrow'
                    replace version     = "`_version'"    in `newrow'
                    replace kind        = "`_kind'"       in `newrow'
                    replace adaptation  = "`_adaptation'" in `newrow'
                    replace aversion    = "`_aversion'"   in `newrow'
                    replace path        = "`vdir'"        in `newrow'
                    replace has_yaml    = `has_yaml'      in `newrow'
                    replace producer    = "`_producer'"   in `newrow'
                    replace license     = "`_license'"    in `newrow'
                    replace modules     = "`_modules'"    in `newrow'
                }

                local ++n_versions
                if "`_kind'" == "master" local ++n_masters
                else                     local ++n_adaptations
            }
        }
    }

    // Sort frame
    frame dtlb_catalog: sort country year survey version kind aversion

    display as text "Scanned: " as result `n_versions' as text " version dirs (" ///
        as result `n_masters' as text " master, " ///
        as result `n_adaptations' as text " adaptation)"
    if `has_yaml_lib' == 0 {
        display as text "  note: yaml_read not on ado-path; YAML metadata not parsed"
    }

    return scalar n_versions    = `n_versions'
    return scalar n_masters     = `n_masters'
    return scalar n_adaptations = `n_adaptations'
    return local  path          = "`path'"
end


*===============================================================================
* _dtlb_catalog_parse_version : parse a CCC_YYYY_SSSS_vNN_M[_vNN_A_HHHH] folder name
*===============================================================================
program define _dtlb_catalog_parse_version, rclass
    version 16
    syntax , name(string) country(string)

    local ccc = lower("`country'")

    // Adaptation: ccc_yyyy_ssss_vNN_m_vNN_a_hhhh
    if regexm("`name'", ///
        "^`ccc'_([0-9][0-9][0-9][0-9])_([a-z0-9]+)_v([0-9][0-9])_m_v([0-9][0-9])_a_([a-z0-9]+)$") ///
    {
        // Capture regex groups before issuing return statements
        local _y  = real(regexs(1))
        local _s  = upper(regexs(2))
        local _v  = "v" + regexs(3)
        local _av = "v" + regexs(4)
        local _h  = upper(regexs(5))

        return scalar parsed     = 1
        return local  kind       = "adaptation"
        return scalar year       = `_y'
        return local  survey     = "`_s'"
        return local  version    = "`_v'"
        return local  aversion   = "`_av'"
        return local  adaptation = "`_h'"
        exit
    }

    // Master: ccc_yyyy_ssss_vNN_m
    if regexm("`name'", ///
        "^`ccc'_([0-9][0-9][0-9][0-9])_([a-z0-9]+)_v([0-9][0-9])_m$") ///
    {
        local _y = real(regexs(1))
        local _s = upper(regexs(2))
        local _v = "v" + regexs(3)

        return scalar parsed     = 1
        return local  kind       = "master"
        return scalar year       = `_y'
        return local  survey     = "`_s'"
        return local  version    = "`_v'"
        return local  aversion   = ""
        return local  adaptation = ""
        exit
    }

    return scalar parsed = 0
end


*===============================================================================
* _dtlb_catalog_read_yaml : extract producer/license/modules from a datalib.yaml
*===============================================================================
program define _dtlb_catalog_read_yaml, rclass
    version 16
    syntax , file(string)

    // yaml_read prefixes frame names with `yaml_` if not already present;
    // we pass the raw stem and address the prefixed name when dropping.
    local frame_stem "dtlb_tmp"
    local frame_actual "yaml_`frame_stem'"

    capture frame drop `frame_actual'
    capture quietly yaml read using "`file'", frame(`frame_stem') replace
    if _rc {
        return local producer = ""
        return local license  = ""
        return local modules  = ""
        exit 0
    }

    local _producer ""
    local _license  ""
    local _modules  ""

    capture quietly yaml get producer, frame(`frame_stem')
    if _rc == 0 local _producer = "`r(value)'"

    capture quietly yaml get license, frame(`frame_stem')
    if _rc == 0 local _license = "`r(value)'"

    capture quietly yaml list modules, frame(`frame_stem')
    if _rc == 0 local _modules = "`r(values)'"

    capture frame drop `frame_actual'

    return local producer = "`_producer'"
    return local license  = "`_license'"
    return local modules  = "`_modules'"
end


*===============================================================================
* _dtlb_catalog_list : print rows from the frame, optionally filtered
*===============================================================================
program define _dtlb_catalog_list, rclass
    version 16
    syntax [, country(string) year(integer 0) survey(string)]

    // Capture caller's frame so we restore it on exit
    local original_frame = c(frame)

    // Confirm frame exists
    capture frame change dtlb_catalog
    if _rc {
        display as error "catalog frame not built — run _dtlb_catalog, scan first"
        exit 198
    }

    // Build filter
    local conds ""
    if "`country'" != "" {
        local CC = upper("`country'")
        local conds `"`conds' & country == "`CC'""'
    }
    if `year' != 0 {
        local conds "`conds' & year == `year'"
    }
    if "`survey'" != "" {
        local SS = upper("`survey'")
        local conds `"`conds' & survey == "`SS'""'
    }
    if `"`conds'"' != "" {
        local conds = substr(`"`conds'"', 4, .)
        local where `"if `conds'"'
    }
    else {
        local where ""
    }

    // List
    list country year survey version kind adaptation aversion has_yaml `where', ///
        sepby(country) noobs abbreviate(15)

    quietly count `where'
    return scalar N = r(N)

    // Restore caller's frame
    frame change `original_frame'
end
