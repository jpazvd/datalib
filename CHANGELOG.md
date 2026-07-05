# Changelog

All notable changes to **datalib** are documented in this file.
Format is based on [Keep a Changelog](https://keepachangelog.com/).
Commit hashes in the 2026-07-04 entry reference the mirror repo (jpazvd/datalib, branch `trip`), where that work was first committed before being ported here.

## 2026-07-04

Three workstreams: hardening the **INEP SAEB downloader** (and fetching SAEB 2023);
starting **Phase 6 — IHSN/DDI documentation & conformance**; and prototyping a
**cross-language `datalib` accessor** (Stata / Python / R) over a shared taxonomy spec.

### Added

- **Stata `_dtlb_put`** — generic deposit command (the write side of the trio): builds
  the IHSN skeleton, writes `<version>[_module].dta`, preserves `Data/Original`, guards
  MASTER immutability, and gates on `_dtlb_check`. (`afde357`)
- **Python package** — `pyproject.toml` (pip-installable) + pytest suite (6 tests, all
  passing). (`1393a2c`)
- **R package** — `DESCRIPTION`/`NAMESPACE` + testthat tests; sources moved under `R/R/`. (`3c96e6d`)
- **Cross-language parity contract** in `docs/taxonomy.md` — canonical option names and
  values shared identically across Stata / Python / R. (`4c822ad`)
- **`docs/taxonomy.md`** — the shared datalib/IHSN specification: folder taxonomy,
  MASTER/HARMONIZED separation, path resolution, and the `get`/`put`/`check` contract
  implemented identically in Stata, Python, and R. (`d8ff746`)
- **Python `datalib` package** (`python/datalib/`) — `get()`/`put()`/`check()` over the
  IHSN archive. `put()` builds the skeleton, writes `<version>[_module].dta`, generates
  DDI + Dublin Core + codebook, and enforces MASTER immutability + MASTER/HARMONIZED
  separation; root from `DATALIB_ROOT`; `.dta` via pyreadstat. Verified end-to-end. (`62e4320`)
- **R `datalib` prototype** (`R/datalib.R`) — `dl_get()`/`dl_put()`/`dl_check()` mirroring
  the Python reference; resolves identical paths and validates the same archive
  (verified cross-language). (`0ea5282`)

- **`_ihsncheck.ado`** (+ `_ihsncheck.sthlp`) — IHSN structural conformance
  validator. Scans a datalib root, checks every survey/version folder against the
  IHSN template built by `_mkdir`, and **enforces MASTER (`_M`) vs HARMONIZED
  (`_A_CLCT`) separation** (a `_A_` file inside a `_M` folder, or vice-versa, is a
  violation). Case-insensitive; returns `r(violations)/r(surveys)/r(master)/r(harmonized)`;
  `strict` exits 459 for pipeline gating. (`53ce8fd`)
- **`02_programs/src/py/generate_ddi.py`** — IHSN metadata generator. From a Stata
  `.dta` (read via `pyreadstat`) it emits **DDI-Codebook 2.5 XML**, **Dublin Core
  XML**, and a human-readable **`_codebook.md`**, parsing country/year/survey/version
  from the IHSN filename and tagging each file MASTER or HARMONIZED. (`8e353c6`)
- **`UPDATE_PLAN.md`** — full-repo review synthesis + 7-phase update plan; documents
  the `F:/data` (raw staging) vs `F:/datalib` (curated IHSN archive) split and the
  MASTER/HARMONIZED separation requirement. (`273e596`)
- **SAEB 2023** added to `download-inep-saeb-microdata.py` — `microdados_saeb_2023.zip`
  (student microdata, single file in 2023) + `..._2023_educacao_infantil.zip`. (`b2ab625`)
- **`02_programs/src/py/README.md`** — documents the microdata download scripts:
  usage, `F:/data` destination, incremental/retry behavior, SAEB edition coverage
  1995–2023, and the SAEB 2025 status (not yet released). (`7adcf59`)

### Changed

- **Namespaced internal Stata helpers with `_dtlb_`** — renamed `_ihsncheck` →
  `_dtlb_check` (avoids collisions with generic names); legacy engine helpers
  (`_dlw`/`_mkdir`/…) scheduled for the same treatment in the Phase-2 refactor. (`afde357`)
- **`.gitignore`** now whitelists package manifests (`pyproject.toml`, `DESCRIPTION`,
  `NAMESPACE`, `*.toml`). (`4c822ad`)
- **SAEB downloader hardened** (`download-inep-saeb-microdata.py`): retry flaky INEP
  downloads up to 5× with backoff + connect/read timeouts (the server resets large
  transfers, `ConnectionResetError 10054`), removing partial files before each retry
  and returning `None` on final failure so a corrupt archive is never unzipped; skip
  extraction when a target folder is already populated (fully incremental re-runs);
  256 KB read chunks. (`e0f1ced`)

### Fixed

- **SAEB download destination** moved `C:/data` → `F:/data/INEP_Microdata/saeb`
  (`download-inep-saeb-microdata.py`), matching where the data tree lives on this
  setup and off the nearly-full C: drive. (`5729d60`)

### Data (not tracked in git)

- Downloaded **SAEB 2023** microdata to `F:/data/INEP_Microdata/saeb`
  (`microdados_saeb_2023.zip`, 661 MB, + educação infantil), extracting the
  grade-5/grade-9 student CSVs. Existing editions 1995–2021 (~21.8 GB) left untouched.
