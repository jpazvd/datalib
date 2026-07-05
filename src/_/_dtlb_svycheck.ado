*******************************************************
** _dtlb_svycheck: Datalib Survey Check Utility
* Author: Joao Pedro Azevedo
*! Version: 1.7.1       Date: 2024-08-18       
** Description: 
* This program checks the surveys archived in the datalib 
* repository. It extracts unique survey names based on the 
* folder structure and filenames following a specified pattern.
*
** Filename patterns:
* MASTER FILE: - <country>_<year>_<survey>_<vintage>_m_<module>
* ADAPTATION FILE: - <country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>_<module>
*
** Folder structure patterns:
* - datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<vintage>_m/
* - datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>/
*******************************************************

capture program drop _dtlb_svycheck
program define _dtlb_svycheck, rclass

    version 15

    * Define syntax with required and optional parameters
    syntax , path(string) [country(string) survey(string) year(string) master adaptation]

    * Initialize variables
    local svylist
    local svylist_M
    local svylist_A
    local mastervintages
    local masteradaptvintages
    local adaptationvintages
    local multiplevintages 0
    local mastercheck 0
    local adaptationcheck 0
    local latestyear ""
    local latestsurvey ""
    local vintagetmp_m 0
    local vintagetmp_a 0

    * Extract folder names in the specified path
    cap: local list : dir "`path'/" dirs "*"

    * continue, if folder exists
    if (_rc==0) {

        foreach folder in `list' {
            * Extract survey name, year, and vintage
            local components = wordcount(subinstr("`folder'", "_", " ", .))
            local svytmp = word(subinstr("`folder'", "_", " ", .), 3)
            local yeartmp = word(subinstr("`folder'", "_", " ", .), 2)
            local vintagetmp_m = word(subinstr("`folder'", "_", " ", .), 4)  // For master
            local vintagetmp_a = word(subinstr("`folder'", "_", " ", .), 6)  // For adaptation
            local adapttmp_a = word(subinstr("`folder'", "_", " ", .), 8)    // For adaptation

            * Skip if the year or survey doesn't match the specified year/survey
            if ("`year'" != "" & "`yeartmp'" != "`year'") continue
            if ("`survey'" != "" & lower("`svytmp'") != lower("`survey'")) continue

            * Process master files, extract master vintage
            if (`components' == 5 & strpos("`folder'", "_m") > 0) {
                local svylist_M "`svylist_M' `svytmp'"
                local mastervintages "`mastervintages' `vintagetmp_m'"
                local mastercheck 1
                local masterfiles "`masterfiles' `folder'"
            }

            * Process adaptation files, extract both master and adaptation vintages
            if (`components' == 8 & strpos("`folder'", "_m_") > 0) {
                local svylist_M "`svylist_M' `svytmp'"
                local masteradaptvintages "`masteradaptvintages' `vintagetmp_m'"
                local masteradaptcheck 1
            }
            if (`components' == 8 & strpos("`folder'", "_a_") > 0)  {
                local svylist_A "`svylist_A' `svytmp'"
                local adaptationvintages "`adaptationvintages' `vintagetmp_a'"
                local adaptationcheck 1
                local adaptlist "`adaptlist' `adapttmp_a'"
            }
            if (`components' == 8 & strpos("`folder'", "_m_") > 0 & strpos("`folder'", "_a_") > 0)  {
                local vintagetmp_ma "`vintagetmp_m'`vintagetmp_a' "
                local mavintage "`mavintage' `vintagetmp_ma'"
                local masteradaptationfiles "`masteradaptationfiles' `folder'"
            }

            * Track the latest year and survey name within the context of the specified survey
            if ("`year'" == "" | "`yeartmp'" >= "`latestyear'") {
                local latestyear = "`yeartmp'"
                local latestsurvey = "`svytmp'"
            }

            * Add to general survey list if no specific filtering is applied
            if ("`master'" == "" & "`adaptation'" == "") {
                local svylist "`svylist' `svytmp'"
            }
        }

        * Filter out results that don't match the specified survey
        if ("`survey'" != "") {
            local svylist_unique "`survey'"
            local svylist_M = cond(strpos("`svylist_M'", "`survey'") > 0, "`survey'", "")
            local svylist_A = cond(strpos("`svylist_A'", "`survey'") > 0, "`survey'", "")
            local svynumb = 1
            local adptnumb = cond("`svylist_A'" != "", 1, 0)
        } 
        else {
            * Create unique lists and check for multiple vintages
            local svylist_unique
            foreach item in `svylist' {
                if strpos("`svylist_unique'", "`item'") == 0 {
                    local svylist_unique "`svylist_unique' `item'"
                }
            }
            local svynumb = wordcount("`svylist_unique'")

            * Create unique lists and check for multiple vintages
            local adaptation_unique
            foreach item in `adaptlist' {
                if strpos("`adaptation_unique'", "`item'") == 0 {
                    local adaptation_unique "`adaptation_unique' `item'"
                }
            }
            local adptnumb = wordcount("`adaptation_unique'")
        }

        * Check for master and adaptation vintages
        if wordcount("`mastervintages'") > 1 | wordcount("`adaptationvintages'") > 1 {
            local multiplevintages 1
        }
    }

    if (_rc) {
        di as error "No surveys found in the specified directory."
        local svynumb = 0
        local adptnumb = 0
    }

    * Return values
    return local svylist = upper(trim("`svylist_unique'"))
    return local adptlist = upper(trim("`adaptation_unique'"))
    return local svynumb = "`svynumb'"
    return local adptnumb = "`adptnumb'"
    return local multiplevintages = "`multiplevintages'"
    return local mastercheck = "`mastercheck'"
    return local masteradaptcheck = "`masteradaptcheck'"
    return local adaptationcheck = "`adaptationcheck'"
    return local mastervintages = trim("`mastervintages'")
    return local masteradaptvintages = trim("`masteradaptvintages'")
    return local adaptationvintages = trim("`adaptationvintages'")
    return local latestyear = "`latestyear'"
    return local latestsurvey = "`latestsurvey'"
    return local masterfiles = upper(trim("`masterfiles'"))
    return local masteradaptfiles = upper(trim("`masteradaptationfiles'"))
    return local mavintage = upper(trim("`mavintage'"))
    return local masterlatestfile = word(upper(trim("`masterfiles'")),-1)
    return local masteradaptlatestfile = word(upper(trim("`masteradaptationfiles'")),-1)

