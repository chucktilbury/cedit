# Changelog

## Unreleased

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
