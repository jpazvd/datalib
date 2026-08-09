*******************************************************
** datalib
* Joao Pedro Azevedo
* Co-author: Minh Cong Nguyen (World Bank)
*! v1.7.1
*******************************************************
* Library resolution: library() names the archive for a call, and the
* resolution preamble below is ported from
* unicef-drp/datalib-unicef-dev @ v0.9.33 (a66b6b6) stata/src/d/datalib.ado
* :123-157, verbatim except for the delegate name (_dtlb_load here, _dlw there).
*
* Ported rather than reinvented on purpose. This repository's naming rule is
* verbatim public names, so a script written against either package resolves its
* library the same way and the two repositories stay diffable. Upstream's
* explorer/update options, which sit alongside library() there, are NOT carried
* -- they were excluded from the v1.1.0 backport scope and nothing here needs
* them.
*******************************************************

capture program drop datalib
program define datalib, rclass

    version 15

    syntax  [varlist]                    ///
            [in] [if]                    ///
            [,                           ///
                subfoldr(string)         ///
                country(string)          ///
                year(string)             ///
                survey(string)           ///
                MODule(string)           ///
                filename(string)         ///
                MASter                   ///
                adaptation               ///
                LATest                   ///
                collection(string)       ///
                harmonization(string)    ///
                VM(string)               ///
                VA(string)               ///
                debug                    ///
                data                     ///   
                doc                      ///
                programs                 ///
                NOMerge                  ///
                WRK                      ///
                clear                    ///
                path(string)         ///
                LIBrary(string)          ///
                NOWARNing                ///
            ]

    *---------------------------------------------------------------------------
    * Library root, resolved in -find- mode: library() outranks the config chain
    * (${datalib}, which getuserconfig fills from the user_config datalib: key,
    * then DATALIB_ROOT); a candidate may name the library or the place holding
    * it; and with nothing configured a library named "datalib" is discovered.
    * datalib_root stops with an actionable error naming library() rather than
    * letting _foldernav/_dtlb_load fail later with a bare -directory not found-.
    *
    * The resolved root is published to ${datalib} because the clickable
    * navigation links _foldernav writes carry no library() option -- they must
    * find the same library on the next call.
    *---------------------------------------------------------------------------
    * The interactive navigation carries its click-state in r(subfoldr) from one
    * call to the next, and datalib_root is rclass -- resolving here would wipe
    * it and break the DATA / DOC / PROGRAMS links. So hold r() across the
    * resolution, and skip it entirely once this session has already validated
    * the library (which also keeps a slow network share from being probed on
    * every single call).
    capture _return drop _dl_rhold
    capture _return hold _dl_rhold
    local _dl_held = (_rc==0)

    if (`"`library'"'!="") {
        datalib_root, root(`"`library'"') find set
        global datalib_checked `"${datalib}"'
    }
    else if !((`"`path'"'!="") & (`"`subfoldr'"'!="")) {
        if ("${datalib}"=="") capture getuserconfig
        if (`"${datalib}"'!=`"${datalib_checked}"') {
            datalib_root, find set
            global datalib_checked `"${datalib}"'
        }
    }

    if (`_dl_held') capture _return restore _dl_rhold

    quietly {

        * Interactive navigation starts if no country, year, or survey is specified
        if ("`country'" == "") & ("`year'" == "") & ("`survey'" == "") & ("`subfoldr'" == "") {
            noi _foldernav
        }
        else if ("`country'" != "") & (("`year'" == "") | ("`survey'" == "")) & ("`subfoldr'" == "") {
            noi _foldernav, country(`country')
            return add   
        }
        else if ("`subfoldr'" != "") {
            noi _foldernav, subfoldr("`subfoldr'") path("`path'")
            return add   
        }
        else if ("`country'" != "") & ("`year'" != "") & ("`survey'" != "")  & ("`subfoldr'" == "") {
            * Load and process data using the _dtlb_load program
            * -noisily-: datalib.ado wraps its dispatch in -quietly- (above),
            * and _dtlb_load wraps its body in another. The merge report is
            * written for the user, so it has to survive both -- otherwise the
            * cost of producing it is paid and none of the benefit reaches
            * anyone. Found by running the command and seeing nothing.
            noisily _dtlb_load                           ///
                ,                                  ///
                    country(`country')             ///
                    year(`year')                   ///
                    survey(`survey')               ///
                    module(`module')               ///
                    `nowarning'                    ///
                    filename("`filename'")         ///
                    `master'                       ///
                    `adaptation'                   ///
                    `latest'                       ///
                    collection(`collection')       ///
                    harmonization(`harmonization') ///
                    va(`va')                       ///
                    vm(`vm')                       ///
                    `debug'                        ///
                    `nomerge'                      ///
                    `wrk'                          ///
                    `clear'                        ///
                    `data'                         ///   
                    `doc'                          ///
                    `programs'

            return add   
        }
    }

end
