{smcl}
{* *! version 1.11.0  12aug2026}{...}
{vieweralsosee "datalib" "help datalib"}{...}
{vieweralsosee "_dtlb_mkdir" "help _dtlb_mkdir"}{...}
{vieweralsosee "_dtlb_put" "help _dtlb_put"}{...}
{vieweralsosee "datalib_makelib" "help datalib_makelib"}{...}
{viewerjumpto "Syntax" "_dtlb_folderplan##syntax"}{...}
{viewerjumpto "Description" "_dtlb_folderplan##description"}{...}
{viewerjumpto "Options" "_dtlb_folderplan##options"}{...}
{viewerjumpto "Plans" "_dtlb_folderplan##plans"}{...}
{viewerjumpto "Stored results" "_dtlb_folderplan##results"}{...}
{cmd:help _dtlb_folderplan}{right:Version 1.11.0}
{hline}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:_dtlb_folderplan}
[{cmd:,}
{opt pla:n(name)}
{opt kin:d(master|adaptation)}
{opt dat:a(names)}
{opt doc(names)}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt pla:n(name)}}{cmd:default}, {cmd:ihsn2014} or {cmd:minimal}; default {cmd:default}{p_end}
{synopt:{opt kin:d(master|adaptation)}}which folder shape; only {cmd:ihsn2014} differs between them{p_end}
{synopt:{opt dat:a(names)}}replace the plan's {cmd:Data/} leaves{p_end}
{synopt:{opt doc(names)}}replace the plan's {cmd:Doc/} leaves{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:_dtlb_folderplan} answers one question: which subfolders does a vintage
folder contain. It creates nothing. Callers that do the creating --
{helpb _dtlb_mkdir}, {helpb _dtlb_put}, {helpb datalib_makelib} and
{cmd:_dtlb_ipums_extract} -- read {cmd:r(subfolders)} and {cmd:mkdir} it.

{pstd}
{bf:Why it exists.} The plan was a hard-coded literal in six places: four
separate blocks in {helpb _dtlb_mkdir} plus one each in the other three
creators. Six copies of a literal drift, and these had. {cmd:datalib_makelib}
built no {cmd:Data/Other} while every other creator did, and {it:none} of the
six built the three {cmd:Doc/} subfolders that Annex 1 of the ECAPOV
Harmonization Guideline -- the origin document for this folder convention --
specifies.

{pstd}
That second one is the one that matters. An empty {cmd:Doc/Technical/} is a
claim: {it:we looked, there is none}. A missing folder says nothing at all, and
there was nowhere a reader could go to find out which was meant.

{pstd}
{bf:The canonical definition is} {cmd:config/folderplan.yml}{bf:}, shared with
the R and Python legs. It is deliberately {it:not} read at runtime:
{cmd:config/} is not in {cmd:datalib.pkg}, so an installed user does not have
it, and a creation path should not need a YAML parse to know where to put a
file. The literal in this command is the Stata copy, and
{cmd:python/tests/test_folderplan.py} asserts it equals the YAML -- so the copy
cannot drift without a test failing, which is exactly what the six copies
lacked.


{marker options}{...}
{title:Options}

{phang}
{opt plan(name)} chooses the subfolder set; see {help _dtlb_folderplan##plans:Plans} below.

{phang}
{opt kind(master|adaptation)} selects the folder shape. Only {cmd:ihsn2014}
distinguishes them: there, an adaptation keeps its harmonised files in
{cmd:Data/Harmonized} and takes a bare {cmd:Doc/}.

{phang}
{opt data(names)} and {opt doc(names)} replace the chosen plan's {cmd:Data/}
and {cmd:Doc/} leaves respectively, one axis each, so
{cmd:plan(ihsn2014) data(Original Stata SPSS)} is Annex 1's tree with SPSS
promoted rather than a restatement of eleven folders. They name {it:leaves},
not paths: a value containing {cmd:/}, {cmd:\} or {cmd:..} is refused, because
the library root is normally a network share and a name carrying a path would
write outside the vintage folder. Using either sets {cmd:r(deviation)} to 1 --
a convention that can be departed from without leaving a trace is not a
convention.


{marker plans}{...}
{title:Plans}

{synoptset 12 tabbed}{...}
{synopt:{cmd:default}}{cmd:Data/}{it:{Original Stata SPSS R Other}}, {cmd:Doc/}{it:{Questionnaires Reports Technical}}, {cmd:Programs/}{p_end}
{synopt:{cmd:ihsn2014}}Annex 1 verbatim: no {cmd:Data/SPSS}, no {cmd:Data/R}; an adaptation takes {cmd:Data/Harmonized} and a bare {cmd:Doc/}{p_end}
{synopt:{cmd:minimal}}{cmd:Data/}, {cmd:Doc/}, {cmd:Programs/} only{p_end}
{p2colreset}{...}

{pstd}
{cmd:Data/}, {cmd:Doc/} and {cmd:Programs/} are {bf:structural}: always created,
never named by a plan. What a plan names are the leaves under the first two.
That is what lets {opt data()} and {opt doc()} vary one axis without restating
the tree, and it stops a plan entry carrying a path where a folder name belongs.


{marker results}{...}
{title:Stored results}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(subfolders)}}the leaves to create, relative to the vintage folder, parents first, quoted for {cmd:foreach ... in}{p_end}
{synopt:{cmd:r(plan)}}the plan in force{p_end}
{synopt:{cmd:r(kind)}}{cmd:master} or {cmd:adaptation}{p_end}
{synopt:{cmd:r(data_leaves)}}the {cmd:Data/} leaves alone{p_end}
{synopt:{cmd:r(doc_leaves)}}the {cmd:Doc/} leaves alone{p_end}
{p2colreset}{...}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(deviation)}}1 when {opt data()} or {opt doc()} departed from the plan{p_end}
{p2colreset}{...}

{pstd}
{cmd:r(subfolders)} carries a {bf:leading} path component per entry and no
leading slash: {cmd:"Data" "Data/Original" ...}. A caller joins it with its own
separator. The list this replaced carried the slash itself
({cmd:"/Data"}), and converting one caller without moving the separator built
every folder a level up -- caught by the SMOKE and DET suites, which is the
argument for having them.


{marker also}{...}
{title:Also see}

{psee}
Online:  {helpb datalib}, {helpb _dtlb_mkdir}, {helpb _dtlb_put},
{helpb datalib_makelib}
{p_end}
