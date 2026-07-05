*******************************************************
* _dtlb_load: Data Loading and Processing Utility (formerly _dlw)
* Author: Joao Pedro Azevedo
*! Version: 1.01       Date: <2024-08-18>       
* Description: 
* This program is designed to facilitate the loading, processing, and 
* merging of survey data modules across different countries and years. 
* The utility provides options to select specific surveys, modules, 
* and collections, with default settings for common use cases.
*******************************************************

capture program drop _dtlb_load
program define _dtlb_load, rclass

    version 15

    syntax  [varlist]                      ///
            [in] [if]                      ///
            [,                             ///
                country(string)            ///
                year(string)               ///
                survey(string)             ///
                MODule(string)             ///
                filename(string)           ///
                MASter			           ///
                adaptation                 ///
                LATest                     ///
                collection(string)         ///
                harmonization(string)      ///
                va(string)                 ///
                vm(string)                 ///
                DEBUG                      ///
                data                       ///   
                doc                        ///
                programs                   ///
                NOMerge                    ///
                clear                      ///
            ]

    quietly {

        /** 
        * Flow Control 
        */

        * Master file selection (not yet supported)
        if ("`master'" != "") {
            di as err "Option master not currently supported."
            exit 198
        }

        * Check if country is specified
        if ("`country'" == "") {
            di as err "Country needs to be specified."
            exit 198
        }

        * Set year to latest if not specified
        if ("`year'" == "") {
            di in y "Year not specified. Latest available survey will be used."
            local latest latest
        }

        * Ensure the datalib path is set
        if ("${datalib}" == "") {
            di as err "Path to datalib needs to be specified. Global datalib needs to be defined."
            exit 198
        }

        * Set default collection to 'HLT' if not specified
        if ("`collection'" != "") & ("`adaptation'" == "") {
            local adaptation "adaptation"
        }
        
        * Set default collection to 'HLT' if not specified
        if ("`collection'" == "") & ("`adaptation'" != "") {
            local collection "HLT"
        }
        local clct "`collection'"

        * Supported modules and sort keys by collection
        if ("`clct'"=="HLT") {
            local allmodule "household hhmembers adult children "
            local sort_household_hhmembers "svy_id household_id"
            local sort_adult_children "svy_id household_id line_number"
        }
        * Brazilian PNAD
        if ("`clct'"=="DTZ") & ("`survey'"=="PNAD") {
            local allmodule "household hhmembers adult children "
            local sort_household_hhmembers "svy_id household_id"
            local sort_adult_children "svy_id household_id line_number"
        }
        
        * Brazilian PNADC
        if ("`clct'"=="DTZ") & ("`survey'"=="PNADC") {
            local allmodule "household hhmembers adult children "
            local sort_household_hhmembers "svy_id household_id"
            local sort_adult_children "svy_id household_id line_number"
        }
        * Select all modules if none specified
        if ("`module'"=="") {
            local module "`allmodule'"
        }

        * Count the number of modules selected
        local cntmod = wordcount("`module'")

        * Enable noisy output for debugging if requested
        if ("`debug'"!="") {
            local noi noisily
        }

        ******************************************
        * Folder Navigation and Data Selection
        ******************************************

        * List available country folders in datalib
        local list : dir "${datalib}/" dirs "*"
        `noi' di `"`list'"'

        * List available survey folders for the selected country
        local list : dir "${datalib}/" dirs "`country'"
        `noi' di "ctry: `"`list'"'"

        * Verify if the selected country exists
        cap: local ctrycheck = match(upper(`list'),"*`country'*")
        if _rc!=0 {
            local ctrycheck = 0
        }

        * If country is valid, list survey folders
        if (`ctrycheck'==1) {

            local list : dir "${datalib}/`country'" dirs "*`survey'*"
            `noi' di "Survey folders: `"`list'"'"

            * Handle cases where the survey is not specified or not available
            if ("`survey'"!="" & `"`list'"'==`""') {
                di as err "`survey' for `country' not available. Please select an eligible survey."
                exit 198
            }

            * Default to the latest available survey if not specified
            if ("`survey'"=="") {
                local list = word(`"`list'"',-1)
                local survey = word(subinstr(`list',"_"," ",.),3)
            }

            * Extract the latest year if not specified
            if ("`year'"=="") {
                foreach folders in `list' {
                    local yr = word(subinstr("`folders'","_"," ",.),2)
                    local year "`year' `yr'"
                }

                `noi' di "`year'"

                if ("`latest'" == "latest") {
                    local year = word("`year'",-1)
                }
            }

            * Construct the file name
            local ctry "`country'"
            local svy "`survey'"
            if ("`adaptation'"!="") {
                local file "`ctry'_`year'_`svy'_`vm'_M_`va'_A_`clct'"
            }
            if ("`adaptation'"=="") {
                local file "`ctry'_`year'_`svy'_`vm'_M"
            }
        }

        * Check if the file exists and load the data
        * If the file does not exist, return an error message
        * If the file exists, load the data and list the variables
        * Prepare the data for merging if more than one module is selected
        * Recode specific variables as needed
        if ("`file'"!="") & ("`filename'"=="") {

            di "`year'"
            
            local i = 0
            foreach type in `module' {

                local i = `i'+1
                
                * Load the data    the specified module if ADAPATATION
                if ("`adaptation'"!="") {
                    local tousedta`i' "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M_`va'_A_`clct'/Data/Stata/`file'_`type'.dta"
                    use "`tousedta`i''", `clear'
                    `noi' di "`type`i''"
                    `noi' ds, varwidth(30) alpha
                    `noi' di ""
                }
                if ("`adaptation'"=="") {
                    local tousedta`i' "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M/Data/Stata/`file'_`type'.dta"
                    use "`tousedta`i''", `clear'
                }

                * Sort and prepare data for merging
                if match("sort_household_hhmembers","*`type'*")==1 {
                    sort `sort_household_hhmembers'
                    gen ctrycode = "`ctry'"
                    gen year = `year'
                    order ctrycode year source `sort_household_hhmembers'
                    local merge "`sort_household_hhmembers'"
                    noi di "Sort: `sort_household_hhmembers' (module `type')"
                }

                if match("sort_adult_children","*`type'*")==1 {
                    sort `sort_adult_children'
                    gen ctrycode = "`ctry'"
                    gen year = `year'
                    order ctrycode year source `sort_adult_children'
                    local merge "`sort_adult_children'"
                    noi di "Sort: `sort_adult_children' (module: `type')"
                }

                local merge`i' ""

                tempfile tmp`i'
                save `tmp`i'', replace

                return local filename`i' = "`file'_`type'.dta"
            }
        } 
        if ("`file'"!="") & ("`filename'"!="") {

            di "`year'"
            
            local i = 0
            foreach flname in `"`filename'"'{

                local i = `i'+1
                
                * Load the data for the specified modules
                if ("`data'"=="data") { 
                    if ("`adaptation'"!="") {
                        local tousedta`i' "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M_`va'_A_`clct'/Data/Stata/`flname'"
                        use "`tousedta`i''", `clear'
                        `noi' di "`type'"
                        `noi' ds, varwidth(30) alpha
                        `noi' di ""
                    }
                    if ("`adaptation'"=="") {
                        local tousedta`i' "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M/Data/Stata/`flname'"
                        use "`tousedta`i''", `clear'
                    }
                    return local data`i' "`tousedta`i''"
                }
                * View the documents from specific surveys
                if ("`doc'"=="doc") { 
                    if ("`adaptation'"!="") {
                        local tousedoc`i'  "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M_`va'_A_`clct'/Doc/`flname'"
                        view browse      "`tousedoc`i''"
                        `noi' di "`type'"
                        `noi' ds, varwidth(30) alpha
                        `noi' di ""
                    }
                    if ("`adaptation'"=="") {
                        local tousedoc`i'  "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M/Doc/`flname'"
                        view browse "`tousedoc`i''"
                    }
                    return local doc`i' "`tousedoc`i''"
                }
                * View the files in the program folder
                if ("`programs'"=="programs") { 
                    if ("`adaptation'"!="") {
                        local touseprog`i' "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M_`va'_A_`clct'/Programs/`flname'"
                        view browse "`touseprog`i''"
                        `noi' di "`type'"
                        `noi' ds, varwidth(30) alpha
                        `noi' di ""
                    }
                    if ("`adaptation'"=="") {
                        local touseprog`i' "${datalib}/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_`vm'_M/Programs/`flname'"
                        view browse "`touseprog`i''"
                    }
                    return local programs`i' "`touseprog`i''"
                }

                * Sort and prepare data for merging
                if match("sort_household_hhmembers","*`type'*")==1 & ("`clct'"=="HLT") {
                    sort `sort_household_hhmembers'
                    cap: gen ctrycode = "`ctry'"
                    cap: gen year = `year'
                    order ctrycode year source `sort_household_hhmembers'
                    local merge "`sort_household_hhmembers'"
                    noi di "Sort: `sort_household_hhmembers' (module `type')"
                }

                if match("sort_adult_children","*`type'*")==1 & ("`clct'"=="HLT")  {
                    sort `sort_adult_children'
                    cap: gen ctrycode = "`ctry'"
                    cap: gen year = `year'
                    order ctrycode year source `sort_adult_children'
                    local merge "`sort_adult_children'"
                    noi di "Sort: `sort_adult_children' (module: `type')"
                }

                local merge`i' ""

                tempfile tmp`i'
                save `tmp`i'', replace

                return local filename`i' = "`flname'"
            }


        }
        if ("`file'"=="") & ("`filename'"=="") {
            noi di as err "No data for `country' available. Please check your selection and resubmit."
            exit 198
        }


        * Merge selected modules if more than one module is chosen
        if (`cntmod'>1 & "`nomerge'"=="") {
            use `tmp1', clear
            forvalues merge = 2(1)`i' {
                local k = `merge'-1
                merge `merge`k'' using `tmp`merge''
                `noi' tab _merge
                drop _merge                    
            }
        }

        * Recode specific variables as needed
        cap: recode windex5 8=.

        * Return the harmonization file name
        return local harmonization = "`file'"
        return add
    }

end

*******************************************************
* _foldernav: Folder Navigation Utility
* Author: Joao Pedro Azevedo
*! Version: 1.0       Date: <2024-03-21>       
* Description: 
* This program is designed to navigate through folder structures 
* in the datalib repository, enabling the selection of subfolders 
* based on the structure of the data collection.
*******************************************************

capture program drop _foldernav 
program define _foldernav, rclass

    version 15

    syntax  [varlist]                     ///
            [in] [if]                     ///
            [,                            ///
                country(string)           ///
                path(string)              ///
                subfoldr(string)          ///
                filename(string)          ///
            ]            

    * Determine subfolder depth and structure
    local stubcnt = wordcount(subinstr("`subfoldr'", "_", " ",.))

    if (`stubcnt'==1) {
        local subfoldr = "`subfoldr'"
    }
    if (`stubcnt'==3) {
        local stub1  = word(subinstr("`subfoldr'", "_", " ",.),1)
        local subfoldr = "`stub1'/`subfoldr'"
    }
    if (`stubcnt'==5) {
        local stub1  = word(subinstr("`subfoldr'", "_", " ",.),1)
        local stub2  = word(subinstr("`subfoldr'", "_", " ",.),2)
        local stub3  = word(subinstr("`subfoldr'", "_", " ",.),3)
        local subfoldr = "`stub1'/`stub1'_`stub2'_`stub3'/`subfoldr'"       
    }
    if (`stubcnt'==8) {
        local subfoldr = "`subfoldr'"
        local stub1  = word(subinstr("`subfoldr'", "_", " ",.),1)
        local stub2  = word(subinstr("`subfoldr'", "_", " ",.),2)
        local stub3  = word(subinstr("`subfoldr'", "_", " ",.),3)
        local subfoldr = "`stub1'/`stub1'_`stub2'_`stub3'/`subfoldr'"      
    }

    * Set the path based on the provided or default value
    if ("`path'"=="") & ("`subfoldr'" == "") {
        local path "${datalib}/"
    } 
    else if ("`path'"=="") & ("`subfoldr'" != "") {
        local path "${datalib}/`subfoldr'/"
    }
    else if ("`path'"!="") & ("`subfoldr'" != "") {
        local path "`path'/`subfoldr'/"
    }

    * Handle navigation for DATA subfolder
    if ("`subfoldr'"=="DATA") {
        local subfoldr = r(subfoldr)
        local path "${datalib}/`subfoldr'/Data/Stata/"
        local list : dir "`path'" files "*.dta" 

        local laststub = word(subinstr("`subfoldr'","/"," ",.),-1)
        local ctry  = word(subinstr("`laststub'","_"," ",.),1)
        local year  = word(subinstr("`laststub'","_"," ",.),2)
        local svy   = word(subinstr("`laststub'","_"," ",.),3)
        local vm    = word(subinstr("`laststub'","_"," ",.),4)
        local va    = word(subinstr("`laststub'","_"," ",.),6)
        local clct  = word(subinstr("`laststub'","_"," ",.),8)

        noi di in smcl _newline
        noi di in g in smcl "{hline}"
        foreach files in `list' {
            local module = subinstr(word(subinstr("`files'","_"," ",.),-1),".dta","",.)
            noi di in g in smcl `" {stata `"datalib, country(`ctry') year(`year') survey(`svy') vm(`vm') va(`va') collection(`clct') filename(`"`files'"') nomerge clear data "': {bf: `files'}} "'
        }

        noi di in g in smcl "{hline}"
        return add
        return local fullfoldr = "`subfoldr'/Data/Stata/"
    }
    * Handle navigation for DOC subfolder
    if ("`subfoldr'"=="DOC") {
        local subfoldr = r(subfoldr)
        local path "${datalib}/`subfoldr'/Doc/"
        local list : dir "`path'" files "*" 

        local laststub = word(subinstr("`subfoldr'","/"," ",.),-1)
        local ctry  = word(subinstr("`laststub'","_"," ",.),1)
        local year  = word(subinstr("`laststub'","_"," ",.),2)
        local svy   = word(subinstr("`laststub'","_"," ",.),3)
        local vm    = word(subinstr("`laststub'","_"," ",.),4)
        local va    = word(subinstr("`laststub'","_"," ",.),6)
        local clct  = word(subinstr("`laststub'","_"," ",.),8)

        noi di in smcl _newline
        noi di in g in smcl "{hline}"
        foreach files in `list' {
            local module = subinstr(word(subinstr("`files'","_"," ",.),-1),".dta","",.)
            noi di in g in smcl `" {stata `"datalib, country(`ctry') year(`year') survey(`svy') vm(`vm') va(`va') collection(`clct') filename(`"`files'"') nomerge clear doc "': {bf: `files'}} "'
        }
        
        noi di in g in smcl "{hline}"
        return add
        return local fullfoldr = "`subfoldr'/Doc/"
    }
    * Handle navigation for PROGRAMS subfolder
    if ("`subfoldr'"=="PROGRAMS") {
        local subfoldr = r(subfoldr)
        local path "${datalib}/`subfoldr'/Programs/"
        local list : dir "`path'" files "*" 

        local laststub = word(subinstr("`subfoldr'","/"," ",.),-1)
        local ctry  = word(subinstr("`laststub'","_"," ",.),1)
        local year  = word(subinstr("`laststub'","_"," ",.),2)
        local svy   = word(subinstr("`laststub'","_"," ",.),3)
        local vm    = word(subinstr("`laststub'","_"," ",.),4)
        local va    = word(subinstr("`laststub'","_"," ",.),6)
        local clct  = word(subinstr("`laststub'","_"," ",.),8)

        noi di in smcl _newline
        noi di in g in smcl "{hline}"
        foreach files in `list' {
            local module = subinstr(word(subinstr("`files'","_"," ",.),-1),".dta","",.)
            noi di in g in smcl `" {stata `"datalib, country(`ctry') year(`year') survey(`svy') vm(`vm') va(`va') collection(`clct') filename(`"`files'"') nomerge clear programs "': {bf: `files'}} "'
        }
        
        noi di in g in smcl "{hline}"
        return add
        return local fullfoldr = "`subfoldr'/Programs/"
    }

    
    * Navigate through folders and list available options
    if (`stubcnt'<=8) & ("`subfoldr'"!="DATA") {
    
        * List available folders in the specified path
        if ("`country'"=="") {
            local list : dir "`path'" dirs "*" 
        }
        else {
            local list `"`country'"'
        }

        noi di in smcl _newline
        noi di in g in smcl "{hline}"
        foreach folders in `list' {
            local folders = upper("`folders'")
*            noi di in g in smcl `" {stata `"_foldernav, path(${datalib}) subfoldr(`folders')"': {bf: `folders'}} "'
            noi di in g in smcl `" {stata `"datalib, subfoldr(`folders')"': {bf: `folders'}} "'
        }
        noi di in g in smcl "{hline}"

        * Return the selected subfolder
        return add
        return local subfoldr`stubcnt' = "`subfoldr'"
        return local subfoldr = "`subfoldr'"
    }

end

/*******************************************************
Version History

v1.01 (2024-08-18)
Enhancements:
Improved handling of the year and survey options to ensure the correct survey year is selected when not specified, defaulting to the latest available survey.
Added more robust logic for loading and merging data modules, ensuring appropriate sorting and variable management across multiple modules.
Enhanced the debugging functionality to provide clearer, noisier output when the DEBUG option is specified.
Implemented better error handling for missing or incorrect country, survey, and year inputs.
Improved folder navigation and file verification to handle more complex folder structures and subfolder depth.

v1.00 (2024-03-21)
Initial Release:
Developed the core utility for loading and processing survey data across different countries and years.
Introduced options to select specific surveys, modules, and collections.
Implemented basic error handling and default settings for common use cases.
Supported integration with master and adaptation file types, though master file handling was not fully implemented.
Included initial support for various modules and sorting mechanisms based on the selected collection.