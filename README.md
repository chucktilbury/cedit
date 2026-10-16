# cedit

`cedit` is the Cwhip source editor: a GTK 4 and GtkSourceView application
implemented in the Cwhip language.

This is a standalone CMake project consuming the installed Cwhip 0.0.1 SDK.
No compiler or workspace checkout is required. See [the build guide](doc/BUILD.md)
and [cedit guide](CEDIT.md). It remains a proof of concept, not a production IDE.

## Source

- `src/cedit.cw` — editor application
- `src/launcher.c` — application launcher
- `src/cwhip-shortcuts.conf` — legacy shortcut configuration import
- `CEDIT.md` — current build, behavior and configuration notes

The initial source import preserves the history of `examples/editor/` from
[Cwhip commit `5a229c6`](https://github.com/chucktilbury/cwhip/commit/5a229c632a1bddd01891c0ef0776f37e34ab8290).
The original Cwhip repository remains the source of shared compiler, runtime,
GTK binding and package APIs until the standalone dependency boundary is
implemented.

## Status

This is an active proof of concept and a workload for testing Cwhip as an
application language, not yet a separately packaged production editor.
Independent CMake build/test/clean/install is supported. Desktop integration,
release packaging and compatibility beyond the exact SDK version remain work in the
[Cwhip Applications project](https://github.com/users/chucktilbury/projects/1).

## License

No standalone license has been selected for this repository yet. The public
source listing does not by itself grant reuse or redistribution rights.
