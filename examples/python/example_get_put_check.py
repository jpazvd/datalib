"""datalib example (Python): put / get / check.

Self-contained - uses a temp folder as the archive root; safe to run as-is.
Requires the datalib package:  pip install -e python/   (from the repo root)
"""
import tempfile

import pandas as pd

import datalib

with tempfile.TemporaryDirectory() as demo_root:
    print(f"demo archive root: {demo_root}")

    df = pd.DataFrame({
        "hhid":   [1, 2, 3, 4],
        "region": [1, 1, 2, 3],
        "poor":   [0, 1, 1, 0],
    })

    # 1. PUT a MASTER: original data as provided (immutable once archived).
    #    Builds the IHSN skeleton and writes DDI + Dublin Core + codebook.
    target = datalib.put(
        df, country="BRA", year=2023, survey="DEMO", root=demo_root,
        column_labels={"hhid": "Household id", "poor": "Below poverty line"},
        value_labels={"poor": {0: "Non-poor", 1: "Poor"}},
    )
    print(f"  deposited MASTER    -> {target}")

    # 2. PUT a HARMONIZED adaptation: its own _A_ folder, never mixed in.
    target = datalib.put(
        df[["hhid", "poor"]], country="BRA", year=2023, survey="DEMO",
        collection="GMD", module="adult", root=demo_root,
    )
    print(f"  deposited HARMONIZED -> {target}")

    # 3. GET them back by coordinates - no file paths needed.
    master = datalib.get(country="BRA", year=2023, survey="DEMO", root=demo_root)
    adult = datalib.get(country="BRA", year=2023, survey="DEMO",
                        collection="GMD", module="adult", latest=True,
                        root=demo_root)
    print(f"  get MASTER: {master.shape}   get HARMONIZED (latest): {adult.shape}")

    # 4. CHECK: validate the archive against the IHSN template.
    violations = datalib.check(root=demo_root)
    print(f"  check violations: {violations or 'NONE (conformant)'}")

    # 5. MASTER immutability: a second put without overwrite=True is refused.
    try:
        datalib.put(df, country="BRA", year=2023, survey="DEMO", root=demo_root)
    except FileExistsError:
        print("  re-deposit refused (MASTER is immutable) - as designed")

# To use a real library instead of the demo root:
#   set DATALIB_ROOT=/path/to/your/datalib   (then omit root=...)
