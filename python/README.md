# datalib (Python)

Access the IHSN-organized survey microdata archive — the Python member of the
`datalib` cross-language family (Stata / Python / R). See
[`../00_documentation/taxonomy.md`](../00_documentation/taxonomy.md) for the shared specification.

## Install

```bash
pip install -e python/          # from the repo root
```

Requires `pandas`, `pyreadstat` and `pyyaml`.

## Configure

The archive root resolves in a fixed order, and **without touching the disk**:

| # | Stage (`source_stage`) | Where it comes from |
|---|---|---|
| 1 | `argument` | `root="F:/datalib"` passed to any call |
| 2 | `env` | `DATALIB_ROOT` |
| 3 | `config_generic` | the `datalib:` key of `~/.config/user_config.yml` |
| 4 | `config_package` | the same key of `~/.config/datalib_config.yml` |

The first non-empty candidate wins and is returned as given — a configured
archive that is momentarily unreachable fails when a file is opened, rather than
resolving somewhere else. The two configuration files are read block by block
and never merged: the root comes from the first whose block for your username
carries a non-empty `datalib:` key.

This leg **reads** those files; it does not write them. Authoring is opt-in and
lives on the Stata side (`getuserconfig, create` / `edit`), so anything Python
consumes here was written deliberately — by a person or by that command — rather
than materialised by a failed read. The file is two lines; writing it by hand is
equally fine.

```bash
export DATALIB_ROOT=F:/datalib   # or pass root="F:/datalib" to any call
```

```python
from datalib import resolve_root, getuserconfig

resolve_root()                       # -> Path
resolve_root(report=True)            # -> RootResolution(root=..., source_stage=...)
getuserconfig()                      # -> UserConfig for this user
```

None of this is required: a configuration file is a convenience for pinning a
root per machine. With nothing set, `resolve_root()` raises `DatalibRootNotSet`
(which is also a `ValueError`, so older `except ValueError` handlers still
work) and the message says what to set.

`DATALIB_CONFIG` pins a single file and turns the fallback off;
`DATALIB_CONFIG_DIR` moves the search elsewhere. Both exist so tests and
scripts need never read a real home directory.

## Use

```python
import datalib

# read a harmonized module as a DataFrame
df = datalib.get(country="BRA", year=2019, survey="MICS",
                 collection="GMD", module="adult")

# deposit a dataset (builds the IHSN folder, writes DDI + codebook, validates)
datalib.put(df, country="BRA", year=2023, survey="SAEB",
            collection="GMD", module="adult")

# validate the archive
violations = datalib.check()          # [] means conformant
```

- No `collection` ⇒ **MASTER** (original, immutable); with `collection` ⇒ **HARMONIZED**.
- `latest=True` resolves the highest available version.
- Option names/values match the Stata and R packages (see the parity contract in the spec).

## Test

```bash
pip install -e "python/[test]"
pytest python/tests
```
