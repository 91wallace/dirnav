# Source provenance — 1.0.1-beta.1 Windows ZIP

- Approved ZIP SHA-256: `9fecce9624d1a81d448fe7060fcbded7a13acccff1862816e19bae31dd322077`.
- The local build input was `dirnav_entry.py`, stamped to `1.0.1-beta.1` by the release build workflow. A line comparison against `dirnav` confirmed the same source before release lint cleanup, apart from version stamping and a final blank line.
- To pass the release Ruff gate, the source committed for this tag removes an unused `ctypes.wintypes` import and discards two unused tuple bindings with `_` in the Windows security helpers. No function call, branch, ordering, or security decision changed in that cleanup.
- The approved ZIP was not rebuilt. The tag source is behaviorally corresponding to the approved build input, but byte-for-byte rebuild reproducibility is not claimed.

This record is intentionally explicit about the small source-only cleanup performed after the approved binary was built.
