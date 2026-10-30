# Changelog

## Unreleased

- Auto-indent (when enabled) adds a level inside `{` / `[` and splits paired
  braces on Enter; still copies the previous line's indent otherwise.
- Recovery Restore clears the snapshot before dismissing the prompt (it used to
  reappear with a `*` title); Cancel keeps the saved file on disk.
- Editor scrollbars use automatic policy again; the GtkGizmo snapshot warning on
  undo/scroll is a GTK TextView bug (#6057) filtered in cwhip. Unsaved-mark
  gutter updates stay deferred.
- Unsaved gutter marks use an insert/delete-aware line alignment so adding a
  line marks that line only, not every following line.
- Preferences: Auto-indent new lines (`auto_indent`, default on) and Mark
  unsaved changed lines in the gutter (`show_unsaved_marks`, default on). Unsaved
  marks are gutter icons only (no line highlight).
- Preferences: **Save to global settings** is a one-shot button (not a checkbox);
  Reset Editor/Keyboard buttons use natural width instead of stretching full-width.
  Right-margin guide visibility needs the matching cwhip SourceView draw fix.
- Trusted in-process plugin hooks (`registerPlugin`) with Plugins menu demos:
  Insert date/time and Toggle `# debug:` marker (also on the edit context menu).
- Crash recovery: dirty buffers snapshot to `.cedit/recovery/`; Restore/Discard
  on project reopen; cleared after Save.
- Edit > Find in Project… (`Ctrl+Shift+F`) searches the project tree (literal
  match; open buffers preferred; no replace); activate a hit to open and center.
- Multi-line selections accept typing / Backspace / Delete at the same column on
  each selected line (cwhip `setSelectedLinesEdit`; not true multi-carets).
- Gutter marks unsaved lines (vs last saved `diskText`); cleared on save/reload.
- Editor preference `right_margin` (default 80, 0 = off) draws the SourceView
  long-line guide.
- Edit > Toggle Line Comment (`Ctrl+/`) and Toggle Block Comment; language-aware
  `//` / `#` and `/* */` for C-family selections.
- Edit > Indent / Outdent (`Tab` / `Shift+Tab`) indent selected lines using the
  configured tab width and spaces-vs-tabs setting; a caret with no multi-line
  selection inserts one indent unit.
- Edit > Go to Line… (`Ctrl+G`) accepts `line` or `line:column` and centers
  the cursor in the active document.
- A failed startup reopen (missing or invalid `last_root`) clears that path so
  the next launch does not keep alerting; `reopen_last` stays enabled.
- Startup reopen (`reopen_last` / `last_root`) is stored only in the global
  settings file, repaired when that file is malformed, and no longer shadowed
  by a per-folder `.cedit` copy of those keys.
- Preferences navigation is Editor, Keyboard, Project, Startup. Project opens
  Configure Project. Each folder uses a full `.cedit/settings.toml` seeded
  from the global template, with local precedence; an optional checkbox also
  updates the global defaults.
- File > Recent is a submenu; the sidebar close control is a flat X; View has
  Show Line Ends.
- The project sidebar cannot be dragged to zero width, and the editor notebook
  scrolls its tabs so the sidebar can grow past the old maximum.
- `cwhip-lsp` only receives `.cw` buffers; `clangd` only C/C++ names; other
  servers skip plain text such as `.txt` and `.md`.
- Language-server diagnostics no longer show a message strip under the document,
  and the status line only notes the count, so the window does not resize when
  they arrive. Marks and tooltips still carry the messages.
- Keep the native edit-pane Cut/Copy/Paste menu and add Reload to it. Project
  and Files right-click menus are native menu rows for Refresh and Show Hidden.
- File > Recent opens a chooser of session files. External disk edits are
  polled while a file is open. Language-server diagnostics mark, underline,
  and tooltip the reported lines.
- Split the editor into class and method files under `src/`. The session
  class stays in `src/cedit.cw` and includes the rest.
- Add File > Reload, a sidebar Close button, and a Files page beside the
  project tree. Focusing a file tab compares it with the copy on disk and can
  reload, save over that copy, or close the tab. Preferences can start
  `cwhip-lsp`, `clangd`, or another language server command.
- Add a View menu for line numbers, white space, indent markers, and the
  project sidebar. Those choices are saved in the user settings. File > Close
  All closes every tab, and Project > Close Project detaches the project
  without deleting its metadata.
- Open and save files that live outside the project root. Those files appear
  in the Explorer and are stored in `.cwhip/workspace.toml` as absolute paths.
  Paths inside the project stay root-relative.
- Read string bytes with `text[index]` and copy half-open spans through an
  inclusive range. The SDK no longer provides `String.byteAt` or `String.slice`.
  Empty spans stay empty, including a typed value whose payload is only its
  type prefix.
- Highlight C, Python, and the other GtkSourceView language specs installed
  with the SDK. `.cw` stays on the bundled Cwhip definition. Untitled buffers,
  `.txt` files, and unrecognized names stay plain text.
- Keep `project()` on the C language so CMake still records `CMAKE_BUILD_TYPE`
  after the launcher source was removed.
- Run the editor as one foreground executable named `cedit`. Remove the native
  launcher, `cedit.bin`, and `--foreground`. Install that program as `bin/cedit`.
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
