# Standalone cedit

Install a complete Cwhip **0.0.1** SDK (executables, runtime archive, headers,
builtins, packages and CMake config) built with GTK 4 >= 4.10 and GtkSourceView 5.
Clang, Python >= 3.11, CMake >= 3.24, a C compiler, pkg-config and those GTK
development libraries must be installed. This project never fetches a compiler.
The SDK must provide the `Cwhip_APPLICATION_OUTPUT_DIRECTORIES` capability
(`cwhip_add_program(OUTPUT_DIRECTORY ...)` and
`cwhip_require_sourceview(RESOURCE_DIRECTORY ...)`) and include
`CwhipApplicationDefaults.cmake` from its package config. Older 0.0.1 SDK
installs without these capabilities are rejected; rebuild/install an updated SDK.
Version 0.0.1 alone is not sufficient: older installs have the same version but
lack `cwhip_apply_application_defaults`. cedit checks this command before calling
it and reports `CEDIT2001` with the selected SDK prefix (or package directory if
the package does not export a prefix). It never skips SDK defaults or switches
to another SDK or `/usr/local` to work around this failure.

### Refreshing a stale SDK

Use Cwhip sources containing
[chucktilbury/cwhip#21](https://github.com/chucktilbury/cwhip/pull/21)
(merge commit `203f7fbab6b7d68820d67288b11b32d1fe0af995`) or later. Updating
cedit or re-running its CMake configuration does not update the installed SDK.
Follow the upstream [GUI SDK build instructions](https://github.com/chucktilbury/cwhip/blob/master/doc/GETTING_STARTED.md#add-the-optional-gui-sdk).
For example, from an updated Cwhip source checkout, use a **new build directory
and unused installation prefix** to avoid mixing old and new SDK files:

```sh
cmake -S . -B build-cedit-sdk -DCMAKE_BUILD_TYPE=Debug \
  -DCWHIP_STAGE_PREFIX="$PWD/build-cedit-sdk/stage" \
  -DCMAKE_INSTALL_PREFIX="$HOME/opt/cwhip-cedit-updated" \
  -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_TESTING=OFF \
  -DCWHIP_GTK=ON -DCWHIP_GTK_SOURCEVIEW=ON -DCWHIP_REGISTER_SDK=OFF
cmake --build build-cedit-sdk --target cwhip --parallel 4
cmake --install build-cedit-sdk
```

The explicit prefix avoids system installation; `CWHIP_REGISTER_SDK=OFF`
preserves existing user SDK settings. Back in the cedit checkout, select that
complete SDK explicitly:

```sh
CWHIP_SDK="$HOME/opt/cwhip-cedit-updated" cmake -S . -B build
cmake --build build --parallel 4
```

The package must both install `CwhipApplicationDefaults.cmake` and include it
from `lib/cmake/Cwhip/CwhipConfig.cmake`; do not copy the helper into cedit or
patch the installed config by hand.

## Project shell

Run the executable setup script, not `source scripts/setup`:

```sh
scripts/setup                 # inherit the SDK application build default
# Alternatively: scripts/setup release or scripts/setup profile
# In the child Bash, initially in build/:
cmake --build . --parallel 4
cedit
exit
```

Without a mode argument, setup does not pass an implicit build type to CMake,
so the selected SDK's application default or an existing build-cache value is
preserved. Explicit `debug`, `release`, and `profile` arguments select `Debug`,
`Release`, and `RelWithDebInfo`. Setup works from outside the repository and
with spaces in paths. It configures `build/` before
opening a fresh interactive Bash using `.project_env`; configuration errors
exit without opening that shell. Nested project shells are rejected. Exiting
returns to the original shell without changing its environment or directory.

The environment sources readable `~/.bashrc`, then prepends project `bin/`,
`scripts/`, and optional `CWHIP_SDK/bin` to PATH. When the shared settings
file selects the SDK, setup exports that prefix as `CWHIP_SDK` to CMake and
the child shell (so its `bin/` is on PATH); it never modifies the settings file
or the calling shell. It exports `_PROJECT_NAME`,
`_PROJECT_LOC`, `_BUILD_TYPE`, and `CWHIP_BUILD_TYPE`, and adds the project and
build mode to the prompt. Explicit `status`, `add`, `commit`, `push`, and `all`
Git functions act on this repository; `all` stages, commits and pushes only
when invoked. `dbg` forwards arguments to `cdbg`. Setup never fetches an SDK,
modifies Git state, or creates a virtualenv. The script and environment file
are project-owned and can be modified for local conventions.

## SDK selection

Direct `cmake -S . -B build` and `scripts/setup` select the SDK in this exact
order:

1. An explicit, non-empty `CWHIP_SDK` environment variable.
2. The top-level TOML string `sdk_prefix` in
   `$XDG_CONFIG_HOME/cwhip/sdk.toml`, or
   `$HOME/.config/cwhip/sdk.toml` when `XDG_CONFIG_HOME` is unset/empty.
   The Cwhip SDK installer records this value in `sdk.toml`, separate from
   cedit's preferences in `settings.toml`. Only when `sdk.toml` does not exist
   is a top-level `sdk_prefix` in the legacy `settings.toml` (same directory)
   used. An existing `sdk.toml` is authoritative: if it is unreadable or
   malformed, or its prefix is invalid, configuration fails with no legacy
   fallback; if it lacks `sdk_prefix`, step 3 applies (not the legacy file).
3. Normal CMake package discovery (`CMAKE_PREFIX_PATH`, `Cwhip_DIR`, and
   conventional locations) when neither selection is present.

```toml
sdk_prefix = "/absolute/path/to/installed/cwhip"
```

The value is the **whole installation prefix**, not its `bin/` or CMake package
directory. It must be a non-empty absolute path to an existing directory without
NUL or line breaks; basic strings with escapes, literal strings, spaces and
comments are supported. A non-empty `XDG_CONFIG_HOME` must be absolute and is the
only config location: a missing file there does not fall back to the HOME
file. With neither `XDG_CONFIG_HOME` nor `HOME`, normal discovery applies.

Missing config files or an absent top-level key leaves normal discovery
unchanged. Malformed TOML, an invalid value, an unreadable file, or a relative
`XDG_CONFIG_HOME` stops configuration (and setup, before opening a shell) with a
diagnostic instead of selecting another SDK. The file is parsed as data with
Python 3.11+ `tomllib` (`scripts/sdk-prefix.py`); it is never sourced or
modified or migrated. Python is needed only when sdk.toml or settings.toml exists and `CWHIP_SDK`
is unset. A non-empty `CWHIP_SDK` bypasses the settings file and config-home
checks entirely, even if they are malformed.

cedit-owned setup, launcher and SDK-selection failures use
`cedit: error[CEDITxxxx]: explanation`; diagnostics go to stderr and setup
usage errors return 2. CMake's own package-discovery output remains intact.
See [cedit's diagnostic boundaries](../CEDIT.md#diagnostics) and the shared
[diagnostic contract](https://github.com/chucktilbury/cwhip/blob/master/doc/DIAGNOSTICS.md).

Whenever `CWHIP_SDK` or `sdk_prefix` selects a prefix, CMake searches only that
prefix and clears a previously cached `Cwhip_DIR`, so switching SDKs in an
existing build tree never silently reuses a stale package. A prefix without a
compatible Cwhip package fails configuration. To return to normal discovery,
unset `CWHIP_SDK`, remove `sdk_prefix`, and clear `Cwhip_DIR` from an existing
cache if needed.

## Application defaults

The selected SDK's package config provides
`CwhipApplicationDefaults.cmake`; cedit calls
`cwhip_apply_application_defaults()` immediately after finding that package
and before `project()` initializes CMake defaults. The helper reads the
`[applications]` table in `sdk.toml`. Its `install_prefix` and `build_type`
values seed `CMAKE_INSTALL_PREFIX` and `CMAKE_BUILD_TYPE` only when those
settings are still defaults. Explicit CMake values, a
`CMAKE_INSTALL_PREFIX` environment setting, and values already stored in the
build cache take precedence. A mode passed to `scripts/setup` is
explicit, while omitting the mode allows the SDK's `build_type` to apply.

The install prefix provides a staging default for `cmake --install build`;
pass `--prefix` to `cmake --install` or set `-DCMAKE_INSTALL_PREFIX=...` to
choose another destination. These defaults do not share a build directory or
propagate arbitrary SDK build flags into the application.

## Direct CMake and installation

```sh
cmake -S . -B build -DCMAKE_PREFIX_PATH=/path/to/installed/cwhip
cmake --build build --parallel 4
ctest --test-dir build --output-on-failure
cmake --build build --target test-all
cmake --build build --target check-noop
cmake --install build --prefix /path/to/cedit
cmake --build build --target clean
cmake --build build
```

Run `bin/cedit` or `/path/to/cedit/bin/cedit`. Its native launcher finds
`cedit.bin` beside its real executable, and the application finds installed
SourceView language definitions relative to that executable. The application
prefix may be moved as a whole. The compiler SDK is a build-time dependency,
not a runtime source-checkout dependency; system GTK/SourceView libraries
remain runtime prerequisites. Compiler actions selected in the editor require
the installed `cwhip` toolchain on PATH.

See [SDK selection](#sdk-selection) for how the SDK prefix is chosen. Missing resources, wrong
version or non-GUI SDKs fail at configure time. Builds use the SDK's
`cwhip_add_program` contract with private HOME/XDG/package locks and no user
module overrides. Intermediates remain in the binary tree; executables go to
project-root `bin/`, native libraries to `lib/`, and SourceView resources to
sibling `share/`. These output directories are not created by configuration.
The native launcher builds privately and is staged alongside `cedit.bin` only
at build time. `clean` removes generated outputs, not application source;
rebuilds recreate removed working directories and resources.

Override output directories with `-DCWHIP_BIN_DIR=/absolute/prefix/bin` and
`-DCWHIP_LIB_DIR=/absolute/prefix/lib`. SourceView resources follow the parent
of the selected executable directory into `share/`; keep that relative layout
when moving build outputs. For workspace-private outputs, use
`-DCWHIP_BIN_DIR=/path/to/app-build/bin -DCWHIP_LIB_DIR=/path/to/app-build/lib`.
Installation always uses the requested install prefix's `bin/` and `share/`,
independently of build output overrides.

Tests own their native fixtures and runners in `tests/`. They use GTK and
the installed public runtime C headers, not compiler tests, native sources
or private GTK headers. `cedit_sdk_discovery` exercises SDK selection with
mock SDK packages and isolated HOME/XDG directories (no GUI required); run it
alone with `python3 tests/test_sdk_discovery.py`. Xvfb and
dbus-daemon enable isolated headless suites; otherwise configuration prints
an explicit exclusion. No test uses the user's desktop. Ordinary CTest does
not rebuild the project; `test-all` builds first, `check-noop` is the explicit
incremental-build regression. This is a proof-of-concept interface with no
promise of cross-version runtime ABI or release packaging stability.

Font-property assertions wait for an actual GTK `after-paint` frame with a
five-second failure deadline. An idle callback (even after sleeping) can run
before GTK validates a newly created view's CSS and observe the default font.
The fixture synchronizes rendering, not retries the assertion or the test.
