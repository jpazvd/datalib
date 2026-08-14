{smcl}
{* *! version 0.9.34  12aug2026}{...}
{vieweralsosee "datalib" "help datalib"}{...}
{vieweralsosee "datalib_resolve" "help datalib_resolve"}{...}
{vieweralsosee "datalib_vintages" "help datalib_vintages"}{...}
{vieweralsosee "datalib_adaptations" "help datalib_adaptations"}{...}
{viewerjumpto "Syntax" "datalib_create##syntax"}{...}
{viewerjumpto "Description" "datalib_create##description"}{...}
{viewerjumpto "Options" "datalib_create##options"}{...}
{viewerjumpto "Choosing the vintage" "datalib_create##vintage"}{...}
{viewerjumpto "The folder plan" "datalib_create##plan"}{...}
{viewerjumpto "Examples" "datalib_create##examples"}{...}
{viewerjumpto "Stored results" "datalib_create##results"}{...}
{cmd:help datalib_create}{right:Version 0.9.34}
{hline}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:datalib_create}
{cmd:,}
{opt country(CCC)}
{opt year(YYYY)}
{opt survey(SSSS)}
[{it:options}]

{p 8 17 2}
{cmd:datalib} {cmd:,} {opt create} {opt country(CCC)} {opt year(YYYY)} {opt survey(SSSS)}
[{it:options}]

{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Which folder}
{synopt:{opt adap:tation(HHHH)}}name of the adaptation, e.g. {cmd:ECAPOV}; implies an adaptation folder{p_end}
{synopt:{opt collection(HHHH)}}synonym of {opt adaptation()}; contract v1's word for the same token{p_end}
{synopt:{opt kin:d(master|adaptation)}}which of the two folder shapes; inferred from {opt adaptation()}{p_end}
{synopt:{opt vm(spec)}}master vintage: a number, {cmd:latest} or {cmd:next}{p_end}
{synopt:{opt va(spec)}}adaptation vintage: a number, {cmd:latest} or {cmd:next}{p_end}
{synopt:{opt master_version(spec)}}synonym of {opt vm()}{p_end}
{synopt:{opt adaptation_version(spec)}}synonym of {opt va()}{p_end}
{synopt:{opt root(string)}}library root; defaults to {cmd:${datalib}}, then {cmd:DATALIB_ROOT}{p_end}

{syntab:What goes in it}
{synopt:{opt pla:n(name)}}{cmd:default}, {cmd:ihsn2014} or {cmd:minimal}; default {cmd:default}{p_end}
{synopt:{opt dat:a(names)}}replace the plan's {cmd:Data/} leaves{p_end}
{synopt:{opt doc(names)}}replace the plan's {cmd:Doc/} leaves{p_end}
{synopt:{opt place:holder}}write a keep-file into every subfolder{p_end}
{synopt:{opt placeholdern:ame(string)}}name it something other than {cmd:.datalib-keep}; implies {opt placeholder}{p_end}

{syntab:Whether to write}
{synopt:{opt create}}actually create; without it the command only reports{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:datalib_create} builds a vintage folder and its subfolders under a datalib
library, following the folder grammar the rest of the package reads back:

{p 8 8 2}{it:CCC}{cmd:/}{it:CCC}{cmd:_}{it:YYYY}{cmd:_}{it:SSSS}{cmd:/}{it:CCC}{cmd:_}{it:YYYY}{cmd:_}{it:SSSS}{cmd:_v}{it:NN}{cmd:_M}{p_end}
{p 8 8 2}{it:CCC}{cmd:/}{it:CCC}{cmd:_}{it:YYYY}{cmd:_}{it:SSSS}{cmd:/}{it:CCC}{cmd:_}{it:YYYY}{cmd:_}{it:SSSS}{cmd:_v}{it:NN}{cmd:_M_v}{it:MM}{cmd:_A_}{it:HHHH}{p_end}

{pstd}
{bf:It reports by default and writes only with} {opt create}{bf:.} Every call
prints the paths it would make and returns them in {cmd:r()}, so a deposit script
can be inspected, diffed or dry-run against a live share before anything is
written. This is deliberate: the root is normally a network drive shared by a
team, and a mistyped country code creates a folder nobody notices for months.

{pstd}
The two folder shapes are siblings, not parent and child. A {bf:master} vintage
holds the data as received; an {bf:adaptation} holds a harmonised derivative of
one master, and its name carries the master it derives from. Adaptation vintages
are therefore numbered {it:within} a master: {cmd:_v02_M_v01_A_ECAPOV} is the
first ECAPOV built on master 2, and says nothing about ECAPOV under master 1.

