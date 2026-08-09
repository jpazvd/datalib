# datalib taxonomy — the shared specification

This is the **single source of truth** for how `datalib` organizes survey
microdata. The Stata command, the Python package, and the R package all implement
*this* document. It follows the **IHSN / World Bank Microdata Library** archival
convention.

## Two roots (keep them separate)

| Setting | Env var | Role | Example |
|---|---|---|---|
| raw staging | `RAWDATA` / `${rawdata}` | downloads as received (INEP, IBGE FTP) | `F:/data` |
| **curated archive** | **`DATALIB_ROOT` / `${datalib}`** | the organized IHSN library | `F:/datalib` |

Nothing is hardcoded. Every tool resolves the archive root through the same
ordered chain, and the first non-empty candidate wins:

| # | Stage | Stata | R | Python |
|---|---|---|---|---|
| 1 | `argument` | `root()` | `root =` | `root=` |
| 2 | `global` | `${datalib}` | — | — |
| 3 | `env` | `DATALIB_ROOT` | `DATALIB_ROOT` | `DATALIB_ROOT` |
| 4 | `option` | — | `options(datalib.root=)` | — |
| 5 | `config_generic` | `~/.config/user_config.yml` | same | same |
| 6 | `config_package` | `~/.config/datalib_config.yml` | same | same |

**Resolution never touches the disk.** A candidate is selected, not verified.
This matters more than it looks: an archive that is momentarily unreachable — a
VPN down, a drive unmapped, a typo in the config — comes back as the path *you*
configured and fails when a file is actually opened. It is never replaced by
some other library whose numbers would not reconcile with yesterday's.

The two configuration files are read **block by block and never merged**: the
root comes from the first file whose block for your username carries a
non-empty `datalib:` key. A generic file that exists but has no such key falls
through to the package file — key presence decides, not file presence. The
resolver reports which stage supplied the root (`r(source_stage)` in Stata,
`report = TRUE` in R and Python), and the stage names above are byte-identical
in all three languages.

**Writing the file.** Resolution reads; it never writes. Authoring the file is a
separate, opt-in act, and only the Stata leg offers it: `getuserconfig, create`
writes `user_config.yml` when it is absent and appends your block when that is
what is missing, and `getuserconfig, edit` opens the file the reader would use.
Both are additive — neither ever rewrites a block that already exists, so a
second run cannot move a root that pipelines depend on. With no `root()`, the
`datalib:` key is written commented out rather than filled with a placeholder:
a path nobody chose would resolve happily and fail much later, at a `use`, as a
missing file rather than as missing configuration. The R and Python legs read
the same two files but leave authoring them alone, so anything they consume was
written deliberately by a person or by the Stata command.

Isolation hooks, for tests and for scripts that must not read a real home:
`DATALIB_CONFIG` pins exactly one file (fallback off); `DATALIB_CONFIG_DIR`
moves the search elsewhere (fallback preserved). Stata additionally accepts
`config()` and `configdir()` options, because Stata cannot set an environment
variable in its own session.

**Discovery.** When *nothing at all* is configured, the Stata leg may search for
a library near the working directory or in your home (stage `discovered`), and
fall back to a demo library you have built (stage `demo`). Discovery is
deliberately narrower than resolution: it is refused in batch runs, it never
fills `${datalib}`, and it announces itself. A configured root is never
replaced by it.

**Two homes, deliberately not unified.** `~/.config` holds operator
*configuration*, shared with sibling tools. `~/.datalib` holds datalib's own
*state* — the catalog registry cache, credentials, the audit log. They serve
different purposes and have different lifetimes; merging them would put
credentials in a file people share.

## Folder template

```
<DATALIB_ROOT>/
  <CCC>/                                    ISO3 country code
    <CCC_YYYY_SSSS>/                        survey folder
      <CCC_YYYY_SSSS_vMM_M>/                MASTER      (required, >=1)
        Data/Original   Data/Stata   Data/Other   Doc   Programs
      <CCC_YYYY_SSSS_vMM_M_vAA_A_CLCT>/     HARMONIZED  (0 or more)
        Data/Original   Data/Stata   Data/Other   Doc   Programs
```

- **CCC** — ISO3 country code (uppercase). **YYYY** — year data collection started.
- **SSSS** — survey acronym (uppercase; e.g. `MICS`, `DHS`, `SAEB`, `PNAD`).
- **vMM** — master version (`01`, `02`, …). **vAA** — adaptation version.
- **CLCT** — harmonization/collection code (e.g. `GMD`, `HLT`, `EDU`).

