{smcl}
{hline}
{cmd:help datalib}{right:Version 1.9.0}
{right:Author: Joao Pedro Azevedo}
{right:Date: 2026-08-06}
{hline}

{title:Title}
{p2colset 5 27 32 2}{...}
{p2col :datalib}{hline 1} Data Loading and Processing Utility.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 19 2}{cmd:datalib} [{cmd:,} {opt country(string)} {opt year(string)} {opt survey(string)} {opt module(string)} {opt filename(string)} {opt subfoldr(string)} {opt library(string)} {opt path(string)} {opt vm(string)} {opt wrk} {it:options}]{p_end}

{pstd}Called with no options at all, {cmd:datalib} starts interactive navigation from the top of the library.{p_end}

{title:Description}
{pstd}{cmd:datalib} is a comprehensive utility designed to facilitate the loading, processing, and merging of survey data modules across different countries and years. It provides a user-friendly interface for navigating the data repository, selecting specific surveys, and performing data operations. When certain parameters like country, year, or survey are not specified, {cmd:datalib} launches an interactive navigation mode to help users browse available options.{p_end}
{pstd}The program leverages several subroutines to handle different tasks:{p_end}
{pstd}- {cmd:_foldernav} handles interactive folder navigation.{p_end}
{pstd}- {cmd:_dlw} loads, processes, and merges survey data modules based on the selected parameters.{p_end}
{pstd}- {cmd:_mkdir} creates directory structures and manages data folders based on specified parameters.{p_end}

{title:Library root}

{pstd}Name the library for a single call with {opt library()}:{p_end}
{p 8 12}{stata "datalib, library(F:/datalib) country(XAA) year(2015) survey(XHS) clear"}{p_end}

{pstd}Or set it once for the session with {helpb datalib_root}:{p_end}
{p 8 12}{stata "datalib_root, root(F:/datalib) set"}{p_end}

{pstd}{opt library()} resolves through {helpb datalib_root} in {opt find} mode, so a
path that is not a library is refused with an actionable message rather than failing
later as a bare {it:directory not found}. The resolved root is then published to
{cmd:${datalib}} — deliberately, not as an oversight: the clickable navigation links
this command writes carry no {opt library()} option, so the root has to persist or the
next click would resolve somewhere else. Once a library has been validated in a
session it is not probed again, which keeps a slow network share off the critical path
of every call.{p_end}

{pstd}With nothing given at all, {cmd:datalib} resolves the root itself through the
chain below. It is no longer an error to call {cmd:datalib} before setting
{cmd:${datalib}}.{p_end}

{pstd}{helpb datalib_root} resolves the root from, in order: its own {opt root()} option, {cmd:${datalib}}, the {cmd:DATALIB_ROOT} environment variable, then the {cmd:datalib:} key of {cmd:user_config.yml} and of {cmd:datalib_config.yml} (see {helpb getuserconfig}). It is {opt set} that copies the answer into the global this command reads. None of these is required: a configuration file is a convenience, not a prerequisite, and {cmd:getuserconfig, create root(}{it:path}{cmd:)} writes one if you want it.{p_end}

{pstd}With no archive to hand, build a synthetic one and point at it:{p_end}
{p 8 12}{stata "datalib_makelib, families(demo) path(mydemo)"}{p_end}
{p 8 12}{stata "datalib_root, root(mydemo) set"}{p_end}


{marker vintages}{...}
{title:Vintages, and the working vintage}

{pstd}A survey folder holds one folder per {it:vintage} — one per delivery. Published
deliveries are numbered {cmd:v01}, {cmd:v02}, … and are immutable once released. Name
one with {opt vm()}; all of {cmd:1}, {cmd:01}, {cmd:v01} and {cmd:V01} are accepted.{p_end}

{pstd}{bf:With no} {opt vm()}{bf:, the LATEST published vintage is loaded}, and which one
it was is printed. That matters more than it looks: without the notice, a do-file's
meaning would change silently the day someone deposits {cmd:v03}, and whoever reads
the log later could not tell which delivery produced the numbers.{p_end}

{marker adaptvintages}{...}
{title:Adaptation vintages}

{pstd}An {it:adaptation} is a derived product built off a published master:
{cmd:{it:CCC_YYYY_SSSS}_vNN_M_vNN_A_{it:collection}}. It carries its own vintage
number, named with {opt va()}.{p_end}

{pstd}{opt va()} behaves exactly as {opt vm()} does, and for the same reasons: the
same four spellings are accepted ({cmd:1}, {cmd:01}, {cmd:v01}, {cmd:V01}), the
{bf:latest adaptation vintage is loaded when it is omitted}, and the choice is
announced. The two options sit on the same command, so a caller who has learned one
is entitled to expect the other to behave — until version 1.4.0 {opt va()} had none of
this, and omitting it built a path with an empty vintage slot.{p_end}

