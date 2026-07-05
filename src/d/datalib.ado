*******************************************************
** datalib 
* Joao Pedro Azevedo
*! v0.1
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
                clear                    ///
                path(string)         ///
            ]

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
            _dtlb_load                                   ///
                ,                                  ///
                    country(`country')             ///
                    year(`year')                   ///
                    survey(`survey')               ///
                    module(`module')               ///
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
                    `clear'                        ///
                    `data'                         ///   
                    `doc'                          ///
                    `programs'

            return add   
        }
    }

end
