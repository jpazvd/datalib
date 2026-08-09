*******************************************************
* _dtlb_mergeplan: plan and execute a multi-module load
* Author: Joao Pedro Azevedo
* Co-author: Minh Cong Nguyen (World Bank)
*! v1.6.0  2026-08-08
*******************************************************
* Loads one or more modules of a vintage, joined along the hierarchy they
* declare about themselves, and leaves the result in memory.
*
*   _dtlb_mergeplan, dir(<vintage dir>) stem(<file stem>) modules(<list>) ///
*                    [ strict ]
*
* Returns:
*   r(plan)          the join actually performed, e.g. "student <- classroom"
*   r(spec_source)   where the declarations came from: yaml | char | legacy
*   r(n_modules)     how many modules were joined
*   r(unmatched)     total rows that failed to match a parent
*   r(base)          the finest module, which the result is one row per
*
* WHAT THIS REFUSES, AND WHY IT IS THE POINT
*
* teacher and student are both children of classroom. Asking for the two
* together is many-to-many, and merging it blindly returns 3 teachers x 30
* students = 90 rows that look exactly like data. This command errors instead,
* naming both modules and their common parent. That refusal is the single most
* valuable thing here: every other failure mode announces itself, and this one
* does not.
*
* A DECLARATION IS A CLAIM, NOT A FACT. Keys are checked against the data in
* hand -- the variables must exist, and they must actually identify rows --
* before anything is merged on them. A wrong declaration that is trusted
* produces a wrong answer silently, which is worse than no declaration at all.
* See internal/hierarchical_modules_implementation_plan.md section 5.
*******************************************************

