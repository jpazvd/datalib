*******************************************************************************
* _dtlb_ipums_extract
*! v1.11.0 12Aug2026                by Joao Pedro Azevedo (UNICEF)
*!                                  and Minh Cong Nguyen (World Bank)
* Submit and download an IPUMS-International extract via the IPUMS API.
*
* Status: SKELETON / DESIGN STUB. The submit-poll-download workflow is sketched
* but not exercised against the live API. Treat this file as a contract for the
* future implementation, not as production code.
*
* NOT SHIPPED. This file is deliberately absent from datalib.pkg as of 1.9.0.
* A skeleton with no help file has no business on a user's ado-path: -which-
* finds it, tab-completion offers it, and the only thing it can do is fail
* somewhere inside a workflow nobody has run. The manifest entry returns, with
* a .sthlp beside it, in the release that implements the workflow.
*
* Note for that release: -net install, replace- does not remove files dropped
* from a manifest, so 1.8.x installs keep a stale copy of this file.
*
* IPUMS API reference: https://developer.ipums.org/
*
* Usage (planned):
*   _dtlb_ipums_extract,                                 ///
*       country(BRA)                                     ///
*       year(2010)                                       ///
*       extract_id(<saved_extract_id>)                   ///
*       [api_key(<key>)]                                 ///
*       [out("${datalib}/BRA/bra_2010_census")]
*
* Reads the IPUMS_API_KEY environment variable if api_key() is omitted.
*
* Step P7 of internal/pipeline_improvement_plan.md.
*******************************************************************************

capture program drop _dtlb_ipums_extract
program define _dtlb_ipums_extract, rclass
    version 16

    syntax , country(string) year(integer) ///
             [extract_id(string) api_key(string) out(string) ///
              variables(string) samples(string) ///
              poll_seconds(integer 30) max_wait_minutes(integer 120) ///
              dryrun]

    // Normalise country to uppercase ISO3 immediately. The catalog scanner
    // only accepts 3-uppercase-letter country folders; passing country(bra)
    // would otherwise create an unscannable lowercase tree.
    local country = upper("`country'")
    if !regexm("`country'", "^[A-Z][A-Z][A-Z]$") {
        display as error "country() must be a 3-letter ISO code (got: `country')"
        exit 198
    }

    // -------- 1. Resolve API key --------
    if "`api_key'" == "" {
        local api_key : env IPUMS_API_KEY
        if "`api_key'" == "" {
            display as error "IPUMS_API_KEY env var not set and api_key() not provided"
            display as error "  obtain a key at https://developer.ipums.org/keys/"
            exit 198
        }
    }

    // -------- 2. Build request body --------
    // The IPUMS API accepts JSON describing the desired extract:
    //   { "datasets": { "<sample_id>": { "variables": [...] } },
    //     "data_format": "stata",
    //     "data_structure": { "rectangular": { "on": "P" } } }
    // For datalib: a saved_extract_id() shortcut lets users name a
    // pre-defined template stored in registry/ipums_extracts/<id>.yaml.

    if "`extract_id'" != "" {
        // load template from registry/ipums_extracts/`extract_id'.yaml
        // and override country/year before submission
        display as text "TODO: template loading not implemented in skeleton"
    }
    else {
        if "`variables'" == "" | "`samples'" == "" {
            display as error "either extract_id() or both variables() and samples() must be provided"
            exit 198
        }
    }

    if "`dryrun'" != "" {
        display as text "[DRYRUN] would submit IPUMS extract for `country' `year'"
        return local extract_id "DRYRUN-`country'-`year'"
        exit 0
    }

    // -------- 3. Submit extract --------
    // POST https://api.ipums.org/extracts/v1?collection=ipumsi
    //   Authorization: Bearer `api_key'
    //   Body: <JSON request>
    // Response includes a numeric extract number and initial status.

    display as text "TODO: extract submission not implemented in skeleton"
    display as text "  see https://developer.ipums.org/docs/v2/reference/extracts/"

    // -------- 4. Poll for completion --------
    // GET https://api.ipums.org/extracts/v1/<extract_number>?collection=ipumsi
    //   Authorization: Bearer `api_key'
    // Status field cycles through queued -> started -> produced -> completed,
    // or errors out as failed.
    // Poll every `poll_seconds' (default 30s) up to `max_wait_minutes' (default 120m).

    local extract_number 0   // placeholder

    // -------- 5. Download artifacts --------
    // Once complete, response includes `download_links.data.url` and
    // `download_links.ddi_codebook.url`. Both are short-lived signed URLs.
    // Use Stata's `copy "<url>" "<local>"` to fetch.

    if "`out'" == "" {
        local out "${datalib}/`country'/`country'_`year'_CENSUS/`country'_`year'_CENSUS_v01_M_v01_A_IPUMS"
    }

    * The canonical vintage tree, copied from _dtlb_mkdir.ado, which is the only
    * command allowed to define it. This block used to be the single place
    * in src/ that spelled the inner folders in lower case -- agreeing with the
    * manuscript's specification against every other file, and against the
    * loader that reads them (_dtlb_load.ado reads Data/Stata literally). A
    * skeleton is a contract for its implementation, so a contract written in the
    * wrong case is worse than no contract at all.
    capture mkdir "`out'"
    quietly _dtlb_folderplan
    foreach _s in `r(subfolders)' {
        capture mkdir "`out'/`_s'"
    }

    display as text "TODO: download not implemented in skeleton"
    display as text "  target: `out'"

    // -------- 6. Write datalib.yaml --------
    // After successful download, populate `out'/datalib.yaml with provenance:
    //   producer: IPUMS-International, Minnesota Population Center
    //   citation: Ruggles et al. (2024)
    //   url: https://international.ipums.org/
    //   license: licensed (per IPUMS terms)
    //   extract_id: <number>
    //   ipums_collection: ipumsi
    //   submitted_at, completed_at: timestamps

    display as text "TODO: datalib.yaml generation not implemented in skeleton"

    return local extract_number "`extract_number'"
    return local extract_status "skeleton"
    return local out_path "`out'"
