# Standalone cedit

Install a complete Cwhip **0.0.1** SDK (executables, runtime archive, headers,
builtins, packages and CMake config) built with GTK 4 >= 4.10 and GtkSourceView 5.
Clang, Python >= 3.11, CMake >= 3.24, a C compiler, pkg-config and those GTK
development libraries must be installed. This project never fetches a compiler.

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

Run `build/bin/cedit` or `/path/to/cedit/bin/cedit`. Its native launcher finds
`cedit.bin` beside its real executable, and the application finds installed
SourceView language definitions relative to that executable. The application
prefix may be moved as a whole. The compiler SDK is a build-time dependency,
not a runtime source-checkout dependency; system GTK/SourceView libraries
remain runtime prerequisites. Compiler actions selected in the editor require
the installed `cwhip` toolchain on PATH.

`Cwhip_DIR` or `CMAKE_PREFIX_PATH` selects the SDK. Missing resources, wrong
version or non-GUI SDKs fail at configure time. Builds use the SDK's
`cwhip_add_program` contract with private HOME/XDG/package locks and no user
module overrides. Generated files remain in the binary tree. `clean` uses
normal CMake rules; rebuilds recreate removed working directories.

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
