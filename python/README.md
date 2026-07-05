# datalib (Python)

Access the IHSN-organized survey microdata archive — the Python member of the
`datalib` cross-language family (Stata / Python / R). See
[`../00_documentation/taxonomy.md`](../00_documentation/taxonomy.md) for the shared specification.

## Install

```bash
pip install -e python/          # from the repo root
```

Requires `pandas` and `pyreadstat`.

## Configure

Point at your curated archive root (the same one Stata's `${datalib}` and R's
`DATALIB_ROOT` use):

```bash
export DATALIB_ROOT=F:/datalib   # or pass root="F:/datalib" to any call
```

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
