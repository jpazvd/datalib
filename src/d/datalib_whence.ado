*******************************************************
* datalib_whence: where did the data in memory come from?
* Author: Joao Pedro Azevedo
* Co-author: Minh Cong Nguyen (World Bank)
*! v1.6.0  2026-08-08
*******************************************************
* Reports the provenance a dataset carries about itself, read from the _dta
* characteristics that -datalib- stamps when it loads.
*
*   datalib_whence [, quietly ]
*
* Returns:
*   r(idno)        the IHSN identifier the data was loaded as
*   r(level)       its declared unit of observation
*   r(keys)        the variables that identify a row
*   r(parent)      the module one level up
*   r(source)      the path it was loaded from
*   r(stamped)     1 if the data carries a datalib stamp, 0 if not
*
* WHY THIS EXISTS. Open a .dta someone sent you and Stata will tell you its
* variables and its label; it will not tell you which vintage of which survey
* it is, which is the question that decides whether a result can be
* reproduced. Characteristics travel with the file -- they survive save/use,
* merge, append, collapse, reshape and frame put -- so a dataset carried out
* of its folder still knows where it came from.
*
* WHAT IT DOES NOT TELL YOU. Chars record ORIGIN, not current content. They
* survive -collapse-, so an aggregate still names the vintage it was built
* from; that is the honest answer to "where did this come from" and the wrong
* answer to "is this still that dataset". For the second question use
* -datasignature-, which covers values and ignores metadata. The two are
* complementary and neither substitutes for the other. See
* internal/provenance_carriers_design_note.md.
*******************************************************

capture program drop datalib_whence
program define datalib_whence, rclass

    version 15

    syntax [, QUIETly ]

    local idno   `"`: char _dta[datalib_idno]'"'
    local level  `"`: char _dta[datalib_level]'"'
    local keys   `"`: char _dta[datalib_keys]'"'
    local parent `"`: char _dta[datalib_parent]'"'
    local pkeys  `"`: char _dta[datalib_parentkeys]'"'
    local source `"`: char _dta[datalib_source]'"'
    local loaded `"`: char _dta[datalib_loaded]'"'
    local pkgver `"`: char _dta[datalib_pkgversion]'"'

    local stamped = (`"`idno'"'!="" | `"`level'"'!="")

    if ("`quietly'"=="") {
        if (!`stamped') {
            di as text `"{p}The data in memory carries no datalib provenance.{p_end}"'
            di as text `"{p}Either it was not loaded with {bf:datalib}, or it was rebuilt by a command that does not preserve characteristics -- {bf:import}, or a save from a frame built by hand.{p_end}"'
        }
        else {
            di as text ""
            di as text "  datalib provenance"
            di as text "  {hline 56}"
            if (`"`idno'"'!="")   di as text "  identifier   " as result `"`idno'"'
            if (`"`source'"'!="") di as text "  loaded from  " as result `"`source'"'
            if (`"`loaded'"'!="") di as text "  loaded at    " as result `"`loaded'"'
            if (`"`pkgver'"'!="") di as text "  datalib      " as result `"`pkgver'"'
            if (`"`level'"'!="") {
                di as text "  {hline 56}"
                di as text "  unit         " as result `"`level'"'
                di as text "  keys         " as result `"`keys'"'
                if (`"`parent'"'!="") {
                    di as text "  parent       " as result `"`parent'"' ///
                        as text "  on " as result `"`pkeys'"'
                }
            }
            di as text "  {hline 56}"
            * Say plainly what the stamp does and does not assert. A reader who
            * takes "loaded from" as proof the data is UNCHANGED has been
            * misled by a command that was trying to help.
            di as text `"{p 2 2 2}This records where the data came from, not"' ///
                `" whether it still matches. Characteristics survive"' ///
                `" {bf:collapse} and {bf:reshape}, so a derived dataset keeps"' ///
                `" its origin. Use {bf:datasignature} to ask whether the"' ///
                `" values have changed.{p_end}"'
        }
    }

    return local idno   `"`idno'"'
    return local level  `"`level'"'
    return local keys   `"`keys'"'
    return local parent `"`parent'"'
    * Return everything the command PRINTS. Reading a value into a local,
    * displaying it, and then not returning it leaves a caller unable to act on
    * what a human can plainly see.
    return local source     `"`source'"'
    return local parentkeys `"`pkeys'"'
    return local loaded     `"`loaded'"'
    return local pkgversion `"`pkgver'"'
    return scalar stamped = `stamped'
end