capture program drop _dtlb_mergeplan
program define _dtlb_mergeplan, rclass

    version 16

    syntax , DIR(string) STEM(string) MODules(string) [ STRICT NOWARNing ]

    local dir = subinstr(`"`dir'"', "\", "/", .)
    local mods = lower("`modules'")
    local nm : word count `mods'
    if (`nm'==0) {
        display as error "modules() is empty"
        exit 198
    }

    * ---- resolve every declaration first ---------------------------------
    local srcs ""
    local i 0
    foreach m of local mods {
        local ++i
        _dtlb_modspec, dir(`"`dir'"') module(`m') stem(`stem')
        local lvl_`i'  `"`r(level)'"'
        local key_`i'  `"`r(keys)'"'
        local par_`i'  `"`r(parent)'"'
        local pky_`i'  `"`r(parentkeys)'"'
        local nam_`i'  "`m'"
        local srcs `"`srcs' `r(source)'"'

        if (`"`lvl_`i''"'=="") {
            display as error `"{p}Module {bf:`m'} declares no structure: no module_schema: entry in datalib.yaml, no datalib_* characteristics on the file, and it is not one of the legacy families.{p_end}"'
            display as error `"{p}Load it on its own, or add a {bf:module_schema:} block naming its {bf:level}, {bf:keys} and {bf:parent}.{p_end}"'
            exit 198
        }
    }

    * one source for the whole plan; "mixed" when a vintage is half-declared
    local src : word 1 of `srcs'
    foreach s of local srcs {
        if ("`s'"!="`src'") local src "mixed"
    }

    * ---- depth of each module in the declared hierarchy -------------------
    * Depth is how many parents lie above it. It orders the join and, more
    * usefully, decides ancestry without a graph walk at every comparison.
    forvalues a = 1/`nm' {
        local d 0
        local cur `"`par_`a''"'
        local guard 0
        while (`"`cur'"'!="" & `guard' < 20) {
            local ++d
            local ++guard
            local nxt ""
            forvalues b = 1/`nm' {
                if (`"`nam_`b''"'==`"`cur'"') local nxt `"`par_`b''"'
            }
            * a parent outside the requested set still counts toward depth,
            * but its own parent is unknown here, so stop climbing
            if (`"`nxt'"'==`"`cur'"') local nxt ""
            local cur `"`nxt'"'
        }
        if (`guard'>=20) {
            display as error `"{p}The declared parent chain for {bf:`nam_`a''} does not terminate -- it is cyclic.{p_end}"'
            exit 198
        }
        local dep_`a' = `d'
    }

    * ---- V5: the requested set must form a chain --------------------------
    * Same level AND same keys -> a 1:1 union of the same units (this is what
    * adult and children are). One an ancestor of the other -> m:1. Anything
    * else is two different levels hanging off a common parent, which is
    * many-to-many and is refused.
    forvalues a = 1/`nm' {
        local b = `a' + 1
        forvalues b = `b'/`nm' {
            local same = (`"`lvl_`a''"'==`"`lvl_`b''"') & (`"`key_`a''"'==`"`key_`b''"')
            local anc  = 0
            if (`"`par_`a''"'==`"`nam_`b''"') local anc 1
            if (`"`par_`b''"'==`"`nam_`a''"') local anc 1
            * non-contiguous ancestry: the deeper one carries the other's keys
            if (`dep_`a''!=`dep_`b'') {
                local deep = cond(`dep_`a''>`dep_`b'', `a', `b')
                local shal = cond(`dep_`a''>`dep_`b'', `b', `a')
                local ok 1
                foreach k in `key_`shal'' {
                    if (strpos(" `key_`deep'' ", " `k' ")==0) local ok 0
                }
                if (`ok') local anc 1
            }
            if (!`same' & !`anc') {
                display as error `"{p}Modules {bf:`nam_`a''} and {bf:`nam_`b''} are different levels of the same hierarchy -- {bf:`lvl_`a''} and {bf:`lvl_`b''} -- and neither contains the other.{p_end}"'
                if (`"`par_`a''"'==`"`par_`b''"' & `"`par_`a''"'!="") {
                    display as error `"{p}Both hang off {bf:`par_`a''}, so joining them is many-to-many: the result would carry one row per PAIR, which looks like data and is not.{p_end}"'
                }
                display as error `"{p}Load them separately, or ask for a chain -- for example {bf:module(`par_`a'' `nam_`a'')}.{p_end}"'
                exit 459
            }
        }
    }

    * ---- order finest to coarsest -----------------------------------------
    local order ""
    local remaining `mods'
    forvalues pass = 1/`nm' {
        local best 0
        local bestd -1
        forvalues a = 1/`nm' {
            if (strpos(" `order' ", " `nam_`a'' ")>0) continue
            if (`dep_`a'' > `bestd') {
                local bestd = `dep_`a''
                local best  = `a'
            }
        }
        local order `"`order' `nam_`best''"'
        local idx_`pass' = `best'
    }
    local order = trim(`"`order'"')

    * ---- load the finest, then join each ancestor onto it -----------------
    local b1 = `idx_1'
    local base `"`nam_`b1''"'
    local f `"`dir'/Data/Stata/`stem'_`base'.dta"'
    capture confirm file `"`f'"'
    if (_rc) {
        display as error `"{p}Module {bf:`base'} declares a structure but its file is missing: `f'{p_end}"'
        exit 601
    }
    use `"`f'"', clear

    * V1 + V2 on the base
    _dtlb_mergeplan_check, module(`base') keys(`"`key_`b1''"') file(`"`f'"')

    local plan `"`base'"'
    local unmatched 0
    local base_n = _N
    return scalar rows_`base' = `base_n'

    * A join the user cannot see is a join they cannot check. The report is on
    * by DEFAULT and -nowarning- turns it off, rather than the other way round:
    * a silent merge that quietly returned the wrong shape is exactly the
    * failure this command exists to prevent, and defaults decide what most
    * people see.
    if ("`nowarning'"=="") {
        di as text ""
        di as text "  joining modules"
        di as text "  {hline 54}"
        di as text "  " %-12s "module" %10s "rows" %12s "distinct" "  join key"
        di as text "  {hline 54}"
        di as text "  " %-12s "`base'" %10.0f `base_n' %12s "-" "  (finest level)"
    }

    forvalues p = 2/`nm' {
        local a = `idx_`p''
        local mm `"`nam_`a''"'
        local mf `"`dir'/Data/Stata/`stem'_`mm'.dta"'
        capture confirm file `"`mf'"'
        if (_rc) {
            display as error `"{p}Module {bf:`mm'} declares a structure but its file is missing: `mf'{p_end}"'
            exit 601
        }

        * the join key is the ANCESTOR's own keys, which the finer module
        * carries -- which is what lets a non-contiguous request skip a level
        local jk `"`key_`a''"'
        foreach k in `jk' {
            capture confirm variable `k'
            if (_rc) {
                display as error `"{p}Cannot join {bf:`mm'}: the data in memory has no variable {bf:`k'}, which {bf:`mm'} declares as a key.{p_end}"'
                exit 111
            }
        }

        local same = (`"`lvl_`a''"'==`"`lvl_`b1''"') & (`"`key_`a''"'==`"`key_`b1''"')
        local mtype = cond(`same', "1:1", "m:1")

        * -quietly-: our own report supersedes merge's table, and printing
        * both puts two different summaries of one join on the screen.
        * -tempvar-, not a fixed name: if the base module happens to carry a
        * variable called _dtlb_merge, -merge- fails on the collision. A
        * loader must not impose a name on the data it loads.
        tempvar mflag
        capture quietly merge `mtype' `jk' using `"`mf'"', ///
            keep(master match) generate(`mflag')
        if (_rc) exit _rc

        * The informative number is not the ancestor's own unique count -- V2
        * has already proved its keys unique, so rows==distinct there by
        * construction. It is how many DISTINCT parent keys the finer module
        * carries: the fan-out. 400 persons over 120 households is a 1:many
        * join; 400 over 400 would be 1:1, and would mean something is wrong.
        if ("`nowarning'"=="") {
            tempvar dtag
            quietly egen byte `dtag' = tag(`jk')
            quietly count if `dtag'
            local ndist = r(N)
            drop `dtag'
            quietly describe using `"`mf'"'
            local anc_n = r(N)
            di as text "  " %-12s "`mm'" %10.0f `anc_n' %12.0f `ndist' "  `jk'"
            return scalar rows_`mm'     = `anc_n'
            return scalar distinct_`mm' = `ndist'
        }

        quietly count if `mflag'==1
        local miss = r(N)
        if (`miss' > 0) {
            local unmatched = `unmatched' + `miss'
            * NAME THE MODULE. A bare _merge tabulation tells the reader that
            * something did not match, not what, and a merge that drops rows
            * quietly is the failure this whole design exists to prevent.
            display as text `"{p}note: `miss' row(s) in {bf:`base'} have no match in {bf:`mm'}.{p_end}"'
            if ("`strict'"!="") {
                display as error "strict: unmatched rows are an error"
                exit 459
            }
        }
        drop `mflag'
        local plan `"`plan' <- `mm'"'
    }

    if ("`nowarning'"=="") {
        di as text "  {hline 54}"
        di as text "  " %-12s "joined" %10.0f _N "     one row per `lvl_`b1''"
        di as text ""
    }

    return local plan        `"`plan'"'
    return local spec_source "`src'"
    return local base        "`base'"
    return scalar n_modules  = `nm'
    return scalar unmatched  = `unmatched'
end


* --- V1 and V2, against the data in hand -------------------------------------
capture program drop _dtlb_mergeplan_check
program define _dtlb_mergeplan_check
    version 16
    syntax , MODule(string) KEYs(string) FILE(string)

    foreach k in `keys' {
        capture confirm variable `k'
        if (_rc) {
            display as error `"{p}Module {bf:`module'} declares key {bf:`k'}, which does not exist in `file'.{p_end}"'
            display as error `"{p}The declaration is wrong, or the file is not what the declaration describes.{p_end}"'
            exit 111
        }
    }
    capture isid `keys'
    if (_rc) {
        quietly duplicates report `keys'
        display as error `"{p}Module {bf:`module'} declares keys {bf:`keys'}, but they do not identify rows uniquely in `file'.{p_end}"'
        display as error `"{p}Merging on them would multiply rows silently.{p_end}"'
        exit 459
    }
end
