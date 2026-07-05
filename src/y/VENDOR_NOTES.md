# YAML library — vendored from `wbopendata-dev`

This directory contains a vendored copy of the YAML read/write/validate library
from [wbopendata-dev](https://github.com/jpazvd/wbopendata-dev). The library is
used by `datalib`'s catalog, registry, and per-survey metadata machinery.

## Source

- **Upstream repo:** `https://github.com/jpazvd/wbopendata-dev`
- **Upstream path:** `src/y/`
- **Pinned commit:** `0fb4e70746f7961fb43dc67fda27063a21723be9`
- **Upstream version:** v18.7.0
- **Vendored date:** 2026-04-28
- **Upstream license:** see `upstream-README.md`

## Files vendored

| File | Type | Purpose |
|---|---|---|
| `yaml.ado` | program | Main `yaml` dispatcher command |
| `yaml.sthlp` | help | Stata help for `yaml` |
| `yaml_clear.ado` | program | Clear loaded YAML state |
| `yaml_describe.ado` | program | Describe a loaded YAML structure |
| `yaml_dir.ado` | program | List YAML data currently loaded (dataset + yaml_* frames) |
| `yaml_frames.ado` | program | Convert YAML to Stata frames |
| `yaml_get.ado` | program | Extract a value by path |
| `yaml_list.ado` | program | List entries at a YAML path |
| `yaml_read.ado` | program | Parse a YAML file |
| `yaml_validate.ado` | program | Validate against a schema |
| `yaml_write.ado` | program | Serialise back to YAML |
| `yaml_examples.sthlp` | help | Worked examples |
| `yaml_whatsnew.sthlp` | help | Upstream changelog |
| `upstream-README.md` | doc | README from upstream `src/y/` |

## Sync procedure

When updating to a newer wbopendata-dev version:

```bash
# from repo root
WBOD=/c/GitHub/myados/wbopendata-dev
TARGET=src/y

# diff first to see what's changing
diff -ur $WBOD/src/y/ $TARGET/ | grep -v "^Only in $TARGET: VENDOR_NOTES.md"

# pull updates
cp $WBOD/src/y/yaml*.ado $TARGET/
cp $WBOD/src/y/yaml*.sthlp $TARGET/
cp $WBOD/src/y/README.md $TARGET/upstream-README.md

# update this file's "Pinned commit" with: git -C $WBOD rev-parse HEAD
# run smoke tests in qa/ before committing
```

## Why vendor instead of depend?

Stata has no native package manager that resolves transitive deps. SSC packages
routinely vendor each other rather than `net install` at runtime. This keeps
`datalib`'s install footprint deterministic — `net install datalib` ships a
known-good YAML library snapshot, immune to upstream churn.

The trade-off (potential drift from upstream) is documented in the project's
top-level red-team analysis (R6 / R14).

## Modifications from upstream

**None.** Files are byte-identical copies. If a local fix is ever needed, it
should first be upstreamed to wbopendata-dev, then re-vendored. Local patches
in this directory create unsustainable drift.
