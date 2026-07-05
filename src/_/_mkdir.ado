*******************************************************
* _mkdir: deprecation stub (renamed to _dtlb_mkdir in v1.0)
* This file forwards calls to _dtlb_mkdir and emits a one-time warning per
* session. It will be removed in v2.0.
*
* Note: Stata's built-in `mkdir' is unaffected by this file because Stata
* prefers built-ins over ado-files.
*******************************************************

capture program drop _mkdir
program define _mkdir, rclass
    version 15

    if "${_dtlb_warned_mkdir}" == "" {
        display as text "{p}{result:note:} {cmd:_mkdir} is deprecated and will be removed in v2.0; " ///
            "use {cmd:_dtlb_mkdir} instead. (forwarding...){p_end}"
        global _dtlb_warned_mkdir "1"
    }

    _dtlb_mkdir `0'
    return add
end
