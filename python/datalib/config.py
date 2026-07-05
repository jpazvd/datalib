"""datalib configuration: resolve the curated archive root."""
import os

ENV_VAR = "DATALIB_ROOT"


def get_root(root=None):
    """Return the datalib archive root (the curated IHSN library).

    Resolution order: explicit ``root`` argument -> ``$DATALIB_ROOT``.
    Raises ``ValueError`` if neither is set.
    """
    root = root or os.environ.get(ENV_VAR)
    if not root:
        raise ValueError(
            f"datalib root not set; pass root=... or set the {ENV_VAR} "
            f"environment variable (e.g. F:/datalib)."
        )
    return root.replace("\\", "/").rstrip("/")
