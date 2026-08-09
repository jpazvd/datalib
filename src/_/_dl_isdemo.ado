*******************************************************
** _dl_isdemo: is this library the bundled demo?
* Author: Joao Pedro Azevedo
* Co-author: Minh Cong Nguyen (World Bank)
*! v1.1.0  2026-08-05
*******************************************************
* Reads a library's .datalib marker and reports two independent facts:
*
*   demo: true    the data is synthetic. Advisory: it tells a caller not to
*                 read a result off this library, nothing more.
*   readonly: 1   deposits are refused at or below this directory. THIS is what
*                 the write commands act on.
*
* The two are separate on purpose. A library built by datalib_makelib is marked
* synthetic but stays writable: it is the operator's copy, in their directory,
* and depositing into it is the point. Read-only is for a library somebody
* wants protected -- a shared fixture, a reference tree -- and it is opt-in by
* adding the key.
*
* The marker is consulted rather than the path compared, because a path
* blocklist is defeated by 8.3 short names, junctions, UNC-versus-mapped
* spellings, case, and by the operator simply copying the tree. A marker
* travels with the data.
*
* Note what does NOT rely on this guard: a first run cannot deposit into a
* library nobody chose, because datalib_root refuses to publish a discovered or
* demo root to ${datalib}, so a write with no explicit root() has nothing to
* land in. The marker protects a library the operator has deliberately named.
*
* Returns:
*   r(demo)      1 if the path is a demo library, 0 otherwise
*   r(readonly)  1 if the marker forbids deposits at or below it
*******************************************************

capture program drop _dl_isdemo
program define _dl_isdemo, rclass

    version 15

    args p

    quietly {
        return scalar demo = 0
        if (`"`p'"'=="") exit

        local p = subinstr(`"`p'"', "\", "/", .)
        while (substr(`"`p'"', -1, 1)=="/" & strlen(`"`p'"')>1 & substr(`"`p'"', -2, 1)!=":") {
            local p = substr(`"`p'"', 1, strlen(`"`p'"')-1)
        }

        * Walk up from the target looking for the marker, bounded. The caller
        * may hand us a deep path (a vintage's Data/Stata folder, say) rather
        * than the library root, and the guard has to hold there too.
        local marker ""
        local probe `"`p'"'
        forvalues up = 1/8 {
            capture confirm file `"`probe'/.datalib"'
            if (_rc==0) {
                local marker `"`probe'/.datalib"'
                continue, break
            }
            local cut = strrpos(`"`probe'"', "/")
            if (`cut'<=0) continue, break
            local probe = substr(`"`probe'"', 1, `cut'-1)
            if (`"`probe'"'=="" | substr(`"`probe'"', -1, 1)==":") continue, break
        }
        if (`"`marker'"'=="") exit

        tempname fh
        capture file open `fh' using `"`marker'"', read text
        if (_rc) exit
        local isdemo 0
        local isro   0
        file read `fh' line
        while (r(eof)==0) {
            local trm = trim(subinstr(`"`macval(line)'"', char(13), "", .))
            if (substr(`"`macval(trm)'"',1,1)!="#") {
                local flat = lower(subinstr(`"`macval(trm)'"', " ", "", .))
                if ("`flat'"=="demo:true")  local isdemo 1
                if ("`flat'"=="readonly:1") local isro 1
            }
            file read `fh' line
        }
        file close `fh'

        return scalar demo     = `isdemo'
        return scalar readonly = `isro'
    }

end
