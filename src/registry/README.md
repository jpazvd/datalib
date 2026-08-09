# datalib registry

YAML-backed configuration for datalib's catalog and validation machinery.

## Files

| File | Schema | Used by |
|---|---|---|
| `countries.yaml` | `<ISO3>: {name, region, income_level, ...}` | `_dtlb_ctrycheck`, catalog frame |
| `harmonizations.yaml` | `<HHHH>: {name, scope, domain, ...}` | `_dtlb_adaptcheck`, catalog frame |
| `catalogs.yaml` | `<short>: {name, base_url, api_version, auth_type, ...}` | `_dtlb_catalogregistry`, `_dtlb_catalog` REST paths |
| `examples/datalib.yaml` | per-survey metadata template | reference for survey owners |

## How files are read

The vendored YAML library at [`../y/`](../y/) provides the parsing primitives:

```stata
yaml read using "registry/countries.yaml", frame(countries)
yaml read using "registry/harmonizations.yaml", frame(harmonizations)
```

Per-survey metadata (`datalib.yaml` files inside each survey folder) is read by
`_dtlb_catalog, scan` during catalog construction.

`catalogs.yaml` is the exception: it is parsed directly by
`_dtlb_catalogregistry` (no dependency on the vendored library, since the
registry sits upstream of everything else in the `api://` stack), and the copy
here is only the **bundled offline fallback**. The canonical registry is
`docs/catalogs.yaml`, served via GitHub Pages at
`https://jpazvd.github.io/datalib-dev/catalogs.yaml` and cached per-user for
24 hours; a user override at `~/.datalib/catalogs.yaml` wins over everything.
Resolution order and the consent rule for custom auth entries are documented
in `help _dtlb_catalogregistry`. Keep this fallback byte-identical to
`docs/catalogs.yaml` at release time.

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