{pstd}One asymmetry is worth knowing, because it follows from what an adaptation
{it:is}. Adaptations are built off {bf:published} masters, so a working vintage cannot
have one. If a survey has a {cmd:vWRK} and you ask for an adaptation without naming a
master, {cmd:vWRK} wins the master default and the folder you are asking for cannot
exist; {cmd:datalib} says so and lists the published masters, rather than failing with
a bare "file not found".{p_end}

{title:The working vintage}

{pstd}A folder named {cmd:{it:CCC_YYYY_SSSS}_vWRK_M} is the {bf:working vintage}: the
delivery {bf:before a public release}. It is a real stage of the archive's lifecycle,
not a scratch directory — the copy being assembled, checked and corrected until it is
numbered and published as {cmd:vNN}.{p_end}

{pstd}Its precedence is deliberately asymmetric:{p_end}

{p2colset 9 34 36 2}{...}
{p2col :{bf:no} {opt vm()}}the working vintage {bf:wins}. Asking for no particular vintage while a working copy exists almost always means you want it — that is why it was made.{p_end}
{p2col :{opt vm(01)} given}{cmd:v01} loads. A pinned vintage is a reproducibility claim, and handing it a pre-release delivery instead would break the one promise the archive exists to keep: that an analysis can name the exact data it ran on.{p_end}
{p2col :{opt wrk} given}the working vintage loads {bf:even over an explicit} {opt vm()}, and says that it is overriding it. This is the deliberate opt-in for working against the pre-release copy.{p_end}
{p2colreset}{...}

{pstd}Loading it always prints a notice, and a louder one than the numbered default:
results from a pre-release delivery are provisional, the folder may change underneath
you, and numbers taken from it must never be mistaken for numbers from a published
vintage. {opt wrk} without a working vintage present is an error ({cmd:601}), not a
silent fall back to a published one.{p_end}

