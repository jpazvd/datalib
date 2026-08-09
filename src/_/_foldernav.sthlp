{smcl}
{hline}
{help datalib}{right:Version 1.6.0}
{cmd:help _foldernav}{right:Author: Joao Pedro Azevedo}
{right:Date: 2026-08-04}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :_foldernav}{hline 1} Folder Navigation Utility for datalib repository.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:_foldernav} [{it:varlist}] [{cmd:if}] [{cmd:in}] [{cmd:,} {cmd:country(string)}
{cmd:path(string)} {cmd:subfoldr(string)} {cmd:filename(string)}]{p_end}

{pstd}All arguments are optional; {cmd:_foldernav} with no arguments lists the top level of
{cmd:${datalib}}.{p_end}

{title:Description}
{pstd}{cmd:_foldernav} is designed to navigate through folder structures in the datalib
repository, enabling the selection of subfolders based on the structure of the data
collection. It dynamically constructs folder paths and displays available options for
browsing the data repository structure.{p_end}
{pstd}{cmd:_foldernav} is an internal helper for the {cmd:datalib} dispatcher, which calls
it to render the clickable navigation. It is not intended to be called directly by user
code, and its interface may change without notice.{p_end}

{title:Options}
{synoptset 27 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt country(string)}}Specifies the country code to filter the folder navigation.
If not specified, all available countries are displayed. This option is optional.{p_end}
{synopt:{opt path(string)}}Specifies the base path for folder navigation. If not
specified, the global macro {cmd:${datalib}} is used by default. Ignored by the DATA, DOC
and PROGRAMS sections, which always build their path from {cmd:${datalib}}. This option is
optional.{p_end}
{synopt:{opt subfoldr(string)}}Specifies the subfolder to navigate to. The folder depth is
determined by the number of underscore-separated tokens in the subfolder name. This option
is optional.{p_end}
{synopt:{opt filename(string)}}Accepted for call-compatibility with {cmd:datalib} and
currently ignored: the program parses it but never reads it. This option is
optional.{p_end}
{synoptline}

{title:Details}
{pstd}The {cmd:_foldernav} program automatically determines folder structure depth based
on the number of underscore-separated tokens in the subfolder specification (e.g.
{cmd:ZZA_2022_XHS} has 3 tokens):{p_end}
{p2colset 5 30 32 2}{...}
{p2col :Tokens{hline 1}}Path Construction{p_end}
{p2colset 5 30 32 2}{...}
{p2col :1}Single-level folder (a country){p_end}
{p2col :3}Two-level path: stub1/folder (a survey folder){p_end}
{p2col :5}Three-level path: stub1/stub1_stub2_stub3/folder (a master vintage
folder){p_end}
{p2col :8}Three-level path: stub1/stub1_stub2_stub3/folder (an adaptation vintage folder;
exactly 8 tokens){p_end}
{p2colreset}{...}

{pstd}Only these four counts construct a path. Any other count (2, 4, 6, 7) leaves the
subfolder unchanged and is treated as a single level, and a count above 8 lists
nothing.{p_end}

{pstd}DATA, DOC and PROGRAMS are handled specially: they list the contents of the
corresponding subfolder of a vintage and print clickable links back to {cmd:datalib}. They
are {it:resume-only}. Each reads the folder left in {cmd:r(subfoldr)} by the previous call
rather than taking one of its own, which is how the links {cmd:datalib} prints reach them.
Called with no such folder available - in a fresh session, or after any intervening r-class
command has cleared {cmd:r()} - they exit with error 198 and explain how to resume, rather
than guessing a folder. They ignore {opt path()}.{p_end}

{title:Examples}
{p 6 16 2}Display all available countries in the datalib repository:{p_end}
{p 8 12}{stata "_foldernav"}{p_end}

{p 6 16 2}Restrict the listing to a single country link rather than every country present
({opt country()} replaces the directory listing; it does not descend into it):{p_end}
{p 8 12}{stata "_foldernav, country(ZZA)"}{p_end}

{p 6 16 2}Navigate to a specific subfolder structure:{p_end}
{p 8 12}{stata "_foldernav, subfoldr(ZZA_2022_XHS)"}{p_end}

{p 6 16 2}List the Stata datasets of the vintage most recently navigated. The DATA, DOC
and PROGRAMS sections are not standalone: they resume from the folder left in
{cmd:r(subfoldr)} by the previous call, which is how the links {cmd:datalib} prints reach
them. Run on their own, with no prior navigation, they exit with error 198 rather than
guess a folder:{p_end}
{p 8 12}{stata "_foldernav, subfoldr(ZZA_2022_XHS_v01_M)"}{p_end}
{p 8 12}{stata "_foldernav, subfoldr(DATA)"}{p_end}

{title:Saved Results}
{pstd}{cmd:_foldernav} saves the following in {cmd:r()}:{p_end}
{synoptset 20 tabbed}
{synopthdr:Results}
{synoptline}
{synopt:{cmd:r(subfoldr)}}The subfolder being navigated, relative to {cmd:${datalib}}. On a
DATA, DOC or PROGRAMS call this is the folder carried over from the previous call, so the
next section click can resume from it.{p_end}
{synopt:{cmd:r(subfoldrN)}}The same value, suffixed with the number of underscore-separated
tokens in the requested subfolder (1, 3, 5 or 8) - not a depth level. Set by navigation
calls only.{p_end}
{synopt:{cmd:r(fullfoldr)}}The listed folder, relative to {cmd:${datalib}} (set by the
DATA, DOC and PROGRAMS sections only).{p_end}
{synoptline}

{title:Authors}
{p 4 4 2}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{p 4 4 2}Minh Cong Nguyen, World Bank{p_end}

{title:Version}
{p 4 4 2}1.1{p_end}

{title:Date}
{p 4 4 2}2026-08-04{p_end}

{title:Version History}
{p 4 4 2}1.1 (2026-08-04): extracted into its own ado file and added to the package
manifest, so a clean install resolves it without first running {cmd:_dtlb_load}. The DATA,
DOC and PROGRAMS sections now capture the previous folder once on entry and fail with a
readable error 198 when it is unavailable, instead of building a path from a missing
{cmd:r()} result and dying with error 601. They also stop after listing, so they no longer
fall through into the generic navigation block.{p_end}
{p 4 4 2}1.0 (2024-03-21): initial release, defined inline inside
{cmd:_dtlb_load.ado}.{p_end}

{title:Also see}

{psee}
Related functions: {helpb datalib} {helpb _dtlb_load} {helpb _dtlb_mkdir}
{helpb _dtlb_ctrycheck} {helpb _dtlb_svycheck} {helpb _dtlb_vcheck}
{helpb _dtlb_adaptcheck}
{p_end}
