*******************************************************************************
* __dtlb_extensions_probe
*! v1.1.0  17Jul2026               by Joao Pedro Azevedo (UNICEF)
*!                                  and Minh Cong Nguyen (World Bank)
* Feature detection for datalib REST extensions on a catalog host.
*
* Issues GET <host>/info and reads the expected JSON:
*   { "nada_api": "v2", "extensions": ["audit-v1", "token-v1"] }
*
* Vanilla NADA deployments do not serve /info: a 404 (or any failure) is
* NOT an error — it simply means "no extensions", and callers such as a
* future datalib, audit_event(...) silently no-op. This is deliberately
* named a *probe*, not "capability negotiation": it detects datalib's own
* REST extras (audit-v1, token-v1) on hosts that serve them; it does not
* propose an upstream NADA standard (R-K in the improvement plan).
*
* The result is cached per session (one global per host), so repeated
* catalog calls do not re-probe. force re-probes and refreshes the cache.
* The cache is informational, not a trust boundary: any later audit/token
* POST must itself succeed against the same TLS-validated host (R-F).
*
* Stored results:
*   r(nada_api)    reported NADA API version ("" when /info is absent)
*   r(extensions)  space-separated extension list ("" when none)
*   r(probed)      1 = live probe this call, 0 = served from session cache
*
* Internal helper (double-underscore tier): may be refactored without notice.
* NA-3 of internal/datalib_nada_improvement_plan.md.
*******************************************************************************

program define __dtlb_extensions_probe, rclass
    version 15

    syntax , host(string) [FORCE]

    // strip a trailing slash so <host>/info is well-formed
    local host = strtrim(`"`host'"')
    if substr(`"`host'"', -1, 1) == "/" {
        local host = substr(`"`host'"', 1, length(`"`host'"') - 1)
    }

    // ----- session cache ---------------------------------------------------
    // key: host squashed to [A-Za-z0-9_]; global names cap at 32 chars, and
    // the "dtlbext_" prefix takes 8, so compress to head+length+tail
    // (collision would only mix probes of two near-identical hosts within
    // one session — an acceptable failure mode for an informational cache)
    //
    // The prefix must NOT begin with an underscore. Stata rejects global
    // names that do: `global __dtlb_ext_x "v"` fails with "invalid syntax",
    // r(198), so the previous "__dtlb_ext_" prefix made every probe error
    // out. Same defect, same fix, as in __dtlb_api_read.ado.
    //
    // Squash with a regex rather than a hand-listed character set: the old
    // -foreach ch in ":" "/" ...- list missed $, @, #, ( and ), any of which
    // yields an invalid global name — and for $, macro-expands at assignment.
    // A negated class is closed by construction.
    local hkey = ustrregexra(`"`host'"', "[^A-Za-z0-9_]", "_")
    local hlen = length("`hkey'")
    if `hlen' > 23 {
        local hkey = substr("`hkey'", 1, 12) + string(`hlen') + substr("`hkey'", -6, .)
    }

    if "`force'" == "" & `"${dtlbext_`hkey'}"' != "" {
        // cached value format: "<nada_api>|<extensions>" ("."="empty")
        local cached `"${dtlbext_`hkey'}"'
        local bar = strpos(`"`cached'"', "|")
        local api = substr(`"`cached'"', 1, `bar' - 1)
        local ext = substr(`"`cached'"', `bar' + 1, .)
        if "`api'" == "." local api ""
        if "`ext'" == "." local ext ""
        return local nada_api   "`api'"
        return local extensions "`ext'"
        return scalar probed = 0
        exit
    }

    // ----- live probe ------------------------------------------------------
    local api ""
    local ext ""
    capture __dtlb_api_read using `"`host'/info"', auth_type(none)
    if _rc == 0 {
        if r(status_code) == 200 & `"`r(body_path)'"' != "" {
            local bodyfile `"`r(body_path)'"'
            capture __dtlb_json scalar, file(`"`bodyfile'"') key(nada_api)
            if _rc == 0 & r(found) == 1 local api "`r(value)'"
            capture __dtlb_json list, file(`"`bodyfile'"') key(extensions)
            if _rc == 0 & r(found) == 1 local ext `"`r(values)'"'
            capture erase `"`bodyfile'"'
        }
        // any non-200 (404 on vanilla NADA): no extensions, not an error
    }

    // ----- cache + return --------------------------------------------------
    local capi = cond("`api'" == "", ".", "`api'")
    local cext = cond(`"`ext'"' == "", ".", `"`ext'"')
    global dtlbext_`hkey' "`capi'|`cext'"

    return local nada_api   "`api'"
    return local extensions `"`ext'"'
    return scalar probed = 1
end
