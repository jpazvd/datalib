*! getuserconfig 1.2.0  — load per-operator paths from the user config file(s)
*! Zero dependencies: parses the constrained two-level YAML schema
*! (<username>: {key: value}) natively, so it runs unchanged on locked-down
*! machines with no YAML/Python stack.
*!
*! Supported subset: a top-level map of <username> blocks, each with indented
*! "key: value" scalars (quoted or unquoted). "#" comments and blank lines are
*! ignored. NOT supported: lists, nested maps >2 deep, multiline scalars,
*! anchors. Use spaces (not tabs) for indentation and forward slashes in paths.
*!
*! The library-root key uses a TWO-FILE key-presence search — the current
*! user's block is looked up first in user_config.yml, then in
*! datalib_config.yml; the FIRST file whose block carries a non-empty
*! `datalib:` key wins (block-level, never merged). The full block comes from
*! the first file that has the user block. r(source_stage) reports where the
*! root came from (config_generic / config_package), byte-identical to the R
*! and Python legs.
*! Isolation hooks: env DATALIB_CONFIG pins one file (fallback off); env
*! DATALIB_CONFIG_DIR searches the two-file list in another directory;
*! configdir() does the same from Stata, which cannot set env vars in-session.
*!
*! Provenance: ported from unicef-drp/datalib-unicef-dev @ v0.9.33 (a66b6b6)
*! stata/src/g/getuserconfig.ado (there v1.2.0). Generalized for this package:
*!   - no Z:/ default for zDrive and no directory probe of it. Upstream
*!     defaulted zDrive to "Z:/" and ran -direxists- on it to print an advisory.
*!     That is a deployment assumption, not a contract: it made every Stata
*!     start-up touch a network share, which blocks -stata -b- outright when the
*!     share is slow or absent. Here the key is read if present and published
*!     as-is, possibly empty.
*!   - the bootstrap writer is reduced to two additive options rather than
*!     upstream's -init- / -profile- / -replace- / -edit- set and its _uc_init
*!     helper. -create- writes the file or appends the user's block and never
*!     overwrites an existing one; -edit- opens the file the reader would use.
*!     Nothing here rewrites a block, so no call can silently change a root, and
*!     -profile- (which edits the machine's profile.do) stays out entirely.
*!     Without either option the command is read-only, as before.
*! The four non-datalib keys are still parsed and published so that a single
*! config file can be shared with sibling tools, but only `datalib:` is
*! meaningful to this package. See 00_documentation/taxonomy.md.

* --- internal: parse ONE file for ONE user's block --------------------------
capture program drop _dl_parse_cfg
program define _dl_parse_cfg, rclass
    version 15
    syntax , FILE(string) USER(string)

    return local found 0
    capture confirm file `"`file'"'
    if _rc exit

    tempname fh
    file open `fh' using `"`file'"', read text
    local in_target 0
    local found     0
    local githubFolder ""
    local teamsRoot    ""
    local zDrive       ""
    local zDriveUNC    ""
    local datalibRoot  ""

    file read `fh' line
    while (r(eof)==0) {
        local raw = subinstr(`"`macval(line)'"', char(13), "", .)   // drop CR (CRLF)
        * Drop a UTF-8 BOM as well. Windows PowerShell's -Out-File- and ">"
        * write one by default, and it would make the first line eight
        * characters, so the leading username block goes unrecognised and the
        * command reports "no entry for user" on a file that plainly has one.
        local raw = subinstr(`"`macval(raw)'"', uchar(65279), "", .)
        local trm = trim(`"`macval(raw)'"')
        local len = strlen(`"`macval(trm)'"')

        if (`len'>0 & substr(`"`macval(trm)'"',1,1)!="#") {
            local lead = strlen(`"`macval(raw)'"') - strlen(ltrim(`"`macval(raw)'"'))
            local cpos = strpos(`"`macval(trm)'"', ":")

            if (`lead'==0 & `cpos'>0) {
                * top-level key: <username>:
                local key = trim(substr(`"`macval(trm)'"', 1, `cpos'-1))
                local in_target = ("`key'"=="`user'")
                if (`in_target') local found 1
            }
            else if (`in_target' & `cpos'>0) {
                * indented "key: value" (first colon splits key/value)
                local k = trim(substr(`"`macval(trm)'"', 1, `cpos'-1))
                local v = trim(substr(`"`macval(trm)'"', `cpos'+1, `len'-`cpos'))

                local q = substr(`"`macval(v)'"', 1, 1)
                if (`"`macval(q)'"'==char(34) | `"`macval(q)'"'==char(39)) {
                    local v  = substr(`"`macval(v)'"', 2, strlen(`"`macval(v)'"')-1)
                    local qp = strpos(`"`macval(v)'"', `"`macval(q)'"')
                    if (`qp'>0) local v = substr(`"`macval(v)'"', 1, `qp'-1)
                }
                else if (strpos(`"`macval(v)'"', " #")>0) {
                    local v = trim(substr(`"`macval(v)'"', 1, strpos(`"`macval(v)'"', " #")-1))
                }

                if ("`k'"=="githubFolder") local githubFolder `"`macval(v)'"'
                if ("`k'"=="teamsRoot")    local teamsRoot    `"`macval(v)'"'
                if ("`k'"=="zDrive")       local zDrive       `"`macval(v)'"'
                if ("`k'"=="zDriveUNC")    local zDriveUNC    `"`macval(v)'"'
                if ("`k'"=="datalib")      local datalibRoot  `"`macval(v)'"'
            }
        }
        file read `fh' line
    }
    file close `fh'

    return local found        `found'
    return local githubFolder `"`macval(githubFolder)'"'
    return local teamsRoot    `"`macval(teamsRoot)'"'
    return local zDrive       `"`macval(zDrive)'"'
    return local zDriveUNC    `"`macval(zDriveUNC)'"'
    return local datalib      `"`macval(datalibRoot)'"'
end

* --- getuserconfig ----------------------------------------------------------
capture program drop getuserconfig
program define getuserconfig, rclass
    version 15
    syntax [, USER(string) CONFIG(string) CONFIGDIR(string) QUIETly EDIT CREATE ROOT(string)]

    if ("`create'"=="" & `"`root'"'!="") {
        di as error "{p}root() sets the library root in a new block; it needs {bf:create}.{p_end}"
        error 198
    }

    if ("`user'"=="") local user = c(username)

    * ---- build the (at most two) config files ----
    * config()    pins one file (fallback off); configdir() / DATALIB_CONFIG_DIR
    * choose the search directory for the two-file list. configdir() is a
    * Stata-specific accommodation (Stata cannot set env vars in-session, so it
    * cannot use DATALIB_CONFIG_DIR the way the R/Python conformance tests do).
    local file1 ""
    local file2 ""
    if (`"`config'"'!="") {
        local file1 `"`config'"'                       // explicit: single file
    }
    else {
        local envfile : environment DATALIB_CONFIG
        if (`"`envfile'"'!="") {
            local file1 `"`envfile'"'                  // DATALIB_CONFIG: single file
        }
        else {
            local dir `"`configdir'"'
            if (`"`dir'"'=="") local dir : environment DATALIB_CONFIG_DIR
            if (`"`dir'"'=="") {
                local home : environment USERPROFILE
                if ("`home'"=="") local home : environment HOME
                local dir "`home'/.config"
            }
            local file1 `"`dir'/user_config.yml"'
            local file2 `"`dir'/datalib_config.yml"'
        }
    }

    * ---- create: write the file / the user's block, never overwrite ---------
    * Additive only. It creates the file when absent and appends the user's
    * block when that is what is missing, but it never rewrites a block that
    * already exists — so running it twice is safe, and it cannot silently
    * change a root somebody's pipelines depend on. It runs BEFORE the read
    * below, so the same call that creates the file also reports what it holds.
    *
    * With no root(), the key is written COMMENTED OUT. A placeholder path that
    * parses would be worse than none: it would fill ${datalib} with a directory
    * that does not exist, and the failure would surface much later, at a
    * -use-, as a missing file rather than as missing configuration.
    if ("`create'"!="") {
        local target `"`file1'"'
        if (`"`target'"'=="") {
            di as error `"{p}create: the target path resolved to nothing.{p_end}"'
            error 198
        }

        capture confirm file `"`target'"'
        local exists = (_rc==0)

        local hasblock 0
        if (`exists') {
            _dl_parse_cfg, file(`"`target'"') user(`"`user'"')
            if ("`r(found)'"=="1") local hasblock 1
        }

        local action "unchanged"
        if (`hasblock') {
            if ("`quietly'"=="") {
                di as txt `"{p}`target' already has a block for '`user'' — left as it is. Use {bf:getuserconfig, edit} to change it.{p_end}"'
            }
        }
        else {
            * Only the leaf directory is created. A nested configdir() that does
            * not exist is reported below rather than silently conjured.
            if (`exists'==0) {
                local fslash = subinstr(`"`target'"', "\", "/", .)
                local tdir = substr(`"`fslash'"', 1, strrpos(`"`fslash'"',"/")-1)
                if (`"`tdir'"'!="") capture mkdir `"`tdir'"'
            }

            tempname wh
            capture file open `wh' using `"`target'"', write text append
            if (_rc) {
                di as error `"{p}create: could not write {bf:`target'}. Check that its directory exists and is writable.{p_end}"'
                error 603
            }
            if (`exists'==0) {
                file write `wh' `"# Configuration for datalib and sibling tools."' _n
                file write `wh' `"# One top-level block per operator, keyed by the name Stata reports"' _n
                file write `wh' `"# as c(username). Use forward slashes in paths."' _n
            }
            else {
                file write `wh' _n
            }
            file write `wh' `"`user':"' _n
            if (`"`macval(root)'"'!="") {
                file write `wh' `"  datalib: `macval(root)'"' _n
            }
            else {
                file write `wh' `"  # datalib: F:/datalib   # <- your library root; uncomment and edit"' _n
            }
            file close `wh'
            local action = cond(`exists', "appended", "created")

            if ("`quietly'"=="") {
                if (`exists') di as result `"{p}Added a block for '`user'' to `target'.{p_end}"'
                else          di as result `"{p}Created `target' with a block for '`user''.{p_end}"'
                if (`"`macval(root)'"'=="") {
                    di as txt `"{p}The library root is commented out — set it with {bf:getuserconfig, edit}, or write it directly next time with {bf:getuserconfig, create root({it:path})}.{p_end}"'
                }
            }
        }
        * r(created) names a file this call WROTE. Returning it after a no-op
        * would make "your block was already there" indistinguishable from
        * "I just wrote it" -- the one thing a caller most needs to tell apart.
        * r(action) reports which of the three happened, always.
        * On the "unchanged" path the read below still runs and publishes
        * r(config), so the file's path is never actually lost.
        if ("`action'"!="unchanged") return local created `"`target'"'
        return local action "`action'"
    }

    * ---- full block from the first file with the user block; datalib key via
    *      two-file key-presence ----
    local anyfile    0
    local blockfound 0
    local cfgfile ""
    local gh ""
    local tr ""
    local zd ""
    local zu ""
    local dl ""
    local src_stage "unset"
    local src_file  ""

    forvalues i = 1/2 {
        local f `"`file`i''"'
        if (`"`f'"'=="") continue
        capture confirm file `"`f'"'
        if _rc continue
        local anyfile 1
        _dl_parse_cfg, file(`"`f'"') user(`"`user'"')
        if ("`r(found)'"=="1") {
            if (`blockfound'==0) {
                local blockfound 1
                local cfgfile `"`f'"'
                local gh `"`r(githubFolder)'"'
                local tr `"`r(teamsRoot)'"'
                local zd `"`r(zDrive)'"'
                local zu `"`r(zDriveUNC)'"'
            }
            if ("`dl'"=="" & `"`r(datalib)'"'!="") {
                local dl `"`r(datalib)'"'
                local src_file `"`f'"'
                local fslash = subinstr(`"`f'"', "\", "/", .)
                local base = substr(`"`fslash'"', strrpos(`"`fslash'"',"/")+1, .)
                if ("`base'"=="user_config.yml") local src_stage "config_generic"
                else local src_stage "config_package"
            }
        }
    }

    * ---- edit: open the file the reader would use --------------------------
    * Opening is the one write-adjacent thing this command does, and it is
    * strictly opt-in. It opens an EXISTING file; it never creates one, so the
    * read path stays free of side effects and the golden cases stay hermetic.
    if ("`edit'"!="") {
        * Prefer the file the reader actually used; then whichever of the two
        * exists (a package-only setup has no user_config.yml); then file1, so
        * the error names the path the reader would have looked at first.
        * Written out rather than looped over with -foreach ... in-, which splits
        * its list on spaces: a home directory like C:/Users/First Last would be
        * torn into two nonexistent paths and the file would never be found.
        local target `"`cfgfile'"'
        if (`"`target'"'=="") {
            capture confirm file `"`file1'"'
            if (_rc==0)  local target `"`file1'"'
        }
        if (`"`target'"'=="") & (`"`file2'"'!="") {
            capture confirm file `"`file2'"'
            if (_rc==0)  local target `"`file2'"'
        }
        if (`"`target'"'=="") local target `"`file1'"'
        capture confirm file `"`target'"'
        if (_rc) {
            if ("`quietly'"=="") {
                di as error `"{p}Nothing to edit: no configuration file at {bf:`target'}.{p_end}"'
                di as error `"{p}Create it with the two lines shown by {bf:getuserconfig} (run it without {bf:edit}), then run this again.{p_end}"'
            }
            error 601
        }
        * doedit opens a window, which a batch run has no way to show and no way
        * to close; report the path instead of hanging or failing obscurely.
        * Both branches honour -quietly-: the option's contract is that it
        * silences the reporting, not that it changes what happens. r(edited)
        * still names the file either way, so a script keeps its answer.
        if ("`c(mode)'"=="batch") {
            if ("`quietly'"=="") {
                di as txt `"{p}Configuration file: {bf:`target'} (not opened: this is a batch run).{p_end}"'
            }
        }
        else {
            capture noisily doedit `"`target'"'
            if (_rc) & ("`quietly'"=="") {
                di as txt `"{p}Could not open an editor. The file is at: {bf:`target'}{p_end}"'
            }
        }
        * Opening the file IS the job here, so stop rather than falling into the
        * read's error path. Otherwise the commonest reason to want the editor --
        * "the file has no block for me yet" -- would open it and then exit 459,
        * reporting a failure for something that just succeeded. The reader's
        * r() results are not set on this path; -edit- is an action, not a read.
        return local edited `"`target'"'
        exit 0
    }

    * ---- config file must exist -------------------------------------------
    if (`anyfile'==0) {
        if ("`quietly'"=="") {
            di as error `"{p}Configuration file not found at expected path: `file1'.{p_end}"'
            * Spell the file out rather than pointing at one in the source
            * repository: most operators arrive via -net install- and have no
            * checkout to copy from.
            di as error `"{p}To create one, write this into {bf:`file1'} (replace the first line with your own username, which Stata reports as {bf:c(username)} — here: {bf:`user'}):{p_end}"'
            di as error `" "'
            di as error `"    `user':"'
            di as error `"      datalib: F:/datalib"'
            di as error `" "'
            di as error `"{p}{bf:datalib} does not require this file — the library root can equally come from {bf:root()}, the {bf:datalib} global, or the {bf:DATALIB_ROOT} environment variable.{p_end}"'
        }
        error 601
    }

    * ---- user entry must exist --------------------------------------------
    if (`blockfound'==0) {
        if ("`quietly'"=="") {
            di as error `"{p}Configuration file found at: `cfgfile'`file1', but it has no entry for user '`user''.{p_end}"'
            di as error `"{p}Add a top-level block keyed by your username — the file is keyed that way so one file can serve several operators on a machine:{p_end}"'
            di as error `" "'
            di as error `"    `user':"'
            di as error `"      datalib: F:/datalib"'
        }
        error 459
    }

    * ---- publish: globals (cross-language parity names) + r() --------------
    * The four non-datalib keys are pass-through: this package does not use
    * them, but publishing them lets one config file serve sibling tools.
    * Unlike upstream, zDrive carries no default and is not probed on disk.
    global githubFolder `"`macval(gh)'"'
    global teamsRoot    `"`macval(tr)'"'
    global zDrive       `"`macval(zd)'"'
    global zDriveUNC    `"`macval(zu)'"'

    * optional per-user library root fills ${datalib} when unset
    if ("${datalib}"=="") & (`"`macval(dl)'"'!="") {
        global datalib `"`macval(dl)'"'
    }

    return local user         "`user'"
    return local config       `"`cfgfile'"'
    return local githubFolder `"`macval(gh)'"'
    return local teamsRoot    `"`macval(tr)'"'
    return local zDrive       `"`macval(zd)'"'
    return local zDriveUNC    `"`macval(zu)'"'
    return local datalib      `"`macval(dl)'"'
    return local source_stage "`src_stage'"
    return local source_file  `"`src_file'"'

    if ("`quietly'"=="") {
        di as result `"{p}Loaded user configuration for '`user'' from: `cfgfile' (datalib root: `src_stage').{p_end}"'
    }
end
