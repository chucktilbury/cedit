# cedit

`cedit` is the Cwhip source editor: a GTK 4 and GtkSourceView application
implemented in the Cwhip language.

This is a standalone CMake project consuming the installed Cwhip 0.0.1 SDK.
No compiler or workspace checkout is required. See [the build guide](doc/BUILD.md)
and [cedit guide](CEDIT.md). It remains a proof of concept, not a production IDE.

Run `scripts/setup` for a Debug project shell (`release` and `profile` are also
supported), then `cmake --build . --parallel 4`. The SDK is selected by a
non-empty `CWHIP_SDK`, then the `sdk_prefix` in `$XDG_CONFIG_HOME/cwhip/sdk.toml` (or `~/.config/cwhip/sdk.toml`;
legacy `settings.toml` only when `sdk.toml` is absent),
then normal CMake discovery; see [SDK selection](doc/BUILD.md#sdk-selection).
Executables are built in the repository's
`bin/` directory; intermediate files stay in `build/`. The shell and output
conventions follow [cwhip-template](https://github.com/chucktilbury/cwhip-template),
without a template dependency or synchronization step.

## Source

- `src/cedit.cw` — editor application
- `src/launcher.c` — application launcher
- `src/cwhip-shortcuts.conf` — legacy shortcut configuration import
- `CEDIT.md` — current build, behavior and configuration notes

The initial source import preserves the history of `examples/editor/` from
[Cwhip commit `5a229c6`](https://github.com/chucktilbury/cwhip/commit/5a229c632a1bddd01891c0ef0776f37e34ab8290).
The original Cwhip repository provides the shared compiler, runtime, GTK binding
and package APIs through its installed SDK.

## Status

This is an active proof of concept and a workload for testing Cwhip as an
application language, not yet a separately packaged production editor.
Independent CMake build/test/clean/install is supported. Desktop integration,
release packaging and compatibility beyond the exact SDK version remain work in the
[Cwhip Applications project](https://github.com/users/chucktilbury/projects/1).
See [the changelog](doc/CHANGELOG.md) for repository changes.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
