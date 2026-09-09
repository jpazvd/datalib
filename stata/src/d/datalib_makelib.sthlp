{smcl}
{hline}
{help datalib}{right:Version 1.2.0}
{cmd:help datalib_makelib}{right:Author: Joao Pedro Azevedo}
{right:Date: 2026-08-05}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :datalib_makelib}{hline 1} Build a synthetic microdata library.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:datalib_makelib} [{cmd:,} {opt path(dir)} {opt fam:ilies(list)}
{opt count:ries(list)} {opt seed(#)} {opt replace} {opt quiet:ly}]{p_end}

{title:Description}
{pstd}{cmd:datalib_makelib} writes a complete datalib library at a path you
choose: the IHSN folder grammar, master and adaptation vintages, labelled Stata
datasets, the original delivery, documentation, programs, and a
{cmd:datalib.yaml} per vintage. Every value in it is synthetic — drawn from
fixed distributions with a pinned seed — so two builds agree and no value
describes a real person or household.{p_end}

{pstd}It exists so this package can ship {it:no} microdata. A library cannot
travel through {cmd:datalib.pkg} in any case: {cmd:net install} places package
files in the PLUS tree by basename without preserving directories, so a nested
tree would arrive flattened, with most of its files overwriting one another. The
recipe ships instead of the result — which also means the library lands
somewhere writable, and belongs to you.{p_end}

{pstd}The generated library carries a {cmd:.datalib} marker recording that it is
synthetic. It is {it:not} marked read-only: it is your copy, in your directory,
and depositing into it is the point.{p_end}

{title:Options}
{synoptset 24 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt path(dir)}}Where to build. Default {cmd:datalib} in the working
directory — which is also the first place {helpb datalib_root} looks when
nothing is configured.{p_end}
{synopt:{opt families(list)}}{it:qa} builds the complete factorial — 3 countries x 2 years x 2 surveys, each with 2 master and 2 adaptation vintages (48 vintages). Every dimension has two members, so "latest" has a wrong answer available and a checker that always returns the only item present fails instead of coinciding. Used by qa/test_det.do.{p_end}
{synopt:}Which survey shapes to generate. Default
{cmd:generic}. {cmd:demo} reproduces the inventory this repository used to ship
as a committed example: five surveys, eight versions, the same module names and
observation counts.{p_end}
{synopt:{opt countries(list)}}ISO3 codes. Its first entry is also the country used by every named family ({cmd:pnad}, {cmd:mics}, ...); the full list is used by the {cmd:generic} family. Default
{cmd:ZZA ZZB} — the ISO 3166-1 user-assigned range, so a generated library
cannot be mistaken for a real archive and a request for a real survey fails as
it should.{p_end}
{synopt:{opt seed(#)}}Random-number seed. Default 20260805.{p_end}
{synopt:{opt replace}}Rebuild over an existing library. Without it, the command
refuses to write into a directory it did not create.{p_end}
{synopt:{opt quietly}}Suppress the progress report.{p_end}
{synoptline}

{title:Families}
{pstd}The module names are not invented. Each family reproduces what this
repository documents:{p_end}

{p2colset 5 18 20 2}{...}
{p2col :{cmd:pnad}}{cmd:dom}, {cmd:pes}, {cmd:both}, plus a DTZ92 adaptation{p_end}
{p2col :{cmd:pnadc}}{cmd:tri}, {cmd:anual}, plus a PANEL adaptation
({cmd:idbas}, {cmd:idrs}){p_end}
{p2col :{cmd:saeb}}{cmd:student}{p_end}
{p2col :{cmd:mics}}{cmd:hh}, {cmd:hl}, {cmd:wm}, {cmd:mn}, {cmd:bh}, {cmd:ch},
{cmd:fs} ({cmd:mn} is optional and {cmd:fs} is MICS6 onwards){p_end}
{p2col :{cmd:dhs}}{cmd:household}, {cmd:women}, {cmd:children}{p_end}
{p2col :{cmd:generic}}the default: two countries, a household and a person module per vintage, plus one adaptation{p_end}
{p2col :{cmd:demo}}the five-survey example inventory{p_end}
{p2colreset}{...}

{pstd}The MICS and DHS families also generate an {cmd:HLT} adaptation carrying
{cmd:svy_id}, {cmd:household_id} and {cmd:line_number} — the only merge keys
this package declares.{p_end}

{pstd}PISA and PIRLS are deliberately absent. Nothing in this repository refers
to them, to plausible values, or to replicate weights, so generating them would
invent a shape rather than reproduce one; and assessment data is
student-within-school rather than person-within-household, so supporting it is a
change to the folder grammar and the registry, not an option on a demo
builder.{p_end}

{title:Examples}
{p 6 16 2}Build a library to try the package against:{p_end}
{p 8 12}{stata "datalib_makelib"}{p_end}

{p 6 16 2}Reproduce the example library the repository used to ship:{p_end}
{p 8 12}{stata "datalib_makelib, families(demo) path(mydemo)"}{p_end}

{p 6 16 2}Generate several documented survey shapes at once:{p_end}
{p 8 12}{stata "datalib_makelib, families(\"pnad mics dhs\") path(mydemo) replace"}{p_end}

{title:Saved Results}
{synoptset 20 tabbed}
{synopthdr:Results}
{synoptline}
{synopt:{cmd:r(path)}}the library root{p_end}
{synopt:{cmd:r(vintages)}}number of vintages created{p_end}
{synoptline}

{title:Authors}
{p 4 4 2}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{p 4 4 2}Minh Cong Nguyen, World Bank{p_end}

{title:Also see}

{psee}
{helpb datalib} {helpb datalib_root} {helpb _dtlb_put} {helpb _dtlb_check} {helpb _dtlb_catalog}
{p_end}
