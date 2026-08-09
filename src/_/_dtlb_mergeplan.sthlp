{smcl}
{* *! version 1.6.0  08Aug2026}{...}
{cmd:help _dtlb_mergeplan}{right:Version 1.6.0}
{hline}

{title:Title}

{p2colset 5 22 24 2}{...}
{p2col :{cmd:_dtlb_mergeplan} {hline 2}}Plan and execute a multi-module load{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 17 2}
{cmd:_dtlb_mergeplan}{cmd:,} {opt dir(path)} {opt stem(string)} {opt mod:ules(namelist)}
[{opt strict} {opt nowarn:ing}]

{title:Description}

{pstd}
{cmd:_dtlb_mergeplan} loads one or more modules of a vintage, joined along the
hierarchy they declare about themselves (see {helpb _dtlb_modspec}), and leaves
the result in memory. It is the internal helper behind {helpb datalib}'s
{opt module()} option.

{title:What it refuses, and why that is the point}

{pstd}
{cmd:teacher} and {cmd:student} are both children of {cmd:classroom}. Asking
for the two together is many-to-many, and merging it blindly returns one row
per {bf:pair} — 3 teachers by 30 students is 90 rows that look exactly like
data. This command errors instead, naming both modules and their common
parent.

{pstd}
Every other failure mode here announces itself; a cartesian product does not.

{title:Validation}

{pstd}
Keys are checked {bf:against the data in hand}: the variables must exist, and
they must actually identify rows, before anything is merged on them. A wrong
declaration that is trusted produces a wrong answer silently, which is worse
than no declaration at all.

{title:The report}

{pstd}
The join is reported by default. A join the user cannot see is a join they
cannot check.

{pstd}
The diagnostic number is the {bf:fan-out} — how many distinct parent keys the
finer module carries — not each module's own unique count, which validation has
already proved equal to its row count. 400 persons over 120 households is
one-to-many; 400 over 400 would be one-to-one and would mean the join did the
wrong thing.

{title:Options}

{phang}{opt strict} promotes unmatched rows from a warning to an error.{p_end}
{phang}{opt nowarning} suppresses the report.{p_end}

{title:Stored results}

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(plan)}}the join performed, e.g. {cmd:student <- classroom}{p_end}
{synopt:{cmd:r(spec_source)}}{cmd:yaml} | {cmd:char} | {cmd:legacy} | {cmd:mixed}{p_end}
{synopt:{cmd:r(base)}}the finest module; the result is one row per unit of it{p_end}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(n_modules)}}how many modules were joined{p_end}
{synopt:{cmd:r(unmatched)}}rows that failed to match a parent{p_end}
{synopt:{cmd:r(rows_}{it:module}{cmd:)}}rows in each module{p_end}
{synopt:{cmd:r(distinct_}{it:module}{cmd:)}}distinct join keys carried{p_end}

{title:Also see}

{psee}
{helpb datalib}, {helpb _dtlb_modspec}, {helpb datalib_whence}
