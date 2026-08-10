*******************************************************
** _dl_islib
* Joao Pedro Azevedo
*! v1.8.2
*******************************************************
* Normalise a path and decide whether it is a datalib LIBRARY (not merely an
* existing directory). Used by datalib_root's -find- mode so that a missing
* library fails loudly instead of resolving to whatever directory happens to
* exist at the candidate path.
*
* Returns:
*   r(path)   normalised path (forward slashes, no trailing separator except
*             on a drive root such as Z:/)
*   r(exists) 1 if the directory exists
*   r(skipped_unreachable), r(volstate)
*             set when the root was NOT read because the operating system
*             reports its drive disconnected or reconnecting. r(volstate)
*             carries which of the two it was. r(skipped_disconnected) is the
*             older name for the same flag, kept for callers that read it.
*   r(skipped_offline), r(skipped_dead)
*             set when the skip came from ${datalib_offline} or from the
*             session/persisted memo instead
*   r(islib)  1 if it exists AND looks like a library, by any of three tests:
*             it is named "datalib", or it carries a .datalib marker file, or it
*             holds a <CCC>/<CCC>_* GRANDCHILD PAIR -- a 3-character child that
*             itself contains a "<child>_*" folder. The name and marker tests
*             let a freshly created, still-empty library qualify.
*
*             The third test deliberately checks the grandchild, not just "a
*             3-character child": the weaker test passes on ordinary
*             directories (C:/ has c:/ado), which is exactly how a missing
*             library could resolve to its parent and have that parent's
*             subfolders read as country codes. See the comment at the test.
*
* Provenance: ported verbatim from unicef-drp/datalib-unicef-dev @ v0.9.33
* (a66b6b6) stata/src/_/_dl_islib.ado. Generalized: nothing -- the test is
* structural and carries no deployment assumptions.
*******************************************************

