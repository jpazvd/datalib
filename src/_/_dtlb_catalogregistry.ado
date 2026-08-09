*******************************************************************************
* _dtlb_catalogregistry
*! v1.1.0  17Jul2026               by Joao Pedro Azevedo (UNICEF)
*!                                  and Minh Cong Nguyen (World Bank)
* Resolve a catalog short name (wb, ihsn, ...) to its NADA REST deployment.
*
* Resolution order (first source whose file exists AND carries the requested
* catalog wins; a source that exists but lacks the entry falls through):
*   1. <home>/catalogs.yaml                user override
*   2. <home>/cache/catalogs.yaml          cached canonical fetch (<= 24h old)
*   3. https://jpazvd.github.io/datalib-dev/catalogs.yaml
*                                          fresh fetch (writes the cache)
*   4. src/registry/catalogs.yaml          bundled offline fallback
* where <home> is __dtlb_userhome (override with registryhome()).
*
* The file is a strict two-level YAML subset (top-level short name, indented
* scalar fields) parsed here directly with -file read- so that registry
* resolution has no dependency on the vendored YAML library being on the
* ado-path: this command sits upstream of everything else in the api://
* stack, including minimal installs.
*
* Security (R-B in internal/datalib_nada_improvement_plan.md): an entry from
* the USER OVERRIDE whose auth_type is not "none" will cause the client to
* send the user's credential to that base_url. The first such use requires
* the acceptauth option (one-time consent, recorded as a marker file and a
* line in <home>/audit.log). Bundled/canonical entries need no consent.
*
* Stored results:
*   r(short) r(name) r(base_url) r(api_version) r(auth_type)
*   r(default)        1 if the entry is flagged default, else 0
*   r(metadata_only)  1 if downloads redirect to producer sites, else 0
*   r(source)         user_override | cache | network | bundled_fallback
*   r(file)           the file the entry was read from
*
* NA-1 of internal/datalib_nada_improvement_plan.md.
*******************************************************************************

