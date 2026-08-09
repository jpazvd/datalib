{smcl}
{* *! version 1.6.0  datalib / UNICEF}{...}
{title:Title}

{p 4 8}{bf:_dtlb_check} {hline 2} Validate a datalib archive against the IHSN folder template and enforce MASTER / HARMONIZED separation{p_end}


{title:Syntax}

{p 8 16}{cmd:_dtlb_check}{cmd:,} {cmdab:p:ath(}{it:string}{cmd:)}
[{cmdab:c:ountry(}{it:string}{cmd:)}
{cmdab:s:urvey(}{it:string}{cmd:)}
{cmd:strict}]


{title:Description}

{p 4 4}{cmd:_dtlb_check} scans a datalib root (the curated IHSN archive, e.g.
{cmd:F:/datalib}) and checks every survey folder against the IHSN / World Bank
Microdata Library template created by {help _dtlb_mkdir:_dtlb_mkdir}:{p_end}

{p 8 8}CCC_YYYY_SSSS/{p_end}
{p 12 12}CCC_YYYY_SSSS_vNN_M/            (MASTER {hline 1} required){p_end}
{p 16 16}Data/{Original,Stata,Other}  Doc  Programs{p_end}
{p 12 12}CCC_YYYY_SSSS_vNN_M_vNN_A_CLCT/ (HARMONIZED {hline 1} 0 or more){p_end}
{p 16 16}Data/{Original,Stata,Other}  Doc  Programs{p_end}

{p 4 4}It reports a violation when: a survey/version name is not conformant; a
required subfolder is missing; a survey has no MASTER; or MASTER and HARMONIZED
data are not kept separate (a {cmd:_A_} file inside a {cmd:_M} folder, or a
non-harmonized file inside a {cmd:_A_} folder). Matching is case-insensitive.{p_end}


{title:Options}

{p 4 8}{cmdab:p:ath(}{it:string}{cmd:)} is {bf:required}: the datalib root to scan.{p_end}
{p 4 8}{cmdab:c:ountry(}{it:string}{cmd:)} restrict to one ISO3 country folder.{p_end}
{p 4 8}{cmdab:s:urvey(}{it:string}{cmd:)} restrict to one survey folder.{p_end}
{p 4 8}{cmd:strict} exit with error 459 if any violation is found (use in pipelines).{p_end}


{title:Stored results}

{p 4 8}{cmd:r(violations)}  number of violations{p_end}
{p 4 8}{cmd:r(surveys)}     surveys scanned{p_end}
{p 4 8}{cmd:r(master)}      MASTER version folders found{p_end}
{p 4 8}{cmd:r(harmonized)}  HARMONIZED version folders found{p_end}


{title:Examples}

{p 8 8}{cmd:. _dtlb_check , path("F:/datalib")}{p_end}
{p 8 8}{cmd:. _dtlb_check , path("F:/datalib") country(XAA)}{p_end}
{p 8 8}{cmd:. _dtlb_check , path("F:/datalib") strict}{p_end}


{title:Also see}

{p 4 8}{help _dtlb_mkdir}, {help datalib}{p_end}