{pstd}
A published vintage is immutable -- when a new version comes, the previous ones
are kept -- so this command never deletes or renames, and creating into a folder
that already exists is not an error. {cmd:r(existed)} tells you which happened.


{marker options}{...}
{title:Options}

{dlgtab:Which folder}

{phang}
{opt adaptation(HHHH)} names the adaptation and puts it in position 8 of the
folder name: {cmd:ECAPOV}, {cmd:HLT}, {cmd:SILC}, {cmd:IPUMS}. Giving it implies
{opt kind(adaptation)}, so {opt kind()} is rarely needed.

{phang}
{opt collection(HHHH)} is the same option under contract v1's vocabulary. The
2014 source note calls this token "the name of the adaptation"; the contract
calls it a collection. Both spellings are accepted; giving both with different
values is an error rather than a silent choice of one.

{phang}
{opt kind(master|adaptation)} selects the folder shape explicitly. It is inferred
from {opt adaptation()}/{opt collection()} and only needs to be given to state
{cmd:master} for clarity. {opt kind(master)} together with {opt collection()} is
a contradiction and is refused.

{phang}
{opt vm(spec)} and {opt va(spec)} take a vintage number ({cmd:1}, {cmd:01} or
{cmd:v01}), or one of the keywords {cmd:latest} and {cmd:next}. See
{help datalib_create##vintage:Choosing the vintage} below.

{phang}
{opt master_version()} and {opt adaptation_version()} are synonyms of {opt vm()}
and {opt va()}, kept because earlier versions of this command spelled them that
way. Passing both spellings of one option is refused.

{phang}
{opt root(string)} is the library root. Without it the command uses
{cmd:${datalib}}, then the {cmd:DATALIB_ROOT} environment variable, and errors if
neither is set. It does not run the {helpb datalib_root} discovery chain -- a
command that writes folders should be pointed at a root, not guess one.

{dlgtab:What goes in it}

{phang}
{opt plan(name)} chooses the subfolder set. See
{help datalib_create##plan:The folder plan} below.

{phang}
{opt data(names)} and {opt doc(names)} replace the chosen plan's {cmd:Data/} and
{cmd:Doc/} leaves respectively, one axis each, so
{cmd:plan(ihsn2014) data(Original Stata SPSS)} is the 2014 tree with SPSS added
rather than a restatement of eleven folders. They name {it:leaves}, not paths: a
value containing {cmd:/}, {cmd:\} or {cmd:..} is refused, because the root is
usually a network share and a name carrying a path would write outside the
vintage folder. Using either sets {cmd:r(deviation)} to 1 -- a convention that
can be departed from without leaving a trace is not a convention.

{phang}
{opt placeholder} writes a small text file into every subfolder created. The
reason to want one is that an empty {cmd:Doc/Technical/} is a claim -- "we
looked, there is none" -- and robocopy, which the {cmd:scripts/ps} sync toolbox
uses, does not carry empty directories without {cmd:/E}.

{phang}
{opt placeholdername(string)} names that file; the default is
{cmd:.datalib-keep}. It is deliberately not {cmd:.gitkeep}: a vintage folder on a
share is not a git working tree. Use {cmd:.gitkeep} for a tree that really is in
git, such as the committed test fixtures. Giving this option implies
{opt placeholder}.

{dlgtab:Whether to write}

{phang}
{opt create} performs the creation. Without it nothing is written and
{cmd:r(created)} is {cmd:0}.


{marker vintage}{...}
{title:Choosing the vintage}

{pstd}
{opt vm()} and {opt va()} accept {cmd:latest} and {cmd:next}, resolved by reading
the survey folder. When omitted, each defaults to whichever of the two matches
its role in the call:

{synoptset 30 tabbed}{...}
{synopt:{it:master folder}}{opt vm()} is the vintage being {it:created} -> {cmd:next}{p_end}
{synopt:{it:adaptation folder}}{opt vm()} names the master being {it:adapted} -> {cmd:latest}{p_end}
{synopt:}{opt va()} is the vintage being {it:created} -> {cmd:next}{p_end}
{p2colreset}{...}

{pstd}
Defaulting a folder you are about to create to {cmd:latest} would point the
creation at an already-published vintage, which is why the two roles default
differently. Both keywords stay available in both places, so {opt vm(latest)} on
a master is how you deliberately backfill a subfolder into an existing vintage.

{pstd}
{bf:One case is refused rather than guessed.} When both {opt vm()} and
{opt va()} are left to default {it:and} the named adaptation already exists under
a master other than the one {cmd:latest} resolves to, the command stops. Silently
starting a second lineage at {cmd:v01} beside an existing {cmd:v03} reads as a
duplicate and is very hard to notice later. The refusal names the masters that
already carry the adaptation and offers each resolved continuation as a clickable
command, so the choice is made once and recorded in the log. It stops rather than
prompting because a modal question cannot be answered by the conformance suite or
by an unattended deposit script.


{marker plan}{...}
{title:The folder plan}

{pstd}
The plan is data, not code, and names {it:leaves}: {cmd:Data/}, {cmd:Doc/} and
{cmd:Programs/} are structural and always created.

{synoptset 12 tabbed}{...}
{synopt:{cmd:default}}{cmd:Data/}{it:{Original Stata SPSS R Other}}, {cmd:Doc/}{it:{Questionnaires Reports Technical}}, {cmd:Programs/}{p_end}
{synopt:{cmd:ihsn2014}}the 2014 source note verbatim: no {cmd:Data/R}, no {cmd:Data/SPSS}; an adaptation keeps its harmonised files in {cmd:Data/Harmonized} and takes a bare {cmd:Doc/}{p_end}
{synopt:{cmd:minimal}}{cmd:Data/}, {cmd:Doc/}, {cmd:Programs/} only{p_end}
{p2colreset}{...}


{marker examples}{...}
{title:Examples}

{pstd}Report what a new master vintage would be, without writing it{p_end}
{phang2}{cmd:. datalib_create, country(TJK) year(2009) survey(TLSS)}{p_end}

{pstd}Create it{p_end}
{phang2}{cmd:. datalib_create, country(TJK) year(2009) survey(TLSS) create}{p_end}

{pstd}The next ECAPOV adaptation on the latest master{p_end}
{phang2}{cmd:. datalib_create, country(TJK) year(2009) survey(TLSS) adaptation(ECAPOV) create}{p_end}

{pstd}Pin both vintages explicitly{p_end}
{phang2}{cmd:. datalib_create, country(TJK) year(2009) survey(TLSS) adaptation(ECAPOV) vm(01) va(03) create}{p_end}

{pstd}The 2014 tree, with SPSS promoted, and a keep-file in every folder{p_end}
{phang2}{cmd:. datalib_create, country(TJK) year(2009) survey(TLSS) plan(ihsn2014)}{p_end}
{phang2}{cmd:     data(Original Stata SPSS) placeholder create}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(root)}}library root used{p_end}
{synopt:{cmd:r(survey_folder)}}{it:CCC}{cmd:_}{it:YYYY}{cmd:_}{it:SSSS}{p_end}
{synopt:{cmd:r(vintage_folder)}}the vintage folder name{p_end}
{synopt:{cmd:r(path)}}its full path{p_end}
{synopt:{cmd:r(plan)}}plan in force{p_end}
{synopt:{cmd:r(subfolders)}}the leaves, relative to {cmd:r(path)}{p_end}
{synopt:{cmd:r(existed)}}1 if the vintage folder was already there{p_end}
{synopt:{cmd:r(created)}}1 if this call created it{p_end}
{synopt:{cmd:r(data_original)}}{cmd:r(path)}{cmd:/Data/Original}{p_end}
{synopt:{cmd:r(data_stata)}}{cmd:r(path)}{cmd:/Data/Stata}{p_end}
{synopt:{cmd:r(data_r)}}{cmd:r(path)}{cmd:/Data/R}{p_end}
{synopt:{cmd:r(doc)}}{cmd:r(path)}{cmd:/Doc}{p_end}
{synopt:{cmd:r(programs)}}{cmd:r(path)}{cmd:/Programs}{p_end}
{p2colreset}{...}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(deviation)}}1 when {opt data()} or {opt doc()} departed from the plan{p_end}
{p2colreset}{...}

{pstd}
{bf:The three} {cmd:r(data_*)} {bf:macros are path constructors, not existence
claims} -- they are returned for any resolved vintage, matching what the R and
Python legs return, and a plan that omits {cmd:Data/R} does not create it. Read
{cmd:r(subfolders)} for what this call actually made.


{marker also}{...}
{title:Also see}

{psee}
Online:  {helpb datalib}, {helpb datalib_resolve}, {helpb datalib_vintages},
{helpb datalib_adaptations}, {helpb datalib_root}
{p_end}
