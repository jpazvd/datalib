*******************************************************************************
* _dtlb_catalog
*! v1.6.0  08Aug2026                by Joao Pedro Azevedo (UNICEF)
*!                                  and Minh Cong Nguyen (World Bank)
* Build and query a frame of all surveys/versions in a datalib tree — from
* the local filesystem, or from a remote NADA catalog (api:// read story).
*
* Subcommands (mutually exclusive — pass exactly one):
*   scan   : walk ${datalib} (or path()), build frame `dtlb_catalog`
*   list   : print rows from the catalog, optionally filtered.
*            With catalog(<short>) the rows come from the NADA REST search
*            of that catalog (registry: _dtlb_catalogregistry) instead of a
*            filesystem walk, with CAPPED pagination: one 100-row page by
*            default; r(more_pages_available)=1 signals the rest, fetched
*            only with the -all- option (bounded by max_rows(), progress
*            every 5 pages). The visible cap is deliberate — see NA-5 of
*            internal/datalib_nada_improvement_plan.md.
*   files  : NADA data_files endpoint for one survey -> frame `dtlb_files`
*            plus r() shortcuts (first <=5 files + summary scalars).
*   clear  : drop the catalog (and files) frames
*
* The filesystem frame schema is one row per master OR adaptation version:
*   country (str3) year (int) survey (str10) version (str3) kind (str10)
*   adaptation (str10) aversion (str3) path (str244) has_yaml (byte)
*   producer (str80) license (str10) modules (str120)
* REST rows carry the same structural fields (parsed from the idno via
* _dtlb_idno; blank when an idno does not follow the convention) plus
*   idno (str120) title (str244) source (str12, "api:<short>")
*
* If the YAML library (yaml_read) is on the ado-path, master-folder
* `datalib.yaml` files are parsed for producer/license/modules. Otherwise
* those columns stay empty and only structural fields (parsed from folder
* names) are populated.
*
* Step 3 of the v1 restructuring plan; REST paths are NA-5/NA-6 of
* internal/datalib_nada_improvement_plan.md.
*******************************************************************************

program define _dtlb_catalog, rclass
    version 16

    syntax [,                       ///
                SCAN                ///
                LIST                ///
                FILES               ///
                CLEAR               ///
                path(string)        ///
                country(string)     ///
                year(integer 0)     ///
                survey(string)      ///
                catalog(string)     ///
                sk(string)          ///
                ALL                 ///
                max_rows(integer 5000) ///
                version(string)     ///
                adaptation(string)  ///
                aversion(string)    ///
                idno(string)        ///
                registryhome(string) ///
                NOFETch             ///
            ]

    // Exactly-one subcommand validation
    local n_subcmds = 0
    foreach c in scan list files clear {
        if "``c''" != "" local ++n_subcmds
    }
    if `n_subcmds' == 0 {
        display as error "specify one of: scan, list, files, clear"
        exit 198
    }
    if `n_subcmds' > 1 {
        display as error "options scan, list, files, clear are mutually exclusive"
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
        if "`catalog'" != "" {
            _dtlb_catalog_list_api, catalog(`catalog') country("`country'") ///
                year(`year') survey("`survey'") sk(`"`sk'"') `all'          ///
                max_rows(`max_rows') registryhome(`"`registryhome'"') `nofetch'
            return scalar rows_found           = r(rows_found)
            return scalar rows_returned        = r(rows_returned)
            return scalar pages_fetched        = r(pages_fetched)
            return scalar more_pages_available = r(more_pages_available)
            return scalar status_code          = r(status_code)
            return local  api_url              `"`r(api_url)'"'
            return scalar N                    = r(rows_returned)
        }
        else {
            _dtlb_catalog_list, country("`country'") year(`year') survey("`survey'")
            return scalar N = r(N)
        }
    }
    else if "`files'" != "" {
        if "`catalog'" == "" {
            display as error "files requires catalog(<short>) — it queries a remote NADA catalog"
            exit 198
        }
        _dtlb_catalog_files, catalog(`catalog') country("`country'")     ///
            year(`year') survey("`survey'") version("`version'")         ///
            adaptation("`adaptation'") aversion("`aversion'")            ///
            idno(`"`idno'"') registryhome(`"`registryhome'"') `nofetch'
        return add
    }
    else if "`clear'" != "" {
        capture frame drop dtlb_catalog
        capture frame drop dtlb_files
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
        // ISO3 must be three letters. Match case-INSENSITIVELY: Stata's
        // -: dir- extended macro function lowercases directory names on
        // Windows, so a tree containing BRA/ IND/ came back as "bra" "ind"
        // and the old uppercase-only test skipped every country, making the
        // scan silently return 0 rows on Windows. On Linux and macOS -: dir-
        // preserves the real case, so the old test happened to work there.
        //
        // Two distinct values are needed from here on:
        //   `c'   the name AS RETURNED -- used for filesystem paths, which
        //         matters on case-sensitive filesystems
        //   `cup' the canonical uppercase ISO3 -- used for matching and for
        //         what is stored in the catalog frame
        local cup = upper("`c'")
        if !regexm("`cup'", "^[A-Z][A-Z][A-Z]$") continue

        local cdir "`path'/`c'"
        local surveys : dir "`cdir'" dirs "*"
        foreach s of local surveys {
            // survey folder: CCC_YYYY_SSSS. The CANONICAL case is uppercase
            // (see internal/demo_test_fixture_protocol.md section 6), but the
            // match is case-INSENSITIVE, exactly as the country folder above
            // already is: it uppercases before matching rather than demanding a
            // case on disk.
            //
            // This is not politeness. Until 2026-08-08 this regex required
            // lowercase while _dtlb_load.ado:436,443 built the path it loads
            // from the caller's country/survey with uppercase _M and _A
            // literals. Loader wanted uppercase, scanner demanded lowercase,
            // and the two only ever coexisted because every recorded gate run
            // is on Windows, whose filesystem is case-insensitive. Requiring
            // uppercase instead of tolerating both would have fixed the
            // disagreement while making every EXISTING lowercase archive on a
            // user's disk invisible to the scanner.
            local sup = upper("`s'")
            if !regexm("`sup'", "^[A-Z][A-Z][A-Z]_[0-9][0-9][0-9][0-9]_[A-Z0-9]+$") continue

            local sdir "`cdir'/`s'"
            local versions : dir "`sdir'" dirs "*"
            foreach v of local versions {
                _dtlb_catalog_parse_version, name("`v'") country("`cup'")
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
                    replace country     = "`cup'"         in `newrow'
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

    // Match case-INSENSITIVELY by uppercasing both the name and the country
    // prefix. The canonical case on disk is uppercase except the module token
    // (which does not appear in a FOLDER name, only in a file name), but a
    // legacy lowercase archive must still parse -- see the note at the survey
    // -foreach- above.
    local ccc  = upper("`country'")
    local name = upper("`name'")

    // Adaptation: CCC_YYYY_SSSS_vNN_M_vNN_A_HHHH
    if regexm("`name'", ///
        "^`ccc'_([0-9][0-9][0-9][0-9])_([A-Z0-9]+)_V([0-9][0-9])_M_V([0-9][0-9])_A_([A-Z0-9]+)$") ///
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

    // Master: CCC_YYYY_SSSS_vNN_M
    if regexm("`name'", ///
        "^`ccc'_([0-9][0-9][0-9][0-9])_([A-Z0-9]+)_V([0-9][0-9])_M$") ///
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


*===============================================================================
* _dtlb_catalog_list_api : NADA REST search -> frame (NA-5)
*
* Capped pagination: NADA serves at most 100 rows per page (ps=100 — do not
* ask for more). One page is fetched by default; if the catalog reports
* more, r(more_pages_available)=1 and a note tells the user to pass -all-.
* With -all-, pages stream in (progress every 5 pages) up to max_rows(), so
* an unfiltered scan of a 12,826-survey catalog cannot happen by accident.
*===============================================================================
program define _dtlb_catalog_list_api, rclass
    version 16
    // sk() and idno() take -string-, NOT -string asis-. The dispatcher
    // forwards them compound-quoted (sk(`"`sk'"')), and an -asis- option
    // keeps that wrapper verbatim: the receiving local ends up 4 characters
    // longer, holding `"value"' rather than value. Verified — asis gives
    // len 23 for a 19-character idno, plain string gives 19.
    //
    // That broke both paths: an unspecified sk() arrived as a non-empty
    // wrapper that put &sk="" in the query URL, and every idno() failed
    // _dtlb_idno with "cannot parse study identifier", so -files idno()-
    // never worked at all.
    syntax , catalog(string) [country(string) year(integer 0) survey(string) ///
        sk(string) ALL max_rows(integer 5000) registryhome(string) NOFETch]

    // ----- resolve the catalog --------------------------------------------
    _dtlb_catalogregistry, get(`catalog') registryhome(`"`registryhome'"') `nofetch'
    local base       `"`r(base_url)'"'
    local auth       "`r(auth_type)'"
    local expect_api "`r(api_version)'"
    local short      "`r(short)'"
    local src_label  "api:`short'"

    // ----- opportunistic version probe (session-cached; R-H early signal) --
    capture __dtlb_extensions_probe, host(`"`base'"')
    if _rc == 0 {
        if "`r(nada_api)'" != "" & "`expect_api'" != "" & "`r(nada_api)'" != "`expect_api'" {
            display as text "note: catalog '`short'' reports NADA API `r(nada_api)' " ///
                "(registry expects `expect_api') — update the catalog registry"
        }
    }

    // ----- build the search query -----------------------------------------
    //
    // Every value interpolated here ends up in a URL that __dtlb_api_read
    // hands to curl. Previously only spaces were encoded, so & = # and quotes
    // passed through untouched: country("X&ps=10000") injected a parameter,
    // and quote characters reached the shell command line the transport used
    // to build. Both values are now validated against a whitelist.
    //
    // Whitelist, not percent-encoding, on purpose. These fields hold ISO3
    // codes and survey keywords, which are alphanumeric; a caller passing &
    // or a quote is far more likely to be probing than to be naming a survey,
    // and failing loudly beats silently transforming their input. Space is
    // the one legitimate exception and is encoded.
    local q "ps=100"
    if "`country'" != "" {
        local ctry = upper(strtrim("`country'"))
        // Same ISO3 rule the scan path already enforces; the REST path
        // skipped it entirely.
        if !ustrregexm("`ctry'", "^[A-Z][A-Z][A-Z]$") {
            display as error "catalog: country() must be a 3-letter ISO code; got '`ctry''"
            exit 198
        }
        local q "`q'&country=`ctry'"
    }
    if `year' != 0 {
        local q "`q'&from=`year'&to=`year'"
    }
    if "`survey'" != "" {
        local sk = strtrim(`"`sk' `=upper(strtrim("`survey'"))'"')
    }
    if `"`sk'"' != "" {
        if !ustrregexm(`"`sk'"', "^[A-Za-z0-9 ._-]*$") {
            display as error "catalog: survey()/sk() may contain only letters, digits, space, dot, underscore and hyphen"
            display as error "  got: `sk'"
            exit 198
        }
        local sk_enc = subinstr(`"`sk'"', " ", "%20", .)
        local q `"`q'&sk=`sk_enc'"'
    }

    // ----- (re)create the frame: rebuild, not append -----------------------
    capture frame drop dtlb_catalog
    frame create dtlb_catalog                                       ///
        str3 country     int year      str10 survey                 ///
        str3 version     str10 kind    str10 adaptation             ///
        str3 aversion    str244 path   byte has_yaml                ///
        str80 producer   str10 license str120 modules               ///
        str120 idno      str244 title  str12 source

    // ----- page loop --------------------------------------------------------
    local page          = 1
    local rows_returned = 0
    local pages_fetched = 0
    local rows_found    = .
    local pages_total   = .
    local last_status   = .
    local api_url_1     ""
    local keep_going    = 1

    while `keep_going' {
        __dtlb_api_read using `"`base'/catalog/search"', auth_type(`auth') ///
            query(`"`q'&page=`page'"')
        local status = r(status_code)
        local body   `"`r(body_path)'"'
        if `page' == 1 local api_url_1 `"`r(url)'"'
        local last_status = `status'

        if `status' == 0 {
            display as error `"cannot reach catalog '`short'' at `base' (transport failure, rc=`r(rc)')"'
            exit 677
        }
        if `status' == 404 {
            display as error `"search endpoint not found at `base' — wrong base_url or unsupported NADA version"'
            exit 601
        }
        if `status' >= 400 {
            display as error `"catalog '`short'' returned HTTP `status' for the search request"'
            exit 677
        }

        // total on the first page
        if `page' == 1 {
            capture __dtlb_json scalar, file(`"`body'"') key(found) number
            if _rc == 0 & r(found) == 1 local rows_found = real("`r(value)'")
            if `rows_found' >= . local rows_found = 0
            local pages_total = max(1, ceil(`rows_found' / 100))
        }

        // split this page's rows and stream them into the frame
        tempfile objlist
        __dtlb_json split, file(`"`body'"') array(rows) saving(`"`objlist'"')
        local n_page = r(n)
        capture erase `"`body'"'

        if `n_page' > 0 {
            tempname fh
            file open `fh' using `"`objlist'"', read text
            file read `fh' line
            local eof = r(eof)
            while `eof' == 0 {
                local obj `"`macval(line)'"'
                if strtrim(`"`obj'"') != "" & `rows_returned' < `max_rows' {
                    // per-row fields (contract pinned by the api fixtures)
                    local _idno  ""
                    local _title ""
                    local _ystart .
                    if ustrregexm(`"`obj'"', `""idno"[ ]*:[ ]*"([^"]*)""') {
                        local _idno = ustrregexs(1)
                    }
                    if ustrregexm(`"`obj'"', `""title"[ ]*:[ ]*"([^"]*)""') {
                        local _title = ustrregexs(1)
                    }
                    if ustrregexm(`"`obj'"', `""year_start"[ ]*:[ ]*"?([0-9]+)"') {
                        local _ystart = real(ustrregexs(1))
                    }

                    // structural fields via the single case-translation funnel
                    local _c ""
                    local _y = .
                    local _s ""
                    local _v ""
                    local _k ""
                    local _a ""
                    local _av ""
                    capture _dtlb_idno, parse(`"`_idno'"')
                    if _rc == 0 {
                        local _c  "`r(country)'"
                        local _y  = r(year)
                        local _s  "`r(survey)'"
                        local _v  "`r(version)'"
                        local _k  "`r(kind)'"
                        local _a  "`r(adaptation)'"
                        local _av "`r(aversion)'"
                        local _idno "`r(idno)'"
                    }
                    else if `_ystart' < . {
                        local _y = `_ystart'
                    }

                    // clamp to the frame's column widths (real catalog
                    // titles/idnos can exceed them; truncation beats abort)
                    local _idno  = substr(`"`_idno'"', 1, 120)
                    local _title = substr(`"`_title'"', 1, 244)
                    local _s     = substr("`_s'", 1, 10)

                    frame post dtlb_catalog ("`_c'") (`_y') ("`_s'")       ///
                        ("`_v'") ("`_k'") ("`_a'") ("`_av'")               ///
                        ("") (0) ("") ("") ("")                            ///
                        (`"`_idno'"') (`"`_title'"') ("`src_label'")
                    local ++rows_returned
                }
                file read `fh' line
                local eof = r(eof)
            }
            file close `fh'
        }

        local ++pages_fetched
        if "`all'" != "" & mod(`pages_fetched', 5) == 0 {
            display as text "  page `pages_fetched' / `pages_total', `rows_returned' rows so far"
        }

        // continue?
        local keep_going = 0
        if "`all'" != "" & `page' < `pages_total' & `rows_returned' < `max_rows' {
            local ++page
            local keep_going = 1
        }
    }

    frame dtlb_catalog: sort country year survey version kind aversion

    local more = (`pages_fetched' < `pages_total')
    if `more' & "`all'" == "" {
        display as text "note: `rows_found' rows match; page 1 (100 max) fetched — pass -all- for the rest"
    }
    if `more' & "`all'" != "" {
        display as text "note: stopped at max_rows(`max_rows') of `rows_found' matching rows"
    }
    display as text "Catalog '`short'': " as result `rows_returned' as text " rows in frame dtlb_catalog"

    return scalar rows_found           = `rows_found'
    return scalar rows_returned        = `rows_returned'
    return scalar pages_fetched        = `pages_fetched'
    return scalar more_pages_available = `more'
    return scalar status_code          = `last_status'
    return local  api_url              `"`api_url_1'"'
end


*===============================================================================
* _dtlb_catalog_files : NADA data_files endpoint for one survey (NA-6)
*
* Returns BOTH shapes (locked decision D-4): frame dtlb_files always holds
* the complete list (file_id, file_name, file_format, file_size,
* description, download_url); r() macros mirror the first <=5 files for the
* common "is there a Stata file and how big" check, plus summary scalars.
*===============================================================================
program define _dtlb_catalog_files, rclass
    version 16
    syntax , catalog(string) [country(string) year(integer 0) survey(string) ///
        version(string) adaptation(string) aversion(string) idno(string) ///
        registryhome(string) NOFETch]

    // ----- resolve the identifier through the case funnel (R-E) ------------
    if `"`idno'"' != "" {
        _dtlb_idno, parse(`"`idno'"')
        local IDNO "`r(idno)'"
    }
    else {
        if "`country'" == "" | `year' == 0 | "`survey'" == "" {
            display as error "files needs idno() or the country() year() survey() triple"
            exit 198
        }
        if "`version'" == "" {
            local version "v01"
            display as text "note: version() omitted — using v01 (most catalog records are v01_M)"
        }
        _dtlb_idno, country(`country') year(`year') survey(`survey') ///
            version(`version') adaptation(`adaptation') aversion(`aversion')
        local IDNO "`r(idno)'"
    }

    // ----- resolve the catalog + fetch --------------------------------------
    _dtlb_catalogregistry, get(`catalog') registryhome(`"`registryhome'"') `nofetch'
    local base  `"`r(base_url)'"'
    local auth  "`r(auth_type)'"
    local short "`r(short)'"

    __dtlb_api_read using `"`base'/catalog/data_files/`IDNO'"', auth_type(`auth')
    local status = r(status_code)
    local body   `"`r(body_path)'"'
    local apiurl `"`r(url)'"'

    if `status' == 0 {
        display as error `"cannot reach catalog '`short'' at `base' (transport failure, rc=`r(rc)')"'
        exit 677
    }
    if `status' == 404 {
        display as error `"survey `IDNO' not found in catalog '`short''"'
        exit 601
    }
    if `status' >= 400 {
        display as error `"catalog '`short'' returned HTTP `status' for data_files/`IDNO'"'
        exit 677
    }

    // ----- parse the file list ----------------------------------------------
    tempfile objlist
    __dtlb_json split, file(`"`body'"') array(datafiles) saving(`"`objlist'"')
    local n_files = r(n)
    capture erase `"`body'"'

    capture frame drop dtlb_files
    frame create dtlb_files                                          ///
        double file_id   str244 file_name  str60 file_format         ///
        double file_size str244 description str244 download_url

    local total_bytes = 0
    local has_stata   = 0
    local i = 0

    if `n_files' > 0 {
        tempname fh
        file open `fh' using `"`objlist'"', read text
        file read `fh' line
        local eof = r(eof)
        while `eof' == 0 {
            local obj `"`macval(line)'"'
            if strtrim(`"`obj'"') != "" {
                local ++i
                local _id   = .
                local _name ""
                local _fmt  ""
                local _size = .
                local _desc ""
                local _url  ""
                if ustrregexm(`"`obj'"', `""file_id"[ ]*:[ ]*"?([0-9]+)"')      local _id   = real(ustrregexs(1))
                if ustrregexm(`"`obj'"', `""file_name"[ ]*:[ ]*"([^"]*)""')     local _name = ustrregexs(1)
                if ustrregexm(`"`obj'"', `""file_format"[ ]*:[ ]*"([^"]*)""')   local _fmt  = ustrregexs(1)
                if ustrregexm(`"`obj'"', `""file_size"[ ]*:[ ]*"?([0-9]+)"')    local _size = real(ustrregexs(1))
                if ustrregexm(`"`obj'"', `""description"[ ]*:[ ]*"([^"]*)""')   local _desc = ustrregexs(1)
                if ustrregexm(`"`obj'"', `""download_url"[ ]*:[ ]*"([^"]*)""')  local _url  = ustrregexs(1)

                // clamp to the frame's column widths
                local _name = substr(`"`_name'"', 1, 244)
                local _fmt  = substr(`"`_fmt'"', 1, 60)
                local _desc = substr(`"`_desc'"', 1, 244)
                local _url  = substr(`"`_url'"', 1, 244)

                frame post dtlb_files (`_id') (`"`_name'"') (`"`_fmt'"') ///
                    (`_size') (`"`_desc'"') (`"`_url'"')

                if `_size' < . local total_bytes = `total_bytes' + `_size'
                if strpos(lower(`"`_fmt'"'), "stata") > 0 local has_stata = 1
                if substr(lower(`"`_name'"'), -4, .) == ".dta" local has_stata = 1

                if `i' <= 5 {
                    local f`i'_name `"`_name'"'
                    local f`i'_fmt  `"`_fmt'"'
                    local f`i'_size = `_size'
                }
            }
            file read `fh' line
            local eof = r(eof)
        }
        file close `fh'
    }

    if `i' > 5 {
        display as text "note: `i' files — r() macros carry the first 5; the full list is in frame dtlb_files"
    }
    display as text "`IDNO': " as result `i' as text " file(s) in frame dtlb_files"

    // ----- both return shapes (D-4) -----------------------------------------
    return local  frame       "dtlb_files"
    return local  idno        "`IDNO'"
    return scalar n_files     = `i'
    return scalar total_bytes = `total_bytes'
    return scalar has_stata   = `has_stata'
    return scalar status_code = `status'
    return local  api_url     `"`apiurl'"'
    forvalues k = 1/`=min(`i', 5)' {
        return local file_`k'_name   `"`f`k'_name'"'
        return local file_`k'_format `"`f`k'_fmt'"'
        return scalar file_`k'_size  = `f`k'_size'
    }
end
