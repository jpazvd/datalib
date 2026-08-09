{smcl}
{* *! version 0.1.0 17Jul2026}{...}
{hline}
help for {hi:__dtlb_userhome}{right:datalib internals}
{hline}

{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:__dtlb_userhome}}Per-user datalib configuration directory{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 16 2}
{cmd:__dtlb_userhome} [{cmd:,} {opt os(string)}]

{title:Description}

{pstd}
Returns the per-user datalib configuration directory in {cmd:r(datalib_home)}:
{cmd:${USERPROFILE}\.datalib} on Windows, {cmd:${HOME}/.datalib} on macOS and
Linux. The directory is where the catalog-registry user override
({cmd:catalogs.yaml}), the registry cache ({cmd:cache/}), and the audit log
live. The command only computes the path; it does not create the directory.

{pstd}
The dispatch matches the {it:literal} {cmd:c(os)} strings {cmd:Windows},
{cmd:MacOSX}, and {cmd:Unix} exactly. Substring matches (such as {cmd:"Mac"}
or {cmd:"win"}) are deliberately not used: a partial match that falls through
silently would return a junk path on one platform and produce
hard-to-diagnose cache misses. Any other {cmd:c(os)} value is an error
(198), never a fallback.

{title:Options}

{phang}
{opt os(string)} overrides the operating-system string. {it:Testing only}:
Stata provides no way to set {cmd:c(os)}, so the test suite uses this option
to exercise all three branches (and the error branch) on any host. Production
callers must not pass it.

{title:Stored results}

{p2colset 5 24 28 2}{...}
{p2col:{cmd:r(datalib_home)}}the per-user datalib directory{p_end}
{p2colreset}{...}

{title:Remarks}

{pstd}
This is an internal helper (double-underscore tier) introduced by NA-2 of
the NADA-API improvement plan; it may be renamed or refactored without
notice. {cmd:${USERPROFILE}}/{cmd:${HOME}} are used rather than Stata's
{cmd:~} expansion (unreliable across versions and platforms) and rather than
{cmd:c(sysdir_personal)} (which is the personal {it:ado} directory — code,
not configuration).

{title:Authors}

{pstd}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{pstd}Minh Cong Nguyen, World Bank{p_end}
