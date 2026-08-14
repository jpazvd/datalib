{smcl}
{hline}
{help datalib}{right:Version 1.1.0}
{cmd:help datalib_root}{right:Author: Joao Pedro Azevedo}
{right:Date: 2026-08-05}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :datalib_root}{hline 1} Resolve the datalib library root.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:datalib_root} [{cmd:,} {opt root(path)} {opt set} {opt find}
{opt cand:idates(list)} {opt nodisc:over} {opt disc:over} {opt quiet:ly}
{opt config(file)} {opt configdir(dir)} {opt require(stages)}]{p_end}

{title:Description}
{pstd}{cmd:datalib_root} answers one question — which library are we reading? —
and reports where the answer came from. Resolution is {it:candidate selection}:
the first non-empty candidate in the chain below wins, and it is returned as
given, without checking the disk.{p_end}

{p2colset 5 24 26 2}{...}
{p2col :{it:stage}}{it:source}{p_end}
{p2col :{cmd:argument}}the {opt root()} option{p_end}
{p2col :{cmd:global}}{cmd:${datalib}}{p_end}
{p2col :{cmd:env}}the {cmd:DATALIB_ROOT} environment variable{p_end}
{p2col :{cmd:config_generic}}the {cmd:datalib:} key in {cmd:user_config.yml}{p_end}
{p2col :{cmd:config_package}}the same key in {cmd:datalib_config.yml}{p_end}
{p2colreset}{...}

{pstd}Not checking the disk is the point. If your archive is momentarily
unreachable — a VPN down, a drive unmapped, a typo in your configuration — you
get back the path {it:you} configured, and the failure happens when a file is
opened. The root is never quietly replaced by a different library, because
numbers that came from the wrong archive are far more expensive than an
error.{p_end}

{pstd}When {bf:nothing at all} is configured, and only then, the command may
{it:discover} a library: first any paths given in {opt candidates()}, then the
working directory and its parents, then your home directory, and finally a demo
library you have already built -- searched for at {cmd:~/.datalib/demo} and, in a
working clone, at {cmd:examples/demo_library}. Nothing is created for you: a
resolver that wrote files when its read failed would surprise you at the worst
moment, so when no demo exists the command says how to build one. Discovery reports stage
{cmd:discovered} or {cmd:demo}, announces itself, and — see {opt set} — never
writes the global.{p_end}

{title:Options}
{synoptset 24 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt root(path)}}An explicit candidate. Outranks everything.{p_end}
{synopt:{opt set}}Also store the resolved root in {cmd:${datalib}}. Refused for
the {cmd:discovered} and {cmd:demo} stages: {cmd:clear all} does {it:not} drop
globals, so a root nobody chose would persist for the whole session and be read
by every later command, including the deposit path.{p_end}
{synopt:{opt find}}Validate the configured candidates against the disk with
{cmd:_dl_islib}, trying {it:candidate}{cmd:/datalib} before {it:candidate}
itself. A candidate that is set but is not a library is an error naming it,
never a silent step to the next one.{p_end}
{synopt:{opt candidates(list)}}Extra discovery candidates, tried first,
space-separated.{p_end}
{synopt:{opt nodiscover}}Stop after the configured stages. Never discover, never
use a demo.{p_end}
{synopt:{opt discover}}Permit discovery in a batch run, where it is refused by
default. A scheduled job that reads a library nobody named is the worst case
this command has, because batch Stata exits 0 even after an error and leaves no
signal behind.{p_end}
{synopt:{opt quietly}}Suppress the discovery notice. The stage is still
reported.{p_end}
{synopt:{opt config(file)}}Read exactly this configuration file; the two-file
fallback is off.{p_end}
{synopt:{opt configdir(dir)}}Look for the two configuration files in this
directory. The Stata counterpart of {cmd:DATALIB_CONFIG_DIR}, which Stata cannot
set in its own session; it is what makes the golden cases hermetic.{p_end}
{synopt:{opt require(stages)}}Fail unless the root came from one of the named
stages. Checked on every path that returns a root, including the default one. {cmd:require(configured)} is shorthand for the five stages an operator
names. Put it at the top of any do-file that must not run against a library
someone else's machine happened to find.{p_end}
{synoptline}

{title:Examples}
{p 6 16 2}Resolve, and say where it came from:{p_end}
{p 8 12}{stata "datalib_root"}{p_end}
{p 8 12}{stata "display r(root) \" via \" r(source_stage)"}{p_end}

{p 6 16 2}Pin a library for the session:{p_end}
{p 8 12}{stata "datalib_root, root(F:/datalib) set"}{p_end}

{p 6 16 2}Refuse to run against anything the operator did not name:{p_end}
{p 8 12}{stata "datalib_root, require(configured)"}{p_end}

{title:Saved Results}
{pstd}{cmd:datalib_root} saves the following in {cmd:r()}:{p_end}
{synoptset 20 tabbed}
{synopthdr:Results}
{synoptline}
{synopt:{cmd:r(root)}}the resolved root{p_end}
{synopt:{cmd:r(source_stage)}}{cmd:argument}, {cmd:global}, {cmd:env},
{cmd:config_generic}, {cmd:config_package}, {cmd:discovered} or {cmd:demo}{p_end}
{synopt:{cmd:r(descended)}}1 if the resolver descended into
{it:candidate}{cmd:/datalib}{p_end}
{synoptline}

{title:Authors}
{p 4 4 2}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{p 4 4 2}Minh Cong Nguyen, World Bank{p_end}

{title:Also see}

{psee}
{helpb datalib} {helpb datalib_config} {helpb getuserconfig} {helpb datalib_makelib} {helpb _dtlb_put}
{p_end}