end 

/*******************************************************
 Usage Examples:

 * Lists all unique surveys found in the datalib directory.
 _dtlb_svycheck , path("D:\datalib\")
 return list

 * Lists all unique surveys found in the datalib/BRA directory.
 _dtlb_svycheck , path("D:\datalib\BRA\")
 return list

 * Lists all unique surveys found in the datalib/KEN directory.
 _dtlb_svycheck , path("D:\datalib\KEN\")
 return list

 * Lists all unique surveys found in the datalib/MDG directory.
 _dtlb_svycheck , path("D:\datalib\MDG\")
 return list

 * Lists all unique surveys found in the datalib/BRA/BRA_2012_PNADC directory.
 _dtlb_svycheck , path("D:\datalib\BRA\BRA_2012_PNADC\")
 return list

 * Checks the surveys available for a specific survey name in the BRA directory.
 _dtlb_svycheck , path("D:\datalib\BRA\") country(BRA) survey(PNADC)
 return list

 * Lists all surveys found in the datalib/BRA/BRA_1981_PNAD directory.
 _dtlb_svycheck , path("D:\datalib\BRA\bra_1981_pnad\")
 return list

 * Lists all surveys found in the datalib/BRA/BRA_2001_PNAD directory.
 _dtlb_svycheck , path("D:\datalib\BRA\bra_2001_pnad\")
 return list

 * Lists all surveys found in the datalib/BRA/BRA_2001_PNAD directory.
 _dtlb_svycheck , path("D:\datalib\BRA\bra_2001_pnad\") year(2001)
 return list
 
 * Lists all surveys found in the datalib/BRA/BRA_2001_PNAD directory.
 _dtlb_svycheck , path("D:\datalib\BRA\bra_2001_pnad\") year(2000)
 return list

* Version History:
* v1.7.1 - 2024-08-18: Improved code readability and structure.
* v1.6.1 - 2024-08-18: Added extraction and counting of adaptation names, improved handling of master and adaptation vintages, and refined return values.
* v1.5.1 - 2024-08-17: Ensured proper functioning of master and adaptation vintage checks, with appropriate return values.
* v1.5.0 - 2024-08-17: Added flags for vintage, master, and adaptation presence, with appropriate return values.
* v1.4.1 - 2024-08-16: Ensured proper functioning of master and adaptation checks; corrected multiple vintage handling.
* v1.4.0 - 2024-08-15: Added support for checking survey availability by year; returned latest survey name and year.
* v1.3.0 - 2024-08-14: Added options for checking master and adaptation files; updated return values.
* v1.2.1 - 2024-08-13: Minor bug fixes; improved directory structure handling and folder naming compatibility.
* v1.2.0 - 2024-08-12: Added year filter; checked for multiple vintages.
* v1.1.0 - 2024-08-11: Added filtering by country and survey type.
* v1.0.0 - 2024-08-10: Initial release with basic survey checking functionality.

*******************************************************
