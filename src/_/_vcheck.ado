*******************************************************
* _vcheck: deprecation stub (renamed to _dtlb_vcheck in v1.0)
* Forwards to _dtlb_vcheck with a one-time per-session warning.
* Will be removed in v2.0.
*******************************************************

capture program drop _vcheck
program define _vcheck, rclass
    version 15

    if "${_dtlb_warned_vcheck}" == "" {
        display as text "{p}{result:note:} {cmd:_vcheck} is deprecated and will be removed in v2.0; " ///
            "use {cmd:_dtlb_vcheck} instead. (forwarding...){p_end}"
        global _dtlb_warned_vcheck "1"
    }

    _dtlb_vcheck `0'
    return add
end
