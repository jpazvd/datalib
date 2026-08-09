{smcl}
{hline}
{help datalib}{right:Version 1.2.0}
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

{title:Description}
{pstd}{cmd:datalib_config} is an alias for {helpb getuserconfig}, under the
{cmd:datalib_*} name the R and Python legs use for the same operation. Every
option is passed through and every saved result is the one {cmd:getuserconfig}
returned.{p_end}

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
