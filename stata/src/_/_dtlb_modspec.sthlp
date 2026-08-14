{smcl}
{* *! version 1.6.0  08Aug2026}{...}
{cmd:help _dtlb_modspec}{right:Version 1.6.0}
{hline}

{title:Title}

{p2colset 5 22 24 2}{...}
{p2col :{cmd:_dtlb_modspec} {hline 2}}Resolve a module's declared structure{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 17 2}
{cmd:_dtlb_modspec}{cmd:,} {opt dir(path)} {opt mod:ule(name)} [{opt stem(string)}]

{title:Description}

{pstd}
{cmd:_dtlb_modspec} answers, for one module of one vintage: what is its unit of
observation, which variables identify a row, and what does it hang off. It is
an internal helper used by {helpb _dtlb_mergeplan} and {helpb datalib}.

{title:Resolution order}

{phang}1. {cmd:datalib.yaml} {cmd:module_schema:} — the {bf:authority}. It is
language-neutral, so the R and Python clients read the same declaration and the
golden conformance cases stay comparable.{p_end}

{phang}2. {cmd:_dta} characteristics — the {bf:mirror}, for a {cmd:.dta} that
has left its folder. Characteristics are Stata-only, so they can never be the
authority without making the three implementations disagree by construction.{p_end}

{phang}3. The legacy hardcoded table, for archives predating any declaration.{p_end}

{pstd}
{cmd:r(source)} reports which stage answered: a resolver that will not say how
it decided cannot be audited.

{pstd}
A declaration needs {bf:both} a level and keys. A level alone is not a
declaration: the planner would fail later on the missing key with an error
pointing at the data rather than at the incomplete metadata.

{title:What it does not do}

{pstd}
It reports what is {bf:declared}. It does not verify that the named variables
exist or that the keys are unique — that is {helpb _dtlb_mergeplan}'s job,
against the data in hand, because a declaration is a claim rather than a fact.

{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(level)}}unit of observation; empty when nothing is declared{p_end}
{synopt:{cmd:r(keys)}}variables that uniquely identify a row{p_end}
{synopt:{cmd:r(parent)}}module one level up; empty at a root{p_end}
{synopt:{cmd:r(parentkeys)}}the parent's keys, which this module also carries{p_end}
{synopt:{cmd:r(source)}}{cmd:yaml} | {cmd:char} | {cmd:legacy} | {cmd:none}{p_end}

{title:Also see}

{psee}
{helpb datalib}, {helpb _dtlb_mergeplan}, {helpb datalib_whence}
