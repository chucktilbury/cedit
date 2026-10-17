# Changelog

## Unreleased

- Add the MIT License.
- Adopt the Cwhip template's executable project-shell setup with Debug, Release,
  and profiling configurations and optional installed-SDK selection.
- Default application executables to project-root `bin/` and native libraries
  to `lib/`, with configurable output directories and build-only creation.
- Preserve the standalone editor, native launcher, SDK resource staging,
  installation, headless tests, and no-op/clean build behavior.
- Replace obsolete integrated compiler/example build instructions with the
  standalone installed-SDK workflow.