## MASTER vs HARMONIZED (the core rule)

- **MASTER** (`_M`) = the original data **as provided by the producer**. It is
  **immutable** once archived — never overwrite; publish a new `vMM` instead.
- **HARMONIZED** (`_A_CLCT`) = an adaptation/collection derived from a master,
  stored in its **own sibling folder** — never mixed into the master.

The two must never share a folder. `check` / `_dtlb_check` enforces this: a `_A_`
file inside a `_M` folder (or vice-versa) is a violation.

## Path resolution

```
<DATALIB_ROOT>/<CCC>/<CCC_YYYY_SSSS>/<version>/Data/Stata/<version>[_<module>].dta
```

`<module>` is an optional dataset within a version (e.g. `adult`, `children`,
`household`). Data file name = the version-folder name, plus `_<module>` if given.

## The get / put / check contract (same in all three languages)

| Operation | Meaning |
|---|---|
| **get** | resolve the path for `(country, year, survey[, module, collection, version, latest])` and load the dataset |
| **put** | deposit a dataset: build the IHSN skeleton, write `<version>[_<module>].dta`, preserve the raw `Original` (master only), generate DDI + Dublin Core + codebook, then `check` |
| **check** | validate an archive (or one survey) against this spec; return the list of violations |

`put` is where compliance is **enforced**: it refuses to overwrite an archived
MASTER (immutability), keeps MASTER/HARMONIZED separate by construction, and
`check`s the result before returning.

### Cross-language parity contract

**Principle:** Stata, Python, and R expose the **same functionality, the same option
names, and the same values** — a user moves between languages with minimal drift.
The canonical options are:

| option | meaning | values |
|---|---|---|
| `country` | ISO3 country | e.g. `BRA` |
| `year` | survey year | e.g. `2019` |
| `survey` | survey acronym | e.g. `MICS` |
| `module` | dataset within a version | e.g. `adult` (optional) |
| `collection` | harmonization code ⇒ HARMONIZED | e.g. `GMD` (omit ⇒ MASTER) |
| `vm` / `va` | master / adaptation version | integer, default `1` |
| `latest` | resolve the highest version | boolean, default off |
| `root` | archive root | path; default from `DATALIB_ROOT` |
| `overwrite` | replace an archived file | boolean, default off (MASTER immutable) |
| `strict` | validate (check) after `put` | boolean, default **on** |
| `original` | raw file preserved in `Data/Original` | path (MASTER only) |
| `ddi` | generate DDI/Dublin Core/codebook on `put` | boolean, default on |

Native-idiom **aliases** are accepted where a language has a strong convention
(Stata: `path()`=`root()`, `replace`=`overwrite`, `nostrict`=`strict` off), but the
canonical name always works in all three.

```
Stata   datalib,     country(BRA) year(2019) survey(MICS) collection(GMD) module(adult) clear
        _dtlb_put,   country(BRA) year(2023) survey(SAEB) collection(GMD) module(adult)
        _dtlb_check, root("F:/datalib")
Python  datalib.get(country="BRA", year=2019, survey="MICS", collection="GMD", module="adult")
        datalib.put(df, country="BRA", year=2023, survey="SAEB", collection="GMD", module="adult")
        datalib.check(root="F:/datalib")
R       dl_get(country="BRA", year=2019, survey="MICS", collection="GMD", module="adult")
        dl_put(df, country="BRA", year=2023, survey="SAEB", collection="GMD", module="adult")
        dl_check(root="F:/datalib")
```

> Parity is a work in progress: `_dtlb_put` already accepts the canonical names; the
> remaining reconciliation (align `get`'s root option across languages, add
> `original`/`ddi` to R, and a shared cross-language parity test-suite) is tracked in
> internal/update_plan_2026-07-04_oldrepo.md.

## Metadata (IHSN documentation)

Each version folder carries, alongside its data:
- `<id>.ddi.xml` — DDI-Codebook 2.5 (study + variable metadata)
- `<id>.dc.xml` — Dublin Core (discovery metadata)
- `Doc/<id>_codebook.md` — human-readable codebook

These are generated by `put` (or `generate_ddi.py` / a future R equivalent) so the
data is documented at deposit time.
