{smcl}
{* *! version 1.6.0 17Jul2026}{...}
{hline}
help for {hi:_dtlb_idno}{right:datalib helpers}
{hline}

{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:_dtlb_idno}}Bidirectional folder ↔ IDNo study-identifier translation{p_end}
{p2colreset}{...}

{title:Syntax}

{pstd}Build an identifier from its parts:{p_end}

{p 8 16 2}
{cmd:_dtlb_idno}{cmd:,} {opt country(CCC)} {opt year(YYYY)} {opt survey(SSSS)}
{opt version(vNN)} [{opt adaptation(HHHH)} {opt aversion(vNN)}]

{pstd}Parse an identifier into its parts:{p_end}

{p 8 16 2}
{cmd:_dtlb_idno}{cmd:,} {opt parse(idno_or_folder)}

{title:Description}

{pstd}
The IHSN study identifier appears in two cases: NADA catalogs index the
{bf:upper} form ({cmd:XAA_2015_XHS_v01_M}, lowercase {cmd:v}), while
datalib's on-disk folders use the {bf:lower} form
({cmd:xaa_2015_xhs_v01_m}). {cmd:_dtlb_idno} is the single point where
that translation happens: every IDNo sent to a catalog API, and every idno
read from a response, goes through it, so case bugs cannot scatter across
call sites. Input is accepted in any case; output is always canonical
(components upper, {cmd:v} lower, {cmd:M}/{cmd:A} upper), with the
lowercase on-disk folder name returned alongside.

{pstd}
Vintage inputs accept the contract-v1 forms {cmd:1}, {cmd:01}, {cmd:v01},
{cmd:V01}; output is the padded lower-v form. In build mode
{opt aversion()} is required whenever {opt adaptation()} is given —
identifiers are exact, so the adaptation vintage is never guessed. In
parse mode a non-conforming identifier exits with error 198; callers that
meet free-text NADA idnos wrap the call in {cmd:capture} and treat failure
as "unparsed".

{title:Stored results}

{p2colset 5 22 26 2}{...}
{p2col:{cmd:r(idno)}}canonical identifier, e.g. {cmd:XAA_2015_XHS_v01_M_v01_A_HCL}{p_end}
{p2col:{cmd:r(folder)}}lowercase on-disk folder name{p_end}
{p2col:{cmd:r(country)}}ISO3 country code (upper){p_end}
{p2col:{cmd:r(year)}}survey year (scalar){p_end}
{p2col:{cmd:r(survey)}}survey acronym (upper){p_end}
{p2col:{cmd:r(version)}}master vintage ({cmd:v01} form){p_end}
{p2col:{cmd:r(kind)}}{cmd:master} or {cmd:adaptation}{p_end}
{p2col:{cmd:r(adaptation)}}collection tag ("" for masters){p_end}
{p2col:{cmd:r(aversion)}}adaptation vintage ("" for masters){p_end}
{p2colreset}{...}

{title:Examples}

{phang}{cmd:. _dtlb_idno, country(xaa) year(2015) survey(xhs) version(1)}{p_end}
{phang}{cmd:. display "`r(idno)' / `r(folder)'"}{p_end}
{phang}{space 2}{it:XAA_2015_XHS_v01_M / xaa_2015_xhs_v01_m}{p_end}

{phang}{cmd:. _dtlb_idno, parse("xaa_2015_xhs_v01_m_v01_a_dtz81")}{p_end}
{phang}{cmd:. return list}{p_end}

{title:Remarks}

{pstd}
No equivalent helper exists in the R/Python NADA clients; it
operationalises the observation that the mapping between datalib's folder
tuple and NADA's {cmd:idno} is a string concatenation, not a translation
layer. NA-4 of {cmd:internal/datalib_nada_improvement_plan.md} (red-team
item R-E).

{title:Authors}

{pstd}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{pstd}Minh Cong Nguyen, World Bank{p_end}

{title:Also see}

{psee}Help: {helpb _dtlb_catalog}, {helpb _dtlb_svycheck}, {helpb _dtlb_vcheck}{p_end}
