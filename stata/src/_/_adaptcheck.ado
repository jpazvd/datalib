*******************************************************
* _adaptcheck: deprecation stub (renamed to _dtlb_adaptcheck in v1.0)
* Forwards to _dtlb_adaptcheck with a one-time per-session warning.
* Will be removed in v2.0.
*! v1.1.0
*******************************************************

capture program drop _adaptcheck
program define _adaptcheck, rclass
    version 15

    if "${_dtlb_warned_adaptcheck}" == "" {
        display as text "{p}{result:note:} {cmd:_adaptcheck} is deprecated and will be removed in v2.0; " ///
            "use {cmd:_dtlb_adaptcheck} instead. (forwarding...){p_end}"
        global _dtlb_warned_adaptcheck "1"
    }

    _dtlb_adaptcheck `0'
    return add
end
