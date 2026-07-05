{smcl}
{hline}
{cmd:help datalib}{right:Version 0.1}
{right:Author: Joao Pedro Azevedo}
{right:Date: 2024-08-18}
{hline}

{title:Title}
{p2colset 5 27 32 2}{...}
{p2col :datalib}{hline 1} Data Loading and Processing Utility.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 19 2}{cmd:datalib} [{cmd:country(string)} {cmd:year(string)} {cmd:survey(string)} {cmd:module(string)} {cmd:filename(string)}] [{cmd:options}]{p_end}

{title:Description}
{pstd}{cmd:datalib} is a comprehensive utility designed to facilitate the loading, processing, and merging of survey data modules across different countries and years. It provides a user-friendly interface for navigating the data repository, selecting specific surveys, and performing data operations. When certain parameters like country, year, or survey are not specified, {cmd:datalib} launches an interactive navigation mode to help users browse available options.{p_end}
{pstd}The program leverages several subroutines to handle different tasks:{p_end}
{pstd}- {cmd:_foldernav} handles interactive folder navigation.{p_end}
{pstd}- {cmd:_dlw} loads, processes, and merges survey data modules based on the selected parameters.{p_end}
{pstd}- {cmd:_mkdir} creates directory structures and manages data folders based on specified parameters.{p_end}

{title:Options}
{synoptset 27 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt country(string)}}Specifies the country code to filter the data search. If not specified, interactive navigation starts.{p_end}
{synopt:{opt year(string)}}Specifies the year of the survey data. If not specified, interactive navigation starts, or the latest available year is selected.{p_end}
{synopt:{opt survey(string)}}Specifies the survey name to filter the data search. If not specified, interactive navigation starts, or the latest available survey is selected.{p_end}
{synopt:{opt module(string)}}Specifies the module(s) to be loaded. If not specified, all available modules are loaded.{p_end}
{synopt:{opt filename(string)}}Specifies the filename of the data to be loaded. Useful when targeting specific files within the data repository.{p_end}
{synopt:{opt master}}Indicates that the program should check for master files. Currently not supported.{p_end}
{synopt:{opt adaptation}}Indicates that the program should check for adaptation files.{p_end}
{synopt:{opt latest}}Indicates that the program should automatically select the latest available survey year.{p_end}
{synopt:{opt collection(string)}}Specifies the collection name for organizing data. Defaults to 'HLT' if not specified.{p_end}
{synopt:{opt harmonization(string)}}Specifies the harmonization file name if applicable.{p_end}
{synopt:{opt vm(string)}}Specifies the vintage number for master files.{p_end}
{synopt:{opt va(string)}}Specifies the vintage number for adaptation files.{p_end}
{synopt:{opt debug}}Enables detailed, noisier output for debugging purposes.{p_end}
{synopt:{opt data}}Loads the data files based on the specified options.{p_end}
{synopt:{opt doc}}Opens documentation files associated with the selected survey.{p_end}
{synopt:{opt programs}}Opens program files associated with the selected survey.{p_end}
{synopt:{opt nomerge}}Prevents automatic merging of modules if multiple modules are selected.{p_end}
{synopt:{opt clear}}Clears the current dataset before loading new data.{p_end}
{synoptline}

{title:Subroutines}

{pstd}{cmd:datalib} relies on the following subroutines for its operation:{p_end}

{pstd}{cmd:_foldernav}: This utility assists with navigating through the folder structure of the data repository. It allows users to interactively browse available countries, years, surveys, and other subdirectories.{p_end}

{pstd}{help _dlw}: This program handles the loading, processing, and merging of survey data modules. It processes the selected survey data based on the options provided by the user, ensuring appropriate sorting, variable management, and file handling.{p_end}

{pstd}{help _mkdir}: This utility is used to create directory structures and manage data folders based on specified parameters such as country, year, survey, and more. It ensures the appropriate organization of data files within the repository.{p_end}


{title:Subroutines used by {cmd:_mkdir}}

{pstd}{help _ctrycheck}: This subroutine verifies whether the specified country exists in the datalib directory. If the country folder is not found, it prompts the user to create a new collection or select an existing one, depending on the options specified.{p_end}

{pstd}{help _svycheck}: This subroutine checks for the availability of surveys in the specified directory. It extracts unique survey names based on the folder structure and filename patterns. It can filter results based on master and adaptation file types and returns flags indicating the presence of multiple vintages, master and adaptation files, and the latest survey year available.{p_end}

{pstd}{help _vcheck}: This subroutine verifies the vintage numbers for both master and adaptation files. It checks if the specified vintage numbers exist and if the new vintage numbers are eligible for creation. It ensures that vintage numbers increase incrementally and correctly reflect the most recent versions available.{p_end}

{pstd}{help _adaptcheck}: This subroutine checks for the availability of adaptation files in the specified directory. It verifies the presence of adaptation vintages and ensures that the selected adaptation matches the existing files or allows for the creation of a new adaptation version.{p_end}

{title:Return Macros}
{pstd}{cmd:datalib} and its subroutines return the following macros in {cmd:r()}:{p_end}

