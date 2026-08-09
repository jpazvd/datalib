# datalib examples

Runnable, self-contained examples of the **datalib** trio — `get` / `put` / `check` —
in all three supported languages. Each script uses a **temporary folder** as the
archive root, so you can run them as-is without touching a real datalib library.

Prefer a ready-made archive to explore instead of an empty temp folder? Build
one:

```stata
. datalib_makelib, families(demo) path("mydemo")
```

That writes a five-survey miniature library — synthetic data, documentation and
programs for BRA PNAD and SAEB, ZWE MICS, KEN DHS, IND PLFS — which the Stata
catalog, the Python package and the R package can all read. Point `DATALIB_ROOT`
(or `${datalib}`) at it, or run it with no `path()` and it lands in `datalib/`
in the working directory, where `datalib_root` looks by default.

**This used to be `examples/demo_library/`, committed to the repository. It is
not tracked any more**, for three reasons, in order of how much they matter.
This package distributes no microdata, and the rule is easier to keep with no
exceptions — including for synthetic data that merely resembles the real thing.
A committed library could not reach installed users regardless: `net install`
places files in the PLUS tree by basename without preserving directories, so a
nested tree arrives flattened. And generating it makes the acceptance suite
prove something it never did before — that a user who has only run `net install`
can produce a working library at all.

`families()` also generates the survey shapes this repository documents —
`pnad`, `pnadc`, `saeb`, `mics`, `dhs` — with the module names and merge keys
each of them actually uses. PISA and PIRLS are deliberately excluded: nothing
here refers to them or to plausible values, so generating them would invent a
shape rather than reproduce one.

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
