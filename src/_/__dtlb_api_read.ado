*******************************************************************************
* __dtlb_api_read
*! v1.1.0  17Jul2026               by Joao Pedro Azevedo (UNICEF)
*!                                  and Minh Cong Nguyen (World Bank)
* HTTP(S)/file transport for the api:// backend — GET one resource.
*
* Schemes:
*   file://   local fixture tree (testing/offline): the scheme and any query
*             string are stripped and the path is read directly; a missing
*             path is retried with ".json" appended (so extensionless
*             endpoint names like /info can live beside *.json fixtures).
*             NEVER consults credentials.
*   http(s):// network. Requires Stata 16+ (older TLS stacks are
*             unreliable; the local file:// backend still works — see the
*             paper's platform note). Two transports:
*               - plain Stata -copy- when no headers are needed
*                 (auth_type(none), default user agent, no extra headers)
*               - -shell curl- when a header must be sent (X-API-KEY /
*                 Authorization: Bearer, user_agent(), headers()); pure
*                 Stata -copy- cannot set request headers, so header-bearing
*                 calls require curl on the PATH. This is the documented
*                 fallback-to-curl gap in the paper's pure-Stata transport
*                 discussion.
*
* Auth dispatch (NA-2): the caller passes auth_type() (from the catalog
* registry); this program alone decides which header that becomes:
*   x-api-key -> "X-API-KEY: <token>"      (NADA registered access)
*   bearer    -> "Authorization: Bearer <token>"  (datalib's own REST)
*   none      -> no auth header, no credential lookup
* Credentials come from __dtlb_credential (DATALIB_TOKEN env var, then
* ${datalib_token} global).
*
* User-Agent (NA-7): default "datalib/0.9 (Stata <version>)". Pass
* user_agent(browser) for a Mozilla string — some WAFs (e.g., UNHCR's)
* block non-browser agents. UA control needs the curl transport; passing
* user_agent() forces it.
*
* Stored results:
*   r(status_code)   200 / 404 / other HTTP code; 0 = transport failure
*   r(body_path)     file holding the response body (in c(tmpdir) unless
*                    saving() is given — NOT a Stata tempfile, so it
*                    survives this program's exit; caller may erase it)
*   r(content_type)  best-effort content type
*   r(url)           the URL as requested
*   r(rc)            Stata/curl return code of the transport
*
* Internal helper (double-underscore tier): may be refactored without notice.
* NA-2 + NA-7 of internal/datalib_nada_improvement_plan.md.
*******************************************************************************

program define __dtlb_api_read, rclass
    version 15

    syntax using/, [                  ///
            method(string)            ///
            auth_type(string)         ///
            headers(string asis)      ///
            query(string asis)        ///
            timeout(integer 30)       ///
            user_agent(string)        ///
            saving(string)            ///
        ]

    local url `"`using'"'

    // ----- defaults + validation ------------------------------------------
    if "`method'" == "" local method "GET"
    if upper("`method'") != "GET" {
        display as error "__dtlb_api_read: only method(GET) is supported (v1 is read-only)"
        exit 198
    }
    if "`auth_type'" == "" local auth_type "none"
    local auth_type = lower(strtrim("`auth_type'"))
    if !inlist("`auth_type'", "x-api-key", "bearer", "none") {
        display as error "auth_type() must be one of: x-api-key, bearer, none"
        exit 198
    }

    // ----- response body destination (never a Stata tempfile: those are ---
    // ----- deleted when this program exits, and r(body_path) must survive) -
    //
    // Scratch filenames are keyed on a -tempname-, which is unique within the
    // session and needs no clearing.
    //
    // This replaces `global __dtlb_api_seq`, which was not merely untidy but
    // ILLEGAL: Stata refuses global macro names beginning with an underscore.
    //
    //     . global __dtlb_api_seq = 0
    //     invalid syntax
    //     r(198);
    //
    // (Verified for both `__name` and `_name`; a name with no leading
    // underscore succeeds.) Because that assignment sat on the first
    // reachable line of the body-destination block, this program failed with
    // r(198) on its FIRST call in any session, on every platform -- including
    // the file:// path, which is the documented offline/testing backend. It
    // is why qa/run_smoke.do never got past its section 5.
    tempname tok

    local tdir = subinstr(`"`c(tmpdir)'"', "\", "/", .)
    if substr(`"`tdir'"', -1, 1) == "/" {
        local tdir = substr(`"`tdir'"', 1, length(`"`tdir'"') - 1)
    }

    if `"`saving'"' == "" {
        local body `"`tdir'/dtlb_api_`tok'.body"'
    }
    else {
        local body `"`saving'"'
    }
    capture erase `"`body'"'

    // ----- append query string --------------------------------------------
    local fullurl `"`url'"'
    if `"`query'"' != "" {
        if strpos(`"`fullurl'"', "?") > 0 local fullurl `"`fullurl'&`query'"'
        else                              local fullurl `"`fullurl'?`query'"'
    }

    // =======================================================================
    // file:// — fixture / offline backend
    // =======================================================================
    if substr(`"`url'"', 1, 7) == "file://" {
        local path = substr(`"`fullurl'"', 8, .)
        // drop any query string: a filesystem has no query semantics
        local qpos = strpos(`"`path'"', "?")
        if `qpos' > 0 local path = substr(`"`path'"', 1, `qpos' - 1)
        local path = subinstr(`"`path'"', "\", "/", .)

        capture confirm file `"`path'"'
        if _rc != 0 {
            // extensionless endpoint name -> sibling .json fixture
            capture confirm file `"`path'.json"'
            if _rc == 0 local path `"`path'.json"'
        }

        capture confirm file `"`path'"'
        if _rc != 0 {
            return scalar status_code = 404
            return local  body_path   ""
            return local  content_type ""
            return local  url         `"`url'"'
            return scalar rc          = 601
            exit
        }

        capture copy `"`path'"' `"`body'"', replace
        if _rc != 0 {
            return scalar status_code = 0
            return local  body_path   ""
            return local  content_type ""
            return local  url         `"`url'"'
            return scalar rc          = _rc
            exit
        }

        __dtlb_api_ctype, path(`"`path'"')
        return scalar status_code = 200
        return local  body_path   `"`body'"'
        return local  content_type "`s(ctype)'"
        return local  url         `"`url'"'
        return scalar rc          = 0
        sreturn clear
        exit
    }

    // =======================================================================
    // http(s):// — network backend
    // =======================================================================
    if substr(`"`url'"', 1, 7) != "http://" & substr(`"`url'"', 1, 8) != "https://" {
        display as error `"__dtlb_api_read: unsupported URL scheme in `url'"'
        display as error "  supported: file://, http://, https://"
        exit 198
    }

    if c(stata_version) < 16 {
        display as error "the api:// backend requires Stata 16 or later. Use the file:// backend instead."
        exit 198
    }

    // ----- credential + header assembly (network only — R-B surface) -------
    local auth_header ""
    if "`auth_type'" != "none" {
        __dtlb_credential, auth_type(`auth_type')
        if "`auth_type'" == "x-api-key" local auth_header `"X-API-KEY: `r(token)'"'
        else                            local auth_header `"Authorization: Bearer `r(token)'"'
    }

    // ----- user agent (NA-7) ----------------------------------------------
    local ua_default "datalib/0.9 (Stata `c(stata_version)')"
    if `"`user_agent'"' == "" {
        local ua ""
    }
    else if lower(`"`user_agent'"') == "browser" {
        local ua "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
    }
    else {
        local ua `"`user_agent'"'
    }

    local needs_curl = ("`auth_header'" != "" | `"`ua'"' != "" | `"`headers'"' != "")

    if !`needs_curl' {
        // pure Stata transport: -copy- (no header control, Stata's own UA)
        capture copy `"`fullurl'"' `"`body'"', replace
        local rc = _rc
        if `rc' == 0 {
            __dtlb_api_ctype, path(`"`body'"')
            return scalar status_code = 200
            return local  body_path   `"`body'"'
            return local  content_type "`s(ctype)'"
            return local  url         `"`fullurl'"'
            return scalar rc          = 0
            sreturn clear
            exit
        }
        // -copy- exposes no HTTP status; map the common failure classes
        if inlist(`rc', 601, 602) local status = 404
        else                      local status = 0
        return scalar status_code = `status'
        return local  body_path   ""
        return local  content_type ""
        return local  url         `"`fullurl'"'
        return scalar rc          = `rc'
        exit
    }

    // ----- curl transport (headers required) -------------------------------
    // tdir and tok are already set above; both scratch files key off the same
    // per-call token, so concurrent calls cannot collide on either.
    if `"`ua'"' == "" local ua "`ua_default'"
    local metafile `"`tdir'/dtlb_api_`tok'.meta"'
    local cfgfile  `"`tdir'/dtlb_api_`tok'.cfg"'
    capture erase `"`metafile'"'
    capture erase `"`cfgfile'"'

    // ---------------------------------------------------------------------
    // Nothing user-controlled goes on the shell command line.
    //
    // The URL, headers, user agent and output path all used to be
    // interpolated into the -shell- string inside double quotes. Under POSIX
    // sh, backticks and $( ) still execute there, and the URL is reachable
    // from a user-override catalogs.yaml base_url, a poisoned registry
    // fetch, or query() input -- so that was arbitrary command execution.
    // The bearer token was on that line too, visible to `ps` and rendered
    // into the log by -set trace on-.
    //
    // Both problems go away if curl reads its arguments from a config file
    // instead: the command line becomes constant, and the token lives in a
    // 0600-ish temp file that is erased on every exit path.
    // ---------------------------------------------------------------------

    // Control characters must be rejected BEFORE the config file is written.
    // A newline in a URL or header would otherwise inject further curl
    // directives (output, upload-file) -- the config-file equivalent of the
    // shell injection this replaces.
    foreach v in fullurl ua headers auth_header body {
        local __v : copy local `v'
        if ustrregexm(`"`__v'"', "[[:cntrl:]]") {
            display as error "__dtlb_api_read: control character in `v'; refusing to build the request"
            capture erase `"`cfgfile'"'
            exit 198
        }
    }

    // curl config quoting: backslash first, then double quote.
    foreach v in fullurl ua headers auth_header body {
        local __v : copy local `v'
        local __v = subinstr(`"`__v'"', "\", "\\", .)
        local __v = subinstr(`"`__v'"', `"""', `"\""', .)
        local `v'_esc `"`__v'"'
    }

    tempname cfh
    capture file open `cfh' using `"`cfgfile'"', write text replace
    if _rc {
        display as error "__dtlb_api_read: cannot write curl config to `cfgfile'"
        exit 603
    }
    file write `cfh' "silent" _n "show-error" _n "location" _n
    file write `cfh' "max-time = `timeout'" _n
    file write `cfh' `"user-agent = "`ua_esc'""' _n
    if `"`auth_header'"' != "" file write `cfh' `"header = "`auth_header_esc'""' _n
    if `"`headers'"'     != "" file write `cfh' `"header = "`headers_esc'""' _n
    file write `cfh' `"output = "`body_esc'""' _n
    file write `cfh' `"write-out = "%{http_code} %{content_type}""' _n
    file write `cfh' `"url = "`fullurl_esc'""' _n
    file close `cfh'

    // metafile is derived from c(tmpdir), not from user input.
    shell curl -sS -K "`cfgfile'" > "`metafile'"

    capture erase `"`cfgfile'"'

    local status = 0
    local ctype  ""
    capture confirm file `"`metafile'"'
    if _rc == 0 {
        tempname fh
        capture file open `fh' using `"`metafile'"', read text
        if _rc == 0 {
            file read `fh' metaline
            file close `fh'
            local status = real(word(`"`metaline'"', 1))
            if `status' >= . local status = 0
            local ctype = word(`"`metaline'"', 2)
        }
        capture erase `"`metafile'"'
    }
    if `status' == 0 {
        display as error "__dtlb_api_read: transport failed (is curl on the PATH?)"
        display as error "  header-bearing api:// calls (auth, custom user agent) require curl;"
        display as error "  unauthenticated endpoints work with pure Stata -copy-."
    }

    local has_body = 0
    capture confirm file `"`body'"'
    if _rc == 0 local has_body = 1

    return scalar status_code = `status'
    if `has_body' & `status' > 0 return local body_path `"`body'"'
    else                         return local body_path ""
    return local  content_type "`ctype'"
    return local  url          `"`fullurl'"'
    return scalar rc           = cond(`status' == 0, 673, 0)
end


*===============================================================================
* __dtlb_api_ctype : best-effort content type from path extension / content
*===============================================================================
program define __dtlb_api_ctype, sclass
    version 15
    syntax , path(string)

    local lpath = lower(`"`path'"')
    if substr(`"`lpath'"', -5, .) == ".json" {
        sreturn local ctype "application/json"
        exit
    }
    if substr(`"`lpath'"', -5, .) == ".yaml" | substr(`"`lpath'"', -4, .) == ".yml" {
        sreturn local ctype "text/yaml"
        exit
    }
    // sniff: JSON bodies start with { or [
    tempname fh
    capture file open `fh' using `"`path'"', read text
    if _rc == 0 {
        file read `fh' firstline
        file close `fh'
        local head = substr(strtrim(`"`macval(firstline)'"'), 1, 1)
        if `"`head'"' == "{" | `"`head'"' == "[" {
            sreturn local ctype "application/json"
            exit
        }
    }
    sreturn local ctype "text/plain"
end
