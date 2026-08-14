*******************************************************************************
* __dtlb_ipums_api_read
*! v1.12.0  13Aug2026                by Joao Pedro Azevedo (UNICEF)
*!                                   and Minh Cong Nguyen (World Bank)
* HTTP transport for the IPUMS API. GET and POST.
*
* WHY THIS IS A SEPARATE COMMAND, NOT A METHOD ON __dtlb_api_read
*
* __dtlb_api_read is read-only on purpose and refuses any method but GET at its
* line 68. That refusal is a design position -- the NADA client is a consumer
* and does not touch a catalog's write surface -- and widening it to carry a
* request body would put a POST path inside the command every NADA call goes
* through, for the benefit of a provider NADA has nothing to do with.
*
* The IPUMS contract is also simply different: a raw key in an Authorization
* header rather than x-api-key or bearer, collection and version as query
* parameters on every call, and a submit-poll-download workflow rather than a
* read. Two transports that share a shape are easier to reason about than one
* transport with two personalities.
*
* WHAT IS COPIED FROM __dtlb_api_read, AND WHY
*
* The curl config-file pattern, the control-character rejection, the escaping
* order and the erase-on-every-exit-path discipline are carried over verbatim
* in intent. They are not stylistic:
*
*   - Nothing user-controlled reaches the shell command line. Under POSIX sh,
*     backticks and $( ) execute inside double quotes, and an endpoint or JSON
*     body is caller-controlled. A constant command line plus a config file
*     removes that class.
*   - The API KEY never appears in argv. It would otherwise be visible to `ps`
*     and rendered into the log by -set trace on-. IPUMS keys are per-user and
*     grant extract submission against that user's account.
*   - A newline in a URL, header or body would inject further curl directives
*     (output, upload-file) -- the config-file equivalent of shell injection --
*     so control characters are rejected BEFORE the config is written.
*
* THE CONTRACT (developer.ipums.org, API v2, verified 2026-08-13)
*
*   base           https://api.ipums.org
*   auth header    Authorization: <key>        <- the RAW key, not "Bearer x"
*   every call     ?collection=<c>&version=2
*   submit         POST /extracts              JSON body
*   poll           GET  /extracts/<number>
*   list           GET  /extracts?limit=<n>
*
* Syntax:
*   __dtlb_ipums_api_read , endpoint(str) collection(str)
*        [ post json(str asis) jsonusing(str) apikey(str) apiversion(int 2)
*          base(str) query(str asis) timeout(int 60) saving(str) ]
*
* Stored results (same shape as __dtlb_api_read, deliberately):
*   r(status_code)   200 / 400 / 401 / other; 0 = transport failure
*   r(body_path)     file holding the response body; "" when there is none
*   r(content_type)  best-effort content type
*   r(url)           the URL as requested, WITHOUT the key
*   r(rc)            0, or 673 when the transport itself failed
*
* Internal helper (double-underscore tier): may be refactored without notice.
* Written for internal/subcommand_redesign_plan.md section 3.3.
*******************************************************************************

