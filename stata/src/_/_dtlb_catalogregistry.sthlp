{smcl}
{* *! version 0.1.0 17Jul2026}{...}
{hline}
help for {hi:_dtlb_catalogregistry}{right:datalib helpers}
{hline}

{title:Title}

{p2colset 5 26 28 2}{...}
{p2col:{cmd:_dtlb_catalogregistry}}Resolve a catalog short name to its NADA REST deployment{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 16 2}
{cmd:_dtlb_catalogregistry}{cmd:,} {opt get(short)}
[{opt registryhome(dir)} {opt nofet:ch} {opt accept:auth}]

{title:Description}

{pstd}
{cmd:_dtlb_catalogregistry} maps a catalog short name ({cmd:wb},
{cmd:ihsn}, or a user-added entry) to the base URL, API version, and
authentication model of the NADA deployment it identifies. It is the
data-driven seam that lets {cmd:_dtlb_catalog} speak to multiple microdata
catalogs without hard-coded URLs: adding a catalog is a YAML edit, not a
code change.

{pstd}
Resolution walks four sources and stops at the first whose file exists
{it:and} carries the requested entry (a source that exists but lacks the
entry falls through, so a user override with only custom catalogs does not
hide the shipped ones):

{phang2}1. {bf:user override} — {cmd:<home>/catalogs.yaml}{p_end}
{phang2}2. {bf:cache} — {cmd:<home>/cache/catalogs.yaml} when 24 hours old
or less (a stale cache is still consulted, with a note, when the canonical
registry is unreachable){p_end}
{phang2}3. {bf:network} — the canonical registry at
{cmd:https://jpazvd.github.io/datalib-dev/catalogs.yaml}, served via GitHub
Pages from {cmd:docs/catalogs.yaml} on {cmd:main}; a successful fetch
refreshes the cache{p_end}
{phang2}4. {bf:bundled fallback} — {cmd:stata/src/registry/catalogs.yaml} shipped
with the package (offline use){p_end}

{pstd}
where {cmd:<home>} is the per-user datalib directory returned by
{helpb __dtlb_userhome} ({cmd:~/.datalib}). Because the canonical copy
lives outside the package release cycle, an upstream URL change (a catalog
moving hosts, an API version bump) is a one-line edit on {cmd:main}, not a
package release.

{title:Options}

{phang}
{opt get(short)} (required) names the catalog to resolve. Shipped entries:
{cmd:wb} (World Bank Microdata Library) and {cmd:ihsn} (IHSN Central
Catalog, metadata-only). Short names are case-insensitive.

{phang}
{opt registryhome(dir)} overrides the per-user datalib directory for this
call — the isolation hook used by the test suite (mirroring the
{cmd:configdir()} precedent in the datalib-unicef configuration seam).

{phang}
{opt nofetch} skips the network stage entirely (sources 1, 2, and 4 only).
Useful for offline runs and deterministic tests.

{phang}
{opt acceptauth} records one-time consent for a {it:user-override} entry
whose {cmd:auth_type} is not {cmd:none}. Such an entry causes datalib to
send the user's credential to that {cmd:base_url}, so the first use
requires this explicit option; consent is remembered as a marker file and
logged to {cmd:<home>/audit.log}. Shipped and canonical entries never
require it.

{title:Registry file schema}

{pstd}Two-level YAML subset, parsed without external dependencies:{p_end}

{p 8 8 2}{cmd:wb:}{break}
{space 2}{cmd:name: World Bank Microdata Library}{break}
{space 2}{cmd:base_url: https://microdata.worldbank.org/index.php/api}{break}
{space 2}{cmd:api_version: v2}{break}
{space 2}{cmd:auth_type: x-api-key}{break}
{space 2}{cmd:default: true}{break}
{space 2}{cmd:metadata_only: false}

{pstd}
{cmd:auth_type} must be one of {cmd:x-api-key} (NADA registered-access
key), {cmd:bearer} (datalib's own REST extension), or {cmd:none}; anything
else is rejected so that a typo fails closed before any credential is
resolved. {cmd:metadata_only: true} marks catalogs (like the IHSN central
catalog) whose records point back to producer sites for the data itself.

{title:Stored results}

{p2colset 5 24 28 2}{...}
{p2col:{cmd:r(short)}}the short name as resolved{p_end}
{p2col:{cmd:r(name)}}display name{p_end}
{p2col:{cmd:r(base_url)}}NADA API base URL (no trailing slash){p_end}
{p2col:{cmd:r(api_version)}}expected NADA API version{p_end}
{p2col:{cmd:r(auth_type)}}{cmd:x-api-key} | {cmd:bearer} | {cmd:none}{p_end}
{p2col:{cmd:r(default)}}1 if flagged as the default catalog{p_end}
{p2col:{cmd:r(metadata_only)}}1 if downloads redirect to producers{p_end}
{p2col:{cmd:r(source)}}{cmd:user_override} | {cmd:cache} | {cmd:network} | {cmd:bundled_fallback}{p_end}
{p2col:{cmd:r(file)}}file (or URL) the entry was read from{p_end}
{p2colreset}{...}

{title:Examples}

{phang}{cmd:. _dtlb_catalogregistry, get(wb)}{p_end}
{phang}{cmd:. display "`r(base_url)' (`r(source)')"}{p_end}
{phang}{cmd:. _dtlb_catalogregistry, get(ihsn) nofetch}{p_end}

{title:Remarks}

{pstd}
NA-1 of the NADA-API improvement plan
({cmd:internal/datalib_nada_improvement_plan.md}); the resolution order and
the consent gate implement that plan's R-A and R-B red-team mitigations.
The canonical URL requires GitHub Pages to be enabled on the repository
(Settings → Pages → {cmd:main} branch, {cmd:/docs} folder); until it is,
resolution proceeds through the cache and bundled stages.

{title:Authors}

{pstd}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{pstd}Minh Cong Nguyen, World Bank{p_end}

{title:Also see}

{psee}Help: {helpb _dtlb_catalog}, {helpb __dtlb_api_read}, {helpb __dtlb_userhome}{p_end}
