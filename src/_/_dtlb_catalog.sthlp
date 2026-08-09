{smcl}
{* *! version 1.6.0 17Jul2026}{...}
{hline}
help for {hi:_dtlb_catalog}{right:datalib helpers}
{hline}

{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:_dtlb_catalog}}Frame-backed survey catalog — local filesystem or remote NADA catalog{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 16 2}
{cmd:_dtlb_catalog}{cmd:,} {opt scan} [{opt path(dir)}]

{p 8 16 2}
{cmd:_dtlb_catalog}{cmd:,} {opt list} [{opt country(CCC)} {opt year(YYYY)} {opt survey(SSSS)}]

{p 8 16 2}
{cmd:_dtlb_catalog}{cmd:,} {opt list} {opt catalog(short)}
[{opt country(CCC)} {opt year(YYYY)} {opt survey(SSSS)} {opt sk(text)}
{opt all} {opt max_rows(#)} {opt registryhome(dir)} {opt nofet:ch}]

{p 8 16 2}
{cmd:_dtlb_catalog}{cmd:,} {opt files} {opt catalog(short)}
{{opt idno(IDNO)} | {opt country(CCC)} {opt year(YYYY)} {opt survey(SSSS)}
[{opt version(vNN)} {opt adaptation(HHHH)} {opt aversion(vNN)}]}
[{opt registryhome(dir)} {opt nofet:ch}]

{p 8 16 2}
{cmd:_dtlb_catalog}{cmd:,} {opt clear}

{title:Description}

{pstd}
{cmd:scan} walks the local archive at {cmd:${datalib}} (or {opt path()})
and builds the frame {cmd:dtlb_catalog}, one row per master or adaptation
vintage, parsing {cmd:datalib.yaml} metadata where the vendored YAML
library is available. Re-entry is {it:rebuild, not append}. {cmd:list}
without {opt catalog()} filters and prints that frame.

{pstd}
{cmd:list} with {opt catalog()} is the {cmd:api://} read story (NA-5):
rows come from the NADA REST search of the named catalog — {cmd:wb},
{cmd:ihsn}, or any entry resolvable by {helpb _dtlb_catalogregistry} — and
land in the same frame with the same structural columns (parsed from each
record's idno through {helpb _dtlb_idno}; blank when an idno does not
follow the convention), plus {cmd:idno}, {cmd:title}, and
{cmd:source} ({cmd:api:}{it:short}) columns.

{pstd}
Pagination is {bf:capped and visible}: NADA serves at most 100 rows per
page, and one page is fetched by default. When more rows match,
{cmd:r(more_pages_available)}=1 and a note says so — honest, instead of a
silent multi-minute network loop. {opt all} streams the remaining pages
(progress every 5 pages) up to {opt max_rows()} (default 5000), so even
{opt all} cannot fetch a 12,826-survey catalog by accident. A
{opt country()} filter keeps every realistic query under the cap.

{pstd}
{cmd:files} (NA-6) wraps the {cmd:data_files/{it:idno}} endpoint: the
complete file list for one survey lands in frame {cmd:dtlb_files}
({cmd:file_id}, {cmd:file_name}, {cmd:file_format}, {cmd:file_size},
{cmd:description}, {cmd:download_url}), and {cmd:r()} carries shortcuts
for the first 5 files plus {cmd:r(n_files)}, {cmd:r(total_bytes)}, and
{cmd:r(has_stata)} — worth checking before a multi-gigabyte
{cmd:copy} blocks for ten minutes. {cmd:clear} drops both frames.

{title:Options}

{phang}{opt catalog(short)} — catalog short name from the registry
({helpb _dtlb_catalogregistry}). Required for {cmd:files}; switches
{cmd:list} to the REST path.{p_end}

{phang}{opt sk(text)} — free-text search terms for the NADA search
({opt survey()} is folded into it on the REST path; spaces are encoded).{p_end}

{phang}{opt all} — fetch every matching page (bounded by
{opt max_rows()}).{p_end}

{phang}{opt max_rows(#)} — hard cap on fetched rows with {opt all};
default 5000.{p_end}

{phang}{opt idno(IDNO)} — study identifier for {cmd:files}, any case
(normalised through {helpb _dtlb_idno}). Without it, the
{opt country()}/{opt year()}/{opt survey()} triple is used;
{opt version()} defaults to {cmd:v01} with a note.{p_end}

{phang}{opt registryhome(dir)}, {opt nofetch} — passed through to
{helpb _dtlb_catalogregistry} (isolation/testing and offline use).{p_end}

{title:Stored results}

{pstd}{cmd:scan}: {cmd:r(n_versions)}, {cmd:r(n_masters)},
{cmd:r(n_adaptations)}, {cmd:r(path)}. Filesystem {cmd:list}:
{cmd:r(N)}.{p_end}

{pstd}REST {cmd:list} (NA-5 contract): {cmd:r(rows_found)},
{cmd:r(rows_returned)}, {cmd:r(pages_fetched)},
{cmd:r(more_pages_available)}, {cmd:r(status_code)}, {cmd:r(api_url)},
plus {cmd:r(N)} (= rows returned).{p_end}

{pstd}{cmd:files} (D-4, both shapes): {cmd:r(frame)}={cmd:dtlb_files},
{cmd:r(idno)}, {cmd:r(n_files)}, {cmd:r(total_bytes)},
{cmd:r(has_stata)}, {cmd:r(status_code)}, {cmd:r(api_url)}, and
{cmd:r(file_}{it:k}{cmd:_name)} / {cmd:r(file_}{it:k}{cmd:_format)} /
{cmd:r(file_}{it:k}{cmd:_size)} for the first {it:k} ≤ 5 files (macros
truncate at 5 with a note; the frame is always complete).{p_end}

{title:Examples}

{phang}{cmd:. _dtlb_catalog, scan}{p_end}
{phang}{cmd:. _dtlb_catalog, list country(XAA) year(2015) survey(XHS)}{p_end}
{phang}{cmd:. _dtlb_catalog, list catalog(wb) country(XAA)}{p_end}
{phang}{cmd:. _dtlb_catalog, list catalog(ihsn) all max_rows(2000)}{p_end}
{phang}{cmd:. _dtlb_catalog, files catalog(wb) country(XAA) year(2015) survey(XHS)}{p_end}
{phang}{cmd:. _dtlb_catalog, clear}{p_end}

{title:Remarks}

{pstd}
The REST paths speak plain NADA (the same endpoints the {cmd:nadar},
{cmd:PyNADA}, and {cmd:nadaverse} clients wrap); parsing is the minimal
{cmd:__dtlb_json} field extractor, whose assumptions the committed
fixture tree under {cmd:qa/fixtures/api/} pins — run
{cmd:do qa/run_smoke.do} after changes. The variables/dictionary endpoint
is deliberately deferred (N2, v1.5), as is default auto-pagination (N1).
NA-5/NA-6 of {cmd:internal/datalib_nada_improvement_plan.md}.

{title:Authors}

{pstd}Joao Pedro Azevedo, UNICEF (jpazevedo@unicef.org){p_end}
{pstd}Minh Cong Nguyen, World Bank{p_end}

{title:Also see}

{psee}Help: {helpb _dtlb_catalogregistry}, {helpb _dtlb_idno},
{helpb __dtlb_api_read}, {helpb datalib}{p_end}
