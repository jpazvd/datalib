{smcl}
{hline}
{help datalib}{right:Version 1.6.0}
{cmd:help _dlw}{right:Author: Joao Pedro Azevedo}
{right:Date: 2024-08-18}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :_dlw}{hline 1} Data Loading and Processing Utility.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:_dlw} [varlist] {cmd:,} {cmd:country(string)} {cmd:year(string)} {cmd:survey(string)} [{cmd:MODule(string)} {cmd:filename(string)} {cmd:MASter} {cmd:adaptation} {cmd:LATest} {cmd:collection(string)} {cmd:harmonization(string)} {cmd:va(string)} {cmd:vm(string)} {cmd:DEBUG} {cmd:data} {cmd:doc} {cmd:programs} {cmd:NOMerge} {cmd:clear}]{p_end}

{title:Description}
{pstd}{cmd:_dlw} is designed to facilitate the loading, processing, and merging of survey data modules across different countries and years. The utility provides options to select specific surveys, modules, and collections, with default settings for common use cases. It allows for the navigation of folder structures in the datalib repository and supports handling of master and adaptation files.{p_end}

{title:Options}
{synoptset 27 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt country(string)}}Specifies the country code for which the data is to be processed. This option is required.{p_end}
{synopt:{opt year(string)}}Specifies the survey year. If not specified, the latest available year is used by default.{p_end}
{synopt:{opt survey(string)}}Specifies the survey name. If not specified, the latest available survey for the selected country and year is used.{p_end}
{synopt:{opt MODule(string)}}Specifies the data modules to be loaded. If not specified, all available modules are selected.{p_end}
{synopt:{opt filename(string)}}Specifies the filename to be used when loading data. If not specified, a filename is constructed based on other options.{p_end}
{synopt:{opt MASter}}Indicates that the program should check for master files. This option is not currently supported.{p_end}
{synopt:{opt adaptation}}Indicates that the program should check for adaptation files. This option is optional.{p_end}
{synopt:{opt LATest}}Indicates that the program should use the latest available survey if the year is not specified.{p_end}
{synopt:{opt collection(string)}}Specifies the collection name. If not specified, a default collection is used based on the selected survey.{p_end}
{synopt:{opt harmonization(string)}}Specifies the harmonization method to be applied. This option is optional.{p_end}
{synopt:{opt va(string)}}Specifies the adaptation vintage. This option is optional and relevant only if {cmd:adaptation} is specified.{p_end}
{synopt:{opt vm(string)}}Specifies the master vintage. This option is optional and relevant only if {cmd:MASter} is specified.{p_end}
{synopt:{opt DEBUG}}Enables noisy output for debugging purposes. This option is optional.{p_end}
{synopt:{opt data}}Specifies that the data should be loaded from the specified file.{p_end}
{synopt:{opt doc}}Specifies that the documentation should be viewed from the specified file.{p_end}
{synopt:{opt programs}}Specifies that the program files should be viewed from the specified file.{p_end}
{synopt:{opt NOMerge}}Prevents automatic merging of data modules if multiple modules are selected. This option is optional.{p_end}
{synopt:{opt clear}}Clears existing data from memory before loading new data. This option is optional.{p_end}
{synoptline}

{title:Examples}
{p 6 16 2}Loads and processes the latest available survey data for Brazil in 2015 from the PNAD collection:{p_end}
{p 8 12}{stata "_dtlb_load , country(XAA) year(2015) survey(XHS)"}{p_end}

{p 6 16 2}Loads and processes all available data modules for the specified survey:{p_end}
{p 8 12}{stata "_dtlb_load , country(XAA) survey(XHS)"}{p_end}

{p 6 16 2}Loads a specific module from the PNADC survey in 2012 and views the documentation:{p_end}
{p 8 12}{stata "_dtlb_load , country(XAA) year(2015) survey(XHS) MODule(hhmembers) doc"}{p_end}

{p 6 16 2}Loads and processes data with debugging output enabled:{p_end}
{p 8 12}{stata "_dtlb_load , country(XAA) year(2015) survey(XHS) DEBUG"}{p_end}

{title:Saved Results}
{pstd}{cmd:_dlw} saves the following in {cmd:r()}:{p_end}
{synoptset 20 tabbed}
{synopthdr:Results}
{synoptline}
{synopt:{cmd:r(filename)}}List of filenames used for loading data{p_end}
{synopt:{cmd:r(data)}}Paths to the data files loaded{p_end}
{synopt:{cmd:r(doc)}}Paths to the documentation files viewed{p_end}
{synopt:{cmd:r(programs)}}Paths to the program files viewed{p_end}
{synopt:{cmd:r(harmonization)}}Harmonization file name{p_end}
{synoptline}

{title:Authors}
{p 4 4 2}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{p 4 4 2}Minh Cong Nguyen, World Bank{p_end}

{title:Version}
{p 4 4 2}1.4.0{p_end}

{title:Date}
{p 4 4 2}2024-08-18{p_end}


{title:Vintage resolution}

{pstd}{opt vm()} and {opt va()} name the master and adaptation vintage. For {opt vm()},
all of {cmd:1}, {cmd:01}, {cmd:v01} and {cmd:V01} mean the same thing, as do {cmd:wrk},
{cmd:WRK}, {cmd:vwrk} and {cmd:vWRK} for the working vintage.{p_end}

{pstd}With {opt vm()} omitted the {bf:latest} vintage loads and is announced, so a log
records which delivery produced the numbers. A folder named {cmd:{it:..}_vWRK_M} is the
{bf:working vintage} — the delivery before a public release. It wins the default, but
never overrides an explicit {opt vm()}; pass {opt wrk} to override deliberately. See
{helpb datalib##vintages:datalib}.{p_end}

{title:Saved results (vintage)}

{synoptset 26 tabbed}{...}
{synopt:{cmd:r(vintage)}}the vintage actually loaded{p_end}
{synopt:{cmd:r(vintage_source)}}how it was chosen: {cmd:explicit}, {cmd:latest}, {cmd:wrk-default} or {cmd:wrk-forced}{p_end}
{synopt:{cmd:r(mastervintages)}}every master vintage in the survey folder, published and working{p_end}
{synopt:{cmd:r(adaptationvintages)}}every adaptation vintage{p_end}
{synoptline}

{pstd}The two lists are populated whenever the corresponding vintage was left to the
command, so a script can branch on what exists rather than guess.{p_end}

{title:Also see}

{psee}
Supplementary functions: {helpb datalib} {helpb _dtlb_load} {helpb _dtlb_mkdir} {helpb _dtlb_ctrycheck} {helpb _dtlb_svycheck} {helpb _dtlb_vcheck} {helpb _dtlb_adaptcheck}
{p_end}