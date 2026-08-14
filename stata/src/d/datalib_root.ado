*******************************************************
* datalib_root: library-root resolver
* Author: Joao Pedro Azevedo
* Co-author: Minh Cong Nguyen (World Bank)
*! v1.7.1  2026-08-06
*******************************************************
* Resolves the datalib library root. Two mechanisms, deliberately separate:
*
* RESOLUTION -- pure candidate selection, in precedence order, WITHOUT touching
* the disk (the same contract the R and Python legs implement):
*     1 argument        root()
*     2 global          ${datalib}
*     3 env             DATALIB_ROOT
*     4 config_generic  <config dir>/user_config.yml   (datalib: key)
*     5 config_package  <config dir>/datalib_config.yml
* The first non-empty candidate wins and is returned as given. It is never
* probed, and never overridden by anything below it. That is the safety
* property: an operator whose archive is momentarily unreachable -- VPN down,
* drive unmapped, a typo in the config -- gets their own path back and fails at
* the file operation, instead of being quietly handed a different library.
*
* DISCOVERY -- runs only when stages 1-5 yield NOTHING AT ALL, i.e. for an
* operator who has configured nothing:
*     6 discovered      the first eligible candidate found on disk
*     7 demo            the demo library bundled with this repository
* Eligibility is decided by _dl_islib (named "datalib", or carrying a .datalib
* marker, or holding a <CCC>/<CCC>_* pair), so an ordinary directory that
* happens to exist is never mistaken for a library. Both stages announce
* themselves: a resolution the operator did not ask for has to be visible, or
* the first thing they learn about it is a number that will not reconcile.
*
* Discovery is deliberately narrower than stages 1-5: the ancestor walk is
* bounded, and discovery is refused outright in batch runs, where an unattended
* job would otherwise read a library nobody named and still exit 0. Neither
* discovered nor demo may fill the ${datalib} global, because -clear all- does
* not drop globals and one such write would be sticky for the session.
*
* Stata returns the candidate as a LITERAL string. R and Python do not: R's
* fs::path_norm collapses "..", expands "~" and strips a trailing separator,
* and Python returns a Path whose Windows string form uses backslashes. The
* three agree on the resolved DIRECTORY, not on its spelling -- the contract
* pins identity, not bytes. Do not assert a returned root byte-for-byte against
* another language's.
*
* -find- opts in to disk validation of the CONFIGURED candidates as well:
*   - each candidate is tested with _dl_islib, in precedence order;
*   - a candidate may name the library OR the place that holds it: <cand>/datalib
*     is tried first (r(descended)=1), then <cand> itself;
*   - a candidate that is set but is not a library is an ERROR naming it -- the
*     root is never silently substituted, because provenance matters more than
*     convenience here.
*
* Options:
*   root(path)        explicit candidate (stage 1)
*   set               also fill ${datalib} with the resolved root
*   find              validate configured candidates against the disk
*   candidates(list)  extra discovery candidates, tried first, space-separated
*                     (quote paths containing spaces)
*   config(file)      pin one config file for stages 4-5 (fallback off)
*   configdir(dir)    search the two-file list in another directory; the Stata
*                     accommodation for DATALIB_CONFIG_DIR, which Stata cannot
*                     set in-session. Both are passed straight to getuserconfig
*                     and exist so the golden cases can run hermetically.
*   nodiscover        stop after stage 5; never discover, never use the demo
*   quietly           suppress the discovery/demo notice (the stage is still
*                     reported in r(source_stage))
*
* Returns:
*   r(root)          the resolved root
*   r(source_stage)  argument | global | env | config_generic | config_package |
*                    discovered | demo
*   r(descended)     1 if the resolver descended into <candidate>/datalib
*
* Provenance: ported from unicef-drp/datalib-unicef-dev @ v0.9.33 (a66b6b6)
* stata/src/d/datalib_root.ado (there v0.9.19). Generalized for this package:
*   - upstream discovery looked for a library named "datalib" under ${zDrive}
*     then a hard-coded Z:/. Both are deployment facts of one installation, not
*     part of the contract; discovery here searches the working directory and
*     its ancestors, the operator's home, and finally the bundled demo.
*   - the config stages (4 and 5) are resolved here. Upstream reaches them only
*     if getuserconfig has already run and filled ${datalib}, typically from a
*     startup profile; making the resolver self-contained means a plain -datalib-
*     call honours the config file on a machine with no startup profile.
*******************************************************

