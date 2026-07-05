# datalib registry

YAML-backed configuration for datalib's catalog and validation machinery.

## Files

| File | Schema | Used by |
|---|---|---|
| `countries.yaml` | `<ISO3>: {name, region, income_level, ...}` | `_dtlb_ctrycheck`, catalog frame |
| `harmonizations.yaml` | `<HHHH>: {name, scope, domain, ...}` | `_dtlb_adaptcheck`, catalog frame |
| `examples/datalib.yaml` | per-survey metadata template | reference for survey owners |

## How files are read

The vendored YAML library at [`../y/`](../y/) provides the parsing primitives:

```stata
yaml read using "registry/countries.yaml", frame(countries)
yaml read using "registry/harmonizations.yaml", frame(harmonizations)
```

Per-survey metadata (`datalib.yaml` files inside each survey folder) is read by
`_dtlb_catalog, scan` during catalog construction.

## Schema validation

Each top-level YAML must validate against an implicit schema:

- **`countries.yaml`** — keys are ISO 3166-1 alpha-3 codes. Required fields:
  `name`, `region`. Optional: `iso2`, `iso_numeric`, `subregion`,
  `income_level`, `unicef_region`.

- **`harmonizations.yaml`** — keys are uppercase short codes (≤ 6 chars).
  Required fields: `name`, `description`, `scope`, `domain`. Conditional:
  `region` (if scope=regional), `country` (if scope=national).

- **Per-survey `datalib.yaml`** — required fields: `country`, `year`,
  `survey`, `version_master`. Adaptations array, statistics, and integrity
  fields are optional/auto-populated.

## Adding a country

Append to `countries.yaml` at the appropriate alphabetic position within its
region block. After editing, run:

```stata
. yaml read using "registry/countries.yaml"
. yaml describe
```

to verify the file still parses cleanly. CI (P6) will run this check on every
push.

## Adding a harmonization

Append to `harmonizations.yaml` under the appropriate scope/region block. New
harmonization tags must be ≤ 6 uppercase characters to fit the
`CCC_YYYY_SSSS_vNN_M_vNN_A_HHHH` folder convention.

## Why YAML and not `.dta`?

- **Diff-able** — meaningful pull-request reviews
- **Source-of-truth without binary** — git history is the changelog
- **Editable without Stata** — researchers and metadata curators don't need
  Stata to update the registry
- **Mirrors `wbopendata-dev` pattern** — same library handles both
