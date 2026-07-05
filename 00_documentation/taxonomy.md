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

Every tool resolves the archive root from `DATALIB_ROOT` (or an explicit
`root=`/`path()` argument). Nothing is hardcoded.

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
