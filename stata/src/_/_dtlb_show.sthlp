{smcl}
{* *! version 1.8.0  08Aug2026}{...}
{vieweralsosee "datalib_browse" "help datalib_browse"}{...}
{vieweralsosee "_dtlb_catalog" "help _dtlb_catalog"}{...}
{viewerjumpto "Syntax" "_dtlb_show##syntax"}{...}
{viewerjumpto "Description" "_dtlb_show##description"}{...}
{viewerjumpto "Options" "_dtlb_show##options"}{...}
{viewerjumpto "Remarks" "_dtlb_show##remarks"}{...}
{viewerjumpto "Examples" "_dtlb_show##examples"}{...}
{viewerjumpto "Stored results" "_dtlb_show##results"}{...}

{title:Title}

{phang}
{bf:_dtlb_show} {hline 2} Render a catalog frame as a list, a grid or a matrix


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:_dtlb_show}
[{cmd:,}
{opt form:at(list|grid|matrix)}
{opt row(varname)}
{opt col(varname)}
{opt cell(varname)}
{opt frame(name)}
{opt link:cmd(template)}
{opt title(text)}
{opt maxc:ols(#)}
{opt nol:inks}
]


{marker description}{...}
{title:Description}

{pstd}
{cmd:_dtlb_show} prints a frame in the Results window in one of three formats.
They are not three programs: they are one pivot with a different number of
dimensions bound to axes.

{synoptset 12 tabbed}{...}
{synopt:{it:format}}{it:pivots}{col 28}{it:a line is}{col 52}{it:cells hold}{p_end}
{synopt:{cmd:list}}0{col 28}one record{col 52}its own attributes{p_end}
{synopt:{cmd:grid}}1{col 28}a wrapped run of values{col 52}the value itself{p_end}
{synopt:{cmd:matrix}}2{col 28}one row-dimension value{col 52}an aggregate{p_end}
{p2colreset}{...}

{pstd}
With no {opt format()} the format is inferred: both {opt row()} and
{opt col()} give a matrix, {opt row()} alone gives a grid, neither gives a list.

{pstd}
The caller's data and current frame are never changed.


{marker options}{...}
{title:Options}

{phang}
{opt format(list|grid|matrix)} selects the format.

{phang}
{opt row(varname)} the row axis. Required for {cmd:grid} and {cmd:matrix}.

{phang}
{opt col(varname)} the column axis. Required for {cmd:matrix}.

{phang}
{opt cell(varname)} what to print in a populated cell. The default is a count
of the records falling in it; with {opt cell()} the first value is shown, with
a trailing {cmd:+} when more than one record is present.

{phang}
{opt frame(name)} the frame to render. Default {cmd:dtlb_catalog}.

{phang}
{opt linkcmd(template)} makes cells clickable. {cmd:@row} and {cmd:@col} are
replaced by the current cell's coordinates, so the renderer needs no knowledge
of what it is rendering.

{phang}
{opt title(text)} a heading printed above the table.

{phang}
{opt maxcols(#)} caps the number of columns drawn.

{phang}
{opt nolinks} prints labels as plain text.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Only the matrix can show absence.} A list of what exists has no row for the
survey nobody deposited. A cross-tab allocates a cell to every combination of
its axes, so a gap is rendered as {cmd:.} and is visible. For a catalogue that
matters, because the question usually put to one is not "what do we have" but
"do we have 2019 for this country" {hline 2} which is answered by an empty cell.

{pstd}
{bf:Why this is not {help tabdisp}.} Measured on Stata 17: {cmd:tabdisp} does
not interpret SMCL in cells (a 14-character link that fits whole still renders
as literal markup, while the same string through {cmd:display} renders as a
working link), and it truncates string cells at 20 characters. Either alone
rules it out for a clickable menu.

{pstd}
{bf:Width arithmetic uses the label.} SMCL directives cost no display columns,
so every width is computed from the visible label while the emitted string is
far longer. A matrix wider than {cmd:c(linesize)} reports how many columns it
could not draw rather than truncating in silence.


{marker examples}{...}
{title:Examples}

{p 6 16 2}Scan a library into the catalog frame:{p_end}
{p 8 12}{stata "datalib_makelib, families(demo) path(dlxshow)"}{p_end}
{p 8 12}{stata "datalib_root, root(dlxshow) set"}{p_end}
{p 8 12}{stata "_dtlb_catalog, scan"}{p_end}

{p 6 16 2}Zero pivots {hline 2} one record per line:{p_end}
{p 8 12}{stata "_dtlb_show, format(list) title(All vintages)"}{p_end}

{p 6 16 2}One pivot {hline 2} the values of one dimension, wrapped:{p_end}
{p 8 12}{stata "_dtlb_show, format(grid) row(country)"}{p_end}

{p 6 16 2}Two pivots {hline 2} the only view that renders a gap:{p_end}
{p 8 12}{stata "_dtlb_show, format(matrix) row(country) col(survey)"}{p_end}

{p 6 16 2}Cells that carry a command:{p_end}
{p 8 12}{stata "_dtlb_show, format(matrix) row(country) col(survey) linkcmd(datalib_browse, country(@row))"}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(rows)}}records in the frame{p_end}
{synopt:{cmd:r(nrows)}}rows drawn{p_end}
{synopt:{cmd:r(ncols)}}columns present on the column axis{p_end}
{synopt:{cmd:r(ntrunc)}}columns that did not fit{p_end}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(format)}}the format rendered{p_end}
{p2colreset}{...}


{title:Also see}

{psee}
Online: {helpb datalib_browse}, {helpb _dtlb_catalog}, {helpb datalib}
{p_end}
