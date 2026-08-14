*******************************************************************************
* __dtlb_userhome
*! v1.1.0  17Jul2026               by Joao Pedro Azevedo (UNICEF)
*!                                  and Minh Cong Nguyen (World Bank)
* Return the per-user datalib configuration directory (`~/.datalib`).
*
* Dispatches on c(os), matching the LITERAL strings "Windows", "MacOSX",
* "Unix" exactly (never substrings such as "Mac" or "win" — see the R-L
* red-team item in internal/datalib_nada_improvement_plan.md). Any other
* value is an error, never a silent fallback to the wrong path.
*
*   Windows       ->  ${USERPROFILE}\.datalib
*   MacOSX, Unix  ->  ${HOME}/.datalib
*
* os() is a TESTING-ONLY override so the three branches can be exercised on
* any host (Stata does not allow setting c(os) directly).
*
* Stored results:
*   r(datalib_home)  the per-user datalib directory (not created here)
*
* Internal helper (double-underscore tier): may be refactored without notice.
* NA-2 of internal/datalib_nada_improvement_plan.md.
*******************************************************************************

program define __dtlb_userhome, rclass
    version 15

    syntax [, os(string)]

    if "`os'" == "" local os = c(os)

    if "`os'" == "Windows" {
        local home : environment USERPROFILE
        if `"`home'"' == "" {
            display as error "__dtlb_userhome: USERPROFILE environment variable is not set"
            exit 198
        }
        return local datalib_home `"`home'\.datalib"'
    }
    else if "`os'" == "MacOSX" | "`os'" == "Unix" {
        local home : environment HOME
        if `"`home'"' == "" {
            display as error "__dtlb_userhome: HOME environment variable is not set"
            exit 198
        }
        return local datalib_home `"`home'/.datalib"'
    }
    else {
        display as error `"__dtlb_userhome: unsupported c(os) value: `os'"'
        exit 198
    }
end
