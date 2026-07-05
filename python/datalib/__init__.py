"""datalib - access the IHSN-organized survey archive from Python.

    import datalib
    df = datalib.get(country="BRA", year=2019, survey="MICS",
                     collection="GMD", module="adult")     # -> pandas.DataFrame
    datalib.put(df, country="BRA", year=2023, survey="SAEB",
                collection="GMD", module="adult")          # deposit (IHSN-checked)
    datalib.check()                                        # validate the archive

The archive root is taken from the DATALIB_ROOT environment variable (e.g.
F:/datalib) or a `root=` argument. Master (original) and harmonized (adaptation)
versions are kept in separate IHSN folders; `put` enforces that separation.
"""
from .config import get_root
from .access import get, put, check
from . import taxonomy

__all__ = ["get", "put", "check", "get_root", "taxonomy"]
__version__ = "0.1.0"
