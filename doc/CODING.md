# Coding standards (cedit)

cedit follows the shared Cwhip PoC coding locks in
[cwhip-lang/cplanets `doc/CODING.md`](https://github.com/cwhip-lang/cplanets/blob/main/doc/CODING.md)
(PR #101): file headers, Changelog, class/method comments, formatting,
naming, ownership, init/empty, exceptions, tests under `tests/` via
CTest, and inline-C FFI.

Near-term work is **comments + general cleanup**, not language-feature
demos. Do **not** mass-rename existing APIs solely to match naming locks;
apply renames on touch when local and safe.

Created: 2026-11-13
Author: Auto

Changelog:
- 2026-11-13  Point at shared locks; cedit-local notes below.

## cedit-local notes (non-conflicting)

- **Operator binary:** `cedit` parses argv with stdlib `cli` (`-h` /
  `--help`, optional paths, `--test`).
- **Settings:** global + per-project overrides; prefer named settings
  keys over magic literals when adding knobs.
- **Embedded `--test`:** `Cedit.test()` remains a compile-in smoke path
  for GTK harnesses. New automated coverage belongs under `tests/` and
  CTest  -  do not grow production-side test suites.
- **Plugins:** compile-in demos until dynamic `.cw` loading exists;
  keep plugin hooks thin.
- **Method names:** historical camelCase (`openFile`, `applyConfigure`)
  is retained for churn control; new methods may use
  `lower_with_underscores` per the shared naming lock.
