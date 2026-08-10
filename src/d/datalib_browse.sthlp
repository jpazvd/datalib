{smcl}
{* *! version 1.8.0  08Aug2026}{...}
{vieweralsosee "datalib" "help datalib"}{...}
{vieweralsosee "_dtlb_show" "help _dtlb_show"}{...}
{viewerjumpto "Syntax" "datalib_browse##syntax"}{...}
{viewerjumpto "Description" "datalib_browse##description"}{...}
{viewerjumpto "Options" "datalib_browse##options"}{...}
{viewerjumpto "Examples" "datalib_browse##examples"}{...}
{viewerjumpto "Stored results" "datalib_browse##results"}{...}

{title:Title}

{phang}
{bf:datalib_browse} {hline 2} Browse the survey catalogue as a clickable menu


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:datalib_browse}
[{cmd:,}
{opt country(CCC)}
{opt survey(SSSS)}
{opt year(YYYY)}
{opt lib:rary(path)}
{opt search(text)}
{opt rescan}
{opt nol:inks}
]


{marker description}{...}
{title:Description}

{pstd}
{cmd:datalib_browse} prints the catalogue in the Results window as a menu whose
cells are links. It has three depths, and each is reached by clicking rather
than by retyping:

{p 8 12 2}1. {it:no options} {space 6}{hline 2} countries by library{p_end}
{p 8 12 2}2. {cmd:country()} {space 5}{hline 2} surveys by year, for one country{p_end}
{p 8 12 2}3. {cmd:country() survey()} {hline 2} each vintage's DATA, CODE and DOC{p_end}

{pstd}
Depth 3 exists because a vintage on disk is three things. Someone opening a
survey they did not build needs the harmonization script and the README at
least as often as the dataset, so all three are offered rather than the data
with the rest as an afterthought.

{pstd}
The catalogue is scanned once per session and reused; {opt rescan} forces a
fresh walk. The caller's data, current frame and sort order are never touched.


{marker options}{...}
{title:Options}

{phang}
{opt country(CCC)} narrows to one country and moves to depth 2.

{phang}
{opt survey(SSSS)} with {opt country()} moves to depth 3.

{phang}
{opt year(YYYY)} narrows to one year.

{phang}
{opt library(path)} names the library for this call, as {cmd:datalib}'s own
{cmd:library()} does, and forces a rescan.

{phang}
{opt search(text)} keeps only rows whose country, survey, module list or
adaptation family contains {it:text}, case-insensitively. The number of rows
hidden is always reported: a filtered view that looks like a full one is
worse than no filter.

{phang}
{opt rescan} rebuilds the catalogue frame before rendering.

{phang}
{opt nolinks} prints the same tables as plain text. Use it when writing to a
log that will be read outside Stata, where a link is only noise.


{marker examples}{...}
{title:Examples}

{p 6 16 2}Build a practice library and point datalib at it:{p_end}
{p 8 12}{stata "datalib_makelib, families(demo) path(dlxbrowse)"}{p_end}
{p 8 12}{stata "datalib_root, root(dlxbrowse) set"}{p_end}

{p 6 16 2}Depth 1 {hline 2} countries by library:{p_end}
{p 8 12}{stata "datalib_browse"}{p_end}

{p 6 16 2}Depth 2 {hline 2} surveys by year, for one country:{p_end}
{p 8 12}{stata "datalib_browse, country(XAA)"}{p_end}

{p 6 16 2}Depth 3 {hline 2} each vintage's DATA, CODE and DOC:{p_end}
{p 8 12}{stata "datalib_browse, country(XAA) survey(XHS)"}{p_end}

{p 6 16 2}Find every vintage mentioning a harmonization family:{p_end}
{p 8 12}{stata "datalib_browse, search(hcl)"}{p_end}

{p 6 16 2}Plain text, for a log read outside Stata:{p_end}
{p 8 12}{stata "datalib_browse, nolinks"}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(depth)}}1, 2 or 3 {hline 2} which view was printed{p_end}
{synopt:{cmd:r(hidden)}}rows removed by {opt search()}{p_end}
{synopt:{cmd:r(nrows)}}rows in the rendered table{p_end}
{synopt:{cmd:r(ncols)}}columns in the rendered table{p_end}
{p2colreset}{...}


{title:Also see}

{psee}
Online: {helpb datalib}, {helpb _dtlb_show}, {helpb _dtlb_catalog}
{p_end}
