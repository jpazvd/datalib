{smcl}
{hline}
{help datalib}{right:Version 1.7.2}
{cmd:help datalib_config}{right:Author: Joao Pedro Azevedo}
{right:Date: 2026-08-05}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :datalib_config}{hline 1} Read the operator's datalib configuration.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:datalib_config} [{cmd:,} {opt user(name)} {opt config(file)} {opt configdir(dir)} {opt quiet:ly}]{p_end}

{p 6 16 2}{cmd:datalib_config}{cmd:,} {opt create} [{opt root(path)} {opt user(name)} {opt configdir(dir)} {opt quiet:ly}]{p_end}

{p 6 16 2}{cmd:datalib_config}{cmd:,} {opt edit} [{opt user(name)} {opt config(file)} {opt configdir(dir)}]{p_end}

{p 6 16 2}{cmd:datalib_config}{cmd:,} {opt list}{p_end}

{p 6 16 2}{cmd:datalib_config}{cmd:,} {opt retryv:olumes}{p_end}

{title:Description}
{pstd}{cmd:datalib_config} is mostly an alias for {helpb getuserconfig}, under
the {cmd:datalib_*} name the R and Python legs use for the same operation. For
every option below except {opt list} and {opt retryvolumes}, the option is
passed through unchanged and every saved result is the one
{cmd:getuserconfig} returned.{p_end}

{pstd}{opt list} and {opt retryvolumes} are handled here and do not reach
{cmd:getuserconfig}: they report and repair state that belongs to this
package rather than to the configuration file.{p_end}

{title:Reporting and repair}
{pstd}{opt list} shows every configuration source that is present, which one
is in force, and — separately — which {cmd:datalib.ado} is answering. Those
are two questions, and an operator with more than one answer to either has no
other way to see it: two installed packages can both provide {cmd:datalib}
and whichever is first on the adopath wins silently.{p_end}

{pstd}{opt retryvolumes} forgets which drives were recorded unreachable. When
a mapped drive does not respond, datalib records it and skips it thereafter
{it:without probing it again}, because probing a disconnected share costs the
operating system's own timeout — measured at over six minutes. That record
has to be forgettable, or a drive that comes back would stay invisible. Run
this after reconnecting one.{p_end}

{pstd}Two names for one command is deliberate. The command it wraps is not
datalib-specific — one configuration file is meant to serve sibling tools, and
only the {cmd:datalib:} key belongs to this package — while the alias lets the
three languages name the same operation identically.{p_end}

{pstd}That includes {opt create} and {opt edit}, which write the configuration
file and open it. Both are additive and neither rewrites an existing block; see
{helpb getuserconfig##create:getuserconfig}. The write side has no counterpart in
the R and Python legs, which read the same two files but leave authoring them to
whoever set the machine up.{p_end}

{title:Saved Results}
{pstd}See {helpb getuserconfig}.{p_end}

{title:Authors}
{p 4 4 2}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{p 4 4 2}Minh Cong Nguyen, World Bank{p_end}

{title:Also see}

{psee}
{helpb getuserconfig} {helpb datalib_root} {helpb datalib_makelib} {helpb datalib}
{p_end}
