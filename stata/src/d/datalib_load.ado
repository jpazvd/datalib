*******************************************************
* datalib_load: contract v1 loader — thin wrapper over _dtlb_load
* Author: Joao Pedro Azevedo
*! Version: 1.12.1      Date: <2026-08-14>
* Maps the shared datalib_* argument names onto the _dtlb_load engine:
*   modules() -> module(), kind(master|adaptation), master_version() -> vm(),
*   adaptation_version() -> va(), merge (default) / nomerge.
*******************************************************

capture program drop datalib_load
program define datalib_load, rclass

    version 15

    syntax , country(string)              ///
        [                                 ///
            year(string)                  ///
            survey(string)                ///
            MODules(string)               ///
            KINd(string)                  ///
            collection(string)            ///
            master_version(string)        ///
            adaptation_version(string)    ///
            filename(string)              ///
            NOMerge                       ///
            clear                         ///
            DEBUG                         ///
            root(string)                  ///
        ]

    quietly {
        * With no kind(), collection() decides: naming a collection is a request
        * for an adaptation, and naming none asks for the master.
        *
        * Ported verbatim from upstream, this line read
        *
        *     cond("`collection'"!="", "adaptation", "adaptation")
        *
        * whose two branches are the same value, so the test did nothing and
        * every kind-less load resolved as an HLT adaptation -- erroring on any
        * library that holds only masters. The identical branches are what give
        * the intent away: the false arm was meant to be "master", and reading it
        * as deliberate requires believing someone wrote a condition to choose
        * between a thing and itself. (Copilot, #106.)
        *
        * Fixed here rather than carried, because datalib_load has never shipped
        * -- it arrives in this release -- so there is no behaviour to preserve,
        * and this is the last moment the defect can be kept out of a released
        * version. It also aligns the explicit spelling with the master-first
        * default that bare -datalib- uses. Divergence from upstream is
        * deliberate and recorded.
        if ("`kind'"=="") local kind = cond("`collection'"!="", "adaptation", "master")
        local kind = lower(trim("`kind'"))
        if !inlist("`kind'", "master", "adaptation") {
            di as err "kind() must be master or adaptation."
            exit 198
        }

        * root(): _dtlb_load reads ${datalib}; honor root() without clobbering the
        * global, and fall back to env DATALIB_ROOT like the other wrappers
        local oldroot "${datalib}"
        if ("`root'"=="") & ("${datalib}"=="") {
            local root : environment DATALIB_ROOT
        }
        if ("`root'"!="") global datalib "`root'"

        * kind(master) passes NOTHING, because master is what the engine does
        * when told nothing -- and it REJECTS an explicit -master-:
        *
        *     _dtlb_load, country(XAA) year(2015) survey(XHS) master
        *     Option master not currently supported.                    rc 198
        *
        * This wrapper sent exactly that, so kind(master) could never have
        * worked. Nothing caught it because nothing exercised the master path:
        * the port probe checked that the command RESOLVED, not that it loaded,
        * and the kind-less default was adaptation, so the broken branch was
        * only reachable by asking for it explicitly. Measured 2026-08-14 and
        * fixed before first release. (Found while checking Copilot's #106
        * finding about the kind() default, which was the visible half of it.)
        local kopt ""
        if ("`kind'"=="adaptation") {
            if ("`collection'"=="") local collection "HLT"
            local kopt "adaptation collection(`collection')"
        }
        local fopt ""
        if ("`filename'"!="") local fopt `"filename("`filename'") data"'

        * _dtlb_load directly, NOT via the _dlw deprecation stub. Two reasons.
        *
        * The stub is BROKEN, measured 2026-08-14: every call through it dies
        * "invalid syntax" rc 198 on arguments _dtlb_load accepts unchanged when
        * given them directly, and its own one-shot warning fires on every call
        * because execution never reaches the `global' that suppresses it. An
        * inline replica of the same body forwards correctly, so the fault is in
        * the shipped file, not in the forwarding idiom.
        *
        * And even sound, the hop is wrong here: it charged every contract-v1
        * load a deprecation warning for a name the caller never typed. This is
        * the same retarget dev made in #104.
        capture noisily _dtlb_load , country(`country') year(`year') survey(`survey') ///
            module(`modules') `kopt' vm(`master_version') va(`adaptation_version') ///
            `fopt' `nomerge' `clear' `debug'
        local rc = _rc

        if ("`root'"!="") global datalib "`oldroot'"
        if (`rc') exit `rc'
        return add
    }

end
