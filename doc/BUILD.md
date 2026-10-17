# Standalone cedit

Install a complete Cwhip **0.0.1** SDK (executables, runtime archive, headers,
builtins, packages and CMake config) built with GTK 4 >= 4.10 and GtkSourceView 5.
Clang, Python >= 3.11, CMake >= 3.24, a C compiler, pkg-config and those GTK
development libraries must be installed. This project never fetches a compiler.
The SDK must provide the `Cwhip_APPLICATION_OUTPUT_DIRECTORIES` capability
(`cwhip_add_program(OUTPUT_DIRECTORY ...)` and
`cwhip_require_sourceview(RESOURCE_DIRECTORY ...)`). Older 0.0.1 SDK installs
without that capability are rejected explicitly; rebuild/install an updated SDK.

## Project shell

Run the executable setup script, not `source scripts/setup`:

```sh
export CWHIP_SDK=/path/to/installed/cwhip
scripts/setup                 # debug (Debug)
# Alternatively: scripts/setup release or scripts/setup profile
# In the child Bash, initially in build/:
cmake --build . --parallel 4
cedit
exit
```

Release selects `Release`; profile selects `RelWithDebInfo`. Setup works from
outside the repository and with spaces in paths. It configures `build/` before
opening a fresh interactive Bash using `.project_env`; configuration errors
exit without opening that shell. Nested project shells are rejected. Exiting
returns to the original shell without changing its environment or directory.

The environment sources readable `~/.bashrc`, then prepends project `bin/`,
`scripts/`, and optional `CWHIP_SDK/bin` to PATH. It exports `_PROJECT_NAME`,
`_PROJECT_LOC`, `_BUILD_TYPE`, and `CWHIP_BUILD_TYPE`, and adds the project and
build mode to the prompt. Explicit `status`, `add`, `commit`, `push`, and `all`
Git functions act on this repository; `all` stages, commits and pushes only
when invoked. `dbg` forwards arguments to `cdbg`. Setup never fetches an SDK,
modifies Git state, or creates a virtualenv. The script and environment file
are project-owned and can be modified for local conventions.

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

`CWHIP_SDK` selects an installed prefix explicitly, including when switching
SDKs in an existing build tree; when unset, `Cwhip_DIR`, `CMAKE_PREFIX_PATH`,
and conventional CMake discovery apply. Missing resources, wrong
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
or private GTK headers. Xvfb and
dbus-daemon enable isolated headless suites; otherwise configuration prints
an explicit exclusion. No test uses the user's desktop. Ordinary CTest does
not rebuild the project; `test-all` builds first, `check-noop` is the explicit
incremental-build regression. This is a proof-of-concept interface with no
promise of cross-version runtime ABI or release packaging stability.

Font-property assertions wait for an actual GTK `after-paint` frame with a
five-second failure deadline. An idle callback (even after sleeping) can run
before GTK validates a newly created view's CSS and observe the default font.
The fixture synchronizes rendering, not retries the assertion or the test.
