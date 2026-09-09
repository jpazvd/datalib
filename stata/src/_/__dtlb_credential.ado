*******************************************************************************
* __dtlb_credential
*! v1.1.0  17Jul2026               by Joao Pedro Azevedo (UNICEF)
*!                                  and Minh Cong Nguyen (World Bank)
* Resolve the API credential for an authenticated catalog call.
*
* Lookup order (NA-2 of internal/datalib_nada_improvement_plan.md):
*   1. DATALIB_TOKEN environment variable
*   2. ${datalib_token} Stata global
*   3. error 198 naming both options
* auth_type(none) short-circuits: returns an empty token, no error.
*
* This is a strict improvement over the session-scoped set_api_key() pattern
* of the existing NADA clients: the env var survives across sessions, works
* in batch/CI, and never lands in a do-file or log.
*
* Stored results:
*   r(token)   the credential ("" when auth_type is none)
*   r(source)  env | global | "" (when auth_type is none)
*
* Internal helper (double-underscore tier): may be refactored without notice.
*******************************************************************************

program define __dtlb_credential, rclass
    version 15

    syntax , auth_type(string)

    local auth_type = lower(strtrim("`auth_type'"))
    if !inlist("`auth_type'", "x-api-key", "bearer", "none") {
        display as error "auth_type() must be one of: x-api-key, bearer, none"
        exit 198
    }

    if "`auth_type'" == "none" {
        return local token  ""
        return local source ""
        exit
    }

    local envtok : environment DATALIB_TOKEN
    if `"`envtok'"' != "" {
        return local token  `"`envtok'"'
        return local source "env"
        exit
    }

    if `"${datalib_token}"' != "" {
        return local token  `"${datalib_token}"'
        return local source "global"
        exit
    }

    display as error "no credential found for auth_type(`auth_type'):"
    display as error "  set the DATALIB_TOKEN environment variable (preferred), or"
    display as error `"  the \${datalib_token} global (this session only)"'
    exit 198
end
