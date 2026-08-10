*******************************************************
* _dtlb_load: Data Loading and Processing Utility (formerly _dlw)
* Author: Joao Pedro Azevedo
* Co-author: Minh Cong Nguyen (World Bank)
*! Version: 1.7.3       Date: 2026-08-06       
* Description: 
* This program is designed to facilitate the loading, processing, and 
* merging of survey data modules across different countries and years. 
* The utility provides options to select specific surveys, modules, 
* and collections, with default settings for common use cases.
*******************************************************

capture program drop _dtlb_load
program define _dtlb_load, rclass

    version 15

    syntax  [varlist]                      ///
            [in] [if]                      ///
            [,                             ///
                country(string)            ///
                year(string)               ///
                survey(string)             ///
                MODule(string)             ///
                NOWARNing                  ///
                filename(string)           ///
                MASter			           ///
                adaptation                 ///
                LATest                     ///
                collection(string)         ///
                harmonization(string)      ///
                va(string)                 ///
                vm(string)                 ///
                DEBUG                      ///
                data                       ///   
                doc                        ///
                programs                   ///
                NOMerge                    ///
                WRK                        ///
                clear                      ///
            ]

    quietly {

        *---------------------------------------------------------------------
        * The package version, read ONCE and FIRST.
        *
        * -findfile- is rclass: it sets r(fn) and in doing so CLEARS r().
        * Read next to the char that consumes it -- which is what the first
        * version of this did -- it wiped the merge-plan returns that
        * _dtlb_mergeplan had just accumulated for -return add-, and DET-10i
        * went red on r(mergeplan). So it happens here, before anything this
        * program returns exists to be destroyed.
        *
        * Read rather than typed: the value was hardcoded "1.5.0" and stayed
        * there through four releases, so datalib_whence reported a version
        * that had not been current since 1.5.0. A provenance stamp that lies
        * is worse than none.
        *---------------------------------------------------------------------
        local _dtlb_pkgver "unknown"
        capture findfile datalib.ado
        if (_rc==0) {
            local _pvfile `"`r(fn)'"'
            tempname _pvh
            local _pvline ""
            capture file open `_pvh' using `"`_pvfile'"', read text
            if (_rc==0) {
                file read `_pvh' _pvline
                while (r(eof)==0) {
                    if (regexm(`"`macval(_pvline)'"', "^\*! *v?([0-9]+\.[0-9]+\.[0-9]+)")) {
                        local _dtlb_pkgver = regexs(1)
                        continue, break
                    }
                    file read `_pvh' _pvline
                }
                file close `_pvh'
            }
        }

        /** 
        * Flow Control 
        */

        * Master file selection (not yet supported)
        if ("`master'" != "") {
            di as err "Option master not currently supported."
            exit 198
        }

        * Check if country is specified
        if ("`country'" == "") {
            di as err "Country needs to be specified."
            exit 198
        }

        * Set year to latest if not specified
        if ("`year'" == "") {
            di in y "Year not specified. Latest available survey will be used."
            local latest latest
        }

        * Ensure the datalib path is set
        if ("${datalib}" == "") {
            di as err "Path to datalib needs to be specified. Global datalib needs to be defined."
            exit 198
        }

        * Set default collection to 'HLT' if not specified
        if ("`collection'" != "") & ("`adaptation'" == "") {
            local adaptation "adaptation"
        }
        
        * Set default collection to 'HLT' if not specified
        if ("`collection'" == "") & ("`adaptation'" != "") {
            local collection "HLT"
        }
        local clct "`collection'"

        * Supported modules and sort keys by collection
        if ("`clct'"=="HLT") {
            local allmodule "household hhmembers adult children "
            local sort_household_hhmembers "svy_id household_id"
            local sort_adult_children "svy_id household_id line_number"
        }
        * Brazilian PNAD
        if ("`clct'"=="DTZ") & ("`survey'"=="PNAD") {
            local allmodule "household hhmembers adult children "
            local sort_household_hhmembers "svy_id household_id"
            local sort_adult_children "svy_id household_id line_number"
        }
        
        * Brazilian PNADC
        if ("`clct'"=="DTZ") & ("`survey'"=="PNADC") {
            local allmodule "household hhmembers adult children "
            local sort_household_hhmembers "svy_id household_id"
            local sort_adult_children "svy_id household_id line_number"
        }
        * Select all modules if none specified
        if ("`module'"=="") {
            local module "`allmodule'"
        }

        * Count the number of modules selected
        local cntmod = wordcount("`module'")

        * Enable noisy output for debugging if requested
        if ("`debug'"!="") {
            local noi noisily
        }

        ******************************************
        * Folder Navigation and Data Selection
        ******************************************

        * List available country folders in datalib
        local list : dir "${datalib}/" dirs "*"
        `noi' di `"`list'"'

        * List available survey folders for the selected country
        local list : dir "${datalib}/" dirs "`country'"
        `noi' di "ctry: `"`list'"'"

        * Verify if the selected country exists
        cap: local ctrycheck = match(upper(`list'),"*`country'*")
        if _rc!=0 {
            local ctrycheck = 0
        }

        * If country is valid, list survey folders
        if (`ctrycheck'==1) {

            local list : dir "${datalib}/`country'" dirs "*`survey'*"
            `noi' di "Survey folders: `"`list'"'"

            * Handle cases where the survey is not specified or not available
            if ("`survey'"!="" & `"`list'"'==`""') {
                di as err "`survey' for `country' not available. Please select an eligible survey."
                exit 198
            }

            * Default to the latest available survey if not specified
            if ("`survey'"=="") {
                local list = word(`"`list'"',-1)
                local survey = word(subinstr(`list',"_"," ",.),3)
            }

            * Extract the latest year if not specified
            if ("`year'"=="") {
                foreach folders in `list' {
                    local yr = word(subinstr("`folders'","_"," ",.),2)
                    local year "`year' `yr'"
                }

                `noi' di "`year'"

                if ("`latest'" == "latest") {
                    local year = word("`year'",-1)
                }
            }

            * Construct the file name
            local ctry "`country'"
            local svy "`survey'"

            *-------------------------------------------------------------------
            * Vintage resolution: default to the LATEST, and say so.
            *
            * Before this, vm() had no default anywhere in this file. Omitting it
            * built a path with an empty vintage slot --
            * `ctry'_`year'_`svy'__M -- which could only ever fail with a bare
            * "file not found", naming a directory that never existed rather than
            * the omission that caused it.
            *
            * Defaulting to the latest is the safe direction for an archive whose
            * whole point is versioned deliveries: a caller who does not name a
            * vintage wants the current one, not the first one ever published.
            * But it is a CHOICE MADE ON THE USER'S BEHALF, so it is announced.
            * Silence here would mean a do-file's meaning changes the day someone
            * deposits v03 -- the reader of that do-file should be able to see,
            * in the log, which delivery the numbers came from.
            *
            * Normalisation is applied whether or not the value was defaulted:
            * _dtlb_idno accepts 1, 01, v01 and V01, and a user who learned that
            * form there is entitled to use it here. Without this, vm(01) built
            * `..._01_M' against a folder named `..._v01_m' and failed.
            *-------------------------------------------------------------------
            *-------------------------------------------------------------------
            * The WORKING vintage, vWRK.
            *
            * A vintage folder named `..._vWRK_M' is the WORKING vintage: the
            * delivery as it stands BEFORE a public release. It is a real stage
            * of the archive's lifecycle, not a scratch directory -- the copy
            * being assembled, checked and corrected until it is numbered and
            * published as vNN. Two rules, and the asymmetry between them is the
            * point.
            *
            *   - It WINS THE DEFAULT. Asking for no particular vintage while a
            *     working copy exists almost always means you want the working
            *     copy; that is why you made one.
            *   - It does NOT override an EXPLICIT vm(). A do-file that pins
            *     vm(01) is making a reproducibility claim, and silently handing
            *     it work in progress would break the one promise this archive
            *     exists to keep -- that an analysis can name the exact data it
            *     ran on. Pass -wrk- to override deliberately.
            *
            * Either way it is announced, and more loudly than the numbered
            * default: numbers in a log that came from a working copy should
            * never be mistaken for numbers from a delivery.
            *-------------------------------------------------------------------
            local wrkdir "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_vWRK_M"
            mata: st_local("haswrk", strofreal(direxists(st_local("wrkdir"))))

            if ("`wrk'"!="") {
                if ("`haswrk'"!="1") {
                    di as err `"{p}No working vintage at: `wrkdir'{p_end}"'
                    di as err `"{p}{bf:wrk} asks for {bf:vWRK} specifically. Drop it to load a published vintage, or deposit a working copy first.{p_end}"'
                    exit 601
                }
                if ("`vm'"!="") {
                    noi di as text `"{p}Note: {bf:wrk} overrides {bf:vm(`vm')}.{p_end}"'
                }
                local vm "vWRK"
                local vmsrc "wrk-forced"
            }

            * Scan the survey folder once when EITHER vintage was left to us.
            * The lists are wanted twice over: to resolve the default, and to
            * report what else was on offer.
            local mvlist ""
            local avlist ""
            if ("`vm'"=="") | ("`va'"=="") {
                capture _dtlb_svycheck, path("${datalib}/`ctry'/`ctry'_`year'_`svy'/")
                local mvlist "`r(mastervintages)'"
                local avlist "`r(adaptationvintages)'"
                if (`"`mvlist'"'==".") local mvlist ""
                if (`"`avlist'"'==".") local avlist ""
                * _dtlb_svycheck DOES enumerate the working vintage -- it walks
                * the folder names, and Windows -dir- lowercases, so it comes
                * back as "vwrk". Appending unconditionally listed it twice
                * ("v01 v02 vwrk vWRK"). Normalise the spelling instead, and only
                * append when the scan genuinely missed it.
                local mvnorm ""
                local sawwrk 0
                foreach _v of local mvlist {
                    if (lower("`_v'")=="vwrk") {
                        local mvnorm "`mvnorm' vWRK"
                        local sawwrk 1
                    }
                    else local mvnorm "`mvnorm' `_v'"
                }
                local mvlist = trim("`mvnorm'")
                if ("`haswrk'"=="1") & (`sawwrk'==0) local mvlist = trim("`mvlist' vWRK")
            }

            local vmauto 0
            if ("`vm'"!="") & ("`vmsrc'"=="") local vmsrc "explicit"
            if ("`vm'"=="") {
                if ("`haswrk'"=="1") {
                    local vm "vWRK"
                    local vmauto 1
                    local vmsrc "wrk-default"
                }
                else if (`"`mvlist'"'!="") {
                    local vm = word("`mvlist'", -1)
                    local vmauto 1
                    local vmsrc "latest"
                }
            }

            * If resolution found NOTHING, stop here. Falling through with an
            * empty vm() rebuilds `<ccc>_<yyyy>_<ssss>__M' -- the exact empty
            * vintage slot this whole block exists to eliminate -- and the user
            * gets a bare "file not found" naming a directory that never
            * existed. The failure is that no vintage could be resolved, so say
            * that, and name what was looked at.
            if ("`vm'"=="") {
                di as err `"{p}No vintage found for {bf:`ctry' `year' `svy'}.{p_end}"'
                di as err `"{p}Looked in: {bf:${datalib}/`ctry'/`ctry'_`year'_`svy'/}{p_end}"'
                di as err `"{p}The survey folder holds no master vintage (no {bf:..._vNN_M} and no {bf:..._vWRK_M}). Check the library root with {bf:datalib_root}, or name a vintage with {bf:vm(}{it:NN}{bf:)}.{p_end}"'
                exit 601
            }
            if ("`vm'"!="") {
                * One spelling rule for every vintage token. Strip the optional
                * leading v, then decide by what is left:
                *
                *   1  01  v01  V01   -> v01   (numbers, zero-padded to two)
                *   wrk WRK vwrk vWRK -> vWRK  (the working vintage)
                *
                * Both halves matter for the same reason. _dtlb_idno already
                * accepts 1/01/v01/V01, so a user who learned the form there is
                * entitled to use it here; and a caller who can write vm(2) will
                * reasonably expect vm(wrk) to work, which it did not -- vWRK
                * resolved and wrk failed 601, for no reason a user could see.
                local vmraw "`vm'"
                local vmdig = subinstr(lower("`vm'"), "v", "", .)
                if ("`vmdig'"=="wrk") {
                    local vm "vWRK"
                }
                else {
                    capture confirm integer number `vmdig'
                    if (_rc==0) local vm = "v" + string(real("`vmdig'"), "%02.0f")
                }
            }
            * Announce whichever way the vintage was chosen. A working vintage
            * gets a louder notice than a numbered one: numbers in a log that
            * came from a PRE-RELEASE delivery must never be mistaken for
            * numbers from a published one.
            if ("`vmsrc'"=="wrk-default") | ("`vmsrc'"=="wrk-forced") {
                noi di as text `"{p}{bf:NOTE: loading the WORKING vintage (vWRK)} — a pre-release delivery, not a published one. Results from it are provisional and the folder may change under you. Name a published vintage with {bf:vm(}{it:NN}{bf:)}.{p_end}"'
            }
            else if (`vmauto') {
                noi di as text `"{p}Loading the latest master vintage: {bf:`vm'}. Name one with {bf:vm(}{it:NN}{bf:)} to pin it.{p_end}"'
            }

            *-------------------------------------------------------------------
            * The ADAPTATION vintage, resolved exactly as the master one is.
            *
            * va() was left behind when vm() was fixed, and the two sit on the
            * same command: vm(2) resolved while va(2) did not, and omitting
            * va() on an adaptation load built `..._vNN_M__A_<clct>' -- the same
            * empty-vintage slot, one level down. A caller who has learned vm()
            * is entitled to expect va() to behave, and had no way to see why it
            * did not.
            *
            * Only on the adaptation path: va() is meaningless without it, and
            * resolving a vintage nobody asked for would print notices on every
            * master load.
            *-------------------------------------------------------------------
            local vaauto 0
            local vasrc  ""
            if ("`adaptation'"!="") {
                if ("`va'"!="") local vasrc "explicit"
                if ("`va'"=="") & (`"`avlist'"'!="") {
                    local va = word("`avlist'", -1)
                    local vaauto 1
                    local vasrc  "latest"
                }
                if ("`va'"=="") {
                    di as err `"{p}No adaptation vintage found for {bf:`ctry' `year' `svy'}.{p_end}"'
                    di as err `"{p}Looked in: {bf:${datalib}/`ctry'/`ctry'_`year'_`svy'/}{p_end}"'
                    di as err `"{p}The survey folder holds no adaptation vintage (no {bf:..._vNN_M_vNN_A_}{it:collection}). Load the master instead by dropping {bf:adaptation}, or name a vintage with {bf:va(}{it:NN}{bf:)}.{p_end}"'
                    exit 601
                }

                * The working vintage wins the MASTER default, but adaptations
                * are built off PUBLISHED deliveries -- so an adaptation load
                * that was handed vWRK by default is asking for a folder that
                * cannot exist, and used to fail with a bare "file not found"
                * naming it. Say what actually happened instead. Only when the
                * master was chosen FOR the caller: someone who typed vm(wrk)
                * and adaptation together has asked for this explicitly and gets
                * the file-not-found they aimed at.
                if ("`vm'"=="vWRK") & ("`vmsrc'"=="wrk-default") {
                    di as err `"{p}{bf:`ctry' `year' `svy'} has a working vintage (vWRK), which wins the master default -- but adaptations are built off published masters, so {bf:..._vWRK_M_`va'_A_`clct'} does not exist.{p_end}"'
                    di as err `"{p}Name the published master you want, for example {bf:vm(}{it:NN}{bf:)}. Published masters here: {bf:`mvlist'}.{p_end}"'
                    exit 601
                }
                * The same spelling rule as vm(). vWRK is carried through rather
                * than mangled into "v." if someone writes it, but it is a
                * master-side concept: no adaptation default resolves to it.
                local vadig = subinstr(lower("`va'"), "v", "", .)
                if ("`vadig'"=="wrk") {
                    local va "vWRK"
                }
                else {
                    capture confirm integer number `vadig'
                    if (_rc==0) local va = "v" + string(real("`vadig'"), "%02.0f")
                }
                if (`vaauto') {
                    noi di as text `"{p}Loading the latest adaptation vintage: {bf:`va'}. Name one with {bf:va(}{it:NN}{bf:)} to pin it.{p_end}"'
                }
            }

            *-------------------------------------------------------------------
            * Report the whole menu, not just the pick.
            *
            * When a vintage was chosen FOR the caller and the survey held more
            * than one, saying only which one we took is half the story: the
            * caller cannot tell whether that was the only option or one of five.
            * r(mastervintages) / r(adaptationvintages) publish the full list --
            * published deliveries and the working vintage together -- so a
            * script can branch on what exists rather than guess, and an
            * interactive user can see what they did not get.
            *
            * Announced only when there was a real choice. A one-vintage survey
            * needs no menu, and printing one on every load would train people to
            * ignore it.
            *-------------------------------------------------------------------
            if (`vmauto') & (wordcount(`"`mvlist'"') > 1) {
                noi di as text `"{p}Master vintages available for `ctry' `year' `svy': {bf:`mvlist'} — loaded {bf:`vm'}.{p_end}"'
            }
            if (`vaauto') & (wordcount(`"`avlist'"') > 1) {
                noi di as text `"{p}Adaptation vintages available: {bf:`avlist'} — loaded {bf:`va'}.{p_end}"'
            }
            else if ("`adaptation'"=="") & (wordcount(`"`avlist'"') > 1) {
                * Not an adaptation load, so nothing was chosen -- but saying
                * that adaptations exist is still worth a line.
                noi di as text `"{p}Adaptation vintages available: {bf:`avlist'}.{p_end}"'
            }
            return local mastervintages     "`mvlist'"
            return local adaptationvintages "`avlist'"
            return local vintage            "`vm'"
            return local vintage_source     "`vmsrc'"
            * Symmetric with the master pair, so a script can branch on how the
            * adaptation vintage was arrived at without re-deriving it.
            return local adaptationvintage  "`va'"
            return local avintage_source    "`vasrc'"
            if ("`adaptation'"!="") {
                local file "`ctry'_`year'_`svy'_`vm'_M_`va'_A_`clct'"
            }
            if ("`adaptation'"=="") {
                local file "`ctry'_`year'_`svy'_`vm'_M"
            }
        }

        * Check if the file exists and load the data
        * If the file does not exist, return an error message
        * If the file exists, load the data and list the variables
        * Prepare the data for merging if more than one module is selected
        * Recode specific variables as needed
        if ("`file'"!="") & ("`filename'"=="") {

            * ================= self-describing module path =================
            * If the modules declare their own structure -- module_schema: in
            * datalib.yaml, or datalib_* chars on the files -- the join is
            * planned from that declaration instead of from the hardcoded
            * per-collection table below. See
            * internal/hierarchical_modules_implementation_plan.md.
            local vdir "${datalib}/`ctry'/`ctry'_`year'_`svy'/`file'"

            * module() now defaults to EVERY module the vintage has, joined.
            * It used to default to `allmodule', which is empty for any master
            * without a recognised collection -- so a plain master load with no
            * module() resolved an empty list and returned an EMPTY DATASET
            * with no error. That defect is why every example in the article
            * names its module explicitly.
            local wantmod `"`module'"'
            if (`"`wantmod'"'=="") {
                local dtas : dir "`vdir'/Data/Stata" files "`file'_*.dta"
                * -: dir- LOWERCASES names on Windows and preserves them on
                * Linux and macOS, so the stem must be matched case-insensitively
                * before it is stripped. Matching the uppercase stem directly
                * strips nothing here, leaving the whole filename as the "module"
                * name -- which then resolves no declaration, and the load falls
                * silently back to the legacy path. This is the same trap that
                * made the catalog scanner skip every survey folder.
                foreach d of local dtas {
                    local d = subinstr(`"`d'"', `"""', "", .)
                    local nm = subinstr(lower(`"`d'"'), lower("`file'_"), "", 1)
                    local nm = subinstr(`"`nm'"', ".dta", "", .)
                    if (`"`nm'"'!="" & `"`nm'"'!=lower(`"`d'"')) {
                        local wantmod `"`wantmod' `nm'"'
                    }
                }
                local wantmod = trim(`"`wantmod'"')
            }

            * Use the planner only when EVERY requested module declares a
            * structure. A half-declared vintage falls through to the legacy
            * path rather than being joined on a guess.
            local alldecl = ("`wantmod'"!="")
            foreach m of local wantmod {
                capture _dtlb_modspec, dir("`vdir'") module(`m') stem(`file')
                if (_rc) local alldecl 0
                else if (`"`r(level)'"'=="") local alldecl 0
            }

            * A survey whose hierarchy has TWO leaves -- teacher and student
            * both hang off classroom -- has no single natural "everything"
            * join, so defaulting to all modules would refuse. Erroring is
            * right, but the message must say why the user is seeing it when
            * they never asked for those two modules together.
            if (`alldecl') & (`"`module'"'=="") {
                local leaves ""
                foreach m of local wantmod {
                    quietly _dtlb_modspec, dir("`vdir'") module(`m') stem(`file')
                    local isparent 0
                    foreach o of local wantmod {
                        quietly _dtlb_modspec, dir("`vdir'") module(`o') stem(`file')
                        if (`"`r(parent)'"'=="`m'") local isparent 1
                    }
                    if (!`isparent') local leaves `"`leaves' `m'"'
                }
                if (wordcount(`"`leaves'"')>1) {
                    di as err `"{p}This survey has more than one finest level -- {bf:`=trim(`"`leaves'"')'} -- so there is no single dataset that is "all of it": they are different units of observation, and joining them would be many-to-many.{p_end}"'
                    di as err `"{p}Name the one you want, for example {bf:module(`=word(`"`leaves'"',1)')}. Everything above it is joined automatically.{p_end}"'
                    exit 459
                }
            }

            if (`alldecl') {
                * -noisily- because _dtlb_load's whole body runs inside a
                * -quietly- block (line 43). Without it the merge report is
                * written and then swallowed, which is the worst of both: the
                * cost of producing it and none of the benefit. Found by
                * running the command and seeing nothing.
                noisily _dtlb_mergeplan, dir("`vdir'") stem(`file') ///
                    modules(`"`wantmod'"') `nowarning'

                * Stamp provenance onto the data itself, so a .dta carried out
                * of its folder still answers "which vintage is this?".
                * datalib_whence reads these. They record ORIGIN, not current
                * content: they survive collapse and reshape, so an aggregate
                * keeps the identifier it was built from -- which is why
                * datasignature, not this, answers "has it changed?".
                char _dta[datalib_idno]       "`file'"
                char _dta[datalib_source]     "`vdir'"
                char _dta[datalib_loaded]     "`c(current_date)' `c(current_time)'"
                * The version that actually loaded this dataset, read from
                * the installed datalib.ado rather than typed. It was
                * hardcoded "1.5.0" and stayed there through 1.6.0, 1.7.0,
                * 1.7.1 and 1.7.2 -- so datalib_whence reported a version that
                * had not been current for four releases. A provenance stamp
                * that lies is worse than none: the whole point of this char
                * is to answer "where did this come from".
                *
                * VERSION is not installed by the package, but datalib.ado is,
                * and it carries the stamp the version guards keep pinned to
                * VERSION. -findfile- rather than -which-, which does not
                * reliably return the path in r(fn).
                char _dta[datalib_pkgversion] "`_dtlb_pkgver'"

                * -return add- rather than a hand-listed subset: the planner
                * returns one rows_/distinct_ pair per module, and a list
                * written out by hand here would silently omit whichever module
                * nobody thought of. That is how r(rows_roster) came back
                * missing the first time.
                local plan_ `"`r(plan)'"'
                local src_   "`r(spec_source)'"
                local base_  "`r(base)'"
                return add
                return local mergeplan       `"`plan_'"'
                return local mergespec_source "`src_'"
                return local modules          `"`wantmod'"'
                return local filename1        "`file'_`base_'.dta"
                exit
            }
            * =============== end self-describing module path ===============

            di "`year'"
            
            local i = 0
            foreach type in `module' {

                local i = `i'+1
                
                * Load the data    the specified module if ADAPATATION
                if ("`adaptation'"!="") {
                    local tousedta`i' "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M_`va'_A_`clct'/Data/Stata/`file'_`type'.dta"
                    use "`tousedta`i''", `clear'
                    `noi' di "`type`i''"
                    `noi' ds, varwidth(30) alpha
                    `noi' di ""
                }
                if ("`adaptation'"=="") {
                    local tousedta`i' "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M/Data/Stata/`file'_`type'.dta"
                    use "`tousedta`i''", `clear'
                }

                * Sort and prepare data for merging
                * Guarded on the key being DEFINED, not merely on the module
                * name matching. The keys are only set for HLT and DTZ
                * collections (see :83-100), so a MASTER load left this local
                * empty and reached -sort- with no varlist -> r(100), after
                * the data had already loaded. The sibling blocks at :327/:336
                * carry the equivalent guard; these two never did.
                if match("sort_household_hhmembers","*`type'*")==1 & ("`sort_household_hhmembers'"!="") {
                    sort `sort_household_hhmembers'
                    gen ctrycode = "`ctry'"
                    gen year = `year'
                    order ctrycode year source `sort_household_hhmembers'
                    local merge "`sort_household_hhmembers'"
                    noi di "Sort: `sort_household_hhmembers' (module `type')"
                }

                if match("sort_adult_children","*`type'*")==1 & ("`sort_adult_children'"!="") {
                    sort `sort_adult_children'
                    gen ctrycode = "`ctry'"
                    gen year = `year'
                    order ctrycode year source `sort_adult_children'
                    local merge "`sort_adult_children'"
                    noi di "Sort: `sort_adult_children' (module: `type')"
                }

                local merge`i' ""

                tempfile tmp`i'
                save `tmp`i'', replace

                return local filename`i' = "`file'_`type'.dta"
            }
        } 
        if ("`file'"!="") & ("`filename'"!="") {

            di "`year'"
            
            local i = 0
            foreach flname in `"`filename'"'{

                local i = `i'+1
                
                * Load the data for the specified modules
                if ("`data'"=="data") { 
                    if ("`adaptation'"!="") {
                        local tousedta`i' "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M_`va'_A_`clct'/Data/Stata/`flname'"
                        use "`tousedta`i''", `clear'
                        `noi' di "`type'"
                        `noi' ds, varwidth(30) alpha
                        `noi' di ""
                    }
                    if ("`adaptation'"=="") {
                        local tousedta`i' "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M/Data/Stata/`flname'"
                        use "`tousedta`i''", `clear'
                    }
                    return local data`i' "`tousedta`i''"
                }
                * View the documents from specific surveys
                if ("`doc'"=="doc") { 
                    if ("`adaptation'"!="") {
                        local tousedoc`i'  "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M_`va'_A_`clct'/Doc/`flname'"
                        view browse      "`tousedoc`i''"
                        `noi' di "`type'"
                        `noi' ds, varwidth(30) alpha
                        `noi' di ""
                    }
                    if ("`adaptation'"=="") {
                        local tousedoc`i'  "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M/Doc/`flname'"
                        view browse "`tousedoc`i''"
                    }
                    return local doc`i' "`tousedoc`i''"
                }
                * View the files in the program folder
                if ("`programs'"=="programs") { 
                    if ("`adaptation'"!="") {
                        local touseprog`i' "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M_`va'_A_`clct'/Programs/`flname'"
                        view browse "`touseprog`i''"
                        `noi' di "`type'"
                        `noi' ds, varwidth(30) alpha
                        `noi' di ""
                    }
                    if ("`adaptation'"=="") {
                        local touseprog`i' "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M/Programs/`flname'"
                        view browse "`touseprog`i''"
                    }
                    return local programs`i' "`touseprog`i''"
                }

                * Sort and prepare data for merging
                if match("sort_household_hhmembers","*`type'*")==1 & ("`clct'"=="HLT") {
                    sort `sort_household_hhmembers'
                    cap: gen ctrycode = "`ctry'"
                    cap: gen year = `year'
                    order ctrycode year source `sort_household_hhmembers'
                    local merge "`sort_household_hhmembers'"
                    noi di "Sort: `sort_household_hhmembers' (module `type')"
                }

                if match("sort_adult_children","*`type'*")==1 & ("`clct'"=="HLT")  {
                    sort `sort_adult_children'
                    cap: gen ctrycode = "`ctry'"
                    cap: gen year = `year'
                    order ctrycode year source `sort_adult_children'
                    local merge "`sort_adult_children'"
                    noi di "Sort: `sort_adult_children' (module: `type')"
                }

                local merge`i' ""

                tempfile tmp`i'
                save `tmp`i'', replace

                return local filename`i' = "`flname'"
            }


        }
        if ("`file'"=="") & ("`filename'"=="") {
            noi di as err "No data for `country' available. Please check your selection and resubmit."
            exit 198
        }


        * Merge selected modules if more than one module is chosen
        if (`cntmod'>1 & "`nomerge'"=="") {
            use `tmp1', clear
            forvalues merge = 2(1)`i' {
                local k = `merge'-1
                merge `merge`k'' using `tmp`merge''
                `noi' tab _merge
                drop _merge                    
            }
        }

        * Recode specific variables as needed
        cap: recode windex5 8=.

        * Return the harmonization file name
        return local harmonization = "`file'"
        return add
    }

end

*  _foldernav lives in its own file (src/_/_foldernav.ado) since v1.1.
*  It used to be defined inline below this program, which meant a clean
*  net-install could not resolve datalib's _foldernav calls until
*  _dtlb_load had run once in the session.
/*******************************************************
Version History

v1.01 (2024-08-18)
Enhancements:
Improved handling of the year and survey options to ensure the correct survey year is selected when not specified, defaulting to the latest available survey.
Added more robust logic for loading and merging data modules, ensuring appropriate sorting and variable management across multiple modules.
Enhanced the debugging functionality to provide clearer, noisier output when the DEBUG option is specified.
Implemented better error handling for missing or incorrect country, survey, and year inputs.
Improved folder navigation and file verification to handle more complex folder structures and subfolder depth.

v1.00 (2024-03-21)
Initial Release:
Developed the core utility for loading and processing survey data across different countries and years.
Introduced options to select specific surveys, modules, and collections.
Implemented basic error handling and default settings for common use cases.
Supported integration with master and adaptation file types, though master file handling was not fully implemented.
Included initial support for various modules and sorting mechanisms based on the selected collection.