*******************************************************************************
* __dtlb_volstate
*! v1.8.2  09Aug2026               by Joao Pedro Azevedo (UNICEF)
*!                                  and Minh Cong Nguyen (World Bank)
* Ask the OPERATING SYSTEM whether a mapped drive is connected, without
* touching the share.
*
*   __dtlb_volstate, volume(Z)
*   -> r(state)  "connected" | "disconnected" | "unknown"
*      r(remote) the UNC path behind the letter, when known
*
* WHY THIS EXISTS
* -direxists() on a disconnected share pays the operating system's own
* timeout. Measured 2026-08-09 with Z: mapped to an Azure Files share and the
* VPN down: a single -datalib- took t=366.90 -- six minutes -- before failing.
* Stata cannot bound a filesystem call, so the only way to avoid the wait is
* not to make it.
*
* Windows already knows. -net use- reads LOCAL mapping state and reports
* "Disconnected" for a dead drive; measured at 0.11s against the same share
* that costs six minutes to probe. So one cheap question replaces a very
* expensive one.
*
* FAIL-SAFE BY CONSTRUCTION
* This command can only ever let the caller SKIP work. Anything it cannot
* classify -- shell unavailable, output in a language whose status word we do
* not recognise, a drive that is not a network mapping -- returns "unknown",
* and the caller then behaves exactly as it did before. A wrong answer here
* must never make a reachable library invisible.
*
* Localisation is the reason for that care: -net use- prints status words in
* the system language, so matching "Disconnected" is a best-effort test, not a
* contract. We match a handful of known forms and give up honestly otherwise.
*******************************************************************************

program define __dtlb_volstate, rclass
    version 15

    syntax , volume(string) [os(string)]

    if ("`os'"=="") local os = c(os)
    local v = upper(strtrim("`volume'"))
    if (substr("`v'", -1, 1)==":") local v = substr("`v'", 1, strlen("`v'")-1)

    return local state  "unknown"
    return local remote ""

    * A drive letter, or nothing. Taking the first character of whatever was
    * passed meant "UNC" answered for drive U: -- a state belonging to an
    * entirely unrelated volume, which could then hide a reachable library.
    * Anything that is not one letter A-Z is "unknown", which is the answer
    * that changes no behaviour.
    if (!regexm("`v'", "^[A-Z]$")) exit

    if ("`os'"!="Windows") exit          // mapped-letter concept is Windows-only

    * -shell- may be refused on a locked-down machine. That is not an error
    * here: it is one more reason to answer "unknown" and let the caller
    * proceed as before.
    tempfile out
    capture quietly shell net use > "`out'" 2>&1
    if (_rc) exit
    capture confirm file "`out'"
    if (_rc) exit

    tempname fh
    file open `fh' using "`out'", read text
    file read `fh' line
    local state  "unknown"
    local remote ""
    while (r(eof)==0) {
        local l `"`macval(line)'"'
        * The drive letter appears as its own token, e.g. "Disconnected Z:".
        * Require the colon so C: does not match a path that merely contains
        * the letter.
        if (strpos(`"`l'"', "`v':") > 0) {
            local first = word(`"`l'"', 1)
            local lf    = lower("`first'")
            if (inlist("`lf'", "ok", "conectado", "verbunden", "connecté")) local state "connected"
            if (inlist("`lf'", "disconnected", "unavailable", "desconectado")) local state "disconnected"
            if (inlist("`lf'", "getrennt", "déconnecté", "indisponible")) local state "disconnected"

            * RECONNECTING is a THIRD state, and it was missing. Found on a
            * live machine: Windows reported "Reconnecting Z:" while the share
            * was coming back, this command had never heard of it, answered
            * "unknown", and the fail-safe path therefore treated a drive that
            * still blocks on touch as usable.
            *
            * It is reported separately rather than folded into "disconnected"
            * because the two are different facts and the caller says which one
            * it saw. What the CALLER does with it is settled in _dl_islib: do
            * not wait for a reconnect, drop the root, and reconsider only on a
            * later explicit attempt.
            if (inlist("`lf'", "reconnecting", "reconectando", "wiederverbinden")) local state "reconnecting"
            if (inlist("`lf'", "reconnexion", "riconnessione")) local state "reconnecting"
            * The UNC is the token beginning with a double backslash.
            local nw : word count `"`l'"'
            forvalues k = 1/`nw' {
                local tk : word `k' of `"`l'"'
                if (substr(`"`tk'"',1,2)=="\\") local remote `"`tk'"'
            }
            continue, break
        }
        file read `fh' line
    }
    file close `fh'

    return local state  "`state'"
    return local remote `"`remote'"'
end