{pstd}{cmd:_dlw}:{p_end}
{pstd}{cmd:r(data#)}: Full path to the loaded data files based on the specified options (e.g., {cmd:r(data1)}, {cmd:r(data2)}).{p_end}
{pstd}{cmd:r(doc#)}: Full path to the documentation files associated with the selected survey (e.g., {cmd:r(doc1)}, {cmd:r(doc2)}).{p_end}
{pstd}{cmd:r(programs#)}: Full path to the program files associated with the selected survey (e.g., {cmd:r(programs1)}, {cmd:r(programs2)}).{p_end}
{pstd}{cmd:r(harmonization)}: The harmonization file name if applicable.{p_end}

{pstd}{cmd:_mkdir}:{p_end}
{pstd}{cmd:r(path)}: The root path where the country, survey, and year folders are created.{p_end}
{pstd}{cmd:r(root)}: The root folder name for the country, year, and survey data.{p_end}
{pstd}{cmd:r(mast)}: The folder name for the master collection data.{p_end}
{pstd}{cmd:r(data_M)}: Path to the data files for the master collection.{p_end}
{pstd}{cmd:r(doc_M)}: Path to the documentation files for the master collection.{p_end}
{pstd}{cmd:r(data_M_original)}: Path to the original data files for the master collection.{p_end}
{pstd}{cmd:r(data_M_stata)}: Path to the Stata-formatted data files for the master collection.{p_end}
{pstd}{cmd:r(adapt)}: The folder name for the adaptation collection data.{p_end}
{pstd}{cmd:r(data_A)}: Path to the data files for the adaptation collection.{p_end}
{pstd}{cmd:r(data_A_original)}: Path to the original data files for the adaptation collection.{p_end}
{pstd}{cmd:r(data_A_stata)}: Path to the Stata-formatted data files for the adaptation collection.{p_end}

{pstd}{cmd:_ctrycheck}:{p_end}
{pstd}{cmd:r(ctrylist)}: List of countries found in the directory.{p_end}
{pstd}{cmd:r(ctrycheck)}: Flag indicating if the specified country exists in the directory.{p_end}

{pstd}{cmd:_svycheck}:{p_end}
{pstd}{cmd:r(svylist)}: List of unique survey names found in the directory.{p_end}
{pstd}{cmd:r(svynumb)}: Number of unique surveys found.{p_end}
{pstd}{cmd:r(svylist_M)}: List of unique master survey names if {cmd:master} is specified.{p_end}
{pstd}{cmd:r(svynumb_M)}: Number of unique master surveys found if {cmd:master} is specified.{p_end}
{pstd}{cmd:r(svylist_A)}: List of unique adaptation survey names if {cmd:adaptation} is specified.{p_end}
{pstd}{cmd:r(svynumb_A)}: Number of unique adaptation surveys found if {cmd:adaptation} is specified.{p_end}
{pstd}{cmd:r(mastervintages)}: List of master vintages found.{p_end}
{pstd}{cmd:r(adaptationvintages)}: List of adaptation vintages found.{p_end}
{pstd}{cmd:r(latestyear)}: The latest survey year found.{p_end}
{pstd}{cmd:r(latestsurvey)}: The latest survey name found.{p_end}
{pstd}{cmd:r(multiplevintages)}: Flag indicating if multiple vintages are found.{p_end}
{pstd}{cmd:r(mastercheck)}: Flag indicating if master files are found.{p_end}
{pstd}{cmd:r(adaptationcheck)}: Flag indicating if adaptation files are found.{p_end}

{pstd}{cmd:_vcheck}:{p_end}
{pstd}{cmd:r(Mcheck)}: Flag indicating if the master files exist for the specified vintage.{p_end}
{pstd}{cmd:r(Acheck)}: Flag indicating if the adaptation files exist for the specified vintage.{p_end}
{pstd}{cmd:r(Mlatestvintage)}: The latest master vintage number found.{p_end}
{pstd}{cmd:r(Alatestvintage)}: The latest adaptation vintage number found.{p_end}
{pstd}{cmd:r(MAlatestvintage)}: The latest combined master and adaptation vintage number found.{p_end}

{pstd}{cmd:_adaptcheck}:{p_end}
{pstd}{cmd:r(adaptations)}: List of available adaptation collections in the directory.{p_end}
{pstd}{cmd:r(adptcount)}: Number of adaptation collections found.{p_end}

{title:Examples}
{p 6 16 2}Starts interactive navigation to explore the data repository.{p_end}
{p 8 12}{stata "datalib" :. datalib}{p_end}

{p 6 16 2}Loads the latest available survey data for Brazil.{p_end}
{p 8 12}{stata "datalib , country(BRA)" :. datalib , country(BRA)}{p_end}

{p 6 16 2}Loads the 2019 MICS survey data for Bangladesh and opens the associated documentation.{p_end}
{p 8 12}{stata "datalib , country(BGD) year(2019) survey(MICS) doc" :. datalib , country(BGD) year(2019) survey(MICS) doc}{p_end}

{p 6 16 2}Loads and merges all available modules from the 2001 PNAD survey in Brazil.{p_end}
{p 8 12}{stata "datalib , country(BRA) year(2001) survey(PNAD) nomerge" :. datalib , country(BRA) year(2001) survey(PNAD) nomerge}{p_end}

{title:Saved Results}
{pstd}{cmd:datalib} does not save any specific results in {cmd:r()} by default. However, subroutines like {cmd:_dlw} may save results related to the loaded and processed data.{p_end}

{title:Author}
{p 4 4 2}Joao Pedro Azevedo (jpazevedo@unicef.org){p_end}

{title:Version}
{p 4 4 2}0.1{p_end}

{title:Date}
{p 4 4 2}2024-08-18{p_end}

{title:Also see}

{psee}
Suplementary functions: {helpb datalib} {helpb _dlw} {helpb _mkdir} {helpb _ctrycheck} {helpb _svycheck} {helpb _vcheck} {helpb _adaptcheck}
{p_end}


