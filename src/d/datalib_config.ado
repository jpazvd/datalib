*******************************************************
* datalib_config: read the operator's datalib configuration
* Author: Joao Pedro Azevedo
* Co-author: Minh Cong Nguyen (World Bank)
*! v1.7.1  2026-08-05
*******************************************************
* Thin alias for -getuserconfig-, under the datalib_* name used by the R and
* Python legs (datalib_config() there). Every option is passed through
* unchanged, and every r() result is the one getuserconfig returned.
*
* The command it wraps is deliberately NOT datalib-specific: one config file is
* meant to serve sibling tools, and only the `datalib:` key belongs to this
* package. The alias exists so the three languages name the same operation.
*
* Provenance: ported from unicef-drp/datalib-unicef-dev @ v0.9.33 (a66b6b6)
* stata/src/d/datalib_config.ado (there v0.9.3). Generalized: upstream's
* -init- branch (which called datalib_root, find to bootstrap a config file) is
* not carried. The bootstrap it existed for is served instead by getuserconfig's
* -create- option, which writes only what is missing and never guesses a root.
*******************************************************

capture program drop datalib_config
program define datalib_config, rclass

    version 15

    syntax [, USER(string) CONFIG(string) CONFIGDIR(string) QUIETly EDIT CREATE ROOT(string) LIST RETRYVolumes]

    * ---- list: every configuration found, which one wins, and its state ----
    * "Which datalib am I running, against which root?" is two questions, and
    * a user with more than one answer to either has no way to see it. Both
    * are reported, because the package matters as much as the root: two
    * different packages can both provide -datalib- and whichever is first on
    * the adopath wins silently.
    if ("`list'"!="") {
        _dtlb_config_list
        exit
    }

    * Forget which volumes were recorded unreachable. _dl_islib skips a
    * recorded volume WITHOUT probing it, which is the point -- but a drive
    * that comes back would stay invisible, so the record has to be
    * forgettable, and by a command rather than by knowing which file to
    * delete.
    if ("`retryvolumes'"!="") {
        capture __dtlb_userhome
        if (_rc) {
            display as error "datalib_config: cannot locate your home directory"
            exit 198
        }
        local dhome = subinstr(`"`r(datalib_home)'"', "\", "/", .)
        local memof `"`dhome'/offline_volumes.txt"'

        local cleared ""
        capture confirm file `"`memof'"'
        if (_rc==0) {
            tempname rh
            file open `rh' using `"`memof'"', read text
            file read `rh' rline
            while (r(eof)==0) {
                local rv = strtrim(upper(`"`macval(rline)'"'))
                if (`"`rv'"'!="") {
                    global dtlb_dead_`rv' ""
                    local cleared `"`cleared' `rv'"'
                }
                file read `rh' rline
            }
            file close `rh'
            capture erase `"`memof'"'
        }
        global dtlb_deadmemo_loaded ""

        if (`"`cleared'"'=="") {
            display as text "No volumes were recorded unreachable; nothing to forget."
        }
        else {
            display as text `"Forgot:`cleared'. They will be probed again on the next lookup, which costs the operating system's timeout if a drive is still down."'
        }
        exit
    }

    getuserconfig, user(`"`user'"') config(`"`config'"') configdir(`"`configdir'"') ///
                   root(`"`root'"') `quietly' `edit' `create'
    return add

end


* --- which configurations exist, and which one is in force -------------------
capture program drop _dtlb_config_list
program define _dtlb_config_list, rclass
    version 15

    di as text ""
    di as text "  datalib configuration"
    di as text "  {hline 66}"

    * which PACKAGE is answering
    * -findfile-, not -which-: -which- prints a path but does not reliably
    * return it in r(fn), so the field came back blank. The PACKAGE matters as
    * much as the root -- two installs can both provide -datalib- and the one
    * first on the adopath wins silently.
    capture findfile datalib.ado
    if (_rc==0) di as text "  command      " as result `"`r(fn)'"'
    else        di as text "  command      " as error  "datalib.ado not on the adopath"
    di as text ""

    * every source, in resolution order
    capture __dtlb_userhome
    local uh `"`r(datalib_home)'"'
    local n 0
    local winner ""

    foreach spec in "argument|" "global|${datalib}" "env|`:environment DATALIB_ROOT'" {
        local nm  = substr("`spec'", 1, strpos("`spec'","|")-1)
        local val = substr("`spec'", strpos("`spec'","|")+1, .)
        if (`"`val'"'!="") {
            local ++n
            _dtlb_config_state `"`val'"'
            di as text "  " %-14s "`nm'" %-30s abbrev(`"`val'"',30) "  " as result "`r(state)'"
            if ("`winner'"=="") local winner "`nm'"
        }
    }
    foreach f in `"`uh'/config.yml"' `"`c(sysdir_personal)'/../.config/user_config.yml"' {
        capture confirm file `"`f'"'
        if (_rc==0) {
            local ++n
            di as text "  " %-14s "config file" %-30s abbrev(`"`f'"',30) "  " as result "present"
        }
    }

    di as text "  {hline 66}"
    if (`n'>1) {
        di as text `"{p}note: `n' configuration sources are present. The first row is in force; pin one deliberately with {bf:datalib_root, root(}{it:path}{bf:) set}.{p_end}"'
    }
    else if (`n'==0) {
        di as text `"{p}No datalib root is configured. Set one with {bf:datalib_root, root(}{it:path}{bf:) set}, or build a practice library with {bf:datalib_makelib}.{p_end}"'
    }
    di as text ""

    return scalar n_sources = `n'
    return local  winner    "`winner'"
end

* --- reachable, unreachable, or skipped -- WITHOUT hanging on a dead share ---
capture program drop _dtlb_config_state
program define _dtlb_config_state, rclass
    version 15
    args p
    local vol = ""
    if (regexm(`"`p'"', "^([A-Za-z]):")) local vol = upper(regexs(1))
    if (substr(`"`p'"',1,2)=="//")       local vol = "UNC"

    * Report a KNOWN-dead or offline-skipped volume from the memo rather than
    * probing it. A status command that hangs while telling you why datalib
    * hangs would be a poor joke.
    if ("`vol'"!="" & "${dtlb_dead_`vol'}"=="1") {
        return local state "UNREACHABLE (`vol':)"
        exit
    }
    if ("`vol'"!="" & "`vol'"!="C" & "${datalib_offline}"=="1") {
        return local state "skipped (offline)"
        exit
    }
    capture _dl_islib `"`p'"'
    if (_rc | r(exists)!=1) return local state "not found"
    else                    return local state "ok"
end
