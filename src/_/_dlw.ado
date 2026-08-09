*******************************************************
* _dlw: deprecation stub (renamed to _dtlb_load in v1.0)
* This file forwards calls to _dtlb_load and emits a one-time warning per
* session. It will be removed in v2.0.
*! v1.1.0
*******************************************************

capture program drop _dlw
program define _dlw, rclass
    version 15

    if "${_dtlb_warned_dlw}" == "" {
        display as text "{p}{result:note:} {cmd:_dlw} is deprecated and will be removed in v2.0; " ///
            "use {cmd:_dtlb_load} instead. (forwarding...){p_end}"
        global _dtlb_warned_dlw "1"
    }

    _dtlb_load `0'
    return add
end
