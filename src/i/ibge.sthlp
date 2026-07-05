{smcl}
{hline}
{help ibge}{right:Version 1.0}
{right:Author: Joao Pedro Azevedo}
{right:Date: 2024-08-18}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :ibge}{hline 2}Data Loading and Processing Utility for IBGE Data.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:ibge} [{cmd:varlist}] [{cmd:in}] [{cmd:if}] {cmd:,} {cmd:survey(string)} {cmd:country(string)} {cmd:year(string)} [{cmd:options}]{p_end}

{title:Description}
{pstd}{cmd:ibge} is a wrapper for the DataZoom program designed to facilitate the loading, processing, and renaming of IBGE (Instituto Brasileiro de Geografia e Estatística) data files. It supports data from the PNAD and PNADC surveys and automates several tasks including data file naming and organization based on the Datalib folder structure convention. When a {cmd:saving} path is not specified, the program defaults to the Datalib folder structure.{p_end}

{pstd}This program integrates several utilities, including {cmd:_mkdir} for directory management and DataZoom commands for data processing, providing a streamlined workflow for handling IBGE data files.{p_end}

{title:Options}
{synoptset 27 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt survey(string)}}Specifies the survey to be processed. Supported surveys are PNAD and PNADC.{p_end}
{synopt:{opt country(string)}}Specifies the country code (e.g., BRA for Brazil).{p_end}
{synopt:{opt year(string)}}Specifies the survey year(s) to be processed.{p_end}
{synopt:{opt original(string)}}Specifies the path to the original data files for processing.{p_end}
{synopt:{opt saving(string)}}Specifies the path where the processed files will be saved. If not specified, the Datalib folder structure is used.{p_end}
{synopt:{opt english}}Processes the data in English, if available. {p_end}
{synopt:{opt ncomp}}Applies non-comparable definitions from DataZoom for PNAD.{p_end}
{synopt:{opt comp81}}Applies definitions comparable to the 1981 PNAD survey.{p_end}
{synopt:{opt comp92}}Applies definitions comparable to the 1992 PNAD survey.{p_end}
{synopt:{opt idbas}}Includes identification of basic geographical units for PNADC.{p_end}
{synopt:{opt nid}}Includes the National Identification Data (NID) for PNADC.{p_end}
{synopt:{opt idrs}}Includes the Regional Sample Identification for PNADC.{p_end}
{synopt:{opt path(string)}}Specifies the base path for data processing.{p_end}
{synopt:{opt subfoldr(string)}}Specifies the subfolder to be processed within the base path.{p_end}
{synopt:{opt filename(string)}}Specifies the filename of the processed data to be saved.{p_end}
{synopt:{opt norename}}Prevents automatic renaming of data files to match the Datalib naming convention.{p_end}
{synopt:{opt noclean}}Prevents the automatic cleaning and deletion of temporary files and subfolders.{p_end}
{synopt:{opt overwrite}}Overwrites existing files in the destination folder without prompting.{p_end}
{synopt:{opt module(string)}}Specifies the module(s) to be processed. If not specified, all available modules are processed.{p_end}
{synopt:{opt master}}Indicates that the program should check for master files (currently not supported).{p_end}
{synopt:{opt adaptation}}Indicates that the program should check for adaptation files.{p_end}
{synopt:{opt collection(string)}}Specifies the collection name for organizing data. Defaults to 'HLT' if not specified.{p_end}
{synopt:{opt harmonization(string)}}Specifies the harmonization file name, if applicable.{p_end}
{synopt:{opt va(string)}}Specifies the vintage number for adaptation files.{p_end}
{synopt:{opt vm(string)}}Specifies the vintage number for master files.{p_end}
{synopt:{opt mkdir}}Creates the necessary directory structure based on the specified parameters.{p_end}
{synoptline}

{title:Examples}
{p 6 16 2}Processes the 2012 PNAD data for Brazil and saves the files using the Datalib folder convention:{p_end}
{p 8 12}{stata "ibge , survey(PNAD) country(BRA) year(2012)"}{p_end}

{p 6 16 2}Processes the 2019 PNADC data for Brazil, including geographical identifiers, and saves the files in a specified directory:{p_end}
{p 8 12}{stata "ibge , survey(PNADC) country(BRA) year(2019) idbas saving(C:\Data\IBGE\PNADC)"}{p_end}

{p 6 16 2}Processes and renames PNAD data for the year 2001 without overwriting existing files:{p_end}
{p 8 12}{stata "ibge , survey(PNAD) country(BRA) year(2001) overwrite"}{p_end}

{title:Saved Results}
{pstd}{cmd:ibge} saves the following in {cmd:r()}:{p_end}
{synoptset 20 tabbed}
{synopthdr:Results}
{synoptline}
{synopt:{cmd:r(original)}}Path to the original data files used in processing.{p_end}
{synopt:{cmd:r(saving)}}Path where the processed data files were saved.{p_end}
{synoptline}

{title:Author}
{p 4 4 2}Joao Pedro Azevedo (jpazevedo@unicef.org){p_end}

{title:Version}
{p 4 4 2}1.0{p_end}

{title:Date}
{p 4 4 2}2024-03-21{p_end}

{title:Also see}

{psee}
Supplementary functions: {helpb _mkdir} {helpb _dlw} {helpb datazoom_pnad} {helpb datazoom_pnadcontinua}
{p_end}
