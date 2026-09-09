{smcl}
{hline}
{help datalib}{right:Version 1.0.2}
{cmd:help _adaptcheck}{right:Author: Joao Pedro Azevedo}
{right:Date: 2024-08-18}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :_adaptcheck}{hline 2}Datalib Adaptation Check Utility.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:_adaptcheck}, {cmd:path(string)}{p_end}

{title:Description}
{pstd}{cmd:_adaptcheck} is a utility that checks the availability of adaptation files in a specified directory (datalib). It verifies the presence of adaptation vintages and ensures that the selected adaptation matches the existing files or allows for the creation of a new adaptation version. This utility is essential for managing and verifying the consistency of adaptation data stored in a structured repository.{p_end}
{pstd}The program identifies adaptation files, extracts their vintage numbers, and returns information about the available adaptations, the latest vintage available, and their numeric equivalents.{p_end}

{title:Filename Patterns}
{p 6 16 2}
- {cmd:<country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>}
{p_end}

{title:Folder Structure Patterns}
{p 6 16 2}
- {cmd:datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>/}
{p_end}

{title:Examples}
{p 6 16 2}Checks the availability of adaptation files for the 2012 PNADC survey in Brazil.{p_end}
{p 8 12}{stata "_dtlb_adaptcheck , path(D:\datalib\BRA\BRA_2012_PNADC)" : _adaptcheck , path(D:\datalib\BRA\BRA_2012_PNADC)"}{p_end}

{p 6 16 2}Checks the availability of adaptation files for the 2019 MICS survey in Bangladesh.{p_end}
{p 8 12}{stata "_dtlb_adaptcheck , path(D:\datalib\BGD\BGD_2019_MICS)" : _adaptcheck , path(D:\datalib\BGD\BGD_2019_MICS)"}{p_end}

{p 6 16 2}Checks the availability of adaptation files for the 2001 PNAD survey in Brazil.{p_end}
{p 8 12}{stata "_dtlb_adaptcheck , path(D:\datalib\BRA\BRA_2001_PNAD)" : _adaptcheck , path(D:\datalib\BRA\BRA_2001_PNAD)"}{p_end}

{title:Saved Results}
{pstd}{cmd:_adaptcheck} saves the following in {cmd:r()}:{p_end}
{synoptset 20 tabbed}
{synopthdr:Results}
{synoptline}
{synopt:{cmd:r(Acheck)}}Indicates whether adaptation data is present ({cmd:1}) or not ({cmd:0}).{p_end}
{synopt:{cmd:r(Avintagelist)}}List of vintage numbers for the adaptation data.{p_end}
{synopt:{cmd:r(Alatestvintage)}}The latest vintage number found in the adaptation data.{p_end}
{synopt:{cmd:r(Anumvintages)}}Total number of vintage numbers found in the adaptation data.{p_end}
{synopt:{cmd:r(Anumvintagelist)}}Numeric equivalents of the vintage numbers found in {cmd:r(Avintagelist)}.{p_end}
{synopt:{cmd:r(AFolders)}}List of folders containing adaptation data.{p_end}
{synoptline}

{title:Authors}
{p 4 4 2}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{p 4 4 2}Minh Cong Nguyen, World Bank{p_end}

{title:Version}
{p 4 4 2}1.0.2{p_end}

{title:Date}
{p 4 4 2}2024-08-18{p_end}

{title:Version History}
{pstd}{bf:v1.0.0} (2024-08-18): Initial release with functionality for checking the availability and consistency of adaptation files within the datalib repository.{p_end}

{title:Also see}

{psee}
Supplementary functions: {helpb datalib} {helpb _dtlb_load} {helpb _dtlb_mkdir} {helpb _dtlb_ctrycheck} {helpb _dtlb_svycheck} {helpb _dtlb_vcheck} {helpb _dtlb_adaptcheck}
{p_end}
