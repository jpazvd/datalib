*******************************************************
* __dtlb_rename: portable rename via copy + erase.
* Private to the datalib package; not intended for direct user call.
*
* On failure the program exits with the _rc returned by copy, so callers
* can detect and stop rather than continuing as if the rename had
* succeeded.
*******************************************************
capture program drop __dtlb_rename
program define __dtlb_rename
    version 15
    args dir oldname newname overwrite
    local src "`dir'/`oldname'"
    local dst "`dir'/`newname'"

    // Use Stata's atomic copy ..., replace when overwrite is requested.
    // Earlier draft erased the destination first and then attempted the
    // copy, which left no file at dst if copy then failed (data loss on
    // permission error, missing source, etc.). copy ..., replace is
    // atomic from the user's perspective: the destination is replaced
    // only if the copy succeeded.
    if ("`overwrite'" == "overwrite") {
        cap copy "`src'" "`dst'", replace
    }
    else {
        cap copy "`src'" "`dst'"
    }
    local copy_rc = _rc
    if (`copy_rc' == 0) {
        cap erase "`src'"
    }
    else {
        noi di as err "Could not rename `src' -> `dst' (_rc=`copy_rc')."
        exit `copy_rc'
    }
end
