"""Typed errors for datalib.

The classes mirror the Stata return codes and the R condition classes so that
the same failure is recognisable in all three languages:

    ConfigFileNotFound   Stata 601   datalib_error_config_missing
    UserBlockNotFound    Stata 459   datalib_error_user_missing
    DatalibRootNotSet    Stata 198   datalib_error_root_unset
"""


class DatalibError(Exception):
    """Base class for every error this package raises deliberately."""


class ConfigFileNotFound(DatalibError):
    """No configuration file was found where one was expected."""


class UserBlockNotFound(DatalibError):
    """A configuration file exists but carries no block for this user."""


class DatalibRootNotSet(DatalibError, ValueError):
    """No library root could be resolved.

    Inherits ``ValueError`` as well as ``DatalibError`` on purpose. Before the
    configuration seam, ``get_root`` raised a bare ``ValueError``, and callers
    wrote ``except ValueError``. Those callers keep working, while new code can
    catch the specific class. Dropping ``ValueError`` here would be a silent
    breaking change for anyone who had already written the obvious handler.
    """