end


*******************************************************************************
* IMPLEMENTATION NOTES (to do, in order):
*
* 1. Use Stata's `copy "https://api.ipums.org/..."` for HTTPS GET. The IPUMS
*    REST API accepts `Authorization: Bearer <key>` headers, but Stata's
*    built-in `copy` does not natively set headers. Two options:
*    (a) Shell out to `curl` (cross-platform; requires curl on PATH)
*    (b) Use `python:` block with the `ipumspy` library (cleaner; requires
*        Python configured in Stata 17+)
*    Recommend (b) for the v0.2 implementation; (a) as a no-Python fallback.
*
* 2. Saved-extract templates live at
*    stata/src/registry/ipums_extracts/<id>.yaml. Schema:
*      name: <human readable>
*      collection: ipumsi
*      samples: [br2010a, ar2010a, ...]
*      variables: [PERSONS, AGE, SEX, EDATTAIN, EMPSTAT, ...]
*      description: |
*        ...
*    Loaded via the vendored yaml_read.ado.
*
* 3. The IPUMS extract numbers are scoped per-user; clients should cache
*    (extract_number, country, year) tuples in
*    stata/src/registry/ipums_extracts/cache/<user>.yaml so that
*    re-running the script for the same template + (country, year) does not
*    submit a duplicate extract.
*
* 4. The datalib.yaml schema entry written by this command should use:
*      kind: adaptation
*      adaptation: IPUMS
*      version_master: v01    (the IBGE Censo this IPUMS extract is derived from)
*      aversion: v01
*    so that the catalog frame correctly identifies IPUMS extracts as
*    adaptations of the underlying census master, not as separate surveys.
*    See registry/harmonizations.yaml for the IPUMS dispatch entry.
*
* 5. Error handling: the IPUMS API returns 401 for bad auth, 429 for rate
*    limit, 500 for failed extract production. Match these to datalib's
*    error code convention (see internal/datalibweb_external_review.md
*    section 4 for the mapping).
*
* 6. Smoke test (qa/test_ipums_extract.do): exercise the dryrun path against
*    the BRA 2010 sample with a saved-extract template. Real-API tests are
*    out of scope for CI; manual verification on first deploy.
*******************************************************************************
