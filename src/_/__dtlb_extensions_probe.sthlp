{smcl}
{* *! version 0.1.0 17Jul2026}{...}
{hline}
help for {hi:__dtlb_extensions_probe}{right:datalib internals}
{hline}

{title:Title}

{p2colset 5 28 30 2}{...}
{p2col:{cmd:__dtlb_extensions_probe}}Detect datalib REST extensions on a catalog host{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 16 2}
{cmd:__dtlb_extensions_probe}{cmd:,} {opt host(url)} [{opt force}]

{title:Description}

{pstd}
Issues {cmd:GET} {it:host}{cmd:/info} and parses the expected JSON
({cmd:nada_api} version plus an {cmd:extensions} list such as
{cmd:audit-v1 token-v1}). Vanilla NADA deployments do not serve
{cmd:/info}: any failure — a 404, an unreachable host — returns empty
results and is {bf:not} an error. Callers use the result for feature
detection: for example, a future {cmd:audit_event(...)} first checks
{cmd:audit-v1} is present and silently no-ops when it is not, so nothing
breaks against stock NADA hosts.

{pstd}
The name is deliberately {it:probe}, not "capability negotiation": the
command detects datalib's own REST extras on hosts that serve them; it
does not propose an upstream NADA standard. Results are cached per session
(one global per host); {opt force} re-probes. The cache is informational,
not a trust boundary — an audit or token POST must still succeed against
the same TLS-validated host that served the data.

{title:Options}

{phang}{opt host(url)} (required) — the catalog base URL (typically
{helpb _dtlb_catalogregistry}'s {cmd:r(base_url)}); a trailing slash is
tolerated.{p_end}

{phang}{opt force} — bypass and refresh the session cache.{p_end}

{title:Stored results}

{p2colset 5 24 28 2}{...}
{p2col:{cmd:r(nada_api)}}reported NADA API version ("" when /info absent){p_end}
{p2col:{cmd:r(extensions)}}space-separated extensions ("" when none){p_end}
{p2col:{cmd:r(probed)}}1 = live probe, 0 = session cache{p_end}
{p2colreset}{...}

{title:Remarks}

{pstd}
When {cmd:r(nada_api)} is non-empty and differs from the registry's
{cmd:api_version}, callers should warn: that is the early signal of an
upstream API migration (R-H in the improvement plan), fixed by a registry
edit rather than an emergency code release. Internal helper
(double-underscore tier); NA-3 of
{cmd:internal/datalib_nada_improvement_plan.md}.

{title:Authors}

{pstd}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{pstd}Minh Cong Nguyen, World Bank{p_end}

{title:Also see}

{psee}Help: {helpb __dtlb_api_read}, {helpb _dtlb_catalogregistry}{p_end}
