# cedit

`src/cedit.cw` is a GTK editor written in Cwhip. Its compiler
is `cwhip`; runtime and package ABI names use the `cwhip_*` prefix. The editor uses the optional GTK
package and a separate GtkSourceView-backed `sourceview` package. It provides
File, Edit, View, Project and Help menus, native open/save-as file choosers, multiple notebook tabs,
duplicate-path focusing, open/save/save-as, session
recent files, dirty tab titles, close protection, undo/redo, find/replace,
line/column status, a non-modal Preferences window, and configurable GTK keyboard shortcuts. GTK's text view
provides ordinary selection, cursor navigation, and clipboard bindings. Its
context menu retains native editing commands but omits Insert Emoji.

The editor's source adapter is `GtkSource.View`. It exposes managed multiline
text buffers, undo/redo, modified state, cursor coordinates, search/replace,
syntax-context queries, and shortcut registration while remaining attachable
to existing `Gtk.Widget` containers. The document editor uses GtkSourceView's
monospace setting; the rest of the application keeps the platform's normal
font. The `cwhip` GtkSourceView language
definition highlights Cwhip keywords/types, strings, comments, and
numbers. The SDK language definition recognizes `int8`/`uint8` through
`int64`/`uint64`, `fp32`/`fp64`, and numeric suffixes including `f64`.
Native numeric aliases `int`, `uint`, and `float` canonicalize to
`int32`, `uint32`, and `fp32` on the supported target; `unsigned`
remains reserved. Callable types use `R<P1,P2>` (or `void<>` for an action
with no parameters); `callback` is an ordinary identifier, not a keyword.
The SDK must also include the syntax cleanup in
[chucktilbury/cwhip#37](https://github.com/chucktilbury/cwhip/pull/37):
return operands use `return(expr)`, dictionaries use `[key: value]` or `[:]`,
and line comments use `#` or `//`, not `;`.
Conditional chains use `else(condition) { ... }`, not `else if`.
The SDK's conditional-chain support is tracked in
[chucktilbury/cwhip#38](https://github.com/chucktilbury/cwhip/pull/38).
cedit has no type-keyword completion list; bracket/quote auto-completion is
unchanged. Highlighting follows the file name. `.cw` uses the bundled `cwhip`
definition. Other names use the GtkSourceView language specs installed with
the SDK, so C, Python, and the other host definitions are highlighted.
Untitled documents, `.txt` files, and unrecognized names stay plain text.
Save As re-evaluates the language for the new name. See
[GTK source editing](https://github.com/chucktilbury/cwhip/blob/master/doc/GTK.md#language-definitions).
Documents are represented separately from notebook pages; opening an
already-open path selects its existing tab. `openDocument(path)` returns the
existing or newly opened document independently of selection, and
`activateDocument(document)` selects its tab; Project Explorer uses
these same APIs. The notebook, scrolled viewport, and source view explicitly
expand horizontally and vertically, so the multiline editor fills the remaining
window space and grows when the window is resized; the menu, search controls,
close prompt, and status line retain their natural height.

## Build and run

On Ubuntu 24.04 or Debian 13, for example, install the compiler/build tools and
optional GUI development and headless-test dependencies:

```sh
sudo apt install build-essential cmake clang python3 pkg-config \
  libgtk-4-dev libgtksourceview-5-dev xvfb dbus-daemon
```

Other releases need equivalent packages meeting CMake >= 3.24, Python >= 3.11,
and GTK >= 4.10; older distribution packages may not meet those requirements.

Install a complete Cwhip 0.0.2 SDK with the `numeric-v2` ABI, GTK 4 >= 4.10,
and rebuilt GtkSourceView support, including callable `R<P1,P2>` source
syntax and native `int`/`uint`/`float` aliases.
This standalone repository consumes that SDK; it does not build the compiler.
Start a project shell and build the editor:

```sh
export CWHIP_SDK=/path/to/installed/cwhip
scripts/setup debug
# In the new shell, initially in build/:
build cedit
cedit file1.cw file2.cw
```

Without an explicit mode, `scripts/setup` inherits the selected SDK's
application build default; if none is configured, CMake's default applies.
`debug`, `release`, and `profile` explicitly select Debug, Release, and
RelWithDebInfo. Exit the child shell to return to the original shell.
Use `scripts/setup --clean debug` (or `scripts/setup debug --clean`) to
remove generated build/staging trees before configuring. `--clean` alone
uses the SDK's default mode after removing the old cache.
The SDK can also be selected with `Cwhip_DIR` or `CMAKE_PREFIX_PATH`.
The editor needs the SDK's `Gtk.Application.schedule` callback. `src/cedit.cw`
holds the session fields and `start`; the other files in `src/` are classes
and method groups included from there.
Inside the project shell, `build [TARGET...]` and `rebuild [TARGET...]` work
with any CMake generator and from any directory; `rebuild` cleans CMake outputs
first. `clean` deletes the default generated trees entirely; exit and run
setup again afterward. The target uses private SDK package locks and compiles
the editor only when its inputs change. The executable is `<source>/bin/cedit`
by default; `CWHIP_BIN_DIR` and `CWHIP_LIB_DIR` override project output locations.
No manual compiler invocation or package activation is needed. Install with
`cmake --install build --prefix /path/to/cedit`; no desktop entry is installed.
See [the build guide](doc/BUILD.md) for direct CMake and relocation instructions.

The editor was previously named `cwhip-editor`; rebuild using the `cedit` target
and update commands to use `cedit`. The source entry point is now `cedit.cw`.
That editor rename did not change compiler or package names. The numeric-v2
migration does change the language's numeric types and native ABI: rebuild
cedit and native packages together; old SDK binaries are incompatible.
For continuity, cedit retains `$XDG_CONFIG_HOME/cwhip/settings.toml` (or
`$HOME/.config/cwhip/settings.toml`), the `cwhip-shortcuts.conf` legacy import,
and `.cwhip/project.toml` and `.cwhip/workspace.toml` project data.
It also retains the `org.cw.Editor` application ID for single-instance forwarding.
No user data is moved or rewritten as part of the rename.

`cedit` stays in the foreground until the editor exits. Startup failures remain
visible on stderr and return a nonzero exit status. The window appears normally,
not minimized or hidden. `--test` runs the built-in test action in that same
process. GUI diagnostics continue to use the launching terminal's stdout/stderr.

## Diagnostics

cedit-owned CLI and GUI failures use the shared
[diagnostic format](https://github.com/chucktilbury/cwhip/blob/master/doc/DIAGNOSTICS.md):
`cedit: error[CEDITxxxx]: explanation`. The shared template setup script keeps
its plain-text diagnostics; its usage errors return 2. CLI diagnostics go to
stderr, and other failures retain their existing
nonzero exit behavior. Codes identify stable reporting boundaries: `CEDIT0001`
for usage/startup invocation, `CEDIT1001`
and `CEDIT1002` for document open/save, `CEDIT2001` and `CEDIT2002` for settings
and project metadata, and `CEDIT3001` for process/configuration failures.
GUI file and project failures keep the affected path and reason visible and
include a recovery hint; failed document saves leave edits unsaved and do not
report success. Existing project/open dialogs remain, and routine information
stays in the status line.

The editor currently has no compiler action or compiler-output parser; source
diagnostics are therefore emitted by the compiler unchanged rather than being
rewrapped or parsed by cedit. CMake and GTK retain their own detailed diagnostics
where they own the failure.

Headless tests require Xvfb and `dbus-daemon`; they default to enabled when
those tools are present, otherwise configuration explicitly reports them
excluded without blocking the build. Set `-DBUILD_TESTING=OFF` to omit tests.
Missing SDK resources, incompatible SDK versions, and SDKs without SourceView
support fail at configure time. See [the standalone build guide](doc/BUILD.md).

**File > New** creates an editable untitled tab. **Open...** uses a native GTK
file chooser that allows selecting several files; each selected file is opened
(an already-open file focuses its existing tab) and the last one becomes active.
A failure for one file does not stop the others: the status line reports the
failure (or `Open failed for N of M files`), and one error dialog lists every
file that could not be opened. Binary files (containing NUL bytes) and files
that are not valid UTF-8 are refused with a "not a text file" error dialog;
they are never lossily decoded, and existing documents are unchanged.
**Save** writes the active document to its current path, or opens **Save As...**
for an untitled document initially named `untitled.cw`. Save As asks for confirmation before replacing an
existing file, and refuses a destination belonging to another open document.
Cancelling a chooser or overwrite confirmation leaves files and document
identities unchanged. Open/read/write/flush/close failures appear in the status
line; Open failures from the chooser or binary files also show a modal error
dialog parented to the editor window. The editor supports local filesystem paths; nonlocal chooser URIs are
explicitly rejected rather than interpreted as cancellation.
**Recent** is a submenu of files opened or saved in this session (most recent
first, up to 20). Choosing a path opens that file.
Command-line file arguments open tabs at startup.

**File > Save All** (`<Control><Alt>s`) saves every modified document with an
existing path. Untitled documents stay unsaved without opening Save As dialogs;
the status line reports the saved and skipped counts, or a save failure.

**Edit** offers Undo, Redo, Cut, Copy, Paste, Select All, Find, Replace,
Strip Trailing Spaces, and Preferences. **Strip Trailing Spaces** removes
trailing spaces and tabs from the active buffer without saving it; it has no
default shortcut.
Find and Replace open a separate, non-modal window transient for the editor.
The Find window contains the query and Find next; Replace adds the replacement
field and Replace next / Replace all. Closing the window hides it and preserves
the query/options for next time. The dialog follows the active document: its
search uses that tab's buffer, and in-selection bounds are stored separately
per document. While it is open, switching to a tab with selected text captures
that selection as the tab's search scope; tabs without a selection retain any
existing scope. If text is selected on a single line when Find or Replace
is opened, it replaces the Find query; otherwise the previous query is kept.
**Find next** selects the next match after the current selection,
wrapping around once; **Replace next** replaces the selected match (or the next
one), and **Replace all** replaces every match in one undoable step and reports
the count. The **Whole words**, **Case sensitive**, and **In selection** check
boxes apply to all three. Searches are case-insensitive substring matches by
default. The **In selection** scope is the selection active when Find or
Replace (menu or shortcut) is invoked, and its bounds follow replacements; a
selection that is just the last Find match keeps the existing scope, and
invoking Find or Replace with no selection clears it. With **In selection**
checked but no scope, the status line asks you to select text first. Undo/Redo and Cut/Copy menu items
track the active buffer's undo/redo and selection state. File dialogs are modal,
asynchronous, parented to the editor window, and cancelled on parent teardown;
they do not run nested event loops.

A modified tab is marked with `*`. Tabs have borders and a close icon; an icon
closes that tab even when it is not selected, using the same dirty-buffer
protection as the menu. **File > Close** (`<Control>w`) closes only
the active tab; closing the last tab leaves the window open with a fresh
untitled document. **File > Close All** (`<Control><Shift>w`) walks every tab
the same way: each modified document gets Save, Discard, or Cancel, and when
the batch finishes one untitled document remains. Cancel stops the batch and
keeps the remaining tabs. Only **Quit** (`<Control>q`) and a window-close
request exit the editor. Close, Close All, Quit, and a window-close request
offer in-app **Save**,
**Discard**, and **Cancel** controls for modified documents. Saving an
untitled document during close opens Save As; cancelling that chooser cancels
the pending close without discarding changes. For a window close with several
modified documents, Save handles them one at a time until all are saved.

Default shortcuts use GTK trigger notation: `<Control>s` saves,
`<Control>o` opens the file chooser, `<Control>n` creates a tab,
`<Control>f` focuses Find, `<Control>h` focuses Replace, `<Control>g` opens
**Go to Line…** (accepts `line` or `line:column`), `Tab` / `<Shift>Tab` indent
or outdent selected lines (or insert one indent unit at the caret),
`<Control>slash` toggles line comments (block comment is menu-only),
`<Control>z` undoes,
and `<Control><Shift>z` redoes. `<Control><Shift>s` opens Save As,
`<Control>w` closes the active tab, `<Control><Shift>w` closes every tab, and
`<Control>q` requests Quit. **File > Reload** reads the active file from disk.
Right-click the edit pane keeps the usual Cut/Copy/Paste menu and adds
**Reload** to it. A clean, unchanged buffer reports that it is already current.
A modified buffer, or one whose file changed underneath the editor, asks to
Reload, Save, or Close. The editor also checks the file on disk every few
seconds while it is open.
`<Control>x`, `<Control>c`, `<Control>v`, and `<Control>a` perform Cut, Copy,
Paste, and Select All. `<Control><Alt>s` saves all modified named documents,
and `<Control>comma` opens Preferences. Menus and configurable
shortcuts resolve to the same named command callbacks.

## Project Explorer

**File > Open Folder...** opens a modal folder chooser parented to the editor.
Acceptance replaces the root in a resizable left-hand Project Explorer;
cancellation leaves the current root and tabs unchanged. The root opens
automatically. Expand a directory with its arrow or click its name; a single click
on a file (or Enter on it) opens it through the same document-opening path
as File > Open, including existing-tab focus and binary/invalid-UTF-8 rejection.
Repeated activation focuses the existing tab, never opens a duplicate.
Right-click the explorer for **Refresh** and checked **Show Hidden**; these
controls are in the context menu, not separate sidebar buttons. Refreshes
preserve expanded folders and open buffers. Successful Save and Save As refresh
the tree when the saved path is under the root and not already listed; failed
or cancelled saves do not.

Only expanded directories are enumerated. Filesystem enumeration and
directories-first, case-sensitive UTF-8 byte-order sorting run off the GUI
thread; entries are delivered in small, bounded batches. GTK virtualizes
rows, and Cwhip retains loading state only for directories actually expanded,
not a managed object for every file in a large folder. Folder, source/text,
image, symlink and special-file icons distinguish entries. Symlinks are shown
as leaves, never recursively expanded; a link to a regular text file can still
be opened normally. Loading, empty-directory and read-error rows make progress
and failures visible. Non-UTF-8 filenames produce an explicit directory error,
rather than silently skipping or lossily decoding names.

**Refresh** re-reads the root after files are added, removed or permissions
change; **Show Hidden** includes dot-prefixed files and directories.
Both rebuild the tree with its root expanded and restore expanded descendants
as their parents load; open documents, unsaved edits and the active tab are
unchanged. Expansion
results are cached until that rebuild. Replacing the root, refreshing, or
closing the editor cancels obsolete work and prevents stale results from
repopulating the tree. A plain folder opened this way has no saved state; the
hidden-files toggle is never saved. Expansion, tabs and layout are saved only
for Cwhip projects (below). A file opened or saved outside the current root
is listed under that root by its absolute path and, for a Cwhip project, is
saved with the workspace. The Explorer does not rename or delete files.

The sidebar is a notebook. **Project** is the project tree. **Files** is a
second tree rooted at the project folder, or at the current directory when no
project is open. Right-click either tree for **Refresh** and **Show Hidden**.
Dragging the splitter cannot collapse the sidebar to zero, and the editor tab
strip scrolls so the sidebar can grow wider. **Close** on the sidebar hides it
and remembers the width. **View > Show Project Manager** shows it again. Giving a named file tab focus,
returning focus to the window, or the periodic disk check compares the
buffer's last loaded text with the file on disk. When they differ, the editor
asks to Reload, Save, or Close.

## Language server

Preferences stores `editor.lsp_command`. An empty command turns the client
off. `cwhip-lsp` talks to the Cwhip language server and only for `.cw` files.
`clangd` talks to clangd for C and C++ names. Any other command is split on
spaces and started as that server; plain-text names such as `.txt` and `.md`
are not sent. The editor keeps a full copy of each named buffer.
`textDocument/publishDiagnostics` marks each reported line in the gutter,
underlines it, tints the background, and shows the message on mouseover. The
status line only notes the count (never the full messages), so the window size
does not change when they appear. Restart the command by editing the preference;
it is saved with the other editor settings.

## View

**View** checkboxes apply immediately and are saved in the user settings file:

- **Show Line Numbers** is `editor.line_numbers` (default on). It stays in step
  with the same checkbox in Preferences. A project override still wins; changing
  the View item while an override is active updates that override and saves
  `project.toml`, so the buffer matches the check.
- **Show White Space** (`editor.show_whitespace`, default off) draws spaces,
  tabs, and non-breaking spaces.
- **Show Line Ends** (`editor.show_line_ends`, default off) draws newline marks.
- **Show Indent Markers** (`editor.show_indent_markers`, default off) draws a
  vertical guide at each tab-width step of leading indentation.
- **Show Project Manager** (`editor.show_project_manager`, default on) hides or
  shows the sidebar notebook. The project stays open, the Project menu keeps
  working, and the last sidebar width is kept. Hiding the sidebar does not
  store a zero width in the workspace. The sidebar close control is a flat **X**
  like a tab close and uses the same setting.

## Projects

A Cwhip project is a folder containing `.cwhip/project.toml`. Ordinary folders
still open through **File > Open Folder...** without any project metadata and
use only the global Preferences. Opening or creating a project never executes
anything: there are no build commands, LSP servers, plugins or trust prompts.

All project commands live in the **Project** menu and are ordinary named
commands (`project-new`, `project-open`, `project-save`, `project-save-as`,
`project-delete`, `project-configure`), so they can be bound in Preferences >
Keyboard like any other command. Choosers are modal folder choosers parented
to the editor; cancelling one changes nothing.

- **New Project...** chooses a root folder and creates `.cwhip/project.toml`
  and `.cwhip/workspace.toml` there (project name defaults to the folder name).
  Source files are never created, modified or moved. If the folder already has
  Cwhip metadata, a confirmation bar offers **Replace Metadata** or **Cancel**.
- **Open Project...** chooses a folder; it must already contain
  `.cwhip/project.toml`, otherwise an alert explains how to create one.
  Running `cedit DIR` opens `DIR` as a project when it contains that file and
  as a plain folder otherwise.
- **Close Project** writes the workspace, then leaves the same folder open
  without project settings. Documents stay open. `.cwhip` stays on disk. If
  that folder was the remembered startup project, the startup entry is cleared.
- **Save Project** writes the current configuration and workspace state.
- **Save Project As...** chooses a different folder and writes a copy of the
  project configuration plus the workspace state rebased to that folder. Saved
  tabs and expanded folders whose relative paths do not exist under the new
  root are dropped. A file outside the original root is kept when that file
  still exists. Source trees are not copied or moved, the original
  project's metadata is left untouched, and open documents stay open. The new
  folder becomes the active project. Existing metadata in the target requires
  **Replace Metadata**; choosing the current root is refused.
- **Delete Project...** asks for confirmation naming the root, then removes
  exactly `.cwhip/workspace.toml` and `.cwhip/project.toml` and removes
  `.cwhip` only if it is then empty. Source files and any other files in
  `.cwhip` are preserved; nothing is deleted recursively, and a symbolic-link
  `.cwhip` is refused. The editor stays on the same folder as a plain folder,
  documents stay open, and a remembered startup project for that root is
  forgotten.
- **Configure Project...** opens a non-modal window parented to the editor:
  project name, Explorer exclusions, and editor overrides. **Apply** validates
  and saves `project.toml` and applies the result immediately; **Reset All to
  Inherit** unchecks every override.

**Open Project** prompts **Save** / **Discard** / **Cancel** for modified
documents before saving the outgoing workspace and replacing the open tabs.
**Quit** likewise resolves dirty documents before writing workspace state.
**New Project** and **Open Folder** save the outgoing project's workspace but
keep open documents and dirty buffers, so they do not prompt to save those
buffers. **Delete Project** removes its metadata after confirmation without
first saving its workspace, and keeps open documents. Dirty edits are never
written to workspace state. A workspace-save failure when switching offers
**Continue Without Saving** or **Cancel**; at Quit it offers **Quit Without
Saving** or **Cancel**.

### Settings precedence

Effective editor settings are project override, then user Preference, then the
built-in default. In Configure Project, a checked override row stores its value
in `project.toml`; an unchecked row is absent from the file and inherits. While
a project is active, Preferences shows which settings the project overrides,
and changing an overridden Preference is saved but does not affect that
project's documents. Overrides apply to existing and newly opened documents.

### Explorer exclusions

`[explorer] exclude` is a list of glob patterns (`*`, `?`) matched with GLib
`g_pattern_match_simple`. A pattern without `/` matches an entry name at any
depth (`build`, `*.log`); a pattern containing `/` matches the path relative to
the project root (`docs/generated`). Patterns must not start or end with `/`
or contain `.`/`..` segments. Excluded entries are hidden from the Explorer
and never enumerated; files remain on disk and can still be opened with File >
Open. Configure Project accepts the list comma-separated.

### Storage format

`.cwhip/project.toml` (at most 64 KiB) is meant to be shared:

```toml
version = 1

[project]
name = "Demo"

[explorer]
exclude = ["build", "*.log"]

[editor]          # optional; each absent key inherits
tab_width = 2
insert_spaces = false
```

Editor keys and ranges are the same as user settings (`font_family`,
`font_size`, `tab_width`, `insert_spaces`, `line_numbers`, `wrap`,
`right_margin` (0 hides the guide; default 80),
`highlight_current_line`). Unknown keys are retained when saving.

`.cwhip/workspace.toml` (at most 1 MiB) is local session state:

```toml
version = 1

[workspace]
active = "src/a.cw"
explorer_width = 300
window_width = 980
window_height = 720
expanded = ["src"]
files = [
    { path = "src/a.cw", line = 2, column = 3 },
    { path = "/home/me/notes/outside.txt", line = 1, column = 1 }
]
```

Paths inside the project are relative to the project root. A file opened or
saved outside that root is stored as an absolute path and shown in the
Explorer under the project, labeled with that path. `..` segments, `.`
segments and absolute paths that escape through those segments are rejected.
An absolute path that is actually inside the root is stored in root-relative
form. **Save Project As** keeps an outside file when that file still exists.
Only saved files with a path are recorded (untitled tabs are not). Closing an
outside file leaves it in the Explorer; the next project save still records
it. On restore, missing files, binary/invalid UTF-8 files and read errors are
skipped and reported; cursors are clamped to the file. Widths are 0-5000 and
window sizes 200-10000 x 150-10000; GTK may enlarge the window to its minimum
size or the screen.

For version control, commit `.cwhip/project.toml` and ignore the local state:

```gitignore
.cwhip/workspace.toml
```

Both files are written with the same asynchronous atomic replacement as user
settings, private permissions, and an expected-content check that refuses to
overwrite a file changed by another process. Malformed TOML, unsupported or
missing `version`, wrong types/ranges, oversized files and read errors are
reported in an alert. Invalid values are ignored, and saving the invalid file
is disabled until it is repaired and the project reopened, so it is never
overwritten automatically. Write failures are reported and never shown as
saved. Persisted paths are only used to open text files; they never authorize
deletion or execution.

### Reopening the last project

Preferences > Startup has **Reopen last project on startup** (default off). When
enabled, the **global** user settings file (`$XDG_CONFIG_HOME/cwhip/settings.toml`)
remembers only the root path of the last active project:

```toml
[project]
reopen_last = true
last_root = "/home/me/src/demo"
```

Those two keys are not stored in per-folder `.cedit/settings.toml` copies, so a
local editor preference cannot look enabled while the global `last_root` is
missing. The workspace itself stays in that project's `.cwhip`. Only this
metadata path is recognized. Older product-named project metadata is ignored and
left untouched; the editor does not copy, rename, or migrate it. Turning the
option off clears `last_root`. At startup the project is reopened only if the
option is on and no file or folder was given on the command line. A missing or
invalid remembered project is reported in an alert, `last_root` is cleared so
the next launch does not keep failing, and the editor starts normally. If the
shared global settings file is malformed, cedit repairs the `[project]` section
(preserving `sdk_prefix` when present) before reading it.

## About

**Help > About cedit...** opens a small window parented to the editor showing the
editor name, version (currently 0.0.1, matching `CMakeLists.txt`), a short
description, and website/repository URLs as text. **Close** hides it; it is
closed with the editor. The current dialog has stale licensing and repository
text: this repository is [MIT-licensed](LICENSE), despite the dialog's
"no license file" message, and cedit's repository is
[chucktilbury/cedit](https://github.com/chucktilbury/cedit), not the upstream
Cwhip repository shown there.

## Preferences and settings

**Edit > Preferences...** or **Ctrl+,** opens a non-modal window with Editor,
Keyboard, Project, and Startup navigation on the left. Closing it hides it;
reopening preserves the selected page. Changes apply immediately to all open
documents and to subsequently created/opened documents, without changing file
contents, modified state, language detection, or search options. **Project**
opens Configure Project when a project is open (same size as the other
category buttons). Preferences always use the full settings schema under
`.cedit/settings.toml` for the active project or folder; local settings take
precedence. **Save to global settings** also copies the current preferences
into the global template used to seed new directories.

The **Editor** page controls an installed monospace font family (or the generic
`monospace`), font size, tab width, insertion of spaces vs tabs, line numbers,
wrapping, and current-line highlighting. Font names must be 1-128 UTF-8 bytes
without control characters; proportional/unknown families are rejected.
Font size is an integer **6-72 points**, and tab width is an integer **1-16
columns**. Defaults are `monospace`, 12 pt, 4 columns, spaces, line numbers on,
wrapping off, and current-line highlighting off. Changing tab width/insertion
does not rewrite existing indentation.

**Strip trailing spaces on save** is off by default. When enabled, every
document save (including Save All and automatic saves) strips trailing spaces
and tabs from the buffer before writing. **Auto-close brackets and quotes**
is on by default and can be disabled independently. It inserts matching
brackets/quotes, wraps selected text, steps over a matching closing character,
and deletes an empty pair together on Backspace. These two settings are
global preferences, not project overrides.

**Save on loss of tab focus** and **Save on loss of window focus** are independent,
persisted options, both off by default. Tab loss saves the outgoing modified
document; window loss saves all modified named documents, including when focus
moves to another window. Untitled buffers stay dirty without opening surprise
Save As dialogs. Pending file/close/project operations suppress automatic saves.
Failures leave buffers dirty and report a persistent status-line error without
opening dialogs or causing focus/dialog loops. Explicit Save and close protections
remain available.

The **Keyboard** page searches named commands, displays their current GTK
trigger strings in aligned, read-only text boxes, and permits recording one key
combination. Text remains selectable/copyable; shortcuts cannot be typed into
the fields. Click
**Record**, then press the combination; modifiers alone keep recording and
Escape cancels. Starting another recording, switching categories, or hiding
Preferences cancels the previous recorder. Invalid syntax and conflicts
(compared using canonical GTK triggers, not raw spelling) show an error without
replacing either command. **Disable** removes a binding; **Reset** restores one
binding unless its default would conflict. Each section's **Reset to Defaults**
requires **Confirm Reset**; **Cancel** changes nothing. Named command
shortcuts are configurable; GTK's ordinary text navigation remains native.

Preferences save automatically to `.cedit/settings.toml` in the active project
or folder. That local file uses the same schema as the global template at
`$XDG_CONFIG_HOME/cwhip/settings.toml` (or `$HOME/.config/cwhip/settings.toml`
when XDG_CONFIG_HOME is unset/empty). Starting in a directory without a local
file replicates the global template there. Opening a root that already has a
local file loads it instead. **Save to global settings** keeps writing the
local file and also updates the global template. Startup reopen of the last
project is remembered in the global template. Settings in older product-named
directories are ignored and left untouched; the editor does not copy or
migrate them.
The config root must be absolute. The settings file is user-editable UTF-8 TOML,
with a 64 KiB limit and this version-1 schema:

```toml
version = 1

[editor]
font_family = "monospace"
font_size = 12
tab_width = 4
insert_spaces = true
line_numbers = true
show_whitespace = false
show_line_ends = false
show_indent_markers = false
show_project_manager = true
wrap = false
right_margin = 80
highlight_current_line = false
save_on_tab_loss = false
save_on_window_loss = false
strip_trailing_spaces = false
auto_complete_brackets = true

[keyboard]
save = "<Control>s"
close = "<Control>w"
quit = "<Control>q"
find = "<Control>f"
replace = "<Control>h"
preferences = "<Control>comma"

[project]
reopen_last = false
last_root = ""
```

Editor keys are optional and use defaults when absent. Keyboard keys are
command IDs (`new`, `open`, `save`, `save-as`, `save-all`, `close`, `quit`,
`find`, `replace`, `undo`, `redo`, `cut`, `copy`, `paste`, `select-all`,
`strip-trailing-spaces`, `preferences`,
`project-new`, `project-open`, `project-save`,
`project-save-as`, `project-delete`, `project-configure`, `about`); omitted IDs
use defaults and `""` explicitly disables one. Unknown keyboard commands are
errors. A missing file is normal first-run behavior: no file is created until
a valid setting changes.

The SDK location lives in a separate `cwhip/sdk.toml` (see
[SDK selection](doc/BUILD.md#sdk-selection)); cedit never writes it. A legacy
`settings.toml` may still contain a top-level `sdk_prefix` string, used only
when `sdk.toml` is absent. An absent `version` is accepted: supplied valid editor
settings still apply, and absent keys use their defaults. Saving
preferences adds `version = 1` and preserves `sdk_prefix` and other unrelated
keys. An explicitly supplied version must still be the integer `1`.

Malformed TOML, wrong types/ranges, invalid/conflicting shortcuts, read errors,
unsupported versions, and strings with encoded NULs are reported in a
startup alert and Preferences. Valid entries still apply, invalid editor entries
use defaults, and invalid/conflicting bindings are not installed. Automatic
saving is disabled for that session, so the original file is not clobbered;
repair it and restart. Preference edits can still apply for the current session.
Write failures are displayed explicitly and never reported as saved.

Saving uses asynchronous GIO atomic replacement on the local filesystem,
with private file permissions, an expected-content check and an ETag check
against concurrent edits. Changes arriving during a save are coalesced into
the next save. Quit waits for the latest queued save; a write failure keeps
Preferences available rather than claiming success. Unknown valid keys/tables
outside the keyboard command map are retained. Serialization normalizes
formatting and does not retain comments; nested unrelated tables/arrays may
be emitted inline. External edits/removal require restarting before saving.

### Shortcut import file

`cwhip-shortcuts.conf` in the working directory takes precedence.
It is read when the TOML settings file is absent or has no `[keyboard]` table.
Product-named shortcut files are ignored and left untouched. Each nonblank line maps one
GTK trigger to one command:

```text
<Control>s=save
<Control>o=open
<Control>n=new
<Control>f=find
<Control>h=replace
<Control>z=undo
<Control><Shift>z=redo
<Control><Shift>s=save-as
<Control>w=close
<Control>q=quit
<Control>x=cut
<Control>c=copy
<Control>v=paste
<Control>a=select-all
```

As before, a legacy file **replaces** the default shortcut map: commands omitted
from it remain disabled. Preferences adds its new Ctrl+, binding only if the
legacy map does not already use that trigger and does not configure Preferences
itself. The menu always remains available. An existing TOML `[keyboard]` table is authoritative
and the legacy file is ignored, even if malformed; missing TOML command keys
then use built-in defaults, not legacy bindings.

The first successful preferences edit saves the complete effective map
(including disabled commands) into TOML, migrating without deleting or
rewriting the legacy file. Subsequent starts use TOML. Duplicate triggers,
duplicate command lines (multiple bindings for one command cannot be represented
by this increment), unknown commands, empty legacy triggers, and invalid triggers
are reported explicitly, and automatic migration/saving is disabled until
repaired. A conflicting later legacy line never overrides the earlier command.

## Deliberately deferred

There is no language server in this iteration. The repository does not provide
a real Cwhip LSP server, and the current process APIs do not yet constitute a
complete JSON-RPC client with correct Content-Length framing, split-message
handling, ordered writes, request correlation, cancellation, notifications,
and shutdown. The editor does not mislabel compiler checking as LSP. A future
LSP client should be a separate configurable component attached to the document
and buffer APIs.

Projects deliberately do not include unsaved-buffer recovery (dirty edits are
only kept in memory), build commands, LSP configuration, plugins, Git
integration or project trust. Persistent recent history, an extension/plugin
runtime, and a configurable toolbar are not included yet. The
dialog controls and menu/shortcut commands use the same editor actions, so a
future toolbar can reuse those actions.
Any future in-process plugins should be treated as trusted code.

Appearance, Files/session, Build, and LSP preference categories and
file-type overrides are future work; no placeholder pages are installed.

Run the standalone editor's headless suite (build first), or use `test-all`
to build and then run it:

```sh
# In the project shell (initially in build/):
ctest --output-on-failure
build test-all
```
