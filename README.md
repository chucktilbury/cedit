# cedit

`cedit` is the Cwhip source editor: a GTK 4 and GtkSourceView application
implemented in Cwhip. Source:
[github.com/chucktilbury/cedit](https://github.com/chucktilbury/cedit).

This directory contains the editor in `src/`, tests in `tests/`, and build
helpers in `scripts/`. It is a standalone CMake project against an installed
Cwhip SDK (0.0.2, ABI `numeric-v2`, with GTK/SourceView packages). No compiler
checkout is required. It remains a proof of concept, not a production IDE.

With a current Cwhip SDK installed, run `scripts/setup [--clean] [debug|release|profile]`
from the checkout, then `build` in the project shell. Use `rebuild` for a
clean-first build, or `clean` to remove generated outputs; exit the shell before
running setup again. Executables land in `bin/`; intermediates stay in `build/`.
See the build guide for SDK selection.

- [Editor guide](CEDIT.md)
- [Build and installation](doc/BUILD.md)
- [Changelog](doc/CHANGELOG.md)

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
