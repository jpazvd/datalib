*******************************************************
* _dtlb_modspec: resolve a module's declared structure
* Author: Joao Pedro Azevedo
* Co-author: Minh Cong Nguyen (World Bank)
*! v1.6.0  2026-08-08
*******************************************************
* Answers, for one module of one vintage: what is its unit of observation,
* which variables identify a row, and what does it hang off?
*
*   _dtlb_modspec, dir(<vintage dir>) module(<name>) [stem(<file stem>)]
*
* Returns:
*   r(level)       unit of observation ("" when nothing is declared)
*   r(keys)        variables that uniquely identify a row
*   r(parent)      module one level up; empty at a root
*   r(parentkeys)  the parent's keys, which this module also carries
*   r(source)      where the answer came from: yaml | char | legacy | none
*
* RESOLUTION ORDER, and why it is this way round:
*
*   1. datalib.yaml   module_schema: is the AUTHORITY. It is language-neutral,
*                     so the R and Python clients read the same declaration and
*                     the golden conformance cases stay comparable.
*   2. _dta chars     the MIRROR, for a .dta that has left its folder. Chars are
*                     Stata-only, so they can never be the authority without
*                     making the three implementations disagree by construction.
*   3. legacy table   the hardcoded HLT/DTZ keys, for archives predating any
*                     declaration.
*
* r(source) is reported for the same reason r(vintage_source) is: a resolver
* that will not say how it decided cannot be audited.
*
* A DECLARATION IS A CLAIM, NOT A FACT. This command reports what is declared;
* it does not verify that the named variables exist or that the keys are
* unique. That is _dtlb_mergeplan's job, against the data in hand. See
* internal/hierarchical_modules_implementation_plan.md section 5.
*******************************************************

capture program drop _dtlb_modspec
program define _dtlb_modspec, rclass

    version 15

    syntax , DIR(string) MODule(string) [ STEM(string) ]

    local m   = lower("`module'")
    local dir = subinstr(`"`dir'"', "\", "/", .)

    local level  ""
    local keys   ""
    local parent ""
    local pkeys  ""
    local src    "none"

    * ---- 1. datalib.yaml : module_schema: --------------------------------
    * Hand-parsed rather than handed to yaml_read: the YAML library is an
    * optional dependency (_dtlb_catalog degrades gracefully without it), and a
    * loader that cannot resolve keys unless an optional package is installed
    * would fail for a reason the user cannot see from the error.
    capture confirm file `"`dir'/datalib.yaml"'
    if (_rc==0) {
        tempname fh
        capture file close `fh'
        file open `fh' using `"`dir'/datalib.yaml"', read text

        local inblock 0
        local inmod   0
        file read `fh' line
        while (r(eof)==0) {
            local raw `"`macval(line)'"'
            local trimmed = trim(`"`raw'"')

            * a top-level key ends any block we were inside
            if (substr(`"`raw'"',1,1)!=" ") & (`"`trimmed'"'!="") {
                local inblock = (`"`trimmed'"'=="module_schema:")
                local inmod   0
            }
            else if (`inblock') {
                * two-space indent introduces a module; four-space is its fields
                if (regexm(`"`raw'"', "^  ([A-Za-z0-9_]+):[ ]*$")) {
                    local inmod = (lower(regexs(1))=="`m'")
                }
                else if (`inmod') {
                    if (regexm(`"`trimmed'"', "^level:[ ]*(.*)$"))      local level  = trim(regexs(1))
                    if (regexm(`"`trimmed'"', "^keys:[ ]*(.*)$"))       local keys   = trim(regexs(1))
                    if (regexm(`"`trimmed'"', "^parent:[ ]*(.*)$"))     local parent = trim(regexs(1))
                    if (regexm(`"`trimmed'"', "^parentkeys:[ ]*(.*)$")) local pkeys  = trim(regexs(1))
                }
            }
            file read `fh' line
        }
        file close `fh'
        * BOTH level and keys, not level alone. A module declared with a
        * level and no keys would be reported as fully declared, and the
        * planner would then fail on the missing key with an error that points
        * at the data rather than at the incomplete declaration. A partial
        * declaration is not a declaration.
        if ("`level'"!="" & "`keys'"!="") local src "yaml"
        else {
            local level "" 
            local keys  ""
        }
    }

    * ---- 2. _dta characteristics on the file itself ------------------------
    if ("`level'"=="" & `"`stem'"'!="") {
        local dta `"`dir'/Data/Stata/`stem'_`m'.dta"'
        capture confirm file `"`dta'"'
        if (_rc==0) {
            * -describe using- does not expose chars, so the file has to be
            * opened. -in 1- keeps that cheap: chars are dataset-level, so one
            * observation carries the whole declaration.
            preserve
            capture use in 1 using `"`dta'"', clear
            if (_rc==0) {
                local level  `"`: char _dta[datalib_level]'"'
                local keys   `"`: char _dta[datalib_keys]'"'
                local parent `"`: char _dta[datalib_parent]'"'
                local pkeys  `"`: char _dta[datalib_parentkeys]'"'
            }
            restore
            if ("`level'"!="" & "`keys'"!="") local src "char"
            else {
                local level ""
                local keys  ""
            }
        }
    }

    * ---- 3. the legacy hardcoded families ---------------------------------
    * Reproduces exactly what _dtlb_load's three duplicated if-blocks declared
    * for HLT and DTZ, so an archive predating module_schema: keeps working.
    if ("`level'"=="") {
        if ("`m'"=="household") {
            local level "household"
            local keys  "svy_id household_id"
            local src   "legacy"
        }
        else if (inlist("`m'","hhmembers","adult","children")) {
            local level  "person"
            local keys   "svy_id household_id line_number"
            local parent "household"
            local pkeys  "svy_id household_id"
            local src    "legacy"
        }
    }

    return local level      "`level'"
    return local keys       "`keys'"
    return local parent     "`parent'"
    return local parentkeys "`pkeys'"
    return local source     "`src'"
end
