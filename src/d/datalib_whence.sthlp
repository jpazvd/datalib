{smcl}
{* *! version 1.6.0  08Aug2026}{...}
{cmd:help datalib_whence}{right:Version 1.6.0}
{hline}

{title:Title}

{p2colset 5 22 24 2}{...}
{p2col :{cmd:datalib_whence} {hline 2}}Where did the data in memory come from?{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 17 2}{cmd:datalib_whence} [{cmd:,} {opt quietly}]

{title:Description}

{pstd}
{cmd:datalib_whence} reports the provenance a dataset carries about itself,
read from the {cmd:_dta} characteristics {cmd:datalib} stamps when it loads.

{pstd}
Open a {cmd:.dta} someone sent you and Stata reports its variables and its
label; it does not report which vintage of which survey it is, which is the
question that decides whether a result can be reproduced. Characteristics
travel with the file, so a dataset carried out of its folder still knows where
it came from.

{title:What it does not tell you}

{pstd}
Characteristics record {bf:origin}, not current content. They survive
{cmd:collapse} and {cmd:reshape}, so an aggregate still names the vintage it
was built from. That is the honest answer to "where did this come from" and
the wrong answer to "is this still that dataset". For the second question use
{helpb datasignature}, which covers values and ignores metadata. The two are
complementary and neither substitutes for the other.

{title:Options}

{phang}{opt quietly} suppresses the report; the {cmd:r()} results are still
returned.

{title:Examples}

{phang}{cmd:. datalib_whence}{p_end}
{phang}{cmd:. datalib_whence, quietly}{p_end}

{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(idno)}}the IHSN identifier the data was loaded as{p_end}
{synopt:{cmd:r(level)}}its declared unit of observation{p_end}
{synopt:{cmd:r(keys)}}the variables that identify a row{p_end}
{synopt:{cmd:r(parent)}}the module one level up{p_end}
{synopt:{cmd:r(parentkeys)}}the parent's keys{p_end}
{synopt:{cmd:r(source)}}the path it was loaded from{p_end}
{synopt:{cmd:r(loaded)}}when it was loaded{p_end}
{synopt:{cmd:r(pkgversion)}}the datalib version that loaded it{p_end}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(stamped)}}1 if the data carries a datalib stamp, 0 if not{p_end}

{title:Also see}

{psee}
{helpb datalib}, {helpb datasignature}