capture program drop __dtlb_ipums_api_read
program define __dtlb_ipums_api_read, rclass
    version 15

    syntax , ENDpoint(string) [        ///
            COLLection(string)         ///
            post                       ///
            JSONUsing(string)          ///
            json(string asis)          ///
            APIkey(string)             ///
            APIVersion(integer 2)      ///
            base(string)               ///
            query(string asis)         ///
            timeout(integer 60)        ///
            saving(string)             ///
        ]

    if (`"`base'"' == "") local base "https://api.ipums.org"
    local base = trim(`"`base'"')
    * -while- requires a brace block. A single-line -while ... statement- parses
    * as "{ required" (rc 100), unlike -if-, which allows one.
    while (substr(`"`base'"', -1, 1) == "/") {
        local base = substr(`"`base'"', 1, strlen(`"`base'"') - 1)
    }

    local method = cond("`post'" != "", "POST", "GET")

    * ---- request body -------------------------------------------------------
    * json() and jsonusing() are the same argument by two routes; giving both is
    * refused rather than resolved, because guessing which one the caller meant
    * would silently submit the wrong extract.
    if (`"`json'"' != "") & (`"`jsonusing'"' != "") {
        display as error "__dtlb_ipums_api_read: give json() or jsonusing(), not both"
        exit 198
    }
    if ("`method'" == "GET") & ((`"`json'"' != "") | (`"`jsonusing'"' != "")) {
        display as error "__dtlb_ipums_api_read: a request body needs -post-"
        exit 198
    }

    * ---- URL ----------------------------------------------------------------
    local ep = trim(`"`endpoint'"')
    if (substr(`"`ep'"', 1, 1) != "/") local ep "/`ep'"

    local qs ""
    if (`"`collection'"' != "") local qs "collection=`collection'&version=`apiversion'"
    else                        local qs "version=`apiversion'"
    if (`"`query'"' != "")      local qs `"`qs'&`query'"'

    local fullurl `"`base'`ep'?`qs'"'

    * ---- per-call scratch token ---------------------------------------------
    * Computed before the fixture branch so BOTH transports use it. A fixed
    * filename collided across concurrent runs; the suites run concurrently.
    local tdir `"`c(tmpdir)'"'
    local tdir = subinstr(`"`tdir'"', "\", "/", .)
    while (substr(`"`tdir'"', -1, 1) == "/") {
        local tdir = substr(`"`tdir'"', 1, strlen(`"`tdir'"') - 1)
    }
    local tok = string(runiformint(100000, 999999)) + string(int(clock("`c(current_time)'", "hms")))

    * ---- fixture transport --------------------------------------------------
    * A file:// base makes the whole workflow testable with no key and no
    * network, which is the only way the submit-poll-download loop gets a
    * regression test: the live API queues extracts for minutes to hours, and
    * CI has no credential. Mirrors __dtlb_api_read's file:// branch.
    if (substr(lower(`"`base'"'), 1, 7) == "file://") {
        local path = substr(`"`base'"', 8, .)
        local path = subinstr(`"`path'`ep'"', "\", "/", .)
        local path = subinstr(`"`path'"', "//", "/", .)

        capture confirm file `"`path'"'
        if (_rc != 0) {
            capture confirm file `"`path'.json"'
            if (_rc == 0) local path `"`path'.json"'
        }
        capture confirm file `"`path'"'
        if (_rc != 0) {
            return scalar status_code = 404
            return local  body_path   ""
            return local  content_type ""
            return local  url         `"`fullurl'"'
            return scalar rc          = 601
            exit
        }

        * NOT a -tempfile-: Stata erases those when this program exits, and
        * r(body_path) is a promise the caller can still read the file.
        * __dtlb_api_read's header makes the same point about its own body
        * destination. A per-call NAME gives the isolation without the erase.
        local fxout `"`tdir'/dtlb_ipums_fx_`tok'.json"'
        capture erase `"`fxout'"'
        capture copy `"`path'"' `"`fxout'"', replace
        if (_rc != 0) {
            return scalar status_code = 0
            return local  body_path   ""
            return local  content_type ""
            return local  url         `"`fullurl'"'
            return scalar rc          = _rc
            exit
        }
        return scalar status_code = 200
        return local  body_path   `"`fxout'"'
        return local  content_type "application/json"
        return local  url         `"`fullurl'"'
        return scalar rc          = 0
        exit
    }

    * ---- scratch files ------------------------------------------------------
    if (`"`saving'"' != "") local respbody `"`saving'"'
    else                    local respbody `"`tdir'/dtlb_ipums_`tok'.body"'
    local cfgfile  `"`tdir'/dtlb_ipums_`tok'.cfg"'
    local metafile `"`tdir'/dtlb_ipums_`tok'.meta"'
    local bodyfile `"`tdir'/dtlb_ipums_`tok'.json"'

    capture erase `"`respbody'"'
    capture erase `"`cfgfile'"'
    capture erase `"`metafile'"'

    * A json() string is written to a file rather than inlined into the config.
    * An extract body carries every sample and variable name and can be long;
    * curl's config parser has line-length limits, and @file has none.
    if (`"`json'"' != "") {
        tempname jfh
        capture file open `jfh' using `"`bodyfile'"', write text replace
        if (_rc) {
            display as error "__dtlb_ipums_api_read: cannot write request body to `bodyfile'"
            exit 603
        }
        file write `jfh' `"`json'"' _n
        file close `jfh'
        local jsonusing `"`bodyfile'"'
    }
    if (`"`jsonusing'"' != "") {
        capture confirm file `"`jsonusing'"'
        if (_rc) {
            display as error "__dtlb_ipums_api_read: jsonusing() not found: `jsonusing'"
            capture erase `"`bodyfile'"'
            exit 601
        }
    }

    * ---- API key ------------------------------------------------------------
    * Resolved AFTER the fixture branch, deliberately. This command's whole
    * claim to being testable is that a file:// base needs no key and no
    * network; requiring one first made that false, and the probe hid it by
    * passing a dummy key on every fixture call -- a test written around the
    * bug rather than at it. __dtlb_api_read's file:// branch has always been
    * usable without credentials; this now matches. (Copilot, PR #97.)
    *
    * On the live path there is no unauthenticated fallback: IPUMS requires the
    * key on EVERY call, metadata included, unlike an open NADA catalog.
    if (`"`apikey'"' == "") local apikey : environment IPUMS_API_KEY
    if (`"`apikey'"' == "") {
        display as error "__dtlb_ipums_api_read: no API key."
        display as error "  set the IPUMS_API_KEY environment variable, or pass apikey()."
        display as error "  keys are free, per-user: https://account.ipums.org/api_keys"
        exit 198
    }

    local auth_header `"Authorization: `apikey'"'

    * ---- reject control characters BEFORE writing the config ----------------
    * The key is checked too: a newline in an environment variable would
    * otherwise append curl directives of the caller's choosing.
    foreach v in fullurl auth_header respbody jsonusing {
        local __v : copy local `v'
        if ustrregexm(`"`__v'"', "[[:cntrl:]]") {
            display as error "__dtlb_ipums_api_read: control character in `v'; refusing to build the request"
            capture erase `"`cfgfile'"'
            capture erase `"`bodyfile'"'
            exit 198
        }
    }

    * curl config quoting: backslash first, then double quote. Order matters --
    * quoting first would then have its own backslashes doubled.
    foreach v in fullurl auth_header respbody jsonusing {
        local __v : copy local `v'
        local __v = subinstr(`"`__v'"', "\", "\\", .)
        local __v = subinstr(`"`__v'"', `"""', `"\""', .)
        local `v'_esc `"`__v'"'
    }

    tempname cfh
    capture file open `cfh' using `"`cfgfile'"', write text replace
    if (_rc) {
        display as error "__dtlb_ipums_api_read: cannot write curl config to `cfgfile'"
        capture erase `"`bodyfile'"'
        exit 603
    }
    file write `cfh' "silent" _n "show-error" _n "location" _n
    file write `cfh' "max-time = `timeout'" _n
    file write `cfh' `"request = "`method'""' _n
    file write `cfh' `"header = "`auth_header_esc'""' _n
    file write `cfh' `"header = "Content-Type: application/json""' _n
    if (`"`jsonusing'"' != "") file write `cfh' `"data-binary = "@`jsonusing_esc'""' _n
    file write `cfh' `"output = "`respbody_esc'""' _n
    file write `cfh' `"write-out = "%{http_code} %{content_type}""' _n
    file write `cfh' `"url = "`fullurl_esc'""' _n
    file close `cfh'

    * The command line is constant. Everything variable is in the config.
    local status = 0
    local ctype  ""
    capture shell curl --config "`cfgfile'" > "`metafile'" 2>&1
    local shellrc = _rc

    capture erase `"`cfgfile'"'
    capture erase `"`bodyfile'"'

    tempname fh
    capture file open `fh' using `"`metafile'"', read text
    if (_rc == 0) {
        file read `fh' metaline
        file close `fh'
        local status = real(word(`"`metaline'"', 1))
        if (`status' >= .) local status = 0
        local ctype = word(`"`metaline'"', 2)
    }
    capture erase `"`metafile'"'

    if (`status' == 0) {
        display as error "__dtlb_ipums_api_read: transport failed (is curl on the PATH?)"
        display as error "  every IPUMS call carries an Authorization header, so there is no"
        display as error "  pure-Stata -copy- fallback the way an open NADA catalog has one."
    }

    local has_body = 0
    capture confirm file `"`respbody'"'
    if (_rc == 0) local has_body = 1

    return scalar status_code = `status'
    if (`has_body' & `status' > 0) return local body_path `"`respbody'"'
    else                           return local body_path ""
    return local  content_type "`ctype'"
    * The URL is returned WITHOUT the key: it is a header, not a query
    * parameter, so this is safe to print and to write into a log.
    return local  url          `"`fullurl'"'
    return scalar rc           = cond(`status' == 0, 673, 0)

end
