*******************************************************
* _dtlb_load: Data Loading and Processing Utility (formerly _dlw)
* Author: Joao Pedro Azevedo
* Co-author: Minh Cong Nguyen (World Bank)
*! Version: 1.10.2      Date: 2026-08-12       
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
                cross(string)              ///
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
        * cross() is read at exactly one point below, and that point sits
        * behind two gates: this one, and -alldecl-. An option that is
        * accepted by -syntax- and then never read is the defect this release
        * fixed for -nomerge-; reintroducing it for cross() would be worse,
        * because a silently-dropped cross() returns ONE module's rows and
        * looks like a successful load. So refuse here, before either gate,
        * rather than let the request evaporate.
        *
        * filename() names files directly and bypasses module resolution
        * entirely, so there is no module structure for cross() to pair on.
        if (`"`cross'"'!="") & ("`filename'"!="") {
            di as err `"{p}{bf:cross()} and {bf:filename()} cannot be combined. {bf:filename()} names files directly and skips module resolution, so there are no declared modules to pair and no parent key to pair them on.{p_end}"'
            di as err `"{p}Name the two modules with {bf:cross()} and drop {bf:filename()}.{p_end}"'
            exit 198
        }

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
            local nodecl  ""
            foreach m of local wantmod {
                capture _dtlb_modspec, dir("`vdir'") module(`m') stem(`file')
                if (_rc) {
                    local alldecl 0
                    local nodecl `"`nodecl' `m'"'
                }
                else if (`"`r(level)'"'=="") {
                    local alldecl 0
                    local nodecl `"`nodecl' `m'"'
                }
            }

            * The second gate. cross() pairs on a key it reads out of the
            * modules' own declarations, so an undeclared vintage cannot be
            * crossed -- but it must be TOLD that, not quietly handed the
            * legacy path, which does not know the option exists and would
            * return a plain single-module load with rc 0.
            *
            * The loop above already knows which modules failed to declare;
            * before this it discarded that and only kept the flag, so the
            * message could not say what to fix.
            if (`"`cross'"'!="") & (!`alldecl') {
                di as err `"{p}{bf:cross()} needs every module of this vintage to declare its own structure -- unit of observation, keys, and parent -- because the pairing key is read from those declarations rather than guessed.{p_end}"'
                di as err `"{p}Undeclared here: {bf:`=trim(`"`nodecl'"')'}. This vintage loads through the legacy path, which has no pairing operation.{p_end}"'
                exit 198
            }

            * A survey whose hierarchy has TWO leaves -- teacher and student
            * both hang off classroom -- has no single natural "everything"
            * join, so defaulting to all modules would refuse. Erroring is
            * right, but the message must say why the user is seeing it when
            * they never asked for those two modules together.
            * cross() -- the deliberate opt-in past the refusal below.
            *
            * The refusal exists because the RESULT's unit of observation is
            * undetermined, not because the join is impossible. cross() is how
            * a caller determines it: the answer is one row per pair, and
            * saying so is the whole point of naming the option after the
            * object it builds rather than after the override. -force- would
            * say "I know better"; it would not say what you get, and with
            * three branches it could not say WHICH pairing was meant.
            *
            * The fan-out is measured and reported here because the files are
            * being read anyway. On the refusal path the same numbers would
            * cost two file reads purely to produce an error message.
            if (`alldecl') & (`"`cross'"'!="") {
                local xn : word count `cross'
                if (`xn'!=2) {
                    di as err `"{p}{bf:cross()} takes exactly two modules -- the two branches to pair. You gave `xn'.{p_end}"'
                    exit 198
                }
                local xa = word("`cross'", 1)
                local xb = word("`cross'", 2)
                * The same module twice passes the arity check -- it is two
                * words -- and would then be joined to itself on its own
                * parent key, multiplying every row by the number of its
                * siblings under that parent. There is no reading of that
                * request that is what the caller wanted.
                if (`"`xa'"'==`"`xb'"') {
                    di as err `"{p}{bf:cross()} pairs two {it:different} modules; you named {bf:`xa'} twice. Crossing a module with itself joins it to its own siblings under the same parent, which multiplies rows without adding anything.{p_end}"'
                    di as err `"{p}To load {bf:`xa'} on its own, use {bf:module(`xa')}.{p_end}"'
                    exit 198
                }
                foreach x in `xa' `xb' {
                    capture quietly _dtlb_modspec, dir("`vdir'") module(`x') stem(`file')
                    if (_rc | `"`r(level)'"'=="") {
                        di as err `"{p}{bf:cross(): `x'} is not a declared module of this vintage. Declared: {bf:`=trim(`"`wantmod'"')'}.{p_end}"'
                        exit 198
                    }
                    local xpar_`x' `"`r(parent)'"'
                    local xkey_`x' `"`r(parentkeys)'"'
                    * Where this module's declaration came from. Captured per
                    * module because the two sides can differ -- one answered
                    * by datalib.yaml, the other by _dta chars.
                    local xsrc_`x' `"`r(source)'"'
                }
                * Ancestor-descendant is not a cross() case, but neither is it
                * an error in the data: the default merge already joins a
                * module to its own ancestors without duplicating anything.
                * Walking the chain, rather than testing the immediate parent,
                * catches grandparent pairs too. Bounded by the module count
                * so a malformed cyclic declaration cannot hang the loop.
                * Both directions, explicitly. -foreach ... in- splits its list
                * on whitespace even when the elements are compound-quoted, so
                * a list of two-word pairs silently iterates over four single
                * words and only the first direction is ever tested.
                local nest ""
                forvalues _d = 1/2 {
                    if (`_d'==1) {
                        local up `"`xa'"'
                        local down `"`xb'"'
                    }
                    else {
                        local up `"`xb'"'
                        local down `"`xa'"'
                    }
                    local walk `"`xpar_`down''"'
                    local guard = 0
                    while (`"`walk'"'!="" & `guard'<20) {
                        if (`"`walk'"'==`"`up'"') local nest `"`up' `down'"'
                        capture quietly _dtlb_modspec, dir("`vdir'") module(`walk') stem(`file')
                        if (_rc) continue, break
                        local walk `"`r(parent)'"'
                        local guard = `guard' + 1
                    }
                }
                if (`"`nest'"'!="") {
                    local anc : word 1 of `nest'
                    local des : word 2 of `nest'
                    di as err `"{p}{bf:`anc'} and {bf:`des'} are not siblings: {bf:`anc'} is an ancestor of {bf:`des'}, so they nest rather than sit side by side. There is nothing to pair -- every {bf:`des'} row already belongs to exactly one {bf:`anc'} row.{p_end}"'
                    di as err `"{p}Drop {bf:cross()} and let the default merge join them. That attaches the {bf:`anc'} columns onto {bf:`des'} without duplicating any row, which is what {bf:cross()} exists to avoid.{p_end}"'
                    exit 198
                }
                if (`"`xpar_`xa''"'!=`"`xpar_`xb''"') {
                    * A root module has no parent, so naming one blindly
                    * produces "school hangs off  and student off classroom".
                    * Say what is true of each side instead.
                    foreach x in `xa' `xb' {
                        if (`"`xpar_`x''"'=="") local xsay_`x' `"{bf:`x'} is the root of the hierarchy and hangs off nothing"'
                        else                    local xsay_`x' `"{bf:`x'} hangs off {bf:`xpar_`x''}"'
                    }
                    di as err `"{p}{bf:`xa'} and {bf:`xb'} do not share a parent -- `xsay_`xa'' and `xsay_`xb''. Only modules meeting at the same parent can be paired, because that parent is what defines which rows belong together.{p_end}"'
                    exit 198
                }
                * Two ROOT modules both declare an empty parent, so they pass
                * the equality test above without sharing anything. Caught
                * here rather than folded into that test, so the message can
                * say what is actually true of them.
                if (`"`xpar_`xa''"'=="") {
                    di as err `"{p}{bf:`xa'} and {bf:`xb'} are both roots of their own hierarchies: neither hangs off anything, so there is no shared parent whose key could pair them. Equal emptiness is not a shared parent.{p_end}"'
                    exit 198
                }

                local xkey `"`xkey_`xa''"'

                * A DECLARATION IS A CLAIM, NOT A FACT -- the rule
                * _dtlb_mergeplan states in its own header and enforces
                * through _dtlb_mergeplan_check. The cross path was taking the
                * declared key and handing it straight to -joinby- unchecked,
                * and an unchecked key here is worse than on the merge path:
                * -joinby- with an EMPTY varlist does not error, it silently
                * joins on every variable the two files have in common. A
                * vintage declaring parent: but leaving parentkeys: blank --
                * which _dtlb_modspec accepts as a complete declaration, since
                * it requires only level and keys -- therefore produced a
                * confident report reading "paired on ," and a row count
                * governed by whatever columns happened to share a name.
                if (`"`=trim(`"`xkey'"')'"'=="") {
                    di as err `"{p}{bf:`xa'} declares {bf:`xpar_`xa''} as its parent but declares no {bf:parentkeys}, so there is no key to pair on. Pairing without one would join on whatever variable names the two modules happen to share, which is not a relationship anybody declared.{p_end}"'
                    di as err `"{p}Add {bf:parentkeys:} for {bf:`xa'} to the {bf:module_schema:} block of this vintage's {bf:datalib.yaml}.{p_end}"'
                    exit 198
                }

                * Each file is confirmed to exist before it is opened, and the
                * declared key is confirmed to be IN it, module by module, so
                * a failure names the module and the variable rather than
                * surfacing as a bare -file not found- or, worse, as a join
                * that quietly used a different set of columns.
                foreach x in `xa' `xb' {
                    capture confirm file "`vdir'/Data/Stata/`file'_`x'.dta"
                    if (_rc) {
                        di as err `"{p}{bf:`x'} is declared in this vintage but its file is missing: {bf:`file'_`x'.dta}.{p_end}"'
                        exit 601
                    }
                }
                use "`vdir'/Data/Stata/`file'_`xa'.dta", `clear'
                local n_a = _N
                foreach v of local xkey {
                    capture confirm variable `v'
                    if (_rc) {
                        di as err `"{p}{bf:`xa'} declares {bf:`v'} among its parent keys, but that variable is not in {bf:`file'_`xa'.dta}. A declaration is a claim, not a fact.{p_end}"'
                        exit 111
                    }
                }
                tempfile _xfile
                quietly save `"`_xfile'"'
                use "`vdir'/Data/Stata/`file'_`xb'.dta", clear
                local n_b = _N
                foreach v of local xkey {
                    capture confirm variable `v'
                    if (_rc) {
                        di as err `"{p}{bf:`xb'} does not carry {bf:`v'}, the parent key {bf:`xa'} is paired on. Two modules can only meet at a parent both of them name.{p_end}"'
                        exit 111
                    }
                }
                quietly joinby `xkey' using `"`_xfile'"', unmatched(none)
                local n_x = _N

                noisily di as text `"{p}{bf:cross(`xa' `xb')}: paired on {bf:`xkey'}, the key of their shared parent {bf:`xpar_`xa''}.{p_end}"'
                noisily di as text `"  `xa' rows      `n_a'"'
                noisily di as text `"  `xb' rows      `n_b'"'
                noisily di as text `"  paired rows   `n_x'"'
                * Report BOTH directions. Either module may be the one the
                * caller cares about, and the multiplication is different for
                * each: pairing 240 with 900 under a shared parent inflates
                * the first 7.5x and the second 2x. Reporting only one leaves
                * whichever the caller was watching unmeasured.
                if (`n_a'>0 & `n_b'>0) {
                    local fan_a = trim(string(`n_x'/`n_a', "%9.2f"))
                    local fan_b = trim(string(`n_x'/`n_b', "%9.2f"))
                    noisily di as text `"{p}The unit of observation is now the pair, not either module. Each {bf:`xa'} row appears {bf:`fan_a'} times on average and each {bf:`xb'} row {bf:`fan_b'} times, so any statistic computed on either from this table, without correction, is inflated by its own factor.{p_end}"'
                }
                * Stamp provenance BEFORE returning. This path used to exit
                * straight past the char block below, so a crossed dataset
                * carried no datalib_* chars at all and datalib_whence could
                * not say which vintage it came from -- visible in the
                * article's own example log, where (b) and (c) report
                * "Contains data from .../XAA_2021_XSA_v01_M_student.dta" and
                * (d) reports a bare "Contains data". The version local is
                * read at the top of this program precisely for this stamp;
                * on this path it was computed and thrown away.
                char _dta[datalib_idno]       "`file'"
                char _dta[datalib_source]     "`vdir'"
                char _dta[datalib_loaded]     "`c(current_date)' `c(current_time)'"
                char _dta[datalib_pkgversion] "`_dtlb_pkgver'"
                * The rows are pairs, not records of either module. Anything
                * reading these chars back should be able to learn that here
                * rather than infer it from a row count.
                char _dta[datalib_cross]      "`xa' `xb'"

                return local mergeplan        "`xa' x `xb'"
                * _dtlb_mergeplan sets r(spec_source); this path never calls
                * it, so reading that macro here always returned empty.
                * _dtlb_modspec answers r(source), per module -- so report
                * that, and say "mixed" when the two sides disagree rather
                * than silently picking one.
                local xsrc = cond(`"`xsrc_`xa''"'==`"`xsrc_`xb''"', `"`xsrc_`xa''"', "mixed")
                return local mergespec_source `"`xsrc'"'
                return local modules          "`xa' `xb'"
                return local base             ""
                return local unit             "pair"
                return local filename1        "`file'_`xa'.dta"
                return local filename2        "`file'_`xb'.dta"
                return scalar n_modules  = 2
                return scalar rows_`xa'  = `n_a'
                return scalar rows_`xb'  = `n_b'
                return scalar rows_pairs = `n_x'
                exit
            }

            if (`alldecl') & (`"`module'"'=="") & (`"`cross'"'=="") {
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
                    * WHY THE MESSAGE SAYS WHAT IT SAYS.
                    * The old text named the condition ("more than one finest
                    * level", "many-to-many") and stopped. That is the
                    * taxonomy, not the consequence, and a reader who does not
                    * already know what a many-to-many join does to their rows
                    * learns nothing from it.
                    *
                    * The consequence is derivable here for free, from the
                    * DECLARATIONS alone: two modules with no ancestor relation
                    * between them share only a common parent, so pairing them
                    * on that parent repeats each row of one for every row of
                    * the other within the same parent. Row counts would make
                    * it sharper still, but they would cost opening both files
                    * merely to produce an error -- which on a slow share is
                    * the expense the whole resolver works to avoid. The counts
                    * are reported by -cross()- instead, where the files are
                    * being read anyway.
                    *
                    * Deliberately domain-neutral: it speaks of modules, a
                    * shared parent and repeated rows, so it reads correctly
                    * whether the leaves are teachers and students, plots and
                    * household members, or firms and workers.
                    local l1 = word(`"`leaves'"', 1)
                    local l2 = word(`"`leaves'"', 2)
                    di as err `"{p}{bf:`=trim(`"`leaves'"')'} are each the finest level of their own branch: no one of them is an ancestor of another, so none of them is "the" unit this survey describes.{p_end}"'
                    di as err `"{p}Merging them is not an extension of the data but a multiplication of it. They meet only at a shared parent, so every row of {bf:`l1'} would be repeated once for each row of {bf:`l2'} under the same parent, and every statistic computed on either would be inflated by that factor. That is why the default merge refuses rather than guessing.{p_end}"'
                    di as err `"{p}Choose one of three:{p_end}"'
                    di as err `"{p2colset 8 24 26 2}{...}"'
                    di as err `"{p2col :{bf:module(`l1')}}load one branch. Everything above it is joined automatically, which is the usual answer.{p_end}"'
                    di as err `"{p2col :{bf:cross(`l1' `l2')}}build the pairing deliberately, as its own unit of observation. The row multiplication is reported when it happens.{p_end}"'
                    di as err `"{p2col :{bf:nomerge}}with {bf:module()} naming one branch, load it without its ancestors.{p_end}"'
                    di as err `"{p2colreset}{...}"'
                    exit 459
                }
            }

            if (`alldecl') {
                * -nomerge- WAS SILENTLY IGNORED HERE. The planner ran
                * regardless, so -datalib, ... nomerge- returned the joined
                * dataset and the option did nothing at all: measured on the
                * demo library, with and without it, N=400 and
                * r(mergeplan)="roster <- household" both times. A documented
                * option that does nothing is worse than one that errors,
                * because nothing tells the caller their instruction was
                * dropped.
                *
                * What it now means on this path is the only thing it CAN
                * mean: Stata holds one dataset, so "do not join them" is a
                * request for the base module alone -- the finest level, the
                * one whose rows the join would have preserved. The ancestors
                * are named rather than silently withheld.
                if ("`nomerge'"!="") {
                    quietly _dtlb_mergeplan, dir("`vdir'") stem(`file') ///
                        modules(`"`wantmod'"') nowarning
                    local base_    "`r(base)'"
                    local others_  : list wantmod - base_
                    * -clear- unconditionally, matching _dtlb_mergeplan:163,
                    * which is the branch this one replaces. Honouring the
                    * caller's -clear- instead makes -nomerge- stricter than
                    * the merge it stands in for: the documented example
                    * -datalib, country(XAA) year(2015) survey(XHS) nomerge-
                    * then dies with rc 4 where the merge path succeeds, which
                    * DOC-03 caught. Whether this path should refuse to discard
                    * in-memory data is a real question, but it is one for both
                    * branches at once, not for this one alone.
                    use "`vdir'/Data/Stata/`file'_`base_'.dta", clear
                    if (`"`others_'"'!="") {
                        noisily di as text `"{p}note: {bf:nomerge} -- loaded {bf:`base_'} alone. Not joined: {bf:`=trim(`"`others_'"')'}. Load one of those instead with {bf:module()}, or drop {bf:nomerge} to have them joined onto {bf:`base_'}.{p_end}"'
                    }
                    return local mergeplan       ""
                    return local mergespec_source "`r(spec_source)'"
                    return local modules          `"`wantmod'"'
                    return local filename1        "`file'_`base_'.dta"
                }
                else {
                * -noisily- because _dtlb_load's whole body runs inside a
                * -quietly- block (line 43). Without it the merge report is
                * written and then swallowed, which is the worst of both: the
                * cost of producing it and none of the benefit. Found by
                * running the command and seeing nothing.
                noisily _dtlb_mergeplan, dir("`vdir'") stem(`file') ///
                    modules(`"`wantmod'"') `nowarning'
                }

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

*  _foldernav lives in its own file (stata/src/_/_foldernav.ado) since v1.1.
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