# cedit

`cedit` is the Cwhip source editor: a GTK 4 and GtkSourceView application
implemented in the Cwhip language.

The editor is intended to be developed and tested alongside the Cwhip compiler.
This repository is the first source/history split from the Cwhip monorepo; its
standalone build, dependency/version policy, installation and release workflow
are not yet established. Until those are added, use the integrated build
instructions in the [Cwhip repository](https://github.com/chucktilbury/cwhip)
and read the [cedit guide](CEDIT.md).

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
Independent CMake configuration, tests/CI, install rules, desktop integration
and release/version compatibility are follow-up work tracked in the
[Cwhip Applications project](https://github.com/users/chucktilbury/projects/1).

## License

No standalone license has been selected for this repository yet. The public
source listing does not by itself grant reuse or redistribution rights.
