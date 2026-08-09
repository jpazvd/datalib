*******************************************************************************
* yaml_list
*! v 2.0.0   06Jul2026               by Joao Pedro Azevedo (UNICEF)
* List keys and values in YAML data
* v 1.6.0: restore v1.3.x behavior lost in the modular refactor --
*   (1) with -children-, returned/displayed keys are bare child names
*       (parent prefix stripped), as documented and as reviewed for the SJ;
*   (2) -noheader- suppresses all printed output, not just the header;
*   (3) return scalar r(found) = 1 if any key matched, 0 otherwise;
*   (4) fix malformed option declaration NoHeader -> NOHeader (capitals must
*       be a prefix); the typo made -noheader- unrecognizable and corrupted
*       option parsing (v1.3.0 correctly declared NOHeader);
*   (5) strip surrounding quotes from the parent argument in the impl (the
*       wrapper passes it quoted), matching yaml_get; without this the
*       parent filter silently matched nothing/everything.
*******************************************************************************

program define yaml_list, rclass
    version 14.0
    
    syntax [anything(name=parent)] [, Frame(string) Keys Values Separator(string) ///
                                      Children STata NOHeader]
    
    local keys_opt = cond("`keys'" != "", "keys", "")
    local values_opt = cond("`values'" != "", "values", "")
    local children_opt = cond("`children'" != "", "children", "")
    local stata_opt = cond("`stata'" != "", "stata", "")
    local noheader_opt = cond("`noheader'" != "", "noheader", "")

    * If frame specified, add yaml_ prefix if not present
    if ("`frame'" != "") {
        if (`c(stata_version)' < 16) {
            di as err "frame() option requires Stata 16 or later"
            exit 198
        }
        if (substr("`frame'", 1, 5) != "yaml_") {
            local frame "yaml_`frame'"
        }
        
        * Check frame exists
        capture frame `frame': describe, short
        if (_rc != 0) {
            di as err "frame `frame' not found"
            exit 198
        }
        
        * Run list in frame context
        frame `frame' {
            _yaml_list_impl "`parent'", `keys_opt' `values_opt' separator("`separator'") `children_opt' `stata_opt' `noheader_opt'
            * Capture return values before exiting frame block
            local _return_names : r(macros)
            foreach _rn of local _return_names {
                local _rv_`_rn' `"`r(`_rn')'"'
            }
            local _return_scalars : r(scalars)
            foreach _rs of local _return_scalars {
                local _rsv_`_rs' = r(`_rs')
            }
        }
        * Restore return values outside frame block
        foreach _rn of local _return_names {
            return local `_rn' `"`_rv_`_rn''"'
        }
        foreach _rs of local _return_scalars {
            return scalar `_rs' = `_rsv_`_rs''
        }
    }
    else {
        * Use current dataset
        _yaml_list_impl "`parent'", `keys_opt' `values_opt' separator("`separator'") `children_opt' `stata_opt' `noheader_opt'
        return add
    }
end

program define _yaml_list_impl, rclass
    syntax [anything(name=parent)] [, Keys Values Separator(string) Children STata NOHeader]
    
    * Ensure required variables exist
    capture confirm variable key value
    if (_rc != 0) {
        di as err "No YAML data in memory. Use 'yaml read using file.yaml' first."
        exit 198
    }
    
    * Default separator
    if ("`separator'" == "") local separator " "
    
    * If no keys or values specified, default to show both
    if ("`keys'" == "" & "`values'" == "") {
        local keys "keys"
        local values "values"
    }
    
    * Default to show header unless noheader specified
    local show_header = ("`noheader'" == "")
    
    * Filter to children if requested
    * Remove surrounding quotes (the wrapper passes the parent quoted),
    * matching the cleaning yaml_get applies to its search prefix
    local parent = subinstr(`"`parent'"', `"""', "", .)
    local parent = strtrim(`"`parent'"')

    local filter_parent = 0
    if ("`parent'" != "") {
        local filter_parent = 1

        * Clean parent key (colons are path separators: variables:male ==
        * variables_male, matching yaml get colon syntax)
        local parent = subinstr("`parent'", ":", "_", .)
        local parent = subinstr("`parent'", "-", "_", .)
        local parent = subinstr("`parent'", " ", "_", .)
        local parent = subinstr("`parent'", ".", "_", .)
    }
    
    * Build list of matching keys/values
    local key_list ""
    local val_list ""
    local n = _N
    local n_found = 0
    local header_shown = 0

    forvalues i = 1/`n' {
        local k = key[`i']
        local v = value[`i']
        local p = ""

        * Get parent if variable exists
        capture confirm variable parent
        if (_rc == 0) {
            local p = parent[`i']
        }

        * Skip if filtering and this key is not a child
        if (`filter_parent') {
            if ("`children'" != "") {
                * Only immediate children
                if ("`p'" != "`parent'") continue
            }
            else {
                * All descendants
                if (strpos("`k'", "`parent'") != 1) continue
            }
        }

        * If this is the parent key itself, skip unless children not requested
        if ("`children'" != "") {
            if ("`k'" == "`parent'") continue
        }

        * With -children-, return bare child names: strip the parent prefix
        * (v1.3.x behavior; the full flattened key stays available via parent)
        if (`filter_parent' & "`children'" != "") {
            local plen = length("`parent'")
            if (substr("`k'", 1, `plen') == "`parent'" & substr("`k'", `plen' + 1, 1) == "_") {
                local k = substr("`k'", `plen' + 2, .)
            }
        }

        local ++n_found

        * Add to list
        if ("`keys'" != "") {
            if ("`stata'" != "") {
                * Stata compound quote format
                local key_list `"`key_list' `"`k'"'"'
            }
            else {
                local key_list "`key_list'`separator'`k'"
            }
        }
        
        if ("`values'" != "") {
            if ("`stata'" != "") {
                local val_list `"`val_list' `"`v'"'"'
            }
            else {
                local val_list "`val_list'`separator'`v'"
            }
        }
        
        * Display row (-noheader- suppresses all printed output)
        if (`show_header') {
            if (`header_shown' == 0) {
                local header_shown = 1
                if ("`keys'" != "" & "`values'" != "") {
                    di as text "Key" _col(35) "Value"
                }
                else if ("`keys'" != "") {
                    di as text "Key"
                }
                else if ("`values'" != "") {
                    di as text "Value"
                }
            }
            if ("`keys'" != "" & "`values'" != "") {
                di as text "`k'" _col(35) "`v'"
            }
            else if ("`keys'" != "") {
                di as text "`k'"
            }
            else if ("`values'" != "") {
                di as text "`v'"
            }
        }
    }

    * Trim lists
    if ("`keys'" != "") {
        local key_list = strtrim("`key_list'")
        return local keys `"`key_list'"'
    }
    if ("`values'" != "") {
        local val_list = strtrim("`val_list'")
        return local values `"`val_list'"'
    }

    if ("`parent'" != "") {
        return local parent "`parent'"
    }

    return scalar found = (`n_found' > 0)
end