capture program drop _dl_islib
program define _dl_islib, rclass

    version 15

    args p

    quietly {
        * ---- normalise -----------------------------------------------------
        local p = subinstr(`"`p'"', "\", "/", .)
        while (substr(`"`p'"', -1, 1)=="/" & strlen(`"`p'"')>1 & substr(`"`p'"', -2, 1)!=":") {
            local p = substr(`"`p'"', 1, strlen(`"`p'"')-1)
        }
        return local path `"`p'"'

        * ---- is this root even reachable? ----------------------------------
        * -direxists()- on a disconnected network share BLOCKS on the OS, and
        * Stata offers no way to bound a filesystem call. The resolver walks
        * several candidates, so one dead drive is not one pause -- it is one
        * per candidate, which is why Stata appears frozen rather than slow.
        * (Observed 2026-08-08: ${datalib} = Z:/datalib with the VPN down,
        * _dl_islib "Z:/datalib" then "Z:/datalib/datalib", Stata "not
        * responding". A bare -ls- on the same share hung identically, so this
        * is the OS, not Stata.)
        *
        * We cannot make the FIRST probe safe. We can stop it becoming the
        * tenth, and skip it entirely when the operator has said they are
        * offline. Three guards, in that order.
        *
        * WHY THE SESSION MEMO IS NOT ENOUGH (2026-08-09)
        * Guard (2) works, and a -set trace on- run proves it: with
        * ${datalib} = Z:/datalib and the share disconnected, the FIRST
        * candidate cost the full OS timeout and the remaining two were
        * skipped by the memo. Measured end to end: t=366.90 -- six minutes
        * and seven seconds for one -datalib- that then failed with a clear
        * "No datalib library at: Z:/datalib".
        *
        * So the probe does return; it just returns slowly, and Stata cannot
        * bound a filesystem call. What the session memo cannot do is remember
        * anything, so EVERY new session pays those six minutes again -- which
        * is what "still getting stuck" means in practice.
        *
        * Guard (0) therefore PERSISTS the finding, so a volume that failed
        * once is skipped in every later session without being touched.
        * Nothing here probes: it reads one small file in the user's home.
        * The memo key. A drive letter is its own key; a UNC path is keyed by
        * SERVER_SHARE, not by the bare word "UNC".
        *
        * Keying every UNC path alike meant one unreachable \\a\x marked every
        * other UNC root dead, hiding a perfectly reachable \\b\y -- a
        * pre-existing scoping bug that persisting the memo would have turned
        * from a session annoyance into a durable one. Found in review.
        *
        * -isletter- is kept separately from -vol- because only a real drive
        * letter may be handed to __dtlb_volstate: "UNC" would be truncated to
        * "U" there and answer for an unrelated U: drive.
        local vol      = ""
        local isletter = 0
        if (regexm(`"`p'"', "^([A-Za-z]):")) {
            local vol      = upper(regexs(1))
            local isletter = 1
        }
        else if (substr(`"`p'"',1,2)=="//") {
            * //server/share/... -> UNC_SERVER_SHARE, with anything that is not
            * A-Z, 0-9 or _ folded to _ so the result is a legal global name.
            local unc = substr(`"`p'"', 3, .)
            local sv  = upper(word(subinstr(`"`unc'"', "/", " ", .), 1))
            local sh  = upper(word(subinstr(`"`unc'"', "/", " ", .), 2))
            local key = "UNC_`sv'_`sh'"
            local key = subinstr("`key'", "-", "_", .)
            local key = subinstr("`key'", ".", "_", .)
            local key = subinstr("`key'", " ", "_", .)
            local vol = substr("`key'", 1, 30)
        }

        * (0) load the persisted dead-volume list, once per session
        if ("${dtlb_deadmemo_loaded}"!="1") {
            global dtlb_deadmemo_loaded 1
            capture __dtlb_userhome
            if (_rc==0) {
                local dhome `"`r(datalib_home)'"'
                local dhome = subinstr(`"`dhome'"', "\", "/", .)
                global dtlb_deadmemo_file `"`dhome'/offline_volumes.txt"'
                capture confirm file `"${dtlb_deadmemo_file}"'
                if (_rc==0) {
                    tempname mh
                    file open `mh' using `"${dtlb_deadmemo_file}"', read text
                    file read `mh' mline
                    while (r(eof)==0) {
                        local mv = strtrim(upper(`"`macval(mline)'"'))
                        if (`"`mv'"'!="" & substr(`"`mv'"',1,1)!="*") {
                            global dtlb_dead_`mv' = 1
                        }
                        file read `mh' mline
                    }
                    file close `mh'
                }
            }
        }

        * (1) offline: skip network roots without touching them
        if ("`vol'"!="" & "`vol'"!="C" & "${datalib_offline}"=="1") {
            noi di as text `"{p}note: skipping {bf:`p'} -- \${datalib_offline} is set and this root is not on the system drive.{p_end}"'
            return scalar exists = 0
            return scalar islib  = 0
            return scalar skipped_offline = 1
            exit
        }

        * (1b) ASK THE OS FIRST. Windows already knows a mapped drive is
        * disconnected and will say so in ~0.1s from local state, without
        * touching the network -- while probing the same drive costs its full
        * timeout (measured: t=366.90 for one -datalib-). One cheap question
        * replaces a very expensive one.
        *
        * Asked once per volume per session, and only ever used to SKIP: a
        * state this cannot classify returns "unknown" and we fall through to
        * the probe exactly as before. Being wrong here must never make a
        * reachable library invisible.
        if (`isletter' & "`vol'"!="C" & "${dtlb_volstate_`vol'}"=="") {
            capture __dtlb_volstate, volume("`vol'")
            if (_rc==0) global dtlb_volstate_`vol' `"`r(state)'"'
            else        global dtlb_volstate_`vol' "unknown"
        }

        * Checked on every call rather than only when the state was just
        * fetched: the invalidation should react to what the state SAYS, not to
        * where it came from, and a string comparison costs nothing.
        if (`isletter' & "`vol'"!="C") {
            * A volume the OS reports CONNECTED is not dead, whatever an
            * earlier session recorded. Without this the memo is a one-way
            * door: guard (0) loads it, this guard asks the OS and is told
            * the drive is fine, and guard (2) skips the drive anyway --
            * the cheap authoritative answer obtained and then ignored.
            *
            * Found on a live machine: S: had been recorded during a
            * VPN-down session, and every later session reported
            * "No datalib library at: S:/datalib" for a share that was
            * mounted, healthy, and named datalib. Persisting the finding
            * is what makes the guard worth having; never revisiting it is
            * what turns a slow drive into a permanently invisible one.
            *
            * Only "connected" clears it. "unknown" must not: that is the
            * answer for a shell we could not run or a status word we did
            * not recognise, and it is no evidence at all.
            if ("${dtlb_volstate_`vol'}"=="connected" & "${dtlb_dead_`vol'}"=="1") {
                global dtlb_dead_`vol' ""

                * Drop it from the file too, or the next session reloads it.
                * Rewrite rather than truncate: other volumes on that list
                * may still be dead and their memo is still worth having.
                if (`"${dtlb_deadmemo_file}"'!="") {
                    capture confirm file `"${dtlb_deadmemo_file}"'
                    if (_rc==0) {
                        tempname kh
                        local keep ""
                        file open `kh' using `"${dtlb_deadmemo_file}"', read text
                        file read `kh' kline
                        while (r(eof)==0) {
                            local kv = strtrim(upper(`"`macval(kline)'"'))
                            if (`"`kv'"'!="" & "`kv'"!="`vol'") local keep `"`keep' `kv'"'
                            file read `kh' kline
                        }
                        file close `kh'

                        capture file open `kh' using `"${dtlb_deadmemo_file}"', write text replace
                        if (_rc==0) {
                            foreach kv of local keep {
                                file write `kh' "`kv'" _n
                            }
                            file close `kh'
                        }
                    }
                }

                noi di as text `"{p}note: drive {bf:`vol':} is connected again; the offline record for it has been cleared.{p_end}"'
            }
        }
        * A drive that is DISCONNECTED or RECONNECTING is dropped now, not
        * waited on. Reconnecting is the case that motivated this: the share is
        * coming back, so a probe may eventually succeed -- after the operating
        * system's timeout, which is the cost this whole guard exists to avoid.
        * Waiting on a maybe is worse than failing on a certainty, because the
        * caller can retry cheaply and cannot un-wait six minutes.
        *
        * "Until there is a second attempt": the volume is marked dead below,
        * so it stays dropped for the session. datalib_config, retryvolumes
        * clears that when the operator knows the drive is back.
        local _vstate "${dtlb_volstate_`vol'}"
        if (`isletter' & inlist("`_vstate'", "disconnected", "reconnecting")) {
            noi di as text `"{p}note: drive {bf:`vol':} is mapped but {bf:`_vstate'}, so {bf:`p'} was not read. The operating system reported this without contacting the share; probing it would have cost minutes.{p_end}"'
            global dtlb_dead_`vol' = 1
            return scalar exists = 0
            return scalar islib  = 0
            return scalar skipped_unreachable = 1
            return local  volstate "`_vstate'"

            * Kept because it was the name before "reconnecting" existed, and a
            * caller may still read it. It is no longer accurate on its own --
            * r(volstate) says which state it actually was -- so new code should
            * read r(skipped_unreachable). (Copilot, PR #62.)
            return scalar skipped_disconnected = 1
            exit
        }

        * (2) memoise: one dead volume is probed ONCE per session, not once
        * per candidate. This is what turns "frozen" into "one pause, then a
        * clear answer".
        if ("`vol'"!="" & "${dtlb_dead_`vol'}"=="1") {
            return scalar exists = 0
            return scalar islib  = 0
            return scalar skipped_dead = 1
            exit
        }

        * ---- exists? -------------------------------------------------------
        mata: st_local("ok", strofreal(direxists(st_local("p"))))
        if ("`ok'"!="1") {
            * A volume that failed once will fail for every remaining
            * candidate, and each of those failures costs another OS timeout.
            *
            * But ONLY if the volume is what failed. -direxists- returns 0 for
            * two entirely different facts -- "this drive did not answer" and
            * "this drive answered, and there is no such directory" -- and
            * condemning the volume for the second is how a healthy drive gets
            * a permanent record. That is how S: came to be memoised on the
            * author's machine: one lookup of a path that was not there, and
            * every later session skipped a mounted, healthy share.
            *
            * So: if the OS says the drive is CONNECTED, a missing directory is
            * an ordinary missing directory. Nothing timed out, there is
            * nothing to remember, and the caller gets exists=0 as it should.
            local vconn = ("${dtlb_volstate_`vol'}"=="connected")
            if ("`vol'"!="" & "`vol'"!="C" & !`vconn') {
                global dtlb_dead_`vol' = 1

                * Record it, so the next session does not pay this again. The
                * probe above cost minutes; writing one line costs nothing,
                * and it is the difference between "slow once" and "slow every
                * time you open Stata".
                local wrote 0
                if (`"${dtlb_deadmemo_file}"'!="") {
                    capture mkdir `"`=substr("${dtlb_deadmemo_file}", 1, strrpos("${dtlb_deadmemo_file}","/")-1)'"'
                    tempname wh
                    capture file open `wh' using `"${dtlb_deadmemo_file}"', write text append
                    if (_rc==0) {
                        file write `wh' "`vol'" _n
                        file close `wh'
                        global dtlb_dead_`vol' = 1
                        local wrote 1
                    }
                }

                noi di as text `"{p}note: {bf:`vol':} did not respond, after the operating system's own timeout. Further candidates on that volume are skipped.{p_end}"'
                if (`wrote') {
                    noi di as text `"{p}It is now recorded in {bf:${dtlb_deadmemo_file}}, so later sessions skip it without waiting. When the drive is back, run {bf:datalib_config, retryvolumes} to forget it.{p_end}"'
                }
                else {
                    noi di as text `"{p}If it is a network drive, connect it (or set {bf:global datalib_offline 1}) and restart.{p_end}"'
                }
            }
            return scalar exists = 0
            return scalar islib  = 0
            exit
        }
        return scalar exists = 1

        * ---- does it look like a library? ----------------------------------
        local base = word(subinstr(`"`p'"', "/", " ", .), -1)
        if (lower(`"`base'"')=="datalib") {
            return scalar islib = 1
            exit
        }
        capture confirm file `"`p'/.datalib"'
        if (_rc==0) {
            return scalar islib = 1
            exit
        }
        * Structural test: a library holds <CCC>/<CCC>_<YYYY>_<SURVEY>/... So
        * require a 3-character child that itself holds a "<child>_*" folder.
        * Testing the grandchild matters -- a bare "3-character folder" test
        * passes on ordinary directories (C:/ has c:/ado), which would let a
        * missing library resolve to whatever exists at the candidate path.
        * Case is not usable here: Stata's -dir- lowercases names on Windows.
        local ccs ""
        capture local ccs : dir `"`p'"' dirs "???"
        local hits 0
        foreach d of local ccs {
            local subs ""
            capture local subs : dir `"`p'/`d'"' dirs `"`d'_*"'
            local ns : word count `subs'
            if (`ns' > 0) {
                local hits 1
                continue, break
            }
        }
        return scalar islib = (`hits' > 0)
    }

end
