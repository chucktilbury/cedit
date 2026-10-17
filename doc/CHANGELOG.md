# Changelog

## Unreleased

- Accept shared SDK-only settings without an editor version; preference saves
  add version 1 and preserve the SDK prefix. Explicit unsupported versions
  remain errors.
- Discover the installed SDK prefix from the top-level `sdk_prefix` in
  `$XDG_CONFIG_HOME/cwhip/settings.toml` (or `$HOME/.config/cwhip/settings.toml`)
  in both CMake and setup, with precedence non-empty `CWHIP_SDK` > settings >
  normal CMake discovery. Settings are parsed safely with Python 3.11+ and
  invalid selections fail without falling back. Add discovery regression tests.
- Add the MIT License.
- Adopt the Cwhip template's executable project-shell setup with Debug, Release,
  and profiling configurations and optional installed-SDK selection.
- Default application executables to project-root `bin/` and native libraries
  to `lib/`, with configurable output directories and build-only creation.
- Preserve the standalone editor, native launcher, SDK resource staging,
  installation, headless tests, and no-op/clean build behavior.
- Replace obsolete integrated compiler/example build instructions with the
  standalone installed-SDK workflow.
