{smcl}
{hline}
{help datalib}{right:Version 1.6.0}
{cmd:help _mkdir}{right:Author: Joao Pedro Azevedo}
{right:Date: 2024-08-18}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :_mkdir}{hline 1} Datalib Directory Creation Utility.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:_mkdir}, {cmd:path(string)} {cmd:country(string)} [{cmd:year(string)} {cmd:survey(string)} {cmd:module(string)} {cmd:master} {cmd:adaptation} {cmd:collection(string)} {cmd:harmonization(string)} {cmd:va(string)} {cmd:vm(string)} {cmd:DEBUG} {cmd:MKDIR} {cmd:OVERWRITE} {cmd:CHECK} {cmd:latest}]{p_end}

{title:Description}
{pstd}{cmd:_mkdir} is a utility designed to create and organize directories for survey data within a specified path (datalib). It ensures that folders are structured according to predefined patterns and that the correct vintage numbers are assigned. The program handles both master and adaptation file types, and it now includes enhanced handling of the {cmd:year} option to ensure that the specified year is used during execution.{p_end}
{pstd}The utility checks for the existence of country and survey folders, creates them if necessary, and validates the presence of the specified year. It also verifies and increments vintage numbers appropriately.{p_end}

{title:Filename Patterns}
{p 6 16 2}
- {cmd:<country>_<year>_<survey>_<vintage>_m}
{p_end}
{p 6 16 2}
- {cmd:<country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>}
{p_end}

{title:Folder Structure Patterns}
{p 6 16 2}
- {cmd:datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<vintage>_m/}
{p_end}
{p 6 16 2}
- {cmd:datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>/}
{p_end}

{title:Options}
{synoptset 27 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt path(string)}}Specifies the directory path to create or check folders. This option is required.{p_end}
{synopt:{opt country(string)}}Specifies the country code for which folders will be created or checked. This option is required.{p_end}
{synopt:{opt year(string)}}Specifies the year for the survey folder. If not provided, the latest year available will be used.{p_end}
{synopt:{opt survey(string)}}Specifies the survey name. If not provided, the latest survey available will be used.{p_end}
{synopt:{opt module(string)}}Specifies the module(s) to be included. If not provided, all modules will be selected.{p_end}
{synopt:{opt master}}Checks or creates master files in the directory.{p_end}
{synopt:{opt adaptation}}Checks or creates adaptation files in the directory. Requires {cmd:collection} name.{p_end}
{synopt:{opt collection(string)}}Specifies the collection name when {cmd:adaptation} is selected.{p_end}
{synopt:{opt harmonization(string)}}Not currently supported.{p_end}
{synopt:{opt va(string)}}Specifies the adaptation vintage. Must be a two-digit value.{p_end}
{synopt:{opt vm(string)}}Specifies the master vintage. Must be a two-digit value.{p_end}
{synopt:{opt DEBUG}}Runs the program with verbose output for debugging.{p_end}
{synopt:{opt MKDIR}}Forces the creation of new folders if they do not exist.{p_end}
{synopt:{opt OVERWRITE}}Allows overwriting of existing folders.{p_end}
{synopt:{opt CHECK}}Checks existing folders without creating new ones.{p_end}
{synopt:{opt latest}}Uses the latest available survey year if {cmd:year} is not specified.{p_end}
{synoptline}


{title:Read-only libraries}

{pstd}This command refuses to write into a library whose {cmd:.datalib} marker file carries {cmd:readonly: 1}, and exits with error 198 naming the path. The check reads the marker, walking up from the target, rather than comparing path strings -- so it still holds for a copy of the tree, and cannot be defeated by 8.3 short names, junctions, UNC-versus-mapped spellings or case.{p_end}

{pstd}A library built by {helpb datalib_makelib} is marked synthetic ({cmd:demo: true}) but is {it:not} read-only: it is your copy, in your directory, and depositing into it is the point. Read-only is opt-in, for a shared fixture or reference tree you want protected.{p_end}

{title:Examples}
{p 6 16 2}Creates or checks the directory structure for the 1981 PNAD survey in Brazil.{p_end}
{p 8 12}{stata "_dtlb_mkdir , path(D:\datalib\) country(XAA) survey(XHS) year(1981)" :. _mkdir , path(D:\datalib\) country(XAA) survey(XHS) year(1981)}{p_end}

{p 6 16 2}Creates the directory structure for the 2001 PNAD survey in Brazil, including master and adaptation files.{p_end}
{p 8 12}{stata "cap: _mkdir , path(D:\datalib\) country(XAA) survey(XHS) year(2001) vm(01) va(01) adaptation" :. cap: _mkdir , path(D:\datalib\) country(XAA) survey(XHS) year(2001) vm(01) va(01) adaptation}{p_end}

{p 6 16 2}Creates the directory structure for the 2012 PNADC survey in Brazil with adaptation.{p_end}
{p 8 12}{stata "_dtlb_mkdir , path(D:\datalib\) country(XAA) survey(XHS) year(2012) adaptation" :. _mkdir , path(D:\datalib\) country(XAA) survey(XHS) year(2012) adaptation}{p_end}

{title:Saved Results}
{pstd}{cmd:_mkdir} saves the following in {cmd:r()}:{p_end}
{synoptset 20 tabbed}
{synopthdr:Results}
{synoptline}
{synopt:{cmd:r(path)}}The specified or created path{p_end}
{synopt:{cmd:r(root)}}The root directory created or checked{p_end}
{synopt:{cmd:r(mast)}}The master directory created or checked{p_end}
{synopt:{cmd:r(data_M)}}Path to the master data folder{p_end}
{synopt:{cmd:r(doc_M)}}Path to the master documentation folder{p_end}
{synopt:{cmd:r(data_M_original)}}Path to the original master data folder{p_end}
{synopt:{cmd:r(data_M_stata)}}Path to the Stata master data folder{p_end}
{synopt:{cmd:r(adapt)}}Path to the adaptation directory if applicable{p_end}
{synopt:{cmd:r(data_A)}}Path to the adaptation data folder{p_end}
{synopt:{cmd:r(data_A_original)}}Path to the original adaptation data folder{p_end}
{synopt:{cmd:r(data_A_stata)}}Path to the Stata adaptation data folder{p_end}
{synoptline}

{title:Authors}
{p 4 4 2}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{p 4 4 2}Minh Cong Nguyen, World Bank{p_end}

{title:Version}
{p 4 4 2}1.2.2{p_end}

{title:Date}
{p 4 4 2}2024-08-18{p_end}

{title:Also see}

{psee}
Supplementary functions: {helpb datalib} {helpb _dtlb_load} {helpb _dtlb_mkdir} {helpb _dtlb_ctrycheck} {helpb _dtlb_svycheck} {helpb _dtlb_vcheck} {helpb _dtlb_adaptcheck}
{p_end}