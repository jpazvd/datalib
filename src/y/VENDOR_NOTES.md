# YAML library — vendored from `wbopendata-dev`

This directory contains a vendored copy of the YAML read/write/validate library
from [wbopendata-dev](https://github.com/jpazvd/wbopendata-dev). The library is
used by `datalib`'s catalog, registry, and per-survey metadata machinery.

## Source

- **Upstream repo:** `https://github.com/jpazvd/yaml-dev`
- **Upstream path:** `src/y/`
- **Pinned commit:** `e52d59f` (branch `rr/sj-revision`)
- **Upstream version:** yaml v2.0.0 (06Jul2026)
- **Vendored date:** 2026-07-19
- **Upstream license:** see `upstream-README.md`

### The source changed on 2026-07-19 — and why

**The previous record was accurate, not mistaken.** This library really was
vendored from `wbopendata-dev@0fb4e70` on 2026-04-28. That commit is
`docs(release): v18.7.0 — alias helper refactor`, which is why the old entry
recorded "Upstream version: v18.7.0" — wbopendata's version, not yaml's. The
commit exists in wbopendata-dev and in no other repo, so the provenance is
unambiguous.

What was wrong was the **sourcing decision, not the documentation**:
wbopendata-dev is itself a *vendor* of this library, not its home.
`jpazvd/yaml-dev` is canonical — the package's own repo and the subject of the
Stata Journal article. Copying sibling-to-sibling is how datalib ended up
three minor versions behind, and how the `src/_` helpers were never noticed as
missing. From 2026-07-19 the source is yaml-dev.

(For the record, the v1.5.1 files were byte-identical across datalib-dev,
wbopendata-dev@0fb4e70 and yaml-dev's develop — wbopendata had not modified
them. The problem was never divergence; it was that a sibling's snapshot
freezes at whatever version that sibling last pulled, and carries only the
subset of files that sibling happened to need.)

**⚠ This pin is to an UNMERGED branch.** yaml v2.0.0 lives only on
`rr/sj-revision` (yaml-dev PR #9, open, Stata Journal R&R). Both `main` and
`develop` there are still at v1.5.1. So this pin can move before PR #9 merges,
and the pinned commit is not reachable from any released ref.

Re-pin to `develop` once PR #9 merges. Until then, treat `src/y` as tracking a
pre-release. This was a deliberate, informed choice on 2026-07-19 to unblock
the catalog's YAML metadata path (see below); it knowingly departs from the
project convention of not re-vendoring the yaml siblings before the v2.0.0 SSC
release. That convention's stated scope is wbopendata-dev and unicefdata-dev,
whose INT-02/INT-03 gates are unaffected by this repo.

### Why v2.0.0 was needed here

`_dtlb_catalog_read_yaml` calls `yaml get producer` / `yaml get license` to
populate the catalog frame's metadata columns. Under v1.5.1 those calls
returned `r(found) == 0` and an empty value for **every** top-level scalar, so
the columns were silently never populated. yaml_get's own v1.6.0 changelog
records the defect:

> scalar-leaf lookups (`yaml get somekey` where somekey holds a value and has
> no children) now return `r(value)`, as documented. Previously this worked
> only in the legacy no-parent-variable fallback, so the documented pattern
> `yaml get input_file` -> `r(value)` silently returned nothing.

That is smoke check S36. The failure was in the vendored version, not in
datalib's caller and not in yaml-dev.

## Files vendored

Upstream splits the library across **two** directories — `src/y/` for the
public `yaml*` commands and `src/_/` for the `_yaml_*` internal helpers. We
consolidate both into this one directory, so that the whole vendored unit
lives in a single place and cannot be half-copied again. File *contents* are
still byte-identical; only their location differs.

| File | Type | Upstream path | Purpose |
|---|---|---|---|
| `_yaml_collapse.ado` | program | `src/_/` | Wide-collapse helper; also defines the Mata functions `_yaml_binsearch`, `_yaml_mata_collapse`, `_yaml_safe_varname`, `_yaml_unique_varname` |
| `_yaml_fastread.ado` | program | `src/_/` | Fast line-oriented reader path |
| `_yaml_mataread.ado` | program | `src/_/` | Mata reader path; defines `_yaml_mata_parse` |
| `_yaml_tokenize_line.ado` | program | `src/_/` | Line tokenizer |

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

Sync from **yaml-dev**, the canonical repo — never from a sibling vendor such
as wbopendata-dev or unicefdata-dev. Sibling-to-sibling copying is how this
directory silently fell three minor versions behind.

```bash
# from repo root
YAMLDEV=/c/GitHub/myados/yaml-dev
TARGET=src/y

# diff first to see what's changing
diff -ur $YAMLDEV/src/y/ $TARGET/ \
  | grep -v "^Only in $TARGET: VENDOR_NOTES.md"

# pull updates (note: upstream's README.md lands as upstream-README.md)
cp $YAMLDEV/src/y/yaml*.ado   $TARGET/
cp $YAMLDEV/src/y/yaml*.sthlp $TARGET/
cp $YAMLDEV/src/y/README.md   $TARGET/upstream-README.md

# CRITICAL: the internal helpers live in src/_ upstream, NOT src/y, and the
# glob yaml*.ado cannot match a name starting with an underscore. Omitting
# this line is how the library was vendored incompletely from 2026-04-28
# until 2026-07-19 -- yaml_read calls all four, plus five Mata functions they
# define, and none of them shipped.
cp $YAMLDEV/src/_/_yaml_*.ado $TARGET/

# update "Pinned commit" above with: git -C $YAMLDEV rev-parse --short HEAD
# and confirm which REF that commit is on -- prefer develop or main
```

Then run the smoke suite before committing, and check the YAML-dependent
checks specifically:

```
"C:\Program Files\Stata17\StataMP-64.exe" -b do qa/run_smoke.do
```

S33–S36 exercise the catalog scan and its YAML metadata columns; they are the
ones a yaml regression breaks first.

## Why vendor instead of depend?

Stata has no native package manager that resolves transitive deps. SSC packages
routinely vendor each other rather than `net install` at runtime. This keeps
`datalib`'s install footprint deterministic — `net install datalib` ships a
known-good YAML library snapshot, immune to upstream churn.

The trade-off (potential drift from upstream) is documented in the project's
top-level red-team analysis (R6 / R14).

## Modifications from upstream

**None.** Files are byte-identical copies of `yaml-dev@e52d59f`. If a local fix
is ever needed, it should first be upstreamed to **yaml-dev**, then
re-vendored. Local patches in this directory create unsustainable drift.

The S36 defect above is the case in point: it was tempting to patch
`yaml_get.ado` here, but the fix already existed upstream (v1.6.0), so a local
patch would have duplicated an existing fix and then conflicted with it at the
next sync.
