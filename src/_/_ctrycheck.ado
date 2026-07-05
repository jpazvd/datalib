*******************************************************
* _ctrycheck: deprecation stub (renamed to _dtlb_ctrycheck in v1.0)
* Forwards to _dtlb_ctrycheck with a one-time per-session warning.
* Will be removed in v2.0.
*******************************************************

capture program drop _ctrycheck
program define _ctrycheck, rclass
    version 15

    if "${_dtlb_warned_ctrycheck}" == "" {
        display as text "{p}{result:note:} {cmd:_ctrycheck} is deprecated and will be removed in v2.0; " ///
            "use {cmd:_dtlb_ctrycheck} instead. (forwarding...){p_end}"
        global _dtlb_warned_ctrycheck "1"
    }

    _dtlb_ctrycheck `0'
    return add
end
