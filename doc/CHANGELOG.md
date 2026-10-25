# Changelog

## Unreleased

- Match the template setup and project environment byte-for-byte: accept
  `--clean` in either argument order and expose `build`/`rebuild` as shell
  functions, retaining the standalone `clean` command. Support settings-file
  paths in the SDK parser as well as CMake's directory input. Document the
  setup-first workflow and template-owned plain-text setup diagnostics.
- Adopt Cwhip's syntax cleanup from compiler PR #37: parenthesize return
  operands in the editor and generated test drivers, and require matching SDK
  syntax definitions. Cover hash comments, removal of semicolon-comment
  highlighting, multiline bracket dictionary/list literals, and
  `else(condition)` chains from compiler PR #38. Preserve full SDK paths in
  the long-prefix discovery diagnostic test while accounting for CMake's
  whitespace wrapping.
- Isolate test HOME/configuration and clear inherited CMake/Cwhip environment
  overrides so the host's SDK selection and build type cannot affect tests.
- Require Cwhip 0.0.2 with SDK ABI `numeric-v2`, rejecting missing or incompatible
  ABI markers during SDK discovery. Migrate editor counts, positions, IDs and
  native test signatures to `int64`, and string conversions to `toInt64`.
  Cover preference/workspace numeric bounds, exact dynamic menu ID types, and
  the SDK's ten numeric type spellings, reserved old names and literal suffixes.
- Diagnose stale 0.0.1 SDKs missing application defaults with `CEDIT2001`,
  identifying the selected SDK and requiring an updated SDK rebuild/install
  instead of an unknown CMake command or silent fallback.
- Keep automatic-save failures in the diagnostic explanation, preserving the
  visible `Automatic Save failed` context and dirty buffers across tab/focus
  changes and successful saves of other documents.
- Adopt stable `CEDIT` diagnostic codes for setup, launcher, SDK discovery,
  document open/save, project metadata, and settings-save failures. GUI errors
  preserve file paths and reasons, include recovery guidance, and explicitly
  retain unsaved edits after failed saves. Link the shared diagnostics contract.
- Accept shared SDK-only settings without an editor version; preference saves
  add version 1 and preserve the SDK prefix. Explicit unsupported versions
  remain errors.
- Discover the installed SDK prefix from the top-level `sdk_prefix` in
  `$XDG_CONFIG_HOME/cwhip/sdk.toml` (or `$HOME/.config/cwhip/sdk.toml`; legacy
  `settings.toml` is read only when `sdk.toml` is absent, so editor preference
  saves can no longer clobber the SDK location)
  in both CMake and setup, with precedence non-empty `CWHIP_SDK` > settings >
  normal CMake discovery. Settings are parsed safely with Python 3.11+ and
  invalid selections fail without falling back. Add discovery regression tests.
- Inherit SDK-provided application `install_prefix` and `build_type` defaults
  through `cwhip_apply_application_defaults()`, preserving explicit CMake
  settings and existing build caches. Setup no longer passes a build type
  unless the user explicitly selects a mode; add override, cache-preservation,
  and install-staging regression coverage.
- Add the MIT License.
- Adopt the Cwhip template's executable project-shell setup with Debug, Release,
  and profiling configurations and optional installed-SDK selection.
- Default application executables to project-root `bin/` and native libraries
  to `lib/`, with configurable output directories and build-only creation.
- Preserve the standalone editor, native launcher, SDK resource staging,
  installation, headless tests, and no-op/clean build behavior.
- Replace obsolete integrated compiler/example build instructions with the
  standalone installed-SDK workflow.