{title:Options}
{synoptset 27 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt subfoldr(string)}}Navigate directly to a folder, named as an underscore-joined stub (for example {cmd:ZZA_2022_XHS}). This is the option the navigation links themselves emit, so it is what a click resolves to.{p_end}
{synopt:{opt country(string)}}Specifies the country code to filter the data search. If not specified, interactive navigation starts.{p_end}
{synopt:{opt year(string)}}Specifies the year of the survey data. If not specified, interactive navigation starts, or the latest available year is selected.{p_end}
{synopt:{opt survey(string)}}Specifies the survey name to filter the data search. If not specified, interactive navigation starts, or the latest available survey is selected.{p_end}
{synopt:{opt module(string)}}Specifies the module(s) to be loaded. If not specified, all available modules are loaded.{p_end}
{synopt:{opt filename(string)}}Specifies the filename of the data to be loaded. Useful when targeting specific files within the data repository.{p_end}
{synopt:{opt library(string)}}Name the archive for this call. Resolved through {helpb datalib_root} in {opt find} mode and published to {cmd:${datalib}}, so navigation links keep working. Outranks {cmd:${datalib}}, {cmd:DATALIB_ROOT} and the configuration files.{p_end}
{synopt:{opt path(string)}}Base path for navigation, in place of {cmd:${datalib}}. Used with {opt subfoldr()}; the DATA, DOC and PROGRAMS sections always build from {cmd:${datalib}}.{p_end}
{synopt:{opt master}}Indicates that the program should check for master files. Currently not supported.{p_end}
{synopt:{opt adaptation}}Indicates that the program should check for adaptation files.{p_end}
{synopt:{opt latest}}Indicates that the program should automatically select the latest available survey year.{p_end}
{synopt:{opt collection(string)}}Specifies the collection name for organizing data. Defaults to 'HLT' if not specified.{p_end}
{synopt:{opt harmonization(string)}}Specifies the harmonization file name if applicable.{p_end}
{synopt:{opt vm(string)}}Master vintage to load. Accepts {cmd:1}, {cmd:01}, {cmd:v01} or {cmd:V01}. Default: the latest published vintage, or the working vintage if one exists. See {help datalib##vintages:Vintages}.{p_end}
{synopt:{opt wrk}}Load the working vintage ({cmd:vWRK}) — the pre-release delivery — even when {opt vm()} names a published one. Errors if no working vintage exists.{p_end}
{synopt:{opt va(string)}}Adaptation vintage. Accepts {cmd:1}, {cmd:01}, {cmd:v01}, {cmd:V01}; defaults to the latest and says so. See {help datalib##adaptvintages:Adaptation vintages}.{p_end}
{synopt:{opt debug}}Enables detailed, noisier output for debugging purposes.{p_end}
{synopt:{opt data}}Loads the data files based on the specified options.{p_end}
{synopt:{opt doc}}Opens documentation files associated with the selected survey.{p_end}
{synopt:{opt programs}}Opens program files associated with the selected survey.{p_end}
{synopt:{opt nomerge}}Prevents automatic merging of modules if multiple modules are selected.{p_end}
{synopt:{opt clear}}Clears the current dataset before loading new data.{p_end}
{synopt:{opt nowarning}}Suppresses the join report that a multi-module load prints by
default -- the {it:joining modules} table naming each module, its row count and its
distinct key count. The report is on by default because a join nobody sees is a join
nobody can check.{p_end}
{synopt:}Note that it also suppresses the per-module {cmd:r(rows_}{it:module}{cmd:)} and
{cmd:r(distinct_}{it:module}{cmd:)} scalars, which are returned from inside the same block;
{cmd:r(rows_}{it:base}{cmd:)} for the base module is returned either way. Notes about
unmatched rows are NOT suppressed -- those report a result, not a progress message.{p_end}
{synoptline}

{title:Subroutines}

{pstd}{cmd:datalib} relies on the following subroutines for its operation:{p_end}

{pstd}{cmd:_foldernav}: This utility assists with navigating through the folder structure of the data repository. It allows users to interactively browse available countries, years, surveys, and other subdirectories.{p_end}

{pstd}{help _dtlb_load}: This program handles the loading, processing, and merging of survey data modules. It processes the selected survey data based on the options provided by the user, ensuring appropriate sorting, variable management, and file handling.{p_end}

{pstd}{help _dtlb_mkdir}: This utility is used to create directory structures and manage data folders based on specified parameters such as country, year, survey, and more. It ensures the appropriate organization of data files within the repository.{p_end}


{title:Subroutines used by {cmd:_mkdir}}

{pstd}{help _dtlb_ctrycheck}: This subroutine verifies whether the specified country exists in the datalib directory. If the country folder is not found, it prompts the user to create a new collection or select an existing one, depending on the options specified.{p_end}

{pstd}{help _dtlb_svycheck}: This subroutine checks for the availability of surveys in the specified directory. It extracts unique survey names based on the folder structure and filename patterns. It can filter results based on master and adaptation file types and returns flags indicating the presence of multiple vintages, master and adaptation files, and the latest survey year available.{p_end}

{pstd}{help _dtlb_vcheck}: This subroutine verifies the vintage numbers for both master and adaptation files. It checks if the specified vintage numbers exist and if the new vintage numbers are eligible for creation. It ensures that vintage numbers increase incrementally and correctly reflect the most recent versions available.{p_end}

{pstd}{help _dtlb_adaptcheck}: This subroutine checks for the availability of adaptation files in the specified directory. It verifies the presence of adaptation vintages and ensures that the selected adaptation matches the existing files or allows for the creation of a new adaptation version.{p_end}

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
{p 8 12}{stata "datalib , country(XAA)" :. datalib , country(XAA)}{p_end}

{p 6 16 2}Loads the 2019 MICS survey data for Bangladesh and opens the associated documentation.{p_end}
{p 8 12}{stata "datalib , country(BGD) year(2019) survey(XHS) doc" :. datalib , country(BGD) year(2019) survey(XHS) doc}{p_end}

{p 6 16 2}Loads all available modules from the 2015 PNAD survey in Brazil, leaving them unmerged.{p_end}
{p 8 12}{stata "datalib , country(XAA) year(2015) survey(XHS) nomerge" :. datalib , country(XAA) year(2015) survey(XHS) nomerge}{p_end}

{title:Saved Results}
{pstd}{cmd:datalib} does not save any specific results in {cmd:r()} by default. However, subroutines like {cmd:_dlw} may save results related to the loaded and processed data.{p_end}

{title:Authors}
{p 4 4 2}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{p 4 4 2}Minh Cong Nguyen, World Bank{p_end}

{title:Version}
{p 4 4 2}1.4.0{p_end}

{title:Date}
{p 4 4 2}2024-08-18{p_end}

{title:Also see}

{psee}
Library root and configuration: {helpb datalib_root} {helpb datalib_config} {helpb getuserconfig} {helpb datalib_makelib}

{p_end}
{psee}
Deposit and validate: {helpb _dtlb_put} {helpb _dtlb_check} {helpb _dtlb_mkdir}

{p_end}
{psee}
Internals: {helpb _dtlb_load} {helpb _foldernav} {helpb _dtlb_ctrycheck} {helpb _dtlb_svycheck} {helpb _dtlb_vcheck} {helpb _dtlb_adaptcheck} {helpb _dtlb_catalog}
{p_end}


