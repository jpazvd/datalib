{smcl}
{hline}
{help datalib}{right:Version 1.2.0}
{cmd:help getuserconfig}{right:Author: Joao Pedro Azevedo}
{right:Date: 2026-08-05}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :getuserconfig}{hline 1} Load per-operator paths from the user configuration file(s).{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:getuserconfig} [{cmd:,} {opt user(name)} {opt config(file)} {opt configdir(dir)} {opt quiet:ly}]{p_end}

{pstd}Create the file, or the caller's block in it:{p_end}

{p 6 16 2}{cmd:getuserconfig}{cmd:,} {opt create} [{opt root(path)} {opt user(name)} {opt configdir(dir)} {opt quiet:ly}]{p_end}

{pstd}Open it in the Do-file Editor:{p_end}

{p 6 16 2}{cmd:getuserconfig}{cmd:,} {opt edit} [{opt user(name)} {opt config(file)} {opt configdir(dir)}]{p_end}

{title:Description}
{pstd}{cmd:getuserconfig} reads a small YAML file keyed by machine username and
publishes that operator's paths. It has no dependencies: the constrained
two-level schema is parsed natively, so it runs unchanged on locked-down
machines with no YAML or Python stack.{p_end}

{pstd}The file is deliberately generic — sibling tools read the same one. Of the
keys below, {cmd:datalib} is the only one this package uses; the rest are parsed
and published untouched so a single file can serve several tools.{p_end}

{p 8 12}{cmd:githubFolder}  {cmd:teamsRoot}  {cmd:zDrive}  {cmd:zDriveUNC}  {cmd:datalib}{p_end}

{pstd}Two files are searched, in order, and they are never merged. The full
block comes from the first file that has one; the library root from the first
file whose block carries a non-empty {cmd:datalib:} key — so a generic file that
exists but lacks the key falls through to the package file. Key presence
decides, not file presence.{p_end}

{p 8 12}{cmd:~/.config/user_config.yml}     -> stage {cmd:config_generic}{p_end}
{p 8 12}{cmd:~/.config/datalib_config.yml}  -> stage {cmd:config_package}{p_end}

{pstd}One session side effect, which the phrase "only reads" should not hide: when the
block carries a {cmd:datalib:} key and the global {cmd:${datalib}} is empty, this command
fills the global. It never overwrites a global you have already set.{p_end}

{marker create}{...}
{title:Creating the file}

{pstd}Without {opt create} or {opt edit} the command writes no files: a read that
writes when it fails makes the golden cases non-hermetic and surprises the
operator at the least convenient moment. Both options are therefore opt-in, and
both are additive.{p_end}

{pstd}{opt create} writes {cmd:user_config.yml} when it is absent and appends the
caller's block when that is what is missing. It never rewrites a block that is
already there — so a second run cannot move a root that pipelines depend on, and
the option is safe to leave in a start-up script. Where a block already exists,
{opt create} says so and stops; use {opt edit} to change it. {cmd:r(action)}
reports which of {cmd:created}, {cmd:appended} or {cmd:unchanged} happened, and
{cmd:r(created)} comes back only when something was actually written — so a
caller can tell "your block was already there" from "I just wrote it".{p_end}

{pstd}With no {opt root()}, the {cmd:datalib:} key is written commented out. A
placeholder path that parsed would be worse than none: it would fill
{cmd:${datalib}} with a directory nobody chose, and the failure would surface much
later, at a {helpb use}, as a missing file rather than as missing
configuration.{p_end}

{pstd}Two lines are all the file needs, so writing it by hand is equally fine:{p_end}

{p 8 12}{cmd:. getuserconfig, create root(F:/datalib)}{p_end}
{p 8 12}{cmd:. getuserconfig, edit}{p_end}

{pstd}{opt edit} opens the file the reader would have used, and only that: pointed
at a path with no file, it reports the error rather than quietly creating one.
Under {cmd:stata -b} it prints the path instead, since a batch run can neither
show a Do-file Editor window nor close it.{p_end}

{pstd}It opens the file and stops there, without going on to read it, so the
usual {cmd:r()} results are not set and only {cmd:r(edited)} is returned. That
matters for the commonest reason to want the editor — the file has no block for
you yet — which would otherwise open the file and then report failure for
something that had just succeeded.{p_end}

{pstd}Neither option touches {cmd:profile.do}. Editing a machine's start-up file
is a bigger commitment than configuring one tool, and it belongs to whoever
administers the machine.{p_end}

{title:Options}
{synoptset 24 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt user(name)}}Whose block to read. Default {cmd:c(username)}.{p_end}
{synopt:{opt config(file)}}Read exactly this file; the fallback is off. The Stata
counterpart of {cmd:DATALIB_CONFIG}.{p_end}
{synopt:{opt configdir(dir)}}Search the two-file list here. The counterpart of
{cmd:DATALIB_CONFIG_DIR}, which Stata cannot set in its own session.{p_end}
{synopt:{opt create}}Write {cmd:user_config.yml}, or append this user's block to it.
Additive only: an existing block is left exactly as it is.{p_end}
{synopt:{opt root(path)}}The library root to write into the new block. Requires
{opt create}. Without it the key is written commented out.{p_end}
{synopt:{opt edit}}Open the configuration file the reader would use. It must
already exist.{p_end}
{synopt:{opt quietly}}Suppress the confirmation and the error text; the return
codes are unchanged.{p_end}
{synoptline}

{title:Saved Results}
{synoptset 20 tabbed}
{synopthdr:Results}
{synoptline}
{synopt:{cmd:r(user)}}the username read{p_end}
{synopt:{cmd:r(config)}}the file the block came from{p_end}
{synopt:{cmd:r(datalib)}}the library root, if the block carries one{p_end}
{synopt:{cmd:r(source_stage)}}{cmd:config_generic}, {cmd:config_package} or {cmd:unset}{p_end}
{synopt:{cmd:r(source_file)}}the file the root came from{p_end}
{synopt:{cmd:r(githubFolder)}, {cmd:r(teamsRoot)}, {cmd:r(zDrive)}, {cmd:r(zDriveUNC)}}pass-through keys{p_end}
{synopt:{cmd:r(created)}}with {opt create}: the file this call wrote. Not
returned when the block was already there and nothing was written{p_end}
{synopt:{cmd:r(action)}}with {opt create}: {cmd:created}, {cmd:appended} or
{cmd:unchanged}{p_end}
{synopt:{cmd:r(edited)}}with {opt edit}: the file opened{p_end}
{synoptline}

{pstd}The same four pass-through keys are also published as globals, for the
sibling tools that expect them.{p_end}

{title:Errors}
{p2colset 5 14 16 2}{...}
{p2col :601}no configuration file was found (with {opt edit}: none to open){p_end}
{p2col :459}a file exists but has no block for this user{p_end}
{p2col :198}{opt root()} was given without {opt create}{p_end}
{p2col :603}{opt create} could not write the file{p_end}
{p2colreset}{...}

{title:Authors}
{p 4 4 2}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{p 4 4 2}Minh Cong Nguyen, World Bank{p_end}

{title:Also see}

{psee}
{helpb datalib_root} {helpb datalib_config} {helpb datalib_makelib} {helpb datalib}
{p_end}