capture program drop datalib_root
program define datalib_root, rclass

    version 15

    syntax [, root(string) FIND set CANDidates(string) NODISCover DISCover ///
              QUIETly CONFIG(string) CONFIGDIR(string) REQUIRE(string) ]

    quietly {
        * ---- ordered candidates and their contract source_stage names -------
        local c1 `"`root'"'
        local s1 "argument"
        local c2 `"${datalib}"'
        local s2 "global"
        local c3 : environment DATALIB_ROOT
        local s3 "env"

        * Stages 4/5 come from the config file(s). getuserconfig fills
        * ${datalib} as a side effect when it is unset, so snapshot the global
        * and put it back unless the caller asked for -set-: a resolver that
        * reports must not mutate the session on the way.
        local c4 ""
        local s4 "config_generic"
        local c5 ""
        local s5 "config_package"
        if (`"`c1'"'=="" & `"`c2'"'=="" & `"`c3'"'=="") {
            local dl_saved `"${datalib}"'
            capture getuserconfig, config(`"`config'"') configdir(`"`configdir'"') quietly
            local cfg_rc = _rc
            local cfg_file `"`r(config)'"'
            if (`cfg_rc'==0) {
                local cfg_root  `"`r(datalib)'"'
                local cfg_stage `"`r(source_stage)'"'
                if (`"`cfg_root'"'!="") {
                    if ("`cfg_stage'"=="config_generic") local c4 `"`cfg_root'"'
                    else                                 local c5 `"`cfg_root'"'
                }
            }
            global datalib `"`dl_saved'"'

            * A configuration that EXISTS but yields no root is a mistake, not an
            * empty stage. Falling through to discovery here is how a typo'd key
            * ("datalib_root:" for "datalib:"), a block written under the wrong
            * username, or tab indentation turns into a confident resolution
            * somewhere else entirely. Only the total absence of a config file
            * may fall through.
            *   rc 601 = no config file at all      -> fall through
            *   rc 459 = file(s) found, no user block
            *   rc   0 with an empty datalib: key
            if (`cfg_rc'==459) {
                noi di as err `"{p}A configuration file was found, but it has no block for user '`c(username)''.{p_end}"'
                noi di as err `"{p}Name the library for one call with {bf:datalib, library(}{it:path}{bf:)}, or for the session with {bf:datalib_root, root(}{it:path}{bf:) set}. To make it permanent, {bf:getuserconfig, create root(}{it:path}{bf:)} (template: config/user_config.yml).{p_end}"'
                exit 198
            }
            if (`cfg_rc'==0 & `"`cfg_root'"'=="") {
                noi di as err `"{p}Configuration read from `cfg_file', but your block carries no {bf:datalib:} key (or it is empty).{p_end}"'
                noi di as err `"{p}Add {bf:datalib: }{it:path-to-your-library}{bf: } to that block, or name the library for one call with {bf:datalib, library(}{it:path}{bf:)} — or for the session with {bf:datalib_root, root(}{it:path}{bf:) set}.{p_end}"'
                exit 198
            }
        }

        * ---- resolution: first non-empty candidate wins ---------------------
        * NB: a bare -exit- inside forvalues does NOT leave the program (it acts
        * like -continue-), so the pick is made in the loop and returned after it.
        local pick  ""
        local stage ""
        forvalues i = 1/5 {
            if (`"`c`i''"'!="") {
                local pick  `"`c`i''"'
                local stage "`s`i''"
                continue, break
            }
        }

        *----------------------------------------------------------------------
        * Default mode: return the candidate as given.
        *----------------------------------------------------------------------
        if ("`find'"=="" & `"`pick'"'!="") {
            if ("`set'"!="") global datalib `"`pick'"'
            return local root         `"`pick'"'
            return local source_stage "`stage'"
            return scalar descended = 0
            exit
        }

        *----------------------------------------------------------------------
        * find: resolve the configured candidates against the disk, in order.
        *----------------------------------------------------------------------
        local found     ""
        local fstage    ""
        local descended 0
        local badcand   ""
        local badexists 0
        if ("`find'"!="") {
            forvalues i = 1/5 {
                if (`"`c`i''"'=="") continue
                _dl_islib `"`c`i''"'
                local cand `"`r(path)'"'
                * child first: the candidate may hold the library rather than be it
                local sep "/"
                if (substr(`"`cand'"', -1, 1)=="/") local sep ""
                _dl_islib `"`cand'`sep'datalib"'
                if (r(islib)==1) {
                    local found     `"`r(path)'"'
                    local fstage    "`s`i''"
                    local descended 1
                    continue, break
                }
                _dl_islib `"`cand'"'
                if (r(islib)==1) {
                    local found  `"`r(path)'"'
                    local fstage "`s`i''"
                    continue, break
                }
                * Set but not a library: stop here rather than trying a later
                * candidate. The root the operator named is never silently replaced.
                local badcand   `"`cand'"'
                local badexists = r(exists)
                continue, break
            }

            if (`"`badcand'"'!="") {
                noi di as err `"{p}No datalib library at: `badcand'{p_end}"'

                * WHY it failed, when the reason is "the drive is not
                * connected". _dl_islib knows this, but says so with -noi di-
                * inside its own -quietly-, which is itself inside THIS
                * command's -quietly- -- so the note escapes one level and is
                * swallowed by the second, and the user saw only "No datalib
                * library at: Z:/datalib" after a six-minute wait. Reported
                * here instead: once, attached to the failure, rather than
                * once per candidate.
                local badvol = ""
                if (regexm(`"`badcand'"', "^([A-Za-z]):")) local badvol = upper(regexs(1))
                if ("`badvol'"!="" & "${dtlb_volstate_`badvol'}"=="disconnected") {
                    noi di as err `"{p}Drive {bf:`badvol':} is mapped but {bf:disconnected}, so it was never read. The operating system reported that from local state, without contacting the share.{p_end}"'
                    noi di as err `"{p}Connect the drive, or point datalib somewhere else: {bf:datalib, library(}{it:path}{bf:)}.{p_end}"'
                    exit 198
                }

                if (`badexists'==1) noi di as err `"{p}That directory exists but does not look like a library (no {bf:datalib} folder inside it, no country folders, no {bf:.datalib} marker).{p_end}"'
                noi di as err `"{p}Name it for one call with {bf:datalib, library(}{it:path}{bf:)}, or for the session with {bf:datalib_root, root(}{it:path}{bf:) set}.{p_end}"'
                exit 198
            }
        }

        *----------------------------------------------------------------------
        * Discovery: only when nothing at all was configured.
        *----------------------------------------------------------------------
        * Batch runs never discover. An unattended job that lands on a library
        * nobody named is the worst case for this command: batch Stata returns
        * exit code 0 even after an error, so there is no downstream signal, and
        * the run's output looks exactly like a successful one. Interactive use
        * is left alone; -discover- is the explicit opt-in for automation that
        * genuinely wants it.
        local batchblock 0
        if ("`c(mode)'"=="batch" & "`discover'"=="") local batchblock 1

        local searched 0
        if (`"`found'"'=="" & `"`pick'"'=="" & "`nodiscover'"=="" & `batchblock'==0) {
            local searched 1

            * (a) caller-supplied candidates, in the order given
            local n : word count `candidates'
            forvalues i = 1/`n' {
                local b : word `i' of `candidates'
                _dl_islib `"`b'"'
                local base `"`r(path)'"'
                local sep "/"
                if (substr(`"`base'"', -1, 1)=="/") local sep ""
                _dl_islib `"`base'`sep'datalib"'
                if (r(islib)==1) {
                    local found     `"`r(path)'"'
                    local fstage    "discovered"
                    local descended 1
                    continue, break
                }
                _dl_islib `"`base'"'
                if (r(islib)==1) {
                    local found  `"`r(path)'"'
                    local fstage "discovered"
                    continue, break
                }
            }

            * (b) the working directory and its ancestors, then the home
            *     directory. A project that keeps its archive beside its code is
            *     found without configuration, the way version control finds its
            *     own root.
            if (`"`found'"'=="") {
                local home : environment USERPROFILE
                if ("`home'"=="") local home : environment HOME
                local home = subinstr(`"`home'"', "\", "/", .)

                local walk = subinstr(`"`c(pwd)'"', "\", "/", .)
                local places ""
                forvalues up = 1/4 {
                    if (`"`walk'"'=="") continue, break
                    local places `"`places' `"`walk'"'"'
                    local cut = strrpos(`"`walk'"', "/")
                    if (`cut'<=0) continue, break
                    local walk = substr(`"`walk'"', 1, `cut'-1)
                }
                if (`"`home'"'!="") {
                    local places `"`places' `"`home'/datalib"' `"`home'/.datalib/library"'"'
                }

                foreach b of local places {
                    _dl_islib `"`b'"'
                    local base `"`r(path)'"'
                    local sep "/"
                    if (substr(`"`base'"', -1, 1)=="/") local sep ""
                    _dl_islib `"`base'`sep'datalib"'
                    if (r(islib)==1) {
                        local found     `"`r(path)'"'
                        local fstage    "discovered"
                        local descended 1
                        continue, break
                    }
                    _dl_islib `"`base'"'
                    if (r(islib)==1) {
                        local found  `"`r(path)'"'
                        local fstage "discovered"
                        continue, break
                    }
                }
            }

            * (c) last resort: the demo library bundled with this repository
            if (`"`found'"'=="") {
                _dl_demo
                if (r(found)==1) {
                    local found  `"`r(path)'"'
                    local fstage "demo"
                }
            }
        }

        if (`"`found'"'=="") {
            if (`batchblock'==1) {
                noi di as err `"{p}No datalib library configured, and this is a batch run.{p_end}"'
                noi di as err `"{p}Discovery is disabled in batch so that an unattended job cannot silently read a library nobody named. Set one of: {bf:root()}, the {bf:datalib} global, {bf:DATALIB_ROOT}, or a {bf:datalib:} key in your config block. Add {bf:discover} if you really want a batch run to search.{p_end}"'
                exit 198
            }
            if (`searched'==1) {
                noi di as err `"{p}No datalib library found: nothing is configured, and no library was discovered near the working directory or in your home directory.{p_end}"'
            }
            noi di as err `"{p}Set a library root with {bf:datalib_root, root(}{it:path}{bf:) set}, the {bf:datalib} global, or the {bf:DATALIB_ROOT} environment variable — or write one with {bf:getuserconfig, create root(}{it:path}{bf:)}, which creates {bf:user_config.yml} and the block for your username.{p_end}"'
            if (`searched'==1) {
                noi di as err `"{p}To try the package without an archive, build a synthetic one: {bf:datalib_makelib, families(demo)}. It writes a complete library you can point at, and this command will find it afterwards.{p_end}"'
            }
            exit 198
        }

        * Announce a root the operator did not ask for. Both stages below are
        * reached only when nothing was configured, so the user has no way of
        * knowing which library they are about to read unless it is said.
        if ("`quietly'"=="") {
            if ("`fstage'"=="discovered") {
                noi di as txt `"{p}datalib: no library configured; discovered one at {bf:`found'}. Set {bf:datalib_root, root(}{it:path}{bf:) set} to pin a different one.{p_end}"'
            }
            if ("`fstage'"=="demo") {
                noi di as txt `"{p}datalib: no library configured; using the synthetic DEMO library at {bf:`found'}. Every value in it is generated — do not read a result off it. Set {bf:datalib_root, root(}{it:path}{bf:) set} to use your own archive.{p_end}"'
                noi di as txt `"{p}Nothing is deposited here by accident: this stage does not fill the {bf:datalib} global, so a write with no explicit {bf:root()} fails rather than landing in the demo.{p_end}"'
            }
        }

        * -set- is legal only for a root the operator actually named. A
        * discovered or demo root must never reach the global: -clear all- does
        * NOT drop globals, so one write is sticky for the whole session,
        * survives the reset idiom analysts reach for, and is then read by every
        * ${datalib} site -- including the deposit path, which would write real
        * microdata into a library nobody chose.
        if ("`set'"!="") {
            if (inlist("`fstage'", "discovered", "demo")) {
                noi di as txt `"{p}Not setting the {bf:datalib} global: the root was `fstage', not configured. Pass {bf:root(}{it:path}{bf:) set} to pin it deliberately.{p_end}"'
            }
            else global datalib `"`found'"'
        }

        capture _dl_require_stage, stage("`fstage'") require(`"`require'"')
        if (_rc) exit _rc

        return local root         `"`found'"'
        return local source_stage "`fstage'"
        return scalar descended   = `descended'
    }

end
