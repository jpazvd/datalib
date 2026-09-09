{smcl}
{hline}
{help ibge}{right:Version 3.0.3}
{right:Author: Joao Pedro Azevedo}
{right:Date: 2026-08-12}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :ibge}{hline 2}Data Loading and Processing Utility for IBGE Data.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:ibge} [{cmd:varlist}] [{cmd:in}] [{cmd:if}] {cmd:,} {cmd:survey(string)} {cmd:country(string)} {cmd:year(string)} [{cmd:options}]{p_end}

{title:Description}
{pstd}{cmd:ibge} is a wrapper for the DataZoom program designed to facilitate the loading, processing, and renaming of IBGE (Instituto Brasileiro de Geografia e Estatística) data files. It supports data from the PNAD and PNADC surveys (annual PNADC is recognised but not yet supported) and automates several tasks including data file naming and organization based on the Datalib folder structure convention. When a {cmd:saving} path is not specified, the program defaults to the Datalib folder structure.{p_end}

{pstd}This program integrates several utilities, including {help _dtlb_mkdir} for directory management and DataZoom commands for data processing, providing a streamlined workflow for handling IBGE data files.{p_end}

{title:Options}
{synoptset 27 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt survey(string)}}Survey to process: {cmd:PNAD} or {cmd:PNADC}. Anything else is refused before any work is done; it used to fall through every branch and return silently. {cmd:PNADCANUAL} is recognised but gated -- the annual-PNADC path exists and has never been executed, so it is refused rather than offered.{p_end}
{synopt:{opt country(string)}}Destination country code. It must be {cmd:BRA}, and defaults to it: this module wraps DataZoom's readers for Brazilian household surveys. Any other value is refused rather than silently redirected to BRA, which is what happened before version 3.0.2.{p_end}
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
{synopt:{opt path(string)}}Library to deposit into, passed to {help _dtlb_mkdir}. Defaults to {cmd:${datalib}}. Declared but discarded before version 3.0.2.{p_end}
{synopt:{opt norename}}Prevents automatic renaming of data files to match the Datalib naming convention.{p_end}
{synopt:{opt clean}}Deletes the temporary sub-folders DataZoom leaves behind once their contents have been moved into place. Cleaning is NOT the default: without this option the working folders are kept.{p_end}
{synopt:{opt overwrite}}Overwrites existing files in the destination folder without prompting.{p_end}
{synopt:{opt module(string)}}Module(s) to create, passed to {help _dtlb_mkdir}. Declared but discarded before version 3.0.2.{p_end}
{synopt:{opt master}}Deposit as a master vintage, passed to {help _dtlb_mkdir} -- which itself does not yet support it and says so. Declared but discarded before version 3.0.2. Cannot be combined with {cmd:panel}.{p_end}
{synopt:{opt adaptation}}Deposit as an adaptation, passed to {help _dtlb_mkdir}. Declared but discarded before version 3.0.2. Cannot be combined with {cmd:panel}, which deposits a PANEL adaptation of its own.{p_end}
{synopt:{opt collection(string)}}Specifies the collection name for organizing data. Defaults to 'HLT' if not specified.{p_end}
{synopt:{opt harmonization(string)}}Specifies the harmonization file name, if applicable.{p_end}
{synopt:{opt va(string)}}Specifies the vintage number for adaptation files.{p_end}
{synopt:{opt vm(string)}}Specifies the vintage number for master files.{p_end}
{synopt:{opt mkdir}}Creates the necessary directory structure based on the specified parameters.{p_end}
{synopt:{opt modules(string)}}Which DataZoom modules to build ({cmd:pes}, {cmd:dom}, {cmd:both}). Distinct from {opt module()}, which names a datalib module and is passed to {help _dtlb_mkdir}. Left empty, and with {opt overwrite} not given, it is filled from the files already present in the destination so that only the missing ones are rebuilt.{p_end}
{synopt:{opt NOIsily}}Runs the DataZoom calls under {cmd:noisily}. They are quiet by default because DataZoom is chatty; turn this on to see what it is doing when an import fails.{p_end}
{synopt:{opt skipdatazoom}}Skips the DataZoom extraction step for a PNADC panel and proceeds with whatever is already on disk. For re-running the deposit half after an extraction that has already succeeded.{p_end}
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

{title:Authors}
{p 4 4 2}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{p 4 4 2}Minh Cong Nguyen, World Bank{p_end}

{title:Version}
{p 4 4 2}3.0.3{p_end}

{title:Date}
{p 4 4 2}2026-08-12{p_end}

{title:Also see}

{psee}
Supplementary functions: {helpb _dtlb_mkdir} {helpb _dtlb_load} {helpb datazoom_pnad} {helpb datazoom_pnadcontinua}
{p_end}
