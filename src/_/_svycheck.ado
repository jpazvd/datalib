*******************************************************
* _svycheck: deprecation stub (renamed to _dtlb_svycheck in v1.0)
* Forwards to _dtlb_svycheck with a one-time per-session warning.
* Will be removed in v2.0.
*******************************************************

capture program drop _svycheck
program define _svycheck, rclass
    version 15

    if "${_dtlb_warned_svycheck}" == "" {
        display as text "{p}{result:note:} {cmd:_svycheck} is deprecated and will be removed in v2.0; " ///
            "use {cmd:_dtlb_svycheck} instead. (forwarding...){p_end}"
        global _dtlb_warned_svycheck "1"
    }

    _dtlb_svycheck `0'
    return add
end
