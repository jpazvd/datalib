*******************************************************
** _dl_islib
* Joao Pedro Azevedo
*! v1.6.0
*******************************************************
* Normalise a path and decide whether it is a datalib LIBRARY (not merely an
* existing directory). Used by datalib_root's -find- mode so that a missing
* library fails loudly instead of resolving to whatever directory happens to
* exist at the candidate path.
*
* Returns:
*   r(path)   normalised path (forward slashes, no trailing separator except
*             on a drive root such as Z:/)
*   r(exists) 1 if the directory exists
*   r(islib)  1 if it exists AND looks like a library, by any of three tests:
*             it is named "datalib", or it carries a .datalib marker file, or it
*             holds a <CCC>/<CCC>_* GRANDCHILD PAIR -- a 3-character child that
*             itself contains a "<child>_*" folder. The name and marker tests
*             let a freshly created, still-empty library qualify.
*
*             The third test deliberately checks the grandchild, not just "a
*             3-character child": the weaker test passes on ordinary
*             directories (C:/ has c:/ado), which is exactly how a missing
*             library could resolve to its parent and have that parent's
*             subfolders read as country codes. See the comment at the test.
*
* Provenance: ported verbatim from unicef-drp/datalib-unicef-dev @ v0.9.33
* (a66b6b6) stata/src/_/_dl_islib.ado. Generalized: nothing -- the test is
* structural and carries no deployment assumptions.
*******************************************************

capture program drop _dl_islib
program define _dl_islib, rclass

    version 15

    args p

    quietly {
        * ---- normalise -----------------------------------------------------
        local p = subinstr(`"`p'"', "\", "/", .)
        while (substr(`"`p'"', -1, 1)=="/" & strlen(`"`p'"')>1 & substr(`"`p'"', -2, 1)!=":") {
            local p = substr(`"`p'"', 1, strlen(`"`p'"')-1)
        }
        return local path `"`p'"'

        * ---- is this root even reachable? ----------------------------------
        * -direxists()- on a disconnected network share BLOCKS on the OS, and
        * Stata offers no way to bound a filesystem call. The resolver walks
        * several candidates, so one dead drive is not one pause -- it is one
        * per candidate, which is why Stata appears frozen rather than slow.
        * (Observed 2026-08-08: ${datalib} = Z:/datalib with the VPN down,
        * _dl_islib "Z:/datalib" then "Z:/datalib/datalib", Stata "not
        * responding". A bare -ls- on the same share hung identically, so this
        * is the OS, not Stata.)
        *
        * We cannot make the FIRST probe safe. We can stop it becoming the
        * tenth, and skip it entirely when the operator has said they are
        * offline. Two guards, in that order.
        local vol = ""
        if (regexm(`"`p'"', "^([A-Za-z]):")) local vol = upper(regexs(1))
        if (substr(`"`p'"',1,2)=="//")       local vol = "UNC"

        * (1) offline: skip network roots without touching them
        if ("`vol'"!="" & "`vol'"!="C" & "${datalib_offline}"=="1") {
            noi di as text `"{p}note: skipping {bf:`p'} -- \${datalib_offline} is set and this root is not on the system drive.{p_end}"'
            return scalar exists = 0
            return scalar islib  = 0
            return scalar skipped_offline = 1
            exit
        }

        * (2) memoise: one dead volume is probed ONCE per session, not once
        * per candidate. This is what turns "frozen" into "one pause, then a
        * clear answer".
        if ("`vol'"!="" & "${dtlb_dead_`vol'}"=="1") {
            return scalar exists = 0
            return scalar islib  = 0
            return scalar skipped_dead = 1
            exit
        }

        * ---- exists? -------------------------------------------------------
        mata: st_local("ok", strofreal(direxists(st_local("p"))))
        if ("`ok'"!="1") {
            * A volume that failed once will fail for every remaining
            * candidate, and each of those failures costs another OS timeout.
            if ("`vol'"!="" & "`vol'"!="C") {
                global dtlb_dead_`vol' = 1
                noi di as text `"{p}note: {bf:`vol':} did not respond. Further candidates on that volume are skipped for this session. If it is a network drive, connect it (or set {bf:global datalib_offline 1}) and restart.{p_end}"'
            }
            return scalar exists = 0
            return scalar islib  = 0
            exit
        }
        return scalar exists = 1

        * ---- does it look like a library? ----------------------------------
        local base = word(subinstr(`"`p'"', "/", " ", .), -1)
        if (lower(`"`base'"')=="datalib") {
            return scalar islib = 1
            exit
        }
        capture confirm file `"`p'/.datalib"'
        if (_rc==0) {
            return scalar islib = 1
            exit
        }
        * Structural test: a library holds <CCC>/<CCC>_<YYYY>_<SURVEY>/... So
        * require a 3-character child that itself holds a "<child>_*" folder.
        * Testing the grandchild matters -- a bare "3-character folder" test
        * passes on ordinary directories (C:/ has c:/ado), which would let a
        * missing library resolve to whatever exists at the candidate path.
        * Case is not usable here: Stata's -dir- lowercases names on Windows.
        local ccs ""
        capture local ccs : dir `"`p'"' dirs "???"
        local hits 0
        foreach d of local ccs {
            local subs ""
            capture local subs : dir `"`p'/`d'"' dirs `"`d'_*"'
            local ns : word count `subs'
            if (`ns' > 0) {
                local hits 1
                continue, break
            }
        }
        return scalar islib = (`hits' > 0)
    }

end
