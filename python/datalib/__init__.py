"""datalib - access the IHSN-organized survey archive from Python.

    import datalib
    df = datalib.get(country="BRA", year=2019, survey="MICS",
                     collection="GMD", module="adult")     # -> pandas.DataFrame
    datalib.put(df, country="BRA", year=2023, survey="SAEB",
                collection="GMD", module="adult")          # deposit (IHSN-checked)
    datalib.check()                                        # validate the archive

The archive root is resolved in a fixed order that touches no disk:
a `root=` argument, then DATALIB_ROOT, then the `datalib:` key in
~/.config/user_config.yml, then ~/.config/datalib_config.yml. The first
non-empty candidate wins and is returned as given -- a configured root that is
momentarily unreachable fails at the file operation rather than resolving
somewhere else. `resolve_root(..., report=True)` says which stage supplied it.

Master (original) and harmonized (adaptation) versions are kept in separate
IHSN folders; `put` enforces that separation.
"""
from .config import (RootResolution, UserConfig, datalib_config, datalib_root,
                     get_root, getuserconfig, resolve_root)
from .errors import (ConfigFileNotFound, DatalibError, DatalibRootNotSet,
                     UserBlockNotFound)
from .access import get, put, check
from . import taxonomy

__all__ = [
    "get", "put", "check", "taxonomy",
    # root and configuration
    "get_root", "resolve_root", "getuserconfig",
    "datalib_root", "datalib_config",
    "RootResolution", "UserConfig",
    # errors
    "DatalibError", "ConfigFileNotFound", "UserBlockNotFound",
    "DatalibRootNotSet",
]
__version__ = "1.7.0"
