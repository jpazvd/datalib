*******************************************************
* __dtlb_rmdir: portable recursive directory removal.
* Private to the datalib package; not intended for direct user call.
*
* Tracks the first non-zero _rc encountered during file or
* subdirectory removal and returns it via r(rc). Callers that treat
* cleanup as a postcondition (e.g. __dtlb_move_and_clean) can inspect
* r(rc) and exit with that code rather than assume success.
*******************************************************
capture program drop __dtlb_rmdir
program define __dtlb_rmdir, rclass
    version 15
    args dir
    local first_rc 0

    local files : dir "`dir'" files "*"
    foreach f of local files {
        cap erase "`dir'/`f'"
        if (_rc != 0 & `first_rc' == 0) {
            local first_rc = _rc
            noi di as err "Could not erase file `dir'/`f' (_rc=" _rc ")."
        }
    }

    local subs : dir "`dir'" dirs "*"
    foreach s of local subs {
        __dtlb_rmdir "`dir'/`s'"
        if (`r(rc)' != 0 & `first_rc' == 0) {
            local first_rc = `r(rc)'
        }
    }

    cap rmdir "`dir'"
    if (_rc != 0 & `first_rc' == 0) {
        local first_rc = _rc
        noi di as err "Could not remove directory `dir' (_rc=" _rc ")."
    }

    return scalar rc = `first_rc'
end
