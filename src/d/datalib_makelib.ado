*******************************************************
* datalib_makelib: build a synthetic microdata library
* Author: Joao Pedro Azevedo
* Co-author: Minh Cong Nguyen (World Bank)
*! v1.6.0  2026-08-07
*******************************************************
* Materialises a small, complete datalib library at a path you choose, so that
* every command in the package has something real to run against: the IHSN
* folder grammar, master and adaptation vintages, labelled Stata datasets, the
* original delivery, documentation, programs, and a datalib.yaml per vintage.
*
* WHY THIS EXISTS RATHER THAN A SHIPPED LIBRARY. -net install- places package
* files in the PLUS tree by basename and does not preserve directories, so a
* nested library cannot travel through datalib.pkg: the tree would arrive
* flattened, with most files overwriting one another. The data here is fully
* synthetic and cheap to generate, so the package ships the recipe instead of
* the result -- which also means the library lands somewhere writable, and
* belongs to you.
*
* The generated library is marked with a .datalib file carrying "demo: true",
* so it is recognisable as synthetic, and is NOT marked read-only: it is your
* copy, in your directory, and depositing into it is the point.
*
* Country codes default to the ISO 3166-1 user-assigned range (ZZA, ZZB) so a
* generated library cannot be confused with a real archive, and a request for a
* real survey against it fails as it should instead of returning made-up
* numbers. Pass countries() to override.
*
* Syntax:
*   datalib_makelib [, path(dir) COUNTries(list) FAMilies(list) SEED(#)
*                      REPLACE QUIETly ]
*
*     path(dir)        where to build it; default "datalib" in the working
*                      directory, which is also the first place discovery looks
*     families(list)   which survey shapes to generate; default "generic".
*                      "demo" builds fictional countries and surveys with
*                      LINKED HIERARCHIES: a household survey as household +
*                      roster, and a school assessment as school + classroom +
*                      teacher + student. Each module declares its own keys, in
*                      module_schema: in datalib.yaml and mirrored into _dta
*                      characteristics, so -datalib- can plan the merge from
*                      the data rather than from a hardcoded table.
*     countries(list)  ISO3 codes for the "generic" family; default "ZZA ZZB"
*     seed(#)          random-number seed; default 20260805, so two runs on two
*                      machines produce comparable data
*     replace          overwrite an existing library at that path
*     quietly          suppress the progress report
*
* THE LEGACY SURVEY SHAPES ARE NOT INVENTED. Each of these families reproduces
* module names and keys this repository actually documents:
*   pnad   dom, pes, both              (src/i/ibge.ado; registry/examples)
*   pnadc  tri, anual; PANEL: idbas,idrs   (src/i/ibge.ado)
*   saeb   student                     (an earlier example library)
*   mics   hh, hl, wm, mn, bh, ch, fs  (00_documentation/mics_data_acquisition.md;
*                                       mn optional, fs is MICS6 onwards)
*   dhs    household, women, children  (the recode-file convention that
*                                       qa/fixtures/build.sh records is noted in
*                                       the help file, not reproduced here)
*   hlt    household, hhmembers, adult, children -- the harmonized adaptation,
*          keyed svy_id household_id [line_number]  (_dtlb_load.ado)
*
* THE "demo" FAMILY IS DIFFERENT, AND DELIBERATELY SO. Its countries and
* surveys are FICTIONAL, because a demo library that says BRA 2015 PNAD invites
* someone to mistake synthetic numbers for Brazilian ones. Codes are drawn from
* ISO 3166-1's four permanently user-assigned alpha-3 ranges (AAA-AAZ, QMA-QZZ,
* XAA-XZZ, ZZA-ZZZ): the three-letter shape every checker expects, with
* collision against a real country impossible.
*
* Its purpose is to exercise LINKED HIERARCHIES, which none of the legacy
* families can express:
*   XHS  household + roster                       (2 levels)
*   XSA  school + classroom + teacher + student   (4 levels, and a sibling pair)
* The teacher/student pair matters: both are children of classroom, so asking
* for them together is many-to-many, and a loader that merges it blindly
* returns a cartesian product that looks like data.
*
* Legacy and hierarchical generators are dispatched by dims(), not by module
* name, because the names collide -- mics and dhs already use "household" and
* saeb already uses "student".
*
* Returns:
*   r(path)      the library root
*   r(vintages)  number of vintages created
*******************************************************

capture program drop datalib_makelib
program define datalib_makelib, rclass

    version 15

    syntax [, PATH(string) COUNTries(string) FAMilies(string) ///
              SEED(integer 20260805) REPLACE QUIETly ]

    if (`"`path'"'=="")      local path "datalib"
    if (`"`countries'"'=="") local countries "ZZA ZZB"
    if (`"`families'"'=="")  local families "generic"

    local path = subinstr(`"`path'"', "\", "/", .)
    while (substr(`"`path'"', -1, 1)=="/" & strlen(`"`path'"')>1 & substr(`"`path'"', -2, 1)!=":") {
        local path = substr(`"`path'"', 1, strlen(`"`path'"')-1)
    }

    * ---- refuse to build on top of something we did not create -------------
    mata: st_local("exists", strofreal(direxists(st_local("path"))))
    if ("`exists'"=="1" & "`replace'"=="") {
        capture confirm file `"`path'/.datalib"'
        local ismarked = (_rc==0)
        di as err `"{p}A directory already exists at: `path'{p_end}"'
        if (`ismarked') {
            di as err `"{p}It carries a {bf:.datalib} marker, so it is already a library. Add {bf:replace} to rebuild it, or choose another {bf:path()}.{p_end}"'
        }
        else {
            di as err `"{p}It is not a datalib library. Choose another {bf:path()} rather than writing a library over it — {bf:replace} would add files to a directory this command did not create.{p_end}"'
        }
        exit 602
    }

    quietly {
        capture mkdir `"`path'"'

        * marker: synthetic, but writable -- this copy belongs to the operator
        tempname mk
        capture file close `mk'
        file open `mk' using `"`path'/.datalib"', write replace text
        file write `mk' "# datalib library marker" _n
        file write `mk' "#" _n
        file write `mk' "# Generated by datalib_makelib. The data below is synthetic: variables are" _n
        file write `mk' "# drawn from fixed distributions with a pinned seed, so two builds agree," _n
        file write `mk' "# and no value describes any real person or household." _n
        file write `mk' "demo: true" _n
        file close `mk'

        local made 0
        local built ""

        * ---- family shapes -------------------------------------------------
        * "demo" builds 6 masters + 2 adaptations across 5 surveys. The count is
        * held at what it was before the hierarchies landed, deliberately, so
        * DET cases that assert inventory size do not churn when only the shapes
        * change.
        *
        * COUNTRIES AND SURVEYS ARE FICTIONAL. The codes come from ISO 3166-1's
        * four permanently user-assigned alpha-3 ranges (AAA-AAZ, QMA-QZZ,
        * XAA-XZZ, ZZA-ZZZ), so they keep the three-letter shape every checker
        * expects while being guaranteed never to collide with a real country.
        * Survey acronyms are X-prefixed to read as invented. A demo library
        * that says BRA 2015 PNAD invites someone to mistake synthetic numbers
        * for Brazilian ones.
        *
        * XAA Arcadia   XBB Borduria   QMA Ruritania   ZZA Syldavia
        * XHS household survey   XSA school assessment   XLF labour force
        if (strpos(" `families' ", " demo ")) {
            local built `"`built' demo (XAA/XBB/QMA/ZZA -- fictional, hierarchical)"'

            * Arcadia household survey: two master vintages and an adaptation.
            * 120 households, 400 people -- so every household has at least
            * three members and no roster row is orphaned.
            _dl_mklib_survey, root(`"`path'"') country(XAA) year(2015) survey(XHS) ///
                vintages("v01 v02") modules("household roster") obs("120 400") ///
                dims("120") ///
                yamlfor("v01") adapt("hcl") adaptmaster("v01") ///
                adaptmodules("household roster") adaptobs("120 400") seed(`seed')
            local made = `made' + 3

            * Arcadia school assessment: the four-level hierarchy.
            * 40 schools, 120 classrooms, 240 teachers, 900 students.
            _dl_mklib_survey, root(`"`path'"') country(XAA) year(2021) survey(XSA) ///
                vintages("v01") modules("school classroom teacher student") ///
                obs("40 120 240 900") dims("40 120") ///
                yamlfor("v01") seed(`=`seed'+11')
            local made = `made' + 1

            _dl_mklib_survey, root(`"`path'"') country(XBB) year(2019) survey(XHS) ///
                vintages("v01") modules("household roster") obs("150 480") ///
                dims("150") yamlfor("v01") seed(`=`seed'+22')
            local made = `made' + 1

            _dl_mklib_survey, root(`"`path'"') country(QMA) year(2014) survey(XLF) ///
                vintages("v01") modules("household roster") obs("100 320") ///
                dims("100") yamlfor("v01") seed(`=`seed'+33')
            local made = `made' + 1

            * Syldavia: a second adaptation, so adaptation arithmetic has more
            * than one case to be right about.
            _dl_mklib_survey, root(`"`path'"') country(ZZA) year(2022) survey(XHS) ///
                vintages("v01") modules("household roster") obs("90 300") ///
                dims("90") yamlfor("v01") adapt("hcl") adaptmaster("v01") ///
                adaptmodules("household roster") adaptobs("90 300") ///
                seed(`=`seed'+44')
            local made = `made' + 2
        }

        * ---- "qa": the complete factorial ----------------------------------
        * 3 countries x 2 years x 2 surveys, each with 2 master vintages and 2
        * adaptation vintages: 48 vintages, every cell filled.
        *
        * The point is not size, it is ASSERTABILITY. -demo- is five one-off
        * surveys with a single year and mostly a single vintage each, so the
        * eleven macros _dtlb_svycheck returns about multiplicity
        * (r(multiplevintages), r(latestyear), r(latestsurvey), r(mastervintages),
        * r(adaptationvintages) ...) and the ten _dtlb_vcheck returns about
        * vintage arithmetic (r(Mlatestvintage), r(Mnumvintages),
        * r(Avintagelist) ...) have exactly one candidate to choose from. A
        * checker that always returns the only item present passes such a test
        * whether or not it works. Here every dimension has two, so "latest" has
        * a WRONG answer available and a regression fails instead of coinciding.
        *
        * Countries stay in the ISO user-assigned ZZ range for the same reason
        * the default does: a generated tree must never be mistaken for a real
        * archive. Survey acronyms are X-prefixed for the same reason -- this
        * family used to name them MICS and DHS, which put invented numbers
        * under the banner of two real survey programmes.
        *
        * The rename does not move any value: the seed is
        * `seed'+1000+17*`qi'', which depends on iteration order, not on the
        * acronym. The survey name reaches the data only as the svy_id string.
        if (strpos(" `families' ", " qa ")) {
            local built `"`built' qa (3 countries x 2 years x 2 surveys, 2M+2A each)"'
            local qi 0
            foreach qc in ZZA ZZB ZZC {
                foreach qy in 2015 2019 {
                    foreach qs in XHS XLF {
                        local qi = `qi' + 1
                        _dl_mklib_survey, root(`"`path'"') country(`qc') ///
                            year(`qy') survey(`qs') ///
                            vintages("v01 v02") modules("household person") ///
                            obs("120 240") yamlfor("v01 v02") ///
                            adapt("hlt") adaptmaster("v02") ///
                            adaptvintages("v01 v02") ///
                            adaptmodules("household person") adaptobs("120 240") ///
                            seed(`=`seed' + 1000 + 17*`qi'')
                        local made = `made' + 4
                    }
                }
            }
        }

        * ---- the documented survey families --------------------------------
        local fcc : word 1 of `countries'
        if ("`fcc'"=="") local fcc "ZZA"
        local fidx 0
        foreach fam of local families {
            local fam = lower("`fam'")
            local fidx = `fidx' + 1
            local fseed = `seed' + 100*`fidx'

            if ("`fam'"=="pnad") {
                local built `"`built' `fcc' PNAD"'
                _dl_mklib_survey, root(`"`path'"') country(`fcc') year(2015) survey(PNAD) ///
                    vintages("v01 v02") modules("dom pes both") obs("120 380 380") ///
                    yamlfor("v01 v02") adapt("dtz92") adaptmaster("v01") ///
                    adaptmodules("dom pes both") adaptobs("120 380 380") seed(`fseed')
                local made = `made' + 3
            }
            if ("`fam'"=="pnadc") {
                local built `"`built' `fcc' PNADC"'
                _dl_mklib_survey, root(`"`path'"') country(`fcc') year(2019) survey(PNADC) ///
                    vintages("v01") modules("tri anual") obs("400 400") ///
                    yamlfor("v01") adapt("panel") adaptmaster("v01") ///
                    adaptmodules("idbas idrs") adaptobs("400 400") seed(`fseed')
                local made = `made' + 2
            }
            if ("`fam'"=="saeb") {
                local built `"`built' `fcc' SAEB"'
                _dl_mklib_survey, root(`"`path'"') country(`fcc') year(2021) survey(SAEB) ///
                    vintages("v01") modules("student") obs("600") yamlfor("v01") seed(`fseed')
                local made = `made' + 1
            }
            if ("`fam'"=="mics") {
                local built `"`built' `fcc' MICS"'
                * mn is optional and fs is MICS6 onwards -- both included here
                _dl_mklib_survey, root(`"`path'"') country(`fcc') year(2019) survey(MICS) ///
                    vintages("v01") modules("hh hl wm mn bh ch fs") ///
                    obs("180 620 240 180 300 220 210") yamlfor("v01") ///
                    adapt("hlt") adaptmaster("v01") ///
                    adaptmodules("household hhmembers adult children") ///
                    adaptobs("180 620 300 220") seed(`fseed')
                local made = `made' + 2
            }
            if ("`fam'"=="dhs") {
                local built `"`built' `fcc' DHS"'
                * producer-native recode names, as the repository's own fixture
                * writes them -- these deliberately break the <version>_<module>
                * rule, which is exactly the case worth having in a library
                _dl_mklib_survey, root(`"`path'"') country(`fcc') year(2014) survey(DHS) ///
                    vintages("v01") modules("household women children") ///
                    obs("200 260 240") yamlfor("v01") adapt("hlt") adaptmaster("v01") ///
                    adaptmodules("household hhmembers adult children") ///
                    adaptobs("200 620 300 240") seed(`fseed')
                local made = `made' + 2
            }
        }

        if (`made'>0) local countries ""
        else local built `"`countries'"'
        local cidx 0
        foreach c of local countries {
            local cidx = `cidx' + 1
            local c = upper("`c'")
            capture mkdir `"`path'/`c'"'

            * two surveys per country, on a fixed calendar so the tree is stable
            local yr1 = 2015 + `cidx'
            local yr2 = 2019 + `cidx'
            local svys "`yr1' HHS `yr2' LFS"

            local k 0
            while (`k' < 2) {
                local k = `k' + 1
                local yr  : word `=2*`k'-1' of `svys'
                local svy : word `=2*`k''   of `svys'
                local stub = upper("`c'_`yr'_`svy'")
                capture mkdir `"`path'/`c'/`stub'"'

                * master vintages: v01 always, v02 for the first survey, so the
                * numeric-latest rule has something to choose between
                local nv = cond(`k'==1, 2, 1)
                forvalues v = 1/`nv' {
                    local vm = string(`v', "%02.0f")
                    local vdir `"`path'/`c'/`stub'/`stub'_v`vm'_m"'
                    _dl_mklib_vintage, dir(`"`vdir'"') country(`c') year(`yr') ///
                        survey(`svy') vintage(`vm') modules("household person") obs("120 380") seed(`=`seed' + 100*`cidx' + 10*`k' + `v'')
                    local made = `made' + 1
                }

                * one harmonized adaptation off the latest master
                local vm = string(`nv', "%02.0f")
                local adir `"`path'/`c'/`stub'/`stub'_v`vm'_m_v01_a_gmd"'
                * avintage() stated rather than left to its default: the folder
                * name above and the file stem inside it must agree, and when
                * that coupling was implicit the two drifted apart.
                _dl_mklib_vintage, dir(`"`adir'"') country(`c') year(`yr') ///
                    survey(`svy') vintage(`vm') adaptation(GMD) avintage(v01) ///
                    modules("household person") obs("120 380") seed(`=`seed' + 500 + 100*`cidx' + 10*`k'')
                local made = `made' + 1
            }
        }
    }

    if ("`quietly'"=="") {
        * -countries- is cleared above once a family produced output, so it
        * cannot be used to describe the build; -built- is kept for reporting.
        di as result _newline `"{p}Built a synthetic datalib library: {bf:`path'}{p_end}"'
        di as txt `"{p}`made' vintages across: `built'. The data is synthetic — the marker file records that. Use it with {bf:datalib_root, root("`path'") set}, or let it be found automatically when you work from this directory.{p_end}"'
    }

    return local path     `"`path'"'
    return scalar vintages = `made'

end

* --- internal: one vintage, complete -----------------------------------------
capture program drop _dl_mklib_vintage
program define _dl_mklib_vintage
    version 15
    syntax , DIR(string) COUNTRY(string) YEAR(string) SURVEY(string) ///
             VINTAGE(string) MODULES(string) OBS(string) SEED(integer) ///
             [ ADAPtation(string) AVINTage(string) YAML(integer 1) DIMS(string) ]

    quietly {
        foreach d in "" "/Data" "/Data/Stata" "/Data/Original" "/Doc" "/Programs" {
            capture mkdir `"`dir'`d'"'
        }

        local kind = cond("`adaptation'"=="", "master", "adaptation")
        * CANONICAL CASE: uppercase, except the survey module token, which is
        * appended by the caller (..._household.dta). The vintage token keeps
        * its documented lowercase v -- CCC_YYYY_SSSS_vNN_M -- which is what
        * the article's section 3 specifies and what _dtlb_idno normalises to.
        * See internal/demo_test_fixture_protocol.md section 6.
        local tag  = upper("`country'_`year'_`survey'")
        * The adaptation vintage belongs in the FILE stem, not just the folder
        * name. It was hardcoded `v01' here while the caller parameterised the
        * directory, so a v02 adaptation folder was filled with files named
        * ..._v01_a_..., and nothing could ever be loaded from it: the directory
        * listed in r(adaptationvintages) while its contents were unreachable.
        * A fixture that lists a vintage it cannot serve is worse than one that
        * omits it, because the checker asserting the list passes.
        local avint = cond("`avintage'"=="", "v01", "`avintage'")
        if ("`adaptation'"=="") local vstem "`tag'_`vintage'_M"
        else                    local vstem "`tag'_`vintage'_M_`avint'_A_`=upper("`adaptation'")'"

        preserve
        local mi 0
        foreach mod of local modules {
            local mi = `mi' + 1
            local n : word `mi' of `obs'
            if ("`n'"=="") local n 300

            * An ADAPTATION has no delivery of its own. Its input is the
            * master already in this tree, so generating a fresh CSV for it
            * would invent a producer file that never existed and break the
            * lineage the folder convention exists to record. The data is
            * still generated here so the label script can be written from a
            * real dataset, but for an adaptation it is DISCARDED -- the
            * harmonization script reads the master instead.
            _dl_mklib_data, module(`mod') n(`n') seed(`=`seed' + 3*`mi'') ///
                country(`country') year(`year') survey(`survey') dims(`"`dims'"')

            * ---- the delivery comes FIRST ---------------------------------
            * A producer delivers files, not a labelled Stata dataset. So the
            * CSV is written here, and Data/Stata is produced from it by a
            * harmonization script that -_dl_mklib_vintage- then runs. Every
            * .dta in a generated library is the output of a script that ships
            * beside it. See internal/demo_test_fixture_protocol.md section 4.
            * -nolabel- writes the CODES, not the label text. Without it,
            * -export delimited- writes "Male"/"Female" for a labelled variable,
            * the CSV round-trips as a string, and the build script's
            * -label values- fails with "may not label strings". Codes plus a
            * codebook is also what a producer actually delivers.
            if ("`adaptation'"=="") {
                export delimited using `"`dir'/Data/Original/raw_`mod'.csv"', ///
                    replace nolabel
            }

            * ---- the metadata the CSV cannot carry -------------------------
            * Variable and value labels, and the module_schema mirror, are
            * emitted as a script rather than restated by hand: it is written
            * FROM the dataset in memory, so it cannot drift from what
            * -_dl_mklib_data- actually produced.
            _dl_mklib_schema, module(`mod')
            local s_level  `"`r(level)'"'
            local s_keys   `"`r(keys)'"'
            local s_parent `"`r(parent)'"'
            local s_pkeys  `"`r(parentkeys)'"'

            * ONE SCRIPT PER MODULE, NAMED AFTER WHAT IT GENERATES.
            *   Programs/<STEM>_<module>.do  ->  Data/Stata/<STEM>_<module>.dta
            * The names match exactly, so the provenance of any .dta needs no
            * explanation: the script beside it with the same name made it.
            * That is the Programs/ exception in the naming rule -- Original,
            * Doc and the rest of Programs keep the names they were delivered
            * under; a harmonization script is named for its output.
            tempname lh
            capture file close `lh'
            file open `lh' using `"`dir'/Programs/`vstem'_`mod'.do"', ///
                write replace text
            file write `lh' `"*! `vstem'_`mod'.do -- harmonize the `mod' module"' _n
            file write `lh' "*" _n
            if ("`adaptation'"=="") {
                file write `lh' `"* Reads   Data/Original/raw_`mod'.csv   (as delivered)"' _n
            }
            else {
                file write `lh' `"* Reads   ../`tag'_`vintage'_M/Data/Stata/`tag'_`vintage'_M_`mod'.dta"' _n
                file write `lh' `"*         (the master; see Data/Original/.provenance)"' _n
            }
            file write `lh' `"* Writes  Data/Stata/`vstem'_`mod'.dta"' _n
            file write `lh' "*" _n
            file write `lh' "* Generated by datalib_makelib. The labels below were written FROM the" _n
            file write `lh' "* generated dataset, so they cannot drift from what it contains." _n
            file write `lh' "* The data is synthetic: no value describes a real person or household." _n _n
            file write `lh' "version 15" _n _n
            * The vintage directory is an ARGUMENT, defaulting to the working
            * directory -- never a path baked in at generation time. This script
            * is committed as part of a fixture, so an absolute path from the
            * machine that generated it would be wrong on every other machine
            * and would leak that machine's layout into the repository. Run it
            * as:   do <this file> <vintage directory>
            * or from inside the vintage directory with no argument.
            file write `lh' "args here" _n
            file write `lh' `"if (\`"\`here'"'=="") local here ".""' _n _n
            if ("`adaptation'"=="") {
                file write `lh' `"import delimited using "\`here'/Data/Original/raw_`mod'.csv", ///"' _n
                file write `lh' `"    clear varnames(1) case(preserve)"' _n _n
            }
            else {
                * The adaptation reads its MASTER, by a path relative to its own
                * directory -- the two are siblings under the survey folder, so
                * nothing absolute is baked in.
                local mstem "`tag'_`vintage'_M"
                file write `lh' "* Input is the master vintage, not a delivery of its own." _n
                file write `lh' `"use "\`here'/../`mstem'/Data/Stata/`mstem'_`mod'.dta", clear"' _n _n
                file write `lh' "* --- harmonize: the `=upper("`adaptation'")' vocabulary --------------------" _n
                file write `lh' "* Keys are NEVER renamed. They are the linkage contract, and a" _n
                file write `lh' "* harmonization that renames them silently breaks every merge that" _n
                file write `lh' "* module_schema promises. Measures are renamed; keys are preserved." _n
                if ("`mod'"=="household") {
                    file write `lh' "capture rename region    region_code" _n
                    file write `lh' "capture rename hh_size   hhsize" _n
                    file write `lh' "capture rename hh_weight weight" _n _n
                    file write `lh' "* --- derive: a categorical the master does not carry ------------" _n
                    file write `lh' "capture confirm variable hhsize" _n
                    file write `lh' "if (_rc==0) {" _n
                    file write `lh' "    gen byte hhsize_grp = 1 + (hhsize>2) + (hhsize>4)" _n
                    file write `lh' `"    label define hhsize_grp 1 "1-2" 2 "3-4" 3 "5+", replace"' _n
                    file write `lh' "    label values hhsize_grp hhsize_grp" _n
                    file write `lh' `"    label variable hhsize_grp "Household size group""' _n
                    file write `lh' "}" _n _n
                    * WHY THE VINTAGES DIFFER. Two adaptation vintages of the
                    * same master, produced by the same harmonization, are
                    * necessarily identical -- and then nothing can tell them
                    * apart, which is precisely the failure DET-09 exists to
                    * catch. What distinguishes adaptation vintages in a real
                    * archive is the harmonization METHOD, revised between
                    * releases. So v02 top-codes household size and v01 does
                    * not: a later release correcting an outlier treatment is
                    * exactly the kind of revision that earns a new vintage.
                    if ("`avint'"=="v02") {
                        file write `lh' "* v02 of this harmonization top-codes household size; v01 did not." _n
                        file write `lh' "capture confirm variable hhsize" _n
                        file write `lh' "if (_rc==0) replace hhsize = 6 if hhsize > 6" _n _n
                    }
                    * --- label the HARMONIZED names -------------------------
                    * Written for the post-rename names. The generic block that
                    * follows is written from the pre-rename dataset, so for an
                    * adaptation its -label variable region ...- lines name
                    * variables that no longer exist and are swallowed by
                    * -capture-. Renaming preserves a variable's label, so those
                    * variables were never unlabelled -- but they carried the
                    * MASTER's wording, and nothing here stated the harmonized
                    * vocabulary. Value labels were absent altogether.
                    file write `lh' "* --- harmonized variable and value labels -----------------------" _n
                    file write `lh' `"capture label variable hhid        "Household identifier""' _n
                    file write `lh' `"capture label variable region_code "Region (harmonized code)""' _n
                    file write `lh' `"capture label variable urban       "Urban residence""' _n
                    file write `lh' `"capture label variable hhsize      "Household size (persons)""' _n
                    file write `lh' `"capture label variable weight      "Sampling weight""' _n _n
                    file write `lh' `"label define hcl_region 1 "North" 2 "East" 3 "South" 4 "West", replace"' _n
                    file write `lh' "capture label values region_code hcl_region" _n
                    file write `lh' `"label define hcl_urban 0 "Rural" 1 "Urban", replace"' _n
                    file write `lh' "capture label values urban hcl_urban" _n _n
                }
                else if (inlist("`mod'","roster","person")) {
                    file write `lh' "capture rename age        age_years" _n
                    file write `lh' "capture rename educ_years edu_years" _n _n
                    file write `lh' "* --- derive: a categorical the master does not carry ------------" _n
                    file write `lh' "capture confirm variable age_years" _n
                    file write `lh' "if (_rc==0) {" _n
                    file write `lh' "    gen byte age_grp = 1 + (age_years>=15) + (age_years>=65)" _n
                    file write `lh' `"    label define age_grp 1 "0-14" 2 "15-64" 3 "65+", replace"' _n
                    file write `lh' "    label values age_grp age_grp" _n
                    file write `lh' `"    label variable age_grp "Age group""' _n
                    file write `lh' "}" _n _n
                    * --- label the HARMONIZED names, variable AND value -----
                    file write `lh' "* --- harmonized variable and value labels -----------------------" _n
                    file write `lh' `"capture label variable hhid       "Household identifier""' _n
                    file write `lh' `"capture label variable pid        "Person number within household""' _n
                    file write `lh' `"capture label variable age_years  "Age in completed years""' _n
                    file write `lh' `"capture label variable sex        "Sex""' _n
                    file write `lh' `"capture label variable relation   "Relationship to household head""' _n
                    file write `lh' `"capture label variable edu_years  "Years of education""' _n _n
                    file write `lh' `"label define hcl_sex 1 "Male" 2 "Female", replace"' _n
                    file write `lh' "capture label values sex hcl_sex" _n
                    file write `lh' `"label define hcl_rel 1 "Head" 2 "Spouse" 3 "Child" 4 "Other relative" 5 "Non-relative", replace"' _n
                    file write `lh' "capture label values relation hcl_rel" _n _n
                }
                file write `lh' `"label data "`country' `year' `survey' `vintage' `kind' - SYNTHETIC (datalib_makelib)""' _n _n
            }
            * The adaptation branch already wrote its own -label data-; the
            * master branch writes it here.
            if ("`adaptation'"=="") {
                file write `lh' `"label data "`country' `year' `survey' `vintage' `kind' - SYNTHETIC (datalib_makelib)""' _n _n
            }
            * Labels are written from the dataset in memory. For an adaptation
            * that dataset is the DISCARDED generated copy, which carries the
            * master's variable names -- so guard each with -capture confirm-,
            * since the harmonization above has renamed some of them.
            * For an adaptation the harmonized labels were written above, from
            * the post-rename names. Running the generic pre-rename block as
            * well would emit label commands for variables that no longer
            * exist -- dead lines that read as if they did something.
            local cap = cond("`adaptation'"=="", "", "capture ")
            if ("`adaptation'"!="") local skiplabels 1
            else                    local skiplabels 0
            foreach v of varlist _all {
                if (`skiplabels') continue
                local vl : variable label `v'
                if (`"`vl'"'!="") {
                    file write `lh' `"`cap'label variable `v' "`vl'""' _n
                }
                local vall : value label `v'
                if ("`vall'"!="") {
                    quietly levelsof `v', local(lv)
                    local defn ""
                    foreach x of local lv {
                        local xl : label `vall' `x'
                        local defn `"`defn' `x' "`xl'""'
                    }
                    file write `lh' `"label define `vall'`defn', replace"' _n
                    file write `lh' `"`cap'label values `v' `vall'"' _n
                }
            }
            if (`"`s_level'"'!="") {
                file write `lh' _n "* declared structure -- mirrors module_schema: in datalib.yaml" _n
                file write `lh' `"char _dta[datalib_level]      "`s_level'""' _n
                file write `lh' `"char _dta[datalib_keys]       "`s_keys'""' _n
                file write `lh' `"char _dta[datalib_parent]     "`s_parent'""' _n
                file write `lh' `"char _dta[datalib_parentkeys] "`s_pkeys'""' _n
            }
            file write `lh' _n `"save "\`here'/Data/Stata/`vstem'_`mod'.dta", replace"' _n
            file close `lh'

            * An adaptation's Data/Original holds no delivery. Leaving it empty
            * would read as an oversight; a .provenance file states, in a form
            * a checker can read, exactly which master vintage this was derived
            * from -- the file-level analogue of the _dta[datalib_source] stamp.
            if ("`adaptation'"!="") {
                tempname pv
                capture file close `pv'
                file open `pv' using `"`dir'/Data/Original/.provenance"', ///
                    write replace text
                file write `pv' "# Provenance of this adaptation vintage." _n
                file write `pv' "#" _n
                file write `pv' "# An adaptation has no producer delivery of its own. Its input is the" _n
                file write `pv' "# master vintage below, already present in this survey folder, so this" _n
                file write `pv' "# directory holds this note instead of a raw file that never existed." _n
                file write `pv' "#" _n
                file write `pv' "# Each module was produced by the harmonization script of the same name" _n
                file write `pv' "# under Programs/, which reads the master and writes Data/Stata." _n _n
                file write `pv' "derived_from: `tag'_`vintage'_M" _n
                file write `pv' "relative_path: ../`tag'_`vintage'_M" _n
                file write `pv' "collection: `=upper("`adaptation'")'" _n
                file write `pv' "adaptation_vintage: `avint'" _n
                file write `pv' "modules: `modules'" _n
                file close `pv'
            }
        }
        restore

        * ---- vintage metadata ---------------------------------------------
        if (`yaml') {
            tempname yh
            capture file close `yh'
            file open `yh' using `"`dir'/datalib.yaml"', write replace text
            file write `yh' "country: `country'" _n
            file write `yh' "year: `year'" _n
            file write `yh' "survey: `survey'" _n
            file write `yh' "vintage: `vintage'" _n
            file write `yh' "kind: `kind'" _n
            if ("`adaptation'"!="") file write `yh' "adaptation: `=upper("`adaptation'")'" _n
            file write `yh' "producer: datalib_makelib" _n
            file write `yh' "license: synthetic data - no restrictions" _n
            file write `yh' "modules: `modules'" _n
            file write `yh' "synthetic: true" _n

            * module_schema: is the AUTHORITY for how these modules link. It is
            * a separate key from modules: on purpose -- modules: is the list of
            * names present, and _dtlb_catalog's YAML reader already returns it
            * as r(modules). Overloading that key with a mapping would break the
            * scanner.
            local anyschema 0
            foreach mod of local modules {
                _dl_mklib_schema, module(`mod')
                if (`"`r(level)'"'!="") local anyschema 1
            }
            if (`anyschema') {
                file write `yh' "module_schema:" _n
                foreach mod of local modules {
                    _dl_mklib_schema, module(`mod')
                    if (`"`r(level)'"'!="") {
                        file write `yh' "  `mod':" _n
                        file write `yh' "    level: `r(level)'" _n
                        file write `yh' "    keys: `r(keys)'" _n
                        file write `yh' "    parent: `r(parent)'" _n
                        file write `yh' "    parentkeys: `r(parentkeys)'" _n
                    }
                }
            }
            file close `yh'
        }

        * ---- documentation and programs -----------------------------------
        tempname dh
        capture file close `dh'
        file open `dh' using `"`dir'/Doc/README.md"', write replace text
        file write `dh' "# `country' `year' `survey' - `vintage' `kind'" _n _n
        file write `dh' "Synthetic vintage generated by datalib_makelib." _n
        file write `dh' "Modules: `modules'." _n _n
        file write `dh' "No value here describes a real person or household." _n
        file close `dh'

        * ---- run the harmonization scripts --------------------------------
        * The point of writing real scripts is undone if the .dta beside them
        * came from somewhere else. Running them here is what makes each script
        * the actual provenance of its own output rather than a description of
        * it. The fixture therefore still ships readable .dta, so no suite needs
        * a build step -- the failure retired in b915303, where test_catalog
        * skipped silently on Windows because its fixture needed bash.
        preserve
        foreach mod of local modules {
            quietly do `"`dir'/Programs/`vstem'_`mod'.do"' `"`dir'"'
        }
        restore
    }
end

* --- internal: a module's declared structure ---------------------------------
* ONE source of truth for the hierarchy. Both the char stamp written onto each
* .dta and the module_schema: block written into datalib.yaml read from here,
* so the mirror cannot drift from the authority it mirrors.
*
* Returns, for a module name:
*   r(level)       unit of observation
*   r(keys)        variables that uniquely identify a row
*   r(parent)      module one level up, empty at a root
*   r(parentkeys)  the parent's keys, which this module also carries
*
* An unknown module returns empty r(level): callers treat that as "no
* declaration", which is what keeps pre-hierarchy families working unchanged.
capture program drop _dl_mklib_schema
program define _dl_mklib_schema, rclass
    version 15
    syntax , MODULE(string)

    * One assignment per line. Stata does NOT treat ";" as a statement
    * separator outside -#delimit ;-, so "local level "person" ; local keys ..."
    * assigns the whole remainder of the line to level, and the resulting char
    * reads: level = person" ; local keys "hhid pid
    local m = lower("`module'")
    local level  ""
    local keys   ""
    local parent ""
    local pkeys  ""

    * -- household hierarchy ------------------------------------------------
    if ("`m'"=="household") {
        local level "household"
        local keys  "hhid"
    }
    else if (inlist("`m'","roster","person")) {
        local level  "person"
        local keys   "hhid pid"
        local parent "household"
        local pkeys  "hhid"
    }
    * -- school hierarchy ---------------------------------------------------
    else if ("`m'"=="school") {
        local level "school"
        local keys  "schid"
    }
    else if ("`m'"=="classroom") {
        local level  "classroom"
        local keys   "schid clsid"
        local parent "school"
        local pkeys  "schid"
    }
    else if ("`m'"=="teacher") {
        local level  "teacher"
        local keys   "schid clsid tchid"
        local parent "classroom"
        local pkeys  "schid clsid"
    }
    else if ("`m'"=="student") {
        local level  "student"
        local keys   "schid clsid stuid"
        local parent "classroom"
        local pkeys  "schid clsid"
    }

    return local level      "`level'"
    return local keys       "`keys'"
    return local parent     "`parent'"
    return local parentkeys "`pkeys'"
end

* --- internal: one module's data ---------------------------------------------
* Variable sets follow what this repository documents for each module family,
* so a generated library exercises the shapes the loader and checkers expect.
*
* Hierarchical modules derive their parent identifiers in CLOSED FORM from the
* row number and the ancestor cardinalities passed in dims(). That is not an
* aesthetic choice: a child whose parent id is drawn at random can reference a
* parent that was never generated, and the resulting library would look right
* in a directory listing while every merge silently dropped rows. Closed form
* makes referential integrity a property of the arithmetic instead of a
* property of the seed.
*
* For dims("NS NC") -- NS schools, NC classrooms -- classroom row k carries
*     schid = 1 + mod(k-1, NS)      clsid = 1 + int((k-1)/NS)
* and teacher/student row j attaches to classroom k = 1 + mod(j-1, NC), taking
* its own within-classroom number from 1 + int((j-1)/NC). Every (schid, clsid)
* a child names is therefore one the classroom module actually generated, and
* the within-parent counter makes the declared keys unique by construction.
capture program drop _dl_mklib_data
program define _dl_mklib_data
    version 15
    syntax , MODULE(string) N(integer) SEED(integer) ///
             COUNTRY(string) YEAR(string) SURVEY(string) [ DIMS(string) ]

    quietly {
        clear
        set seed `seed'
        set obs `n'

        local m = lower("`module'")
        local sid = lower("`country'_`survey'_`year'")

        * ancestor cardinalities, in coarsest-first order
        local d1 : word 1 of `dims'
        local d2 : word 2 of `dims'
        if ("`d1'"=="") local d1 0
        if ("`d2'"=="") local d2 0

        * dims() is the switch between the hierarchical generators and the flat
        * legacy ones. It has to be, because the names collide: the legacy MICS
        * and DHS families already use a module called "household", and the
        * legacy SAEB family already uses one called "student". Dispatching on
        * the module name alone would silently re-shape those families and move
        * every DET baseline that depends on them.
        local hier = ("`dims'"!="")

        * =================== hierarchical generators ======================
        if (`hier') {
        * -- household survey ----------------------------------------------
        if ("`m'"=="household") {
            gen long hhid = _n
            gen byte region = 1 + mod(_n-1, 4)
            gen byte urban  = (runiform() < 0.62)
            gen byte hh_size = 1 + int(runiform()*8)
            gen double hh_weight = 1 + runiform()*3
            label variable hhid "Household identifier"
            label variable region "Region"
            label variable urban "Urban residence"
            label variable hh_size "Household size"
            label variable hh_weight "Household sampling weight"
        }
        else if ("`m'"=="roster") {
            gen long hhid = 1 + mod(_n-1, `d1')
            gen int  pid  = 1 + int((_n-1)/`d1')
            gen byte age  = min(95, max(0, int(rnormal(28, 18))))
            gen byte sex  = 1 + (runiform() < 0.51)
            label define dl_sex 1 "Male" 2 "Female", replace
            label values sex dl_sex
            gen byte relation = 1 + int(runiform()*5)
            gen byte educ_years = min(20, max(0, int(rnormal(8, 4))))
            label variable hhid "Household identifier"
            label variable pid "Person number within household"
            label variable age "Age in completed years"
            label variable sex "Sex"
            label variable relation "Relationship to household head"
            label variable educ_years "Years of education"
        }
        * -- hierarchical: school assessment ------------------------------
        else if ("`m'"=="school") {
            gen long schid = _n
            gen byte region = 1 + mod(_n-1, 4)
            gen byte urban  = (runiform() < 0.55)
            label variable schid "School identifier"
            label variable region "Region"
            label variable urban "Urban school"
        }
        else if ("`m'"=="classroom") {
            gen long schid = 1 + mod(_n-1, `d1')
            gen int  clsid = 1 + int((_n-1)/`d1')
            gen byte grade = cond(runiform()<0.5, 4, 8)
            label variable schid "School identifier"
            label variable clsid "Classroom number within school"
            label variable grade "Grade taught"
        }
        else if ("`m'"=="teacher") {
            gen long _k    = 1 + mod(_n-1, `d2')
            gen long schid = 1 + mod(_k-1, `d1')
            gen int  clsid = 1 + int((_k-1)/`d1')
            gen int  tchid = 1 + int((_n-1)/`d2')
            gen byte subject = 1 + int(runiform()*3)
            gen byte experience = int(runiform()*30)
            drop _k
            label variable schid "School identifier"
            label variable clsid "Classroom number within school"
            label variable tchid "Teacher number within classroom"
            label variable subject "Subject taught"
            label variable experience "Years of teaching experience"
        }
        else if ("`m'"=="student") {
            gen long _k    = 1 + mod(_n-1, `d2')
            gen long schid = 1 + mod(_k-1, `d1')
            gen int  clsid = 1 + int((_k-1)/`d1')
            gen int  stuid = 1 + int((_n-1)/`d2')
            gen byte sex = 1 + (runiform() < 0.51)
            label define dl_sex 1 "Male" 2 "Female", replace
            label values sex dl_sex
            gen byte age = 8 + int(runiform()*8)
            gen double score_read = rnormal(500, 100)
            gen double score_math = rnormal(500, 100)
            drop _k
            label variable schid "School identifier"
            label variable clsid "Classroom number within school"
            label variable stuid "Student number within classroom"
            label variable sex "Sex"
            label variable age "Age in completed years"
            label variable score_read "Reading score"
            label variable score_math "Mathematics score"
        }
        else {
            display as error "unknown hierarchical module: `m'"
            exit 198
        }
        }
        * ===================== legacy generators ==========================
        else {
        * household-level: hh / dom / household
        if (inlist("`m'","hh","dom","household")) {
            gen long hhid = _n
            gen long household_id = hhid
            gen int  cluster = 1 + int((_n-1)/12)
            gen byte hh_size = 1 + int(runiform()*8)
            gen byte windex5 = 1 + int(runiform()*5)
            replace  windex5 = 8 if runiform() < 0.02
            label variable household_id "Household identifier (harmonized key)"
            label variable cluster "Sample cluster"
            label variable hh_size "Household size"
            label variable windex5 "Wealth index quintile (8 = missing/DK)"
        }
        * student-level: SAEB
        else if ("`m'"=="student") {
            gen long school_id  = 1 + int((_n-1)/25)
            gen long student_id = _n
            gen byte grade = cond(runiform()<0.5, 5, 9)
            gen double portuguese_score = rnormal(250, 50)
            gen double math_score       = rnormal(255, 52)
            label variable school_id "School identifier (synthetic)"
            label variable student_id "Student identifier (synthetic)"
            label variable grade "Assessed grade (5 or 9)"
            label variable portuguese_score "Portuguese proficiency score"
            label variable math_score "Mathematics proficiency score"
        }
        * child-level: ch / children / bh / fs
        else if (inlist("`m'","ch","children","bh","fs")) {
            gen long hhid = 1 + int((_n-1)/2)
            gen long household_id = hhid
            by hhid, sort: gen byte line_number = _n
            gen int  age_months = int(runiform()*60)
            gen byte vaccinated = (runiform() < 0.78)
            gen double weight_kg = 3 + age_months*0.15 + rnormal(0, 1)
            label variable household_id "Household identifier (harmonized key)"
            label variable line_number "Person line number within household"
            label variable age_months "Age in completed months"
            label variable vaccinated "Received basic vaccination schedule"
            label variable weight_kg "Weight in kilograms"
            if ("`m'"=="fs") {
                gen byte reads = (runiform() < 0.45)
                gen byte numeracy = (runiform() < 0.38)
                label variable reads "Foundational reading skill"
                label variable numeracy "Foundational numeracy skill"
            }
        }
        * women / men questionnaires: wm / women / mn
        else if (inlist("`m'","wm","women","mn")) {
            gen long hhid = 1 + int((_n-1)/2)
            gen long household_id = hhid
            by hhid, sort: gen byte line_number = _n
            gen byte age = 15 + int(runiform()*35)
            gen byte parity = int(runiform()*6)
            gen byte anc_visits = int(runiform()*8)
            label variable household_id "Household identifier (harmonized key)"
            label variable line_number "Person line number within household"
            label variable age "Age in completed years"
            label variable parity "Number of live births"
            label variable anc_visits "Antenatal care visits"
        }
        * person-level: pes / hl / hhmembers / adult / person / tri / anual / both
        else {
            local nhh = max(1, int(`n'/3))
            gen long hhid = 1 + mod(_n-1, `nhh')
            gen long household_id = hhid
            by hhid, sort: gen byte pid = _n
            gen byte line_number = pid
            gen byte age = min(95, max(0, int(rnormal(28, 18))))
            gen byte sex = 1 + (runiform() < 0.51)
            label define sexlbl 1 "Male" 2 "Female", replace
            label values sex sexlbl
            gen byte educ_years = min(20, max(0, int(rnormal(8, 4))))
            gen byte edu_level = 1 + int(educ_years/5)
            gen byte employed = (age >= 15) * (runiform() < 0.62)
            gen double income = employed * exp(rnormal(6.5, 0.8))
            label variable household_id "Household identifier (harmonized key)"
            label variable pid "Person line number within household"
            label variable line_number "Person line number within household"
            label variable age "Age in completed years"
            label variable sex "Sex"
            label variable educ_years "Years of education"
            label variable edu_level "Education level"
            label variable employed "Employed in reference week"
            label variable income "Monthly labour income (synthetic currency)"
            if (inlist("`m'","tri","anual","idbas","idrs")) {
                gen int Ano = `year'
                gen byte Trimestre = 1 + int(runiform()*4)
                gen long idind = _n
                label variable Ano "Reference year"
                label variable Trimestre "Reference quarter"
                label variable idind "Longitudinal person identifier"
            }
        }

        * every legacy module carries a weight and the harmonized survey
        * identifier. Hierarchical modules do not: their keys are declared in
        * module_schema, so svy_id is not doing any linking work there, and
        * adding it would put an unused variable in every generated file.
        gen double weight = 1 + runiform()*3
        label variable weight "Sampling weight"
        gen str32 svy_id = "`sid'"
        label variable svy_id "Survey identifier (ccc_svy_yyyy)"
        * not every module is household-based -- the student module is not
        capture label variable hhid "Household identifier"
        }
    }
end

* --- internal: one survey folder, its masters and its adaptation -------------
capture program drop _dl_mklib_survey
program define _dl_mklib_survey
    version 15
    syntax , ROOT(string) COUNTRY(string) YEAR(string) SURVEY(string) ///
             VINTAGES(string) MODULES(string) OBS(string) SEED(integer) ///
             [ YAMLFOR(string) ADAPT(string) ADAPTMASTER(string) ///
               ADAPTMODULES(string) ADAPTOBS(string) ADAPTVINTAGES(string) ///
               DIMS(string) ]

    quietly {
        local c    = upper("`country'")
        local svy  = upper("`survey'")
        local stub = upper("`c'_`year'_`svy'")

        capture mkdir `"`root'/`c'"'
        capture mkdir `"`root'/`c'/`stub'"'

        local vi 0
        foreach vm of local vintages {
            local vi = `vi' + 1
            local vdir `"`root'/`c'/`stub'/`stub'_`vm'_M"'
            local wantyaml = (strpos(" `yamlfor' ", " `vm' ") > 0)
            _dl_mklib_vintage, dir(`"`vdir'"') country(`c') year(`year') ///
                survey(`svy') vintage(`vm') modules(`"`modules'"') obs(`"`obs'"') ///
                seed(`=`seed' + 7*`vi'') yaml(`wantyaml') dims(`"`dims'"')
        }

        if ("`adapt'"!="") {
            local am = cond("`adaptmaster'"=="", "v01", "`adaptmaster'")

            * adaptvintages() defaults to "v01", which is what every caller got
            * when this branch hardcoded _v01_a_. It is a parameter now because
            * with a single adaptation vintage the whole of _dtlb_vcheck's
            * adaptation arithmetic -- r(Anumvintages), r(Alatestvintage),
            * r(Avintagelist) -- has only one candidate and cannot be asserted
            * against a wrong answer. A checker that always returns the only
            * item present passes a one-item test whether or not it works.
            local avs = cond("`adaptvintages'"=="", "v01", "`adaptvintages'")

            local ai 0
            foreach av of local avs {
                local ai = `ai' + 1
                local adir `"`root'/`c'/`stub'/`stub'_`am'_M_`av'_A_`=upper("`adapt'")'"'
                * Adaptations carry no datalib.yaml, matching the library this
                * reproduces: metadata describes the master delivery, and leaving
                * the adaptations without one keeps the has_yaml=0 path covered.
                _dl_mklib_vintage, dir(`"`adir'"') country(`c') year(`year') ///
                    survey(`svy') vintage(`am') adaptation(`adapt') ///
                    avintage(`av') ///
                    modules(`"`adaptmodules'"') obs(`"`adaptobs'"') ///
                    seed(`=`seed' + 500 + 13*`ai'') yaml(0) dims(`"`dims'"')
            }
        }
    }
end
