{smcl}
{* *! version 0.1.0 17Jul2026}{...}
{hline}
help for {hi:__dtlb_api_read}{right:datalib internals}
{hline}

{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:__dtlb_api_read}}GET one resource over file:// or http(s):// for the api:// backend{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 16 2}
{cmd:__dtlb_api_read} {cmd:using} {it:"url"}{cmd:,}
[{opt method(GET)}
{opt auth_type(x-api-key|bearer|none)}
{opt headers(string)}
{opt query(string)}
{opt timeout(#)}
{opt user_agent(string)}
{opt saving(filename)}]

{title:Description}

{pstd}
{cmd:__dtlb_api_read} is the single transport funnel for datalib's
{cmd:api://} backend. Every remote read — catalog search, file lists, the
extensions probe — goes through it, so auth headers, user-agent policy, and
error mapping live in exactly one place. Only {cmd:GET} is supported: the
v1 client is a catalog {it:consumer}; NADA admin verbs are an explicit
non-goal.

{pstd}
{cmd:file://} URLs read the local filesystem (the conformance-fixture
backend): the scheme and any query string are stripped, and a missing path
is retried with {cmd:.json} appended, so extensionless endpoint names such
as {cmd:/info} resolve beside {cmd:*.json} fixtures. The file:// path
{bf:never consults credentials}.

{pstd}
{cmd:http(s)://} URLs require Stata 16 or later (the file:// backend works
on Stata 15). When no request header is needed — {cmd:auth_type(none)},
default user agent, no {cmd:headers()} — the transport is pure Stata
{helpb copy}. When a header must be sent, the call shells out to
{cmd:curl}, because {cmd:copy} cannot set request headers; if curl is not
on the PATH, the command fails with a message saying exactly that. This is
the documented fallback-to-curl gap in the paper's pure-Stata transport
discussion.

{title:Options}

{phang}
{opt method(GET)} — request method; anything but GET is refused.

{phang}
{opt auth_type()} — how to authenticate, normally taken from
{helpb _dtlb_catalogregistry}'s {cmd:r(auth_type)}. The dispatch to a
concrete header happens here and only here: {cmd:x-api-key} sends
{cmd:X-API-KEY:} {it:token} (NADA registered access); {cmd:bearer} sends
{cmd:Authorization: Bearer} {it:token} (datalib's own REST extension);
{cmd:none} (default) sends no auth header and never resolves a credential.
Tokens come from {cmd:__dtlb_credential} ({cmd:DATALIB_TOKEN}
environment variable, then the {cmd:${datalib_token}} global).

{phang}
{opt headers(string)} — one extra raw header line to send (curl transport).

{phang}
{opt query(string)} — query string (without the leading {cmd:?}) appended
to the URL, e.g. {cmd:query(ps=100&page=2)}.

{phang}
{opt timeout(#)} — network timeout in seconds; default 30.

{phang}
{opt user_agent(string)} — override the user agent (default
{cmd:datalib/0.9 (Stata} {it:version}{cmd:)}). The literal word
{cmd:browser} sends a Mozilla string: some web-application firewalls
(UNHCR's microdata catalog, notably) block non-browser agents. Passing
this option forces the curl transport, since {cmd:copy} always sends
Stata's own agent string.

{phang}
{opt saving(filename)} — write the response body here. By default the body
lands in a uniquely-named file under {cmd:c(tmpdir)} — deliberately
{it:not} a Stata tempfile, which would be deleted the moment this program
exits, dangling {cmd:r(body_path)}. Callers may {cmd:erase} the file when
done.

{title:Stored results}

{p2colset 5 24 28 2}{...}
{p2col:{cmd:r(status_code)}}HTTP status; 404 for a missing file:// fixture; 0 = transport failure{p_end}
{p2col:{cmd:r(body_path)}}path of the response body ("" on failure){p_end}
{p2col:{cmd:r(content_type)}}best-effort content type{p_end}
{p2col:{cmd:r(url)}}the URL as requested (query appended){p_end}
{p2col:{cmd:r(rc)}}transport return code (0 on success){p_end}
{p2colreset}{...}

{title:Examples}

{phang}{cmd:. __dtlb_api_read using "file://qa/fixtures/api/info"}{p_end}
{phang}{cmd:. __dtlb_api_read using "https://catalog.ihsn.org/index.php/api/catalog/search", query(ps=100&country=BRA)}{p_end}

{title:Remarks}

{pstd}
Internal helper (double-underscore tier); may be refactored without
notice. NA-2 and NA-7 of the NADA-API improvement plan
({cmd:internal/datalib_nada_improvement_plan.md}).

{title:Authors}

{pstd}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{pstd}Minh Cong Nguyen, World Bank{p_end}

{title:Also see}

{psee}Help: {helpb _dtlb_catalogregistry}, {helpb _dtlb_catalog}, {helpb __dtlb_userhome}{p_end}
{helpb __dtlb_extensions_probe}
