# datalib examples

Runnable, self-contained examples of the **datalib** trio — `get` / `put` / `check` —
in all three supported languages. Each script uses a **temporary folder** as the
archive root, so you can run them as-is without touching a real datalib library.

| Example | Language | Shows |
|---|---|---|
| [`stata/example_get_put_check.do`](stata/example_get_put_check.do) | Stata | `_dtlb_put` (deposit MASTER + HARMONIZED), `_dtlb_check` (validate), reading back |
| [`python/example_get_put_check.py`](python/example_get_put_check.py) | Python | `datalib.put()`, `datalib.get(latest=True)`, `datalib.check()`, DDI metadata |
| [`R/example_get_put_check.R`](R/example_get_put_check.R) | R | `dl_put()`, `dl_get()`, `dl_check()` |

## The idea in one paragraph

`datalib` organizes survey microdata in the **IHSN / World Bank Microdata Library**
folder taxonomy: each survey lives under `CCC_YYYY_SSSS/`, with the original data in
an immutable **MASTER** version folder (`*_vNN_M`) and each harmonization in its own
**HARMONIZED** sibling (`*_vNN_M_vNN_A_CLCT`). `put` deposits data into that
structure (creating folders, writing metadata, refusing to overwrite masters),
`get` loads any dataset by `(country, year, survey, …)` coordinates instead of file
paths, and `check` validates that an archive conforms. The **same option names and
values** work in Stata, Python, and R — see
[`00_documentation/taxonomy.md`](../00_documentation/taxonomy.md) for the full
specification.

## Quick start

```stata
* Stata — after: net install datalib, from(https://raw.githubusercontent.com/jpazvd/datalib/main/)
do examples/stata/example_get_put_check.do
```

```bash
# Python — after: pip install -e python/
python examples/python/example_get_put_check.py
```

```r
# R — needs haven; then:
source("examples/R/example_get_put_check.R")
```

## Pointing at a real library

Every example ends by showing the one setting you change to work against a real
archive instead of the demo temp folder:

- Stata: `global datalib "/path/to/your/datalib"` (or the `root()` option)
- Python: `DATALIB_ROOT=/path/to/your/datalib` env var (or `root=` argument)
- R: `Sys.setenv(DATALIB_ROOT = "/path/to/your/datalib")` (or `root =` argument)
