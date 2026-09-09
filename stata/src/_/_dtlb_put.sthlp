{smcl}
{* *! version 1.6.0  datalib}{...}
{title:Title}

{p 4 8}{bf:_dtlb_put} {hline 2} Deposit a dataset into the datalib archive (IHSN-compliant){p_end}


{title:Syntax}

{p 8 16}{cmd:_dtlb_put} [{cmd:using} {it:filename}]{cmd:,}
{cmdab:c:ountry(}{it:string}{cmd:)}
{cmdab:y:ear(}{it:string}{cmd:)}
{cmdab:s:urvey(}{it:string}{cmd:)}
[{cmdab:m:odule(}{it:string}{cmd:)}
{cmdab:coll:ection(}{it:string}{cmd:)}
{cmd:vm(}{it:##}{cmd:)} {cmd:va(}{it:##}{cmd:)}
{cmd:root(}{it:path}{cmd:)} {cmdab:p:ath(}{it:path}{cmd:)}
{cmdab:orig:inal(}{it:filename}{cmd:)}
{cmd:overwrite} {cmd:replace} {cmd:nostrict} {cmdab:noch:eck}]


{title:Description}

{p 4 4}{cmd:_dtlb_put} files the dataset in memory (or {it:filename} given with
{cmd:using}) into the curated datalib archive following the IHSN taxonomy (see
{it:00_documentation/taxonomy.md}). It is the write-side counterpart of the read
accessor and of {help _dtlb_check:_dtlb_check}, and mirrors {cmd:datalib.put()}
in Python and {cmd:dl_put()} in R (same canonical option names and values).{p_end}

{p 4 4}It builds the IHSN version skeleton, writes
{it:<version>}[{cmd:_}{it:module}]{cmd:.dta} into {cmd:Data/Stata}, optionally
preserves a raw {cmd:original()} file under {cmd:Data/Original} (MASTER only),
then validates the survey with {cmd:_dtlb_check}.{p_end}

{p 4 4}Without {cmd:collection()} the deposit is a {bf:MASTER} ({cmd:_M}) -
the original data as provided, which is {bf:immutable}: an already-archived file
is refused unless {cmd:overwrite} is given; publish a new version with
{cmd:vm()}/{cmd:va()} instead. With {cmd:collection()} the deposit is a
{bf:HARMONIZED} adaptation, written to its own sibling {cmd:_A_}{it:CLCT} folder,
never mixed with the master.{p_end}


{title:Options}

{p 4 8}{cmd:country()}, {cmd:year()}, {cmd:survey()} are {bf:required} and define CCC_YYYY_SSSS.{p_end}
{p 4 8}{cmd:module()} names a dataset within the version (e.g. {it:adult}).{p_end}
{p 4 8}{cmd:collection()} harmonization code (e.g. {it:GMD}) - deposit as HARMONIZED.{p_end}
{p 4 8}{cmd:vm()} / {cmd:va()} master / adaptation version numbers (default 01).{p_end}
{p 4 8}{cmd:root()} archive root; default {cmd:${datalib}}. {cmd:path()} is a synonym.{p_end}
{p 4 8}{cmd:original()} raw file to preserve under {cmd:Data/Original} (MASTER only).{p_end}
{p 4 8}{cmd:overwrite} (synonym {cmd:replace}) allow replacing an archived file.{p_end}
{p 4 8}{cmd:nostrict} (synonym {cmd:nocheck}) skip the post-deposit conformance check.{p_end}


{title:Stored results}

{p 4 8}{cmd:r(target)}   full path of the deposited file{p_end}
{p 4 8}{cmd:r(version)}  version-folder name{p_end}
{p 4 8}{cmd:r(kind)}     MASTER or HARMONIZED{p_end}
{p 4 8}{cmd:r(violations)} conformance violations after deposit (0 = pass){p_end}



{title:Read-only libraries}

{pstd}This command refuses to write into a library whose {cmd:.datalib} marker file carries {cmd:readonly: 1}, and exits with error 198 naming the path. The check reads the marker, walking up from the target, rather than comparing path strings -- so it still holds for a copy of the tree, and cannot be defeated by 8.3 short names, junctions, UNC-versus-mapped spellings or case.{p_end}

{pstd}A library built by {helpb datalib_makelib} is marked synthetic ({cmd:demo: true}) but is {it:not} read-only: it is your copy, in your directory, and depositing into it is the point. Read-only is opt-in, for a shared fixture or reference tree you want protected.{p_end}

{title:Examples}

{p 8 8}{cmd:. _dtlb_put, country(XAA) year(2023) survey(SAEB)}{p_end}
{p 8 8}{cmd:. _dtlb_put, country(XAA) year(2023) survey(SAEB) collection(HCL) module(adult)}{p_end}
{p 8 8}{cmd:. _dtlb_put using rawfile.dta, country(XAA) year(2023) survey(SAEB) original(raw.zip)}{p_end}


{title:Also see}

{p 4 8}{help _dtlb_check}, {help _dtlb_mkdir}, {help _dtlb_load}, {help datalib}{p_end}