program define _dtlb_catalogregistry, rclass
    version 16

    syntax , get(string) [registryhome(string) NOFETch ACCEPTauth]

    local short = strtrim(lower("`get'"))
    if "`short'" == "" {
        display as error "get() requires a catalog short name (e.g., wb, ihsn)"
        exit 198
    }

    local canonical_url "https://jpazvd.github.io/datalib-dev/catalogs.yaml"

    // ----- per-user home -------------------------------------------------
    if `"`registryhome'"' != "" {
        local home `"`registryhome'"'
    }
    else {
        __dtlb_userhome
        local home `"`r(datalib_home)'"'
    }
    local home = subinstr(`"`home'"', "\", "/", .)
    local f_user  `"`home'/catalogs.yaml"'
    local f_cache `"`home'/cache/catalogs.yaml"'
    local f_stamp `"`home'/cache/catalogs.stamp"'

    local resolved = 0

    // ----- 1. user override ----------------------------------------------
    capture confirm file `"`f_user'"'
    if _rc == 0 {
        __dtlb_catreg_parse, file(`"`f_user'"') short("`short'")
        if r(found) == 1 {
            local source "user_override"
            local file   `"`f_user'"'
            __dtlb_catreg_keep
            local resolved = 1
        }
    }

    // ----- 2. fresh cache -------------------------------------------------
    if `resolved' == 0 {
        capture confirm file `"`f_cache'"'
        local has_cache = (_rc == 0)
        local cache_fresh = 0
        if `has_cache' {
            capture confirm file `"`f_stamp'"'
            if _rc == 0 {
                tempname fh
                capture file open `fh' using `"`f_stamp'"', read text
                if _rc == 0 {
                    file read `fh' stampline
                    file close `fh'
                    local stamp = real(strtrim(`"`stampline'"'))
                    local now = clock("`c(current_date)' `c(current_time)'", "DMY hms")
                    if `stamp' < . {
                        local age_h = (`now' - `stamp') / 3600000
                        if `age_h' >= 0 & `age_h' <= 24 local cache_fresh = 1
                    }
                }
            }
        }
        if `has_cache' & `cache_fresh' {
            __dtlb_catreg_parse, file(`"`f_cache'"') short("`short'")
            if r(found) == 1 {
                local source "cache"
                local file   `"`f_cache'"'
                __dtlb_catreg_keep
                local resolved = 1
            }
        }
    }

    // ----- 3. fresh fetch of the canonical registry -----------------------
    if `resolved' == 0 & "`nofetch'" == "" {
        tempfile fetched
        capture copy "`canonical_url'" `"`fetched'"', replace
        if _rc == 0 {
            // refresh the cache (best-effort; failures never block resolution)
            capture mkdir `"`home'"'
            capture mkdir `"`home'/cache"'
            capture copy `"`fetched'"' `"`f_cache'"', replace
            local now = clock("`c(current_date)' `c(current_time)'", "DMY hms")
            tempname fh
            capture file open `fh' using `"`f_stamp'"', write text replace
            if _rc == 0 {
                file write `fh' %20.0f (`now') _n
                file close `fh'
            }
            __dtlb_catreg_parse, file(`"`fetched'"') short("`short'")
            if r(found) == 1 {
                local source "network"
                local file   "`canonical_url'"
                __dtlb_catreg_keep
                local resolved = 1
            }
        }
    }

    // ----- 3b. stale cache (offline, canonical unreachable) ---------------
    if `resolved' == 0 {
        capture confirm file `"`f_cache'"'
        if _rc == 0 {
            __dtlb_catreg_parse, file(`"`f_cache'"') short("`short'")
            if r(found) == 1 {
                display as text "note: using cached catalog registry older than 24h (canonical registry unreachable)"
                local source "cache"
                local file   `"`f_cache'"'
                __dtlb_catreg_keep
                local resolved = 1
            }
        }
    }

    // ----- 4. bundled offline fallback ------------------------------------
    if `resolved' == 0 {
        local f_bundled ""
        capture findfile catalogs.yaml
        if _rc == 0 local f_bundled `"`r(fn)'"'
        if `"`f_bundled'"' == "" {
            capture confirm file "src/registry/catalogs.yaml"
            if _rc == 0 local f_bundled "src/registry/catalogs.yaml"
        }
        if `"`f_bundled'"' != "" {
            __dtlb_catreg_parse, file(`"`f_bundled'"') short("`short'")
            if r(found) == 1 {
                local source "bundled_fallback"
                local file   `"`f_bundled'"'
                __dtlb_catreg_keep
                local resolved = 1
            }
        }
    }

    if `resolved' == 0 {
        display as error `"catalog '`short'' not found in any registry source"'
        display as error `"  looked in: user override, cache, canonical registry, bundled fallback"'
        display as error `"  to add it: edit `f_user' (see src/registry/catalogs.yaml for the schema)"'
        exit 198
    }

    // ----- validate + normalise fields ------------------------------------
    local auth_type = lower(strtrim("`s(auth_type)'"))
    if "`auth_type'" == "" local auth_type "none"
    if !inlist("`auth_type'", "x-api-key", "bearer", "none") {
        display as error `"catalog '`short'': invalid auth_type '`auth_type'' (allowed: x-api-key, bearer, none)"'
        exit 198
    }
    local metadata_only = (lower(strtrim("`s(metadata_only)'")) == "true")
    local isdefault     = (lower(strtrim("`s(default)'")) == "true")

    // ----- R-B consent gate for untrusted auth entries ---------------------
    //
    // This used to fire only for source == "user_override", which left the
    // control it advertises trivially bypassable. Step 4 above locates the
    // bundled registry with a bare -findfile catalogs.yaml-, and findfile
    // searches the whole ado-path -- PERSONAL, PLUS, SITE, the working
    // directory. A catalogs.yaml planted in any of those resolves as
    // "bundled_fallback", so an attacker-supplied entry with
    // auth_type(bearer) and a hostile base_url received the user's token
    // with no prompt at all.
    //
    // bundled_fallback is therefore treated as untrusted for auth purposes.
    // The UX cost is close to zero: bundled is the *offline* fallback, and
    // the only auth-bearing shipped catalog (wb) normally resolves from the
    // cache or the canonical registry, neither of which is gated. Reaching
    // an auth entry through the bundled path means we are offline and cannot
    // verify the registry, which is exactly when a prompt is warranted.
    //
    // Residual risk, tracked in datalib_nada_improvement_plan.md rather than
    // fixed here: the network and cache sources have no integrity check, so a
    // single successful registry poisoning persists in the cache and is
    // served indefinitely whenever the canonical host is unreachable.
    if inlist("`source'", "user_override", "bundled_fallback") & "`auth_type'" != "none" {
        local marker `"`home'/consent_auth_`short'"'
        capture confirm file `"`marker'"'
        if _rc != 0 {
            if "`acceptauth'" == "" {
                if "`source'" == "user_override" {
                    local whence "from your user override, `f_user'"
                }
                else {
                    local whence `"from an unverified registry file at `file'"'
                }
                display as error `"catalog '`short'' (`whence') declares auth_type(`auth_type'):"'
                display as error `"datalib would send your credential to `s(base_url)'."'
                display as error `"Confirm you trust that host before proceeding."'
                display as error `"If this is intended, re-run once with the acceptauth option"'
                display as error `"(consent is remembered and logged to `home'/audit.log)."'
                exit 198
            }
            capture mkdir `"`home'"'
            tempname fh
            capture file open `fh' using `"`marker'"', write text replace
            if _rc == 0 {
                file write `fh' "consented `c(current_date)' `c(current_time)'" _n
                file close `fh'
            }
            capture file open `fh' using `"`home'/audit.log"', write text append
            if _rc == 0 {
                file write `fh' `"`c(current_date)' `c(current_time)' | consent_custom_auth | `short' | `s(base_url)'"' _n
                file close `fh'
            }
        }
    }

    // ----- return ----------------------------------------------------------
    return local  short         "`short'"
    return local  name          `"`s(name)'"'
    return local  base_url      `"`s(base_url)'"'
    return local  api_version   "`s(api_version)'"
    return local  auth_type     "`auth_type'"
    return scalar default       = `isdefault'
    return scalar metadata_only = `metadata_only'
    return local  source        "`source'"
    return local  file          `"`file'"'
    sreturn clear
end


*===============================================================================
* __dtlb_catreg_keep : stash the parse results in s() so later capture calls
*                      (confirm file, etc.) cannot clobber them
*===============================================================================
program define __dtlb_catreg_keep, sclass
    sreturn local name          `"`r(name)'"'
    sreturn local base_url      `"`r(base_url)'"'
    sreturn local api_version   `"`r(api_version)'"'
    sreturn local auth_type     `"`r(auth_type)'"'
    sreturn local default       `"`r(default)'"'
    sreturn local metadata_only `"`r(metadata_only)'"'
end


*===============================================================================
* __dtlb_catreg_parse : parse the two-level catalogs.yaml subset
*
*   <short>:            <- top level, no indentation, trailing colon
*     name: ...         <- indented "key: value" scalars
*     base_url: ...
*
* Full-line comments (#...) and blank lines are skipped; an inline " #"
* starts a trailing comment; surrounding single/double quotes on values are
* stripped. Values may contain colons (split is at the FIRST colon only).
* r(found)==1 requires the section to exist AND carry a non-empty base_url.
*===============================================================================
program define __dtlb_catreg_parse, rclass
    version 16
    syntax , file(string) short(string)

    local in_section = 0
    local found      = 0
    foreach f in name base_url api_version auth_type default metadata_only {
        local f_`f' ""
    }

    tempname fh
    capture file open `fh' using `"`file'"', read text
    if _rc {
        return scalar found = 0
        exit
    }

    file read `fh' line
    while r(eof) == 0 {
        local raw `"`macval(line)'"'
        local trimmed = strtrim(`"`raw'"')

        // skip blanks and full-line comments
        if `"`trimmed'"' == "" | substr(`"`trimmed'"', 1, 1) == "#" {
            file read `fh' line
            continue
        }

        local colon_pos = strpos(`"`trimmed'"', ":")
        if `colon_pos' == 0 {
            file read `fh' line
            continue
        }

        if substr(`"`raw'"', 1, 1) != " " {
            // top-level line: "<short>:"
            local section = lower(strtrim(substr(`"`trimmed'"', 1, `colon_pos' - 1)))
            local in_section = ("`section'" == lower("`short'"))
        }
        else if `in_section' {
            // indented "key: value" inside the requested section
            local k = lower(strtrim(substr(`"`trimmed'"', 1, `colon_pos' - 1)))
            local v = strtrim(substr(`"`trimmed'"', `colon_pos' + 1, .))
            // strip trailing inline comment
            local cpos = strpos(`"`v'"', " #")
            if `cpos' > 0 local v = strtrim(substr(`"`v'"', 1, `cpos' - 1))
            // strip surrounding quotes (char(34) = double, char(39) = single;
            // char() comparisons avoid quote-literal parsing pitfalls)
            if length(`"`v'"') >= 2 {
                local first = substr(`"`v'"', 1, 1)
                local last  = substr(`"`v'"', -1, 1)
                if (`"`first'"' == char(34) & `"`last'"' == char(34)) | ///
                   (`"`first'"' == char(39) & `"`last'"' == char(39)) {
                    local v = substr(`"`v'"', 2, length(`"`v'"') - 2)
                }
            }
            if inlist("`k'", "name", "base_url", "api_version", "auth_type", "default", "metadata_only") {
                local f_`k' `"`v'"'
            }
        }

        file read `fh' line
    }
    file close `fh'

    if `"`f_base_url'"' != "" local found = 1

    return scalar found         = `found'
    return local  name          `"`f_name'"'
    return local  base_url      `"`f_base_url'"'
    return local  api_version   `"`f_api_version'"'
    return local  auth_type     `"`f_auth_type'"'
    return local  default       `"`f_default'"'
    return local  metadata_only `"`f_metadata_only'"'
end
