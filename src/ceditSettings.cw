class CeditSettings {
    String fontFamily
    int64 fontSize
    int64 tabWidth
    bool insertSpaces
    bool lineNumbers
    bool showWhitespace
    bool showLineEnds
    bool showIndentMarkers
    bool showProjectManager
    String lspCommand
    bool wrap
    bool highlightLine
    bool saveOnTabLoss
    bool saveOnWindowLoss
    bool stripTrailingSpaces
    bool autoCompleteBrackets
    bool reopenLast
    String lastRoot
    list commands
    String globalPath
    String path
    String original
    String errors
    bool writable
    bool legacyConflict
    int64 shortcutRevision

    CeditSettings() {
        resetEditor()
        commands = [
            CommandBinding("new", "New document", "<Control>n"),
            CommandBinding("open", "Open files", "<Control>o"),
            CommandBinding("save", "Save", "<Control>s"),
            CommandBinding("save-as", "Save as", "<Control><Shift>s"),
            CommandBinding("save-all", "Save all", "<Control><Alt>s"),
            CommandBinding("close", "Close tab", "<Control>w"),
            CommandBinding("close-all", "Close all tabs", "<Control><Shift>w"),
            CommandBinding("reload", "Reload", ""),
            CommandBinding("quit", "Quit", "<Control>q"),
            CommandBinding("find", "Find", "<Control>f"),
            CommandBinding("replace", "Find and replace", "<Control>h"),
            CommandBinding("undo", "Undo", "<Control>z"),
            CommandBinding("redo", "Redo", "<Control><Shift>z"),
            CommandBinding("cut", "Cut", "<Control>x"),
            CommandBinding("copy", "Copy", "<Control>c"),
            CommandBinding("paste", "Paste", "<Control>v"),
            CommandBinding("select-all", "Select all", "<Control>a"),
            CommandBinding("strip-trailing-spaces", "Strip trailing spaces", ""),
            CommandBinding("preferences", "Preferences", "<Control>comma"),
            CommandBinding("project-new", "New project", ""),
            CommandBinding("project-open", "Open project", ""),
            CommandBinding("project-save", "Save project", ""),
            CommandBinding("project-save-as", "Save project as", ""),
            CommandBinding("project-delete", "Delete project metadata", ""),
            CommandBinding("project-configure", "Configure project", ""),
            CommandBinding("project-close", "Close project", ""),
            CommandBinding("view-line-numbers", "Show line numbers", ""),
            CommandBinding("view-whitespace", "Show white space", ""),
            CommandBinding("view-line-ends", "Show line ends", ""),
            CommandBinding("view-indent-markers", "Show indent markers", ""),
            CommandBinding("view-project-manager", "Show project manager", ""),
            CommandBinding("about", "About cedit", "")
        ]
        reopenLast = false
        lastRoot = ""
        original = ""
        errors = ""
        writable = true
        legacyConflict = false
        shortcutRevision = 1
        String configHome = System.Process().getEnv("XDG_CONFIG_HOME")
        if (configHome.equals("")) {
            configHome = System.FileSystem().join(System.Process().getEnv("HOME"), ".config")
        }
        globalPath = System.FileSystem().join(configHome, "cwhip/settings.toml")
        path = globalPath
        if (!configHome.startsWith("/")) {
            error("XDG_CONFIG_HOME (or HOME fallback) must be an absolute path")
        }
        load()
    }

    bool saveToGlobal() { return(path.equals(globalPath)) }

    String localPath(String root) {
        return(System.FileSystem().join(root, ".cedit/settings.toml"))
    }

    void resetEditor() {
        fontFamily = "monospace"
        fontSize = 12
        tabWidth = 4
        insertSpaces = true
        lineNumbers = true
        showWhitespace = false
        showLineEnds = false
        showIndentMarkers = false
        showProjectManager = true
        lspCommand = ""
        wrap = false
        highlightLine = false
        saveOnTabLoss = false
        saveOnWindowLoss = false
        stripTrailingSpaces = false
        autoCompleteBrackets = true
    }

    void error(String message) {
        if (!errors.equals("")) { errors.append("\n") }
        errors.append(message)
        writable = false
    }

    CommandBinding command(String id) {
        int64 i = 0
        while (i < commands.length) {
            CommandBinding binding = commands[i] as CommandBinding
            if (binding.id.equals(id)) { return(binding) }
            i = i + 1
        }
        return(null)
    }

    String bindingError(CommandBinding binding, String trigger) {
        if (trigger.equals("")) { return("") }
        String normalized = binding.normalized
        if (!trigger.equals(binding.trigger)) { normalized = Gtk.Keyboard().normalize(trigger) }
        if (normalized.equals("")) { return(format("Invalid shortcut trigger: {}", trigger)) }
        int64 i = 0
        while (i < commands.length) {
            CommandBinding other = commands[i] as CommandBinding
            if (other != binding && !other.trigger.equals("") &&
                other.normalized.equals(normalized)) {
                return(format("Shortcut conflicts with {}: {}", other.name, trigger))
            }
            i = i + 1
        }
        return("")
    }

    void loadLegacy() {
        String legacy = "cwhip-shortcuts.conf"
        String presence = Gtk.Config().fileStatus(legacy)
        if (presence.equals("missing")) { return }
        if (presence.length > 0) {
            error(format("Could not read {}: {}", legacy, presence))
            return
        }
        System.File file = null
        try {
            file = System.File(legacy, "r")
        } except(Exception) {
            error(format("Could not read {}", legacy))
            return
        }
        list lines = file.readLines()
        String readError = System.System().lastError()
        file.close()
        if (!readError.equals("")) {
            error(readError)
            return
        }
        // Legacy files replaced the entire default map. Preserve that behavior.
        int64 i = 0
        while (i < commands.length) {
            (commands[i] as CommandBinding).setTrigger("")
            i = i + 1
        }
        i = 0
        while (i < lines.length) {
            String line = (lines[i] as String).trim()
            if (!line.equals("")) {
                list fields = line.split("=")
                if (fields.length != 2) {
                    error(format("Invalid shortcut config line {}", i + 1))
                } else {
                    CommandBinding binding = command((fields[1] as String).trim())
                    String trigger = (fields[0] as String).trim()
                    if (binding == null) {
                        error(format("Unknown legacy shortcut command: {}", fields[1] as String))
                    } else {
                        String problem = bindingError(binding, trigger)
                        if (trigger.length == 0) { problem = "Empty legacy shortcut trigger" }
                        if (!problem.equals("")) {
                            legacyConflict = true
                            error(problem)
                        } else {
                            if (!binding.trigger.equals("")) {
                                error(format("Duplicate legacy command: {}", binding.id))
                            } else { binding.setTrigger(trigger) }
                        }
                    }
                }
            }
            i = i + 1
        }
        CommandBinding preferences = command("preferences")
        if (preferences.trigger.length == 0 && bindingError(preferences, preferences.defaultTrigger).length == 0) {
            preferences.setTrigger(preferences.defaultTrigger)
        }
    }

    String value(String section, String key) {
        return(Gtk.Config().value(original, section, key))
    }

    int64 integer(String key, int64 fallback, int64 minimum, int64 maximum) {
        String raw = value("editor", key)
        if (raw.equals("")) { return(fallback) }
        if (raw.startsWith("i")) {
            int64 number = byteSpan(raw, 1, raw.length).toInt64()
            if (number >= minimum && number <= maximum) { return(number) }
        }
        error(format("editor.{} must be an integer from {} to {}", key, minimum, maximum))
        return(fallback)
    }

    bool boolean(String key, bool fallback) {
        String raw = value("editor", key)
        if (raw.equals("")) { return(fallback) }
        if (raw.equals("btrue")) { return(true) }
        if (raw.equals("bfalse")) { return(false) }
        error(format("editor.{} must be a boolean", key))
        return(fallback)
    }

    String fontError(String font) {
        if (font.trim().equals("") || font.length > 128 || font.contains("\n") ||
            font.contains("\r") || font.contains("\t")) {
            return("Font family must be 1-128 characters, without control characters")
        }
        if (!Gtk.Font().isMonospace(font)) { return("Choose an installed monospace font family (or monospace)") }
        return("")
    }

    void load() {
        String presence = Gtk.Config().fileStatus(path)
        if (presence.equals("missing")) {
            loadLegacy()
            return
        }
        if (presence.length > 0) {
            error(format("Could not read settings: {}", presence))
            return
        }
        if (!System.FileSystem().isFile(path) || System.FileSystem().fileSize(path) > 65536) {
            error("Settings must be a regular TOML file no larger than 64 KiB")
            return
        }
        System.File file = null
        try {
            file = System.File(path, "r")
        } except(Exception) {
            error(format("Could not read settings: {}", System.System().lastError()))
            return
        }
        try { original = file.readAll() }
        except(Exception) as failure { error(failure.message) }
        String readError = System.System().lastError()
        file.close()
        if (!readError.equals("")) { error(readError) }
        if (!GtkSource.Content().isText(original)) {
            error("Malformed settings TOML: embedded NUL bytes")
            return
        }
        String malformed = Gtk.Config().validate(original)
        if (!malformed.equals("")) {
            error(format("Malformed settings TOML: {}", malformed))
            return
        }
        String version = value("", "version")
        if (!version.equals("") && !version.equals("i1")) {
            error("Unsupported settings version: expected version = 1")
            return
        }
        if (!value("", "editor").equals("") && !value("", "editor").equals("t")) {
            error("editor must be a table")
        }
        if (!value("", "keyboard").equals("") && !value("", "keyboard").equals("t")) {
            error("keyboard must be a table")
        }
        if (!value("", "project").equals("") && !value("", "project").equals("t")) {
            error("project must be a table")
        }
        if (value("", "keyboard").equals("")) { loadLegacy() }
        String reopen = value("project", "reopen_last")
        if (reopen.equals("btrue")) { reopenLast = true }
        else { if (!reopen.equals("") && !reopen.equals("bfalse")) { error("project.reopen_last must be a boolean") } }
        String last = value("project", "last_root")
        if (!last.equals("") && !last.equals("s")) {
            if (!last.startsWith("s/") || last.contains("\n") || last.length > 4097) {
                error("project.last_root must be an absolute folder path")
            } else { lastRoot = byteSpan(last, 1, last.length) }
        }
        String font = value("editor", "font_family")
        if (!font.equals("")) {
            if (!font.startsWith("s")) { error("editor.font_family must be a string") }
            else {
                String name = byteSpan(font, 1, font.length)
                String problem = fontError(name)
                if (problem.equals("")) { fontFamily = name } else { error(problem) }
            }
        }
        fontSize = integer("font_size", fontSize, 6, 72)
        tabWidth = integer("tab_width", tabWidth, 1, 16)
        insertSpaces = boolean("insert_spaces", insertSpaces)
        lineNumbers = boolean("line_numbers", lineNumbers)
        showWhitespace = boolean("show_whitespace", showWhitespace)
        showLineEnds = boolean("show_line_ends", showLineEnds)
        showIndentMarkers = boolean("show_indent_markers", showIndentMarkers)
        showProjectManager = boolean("show_project_manager", showProjectManager)
        String languageServer = value("editor", "lsp_command")
        if (!languageServer.equals("")) {
            if (!languageServer.startsWith("s")) { error("editor.lsp_command must be a string") }
            else { lspCommand = byteSpan(languageServer, 1, languageServer.length) }
        }
        wrap = boolean("wrap", wrap)
        highlightLine = boolean("highlight_current_line", highlightLine)
        saveOnTabLoss = boolean("save_on_tab_loss", saveOnTabLoss)
        saveOnWindowLoss = boolean("save_on_window_loss", saveOnWindowLoss)
        stripTrailingSpaces = boolean("strip_trailing_spaces", stripTrailingSpaces)
        autoCompleteBrackets = boolean("auto_complete_brackets", autoCompleteBrackets)
        // Stage the complete map before checking conflicts, allowing swaps.
        int64 i = 0
        while (i < commands.length) {
            CommandBinding binding = commands[i] as CommandBinding
            String raw = value("keyboard", binding.id)
            if (!raw.equals("")) {
                if (!raw.startsWith("s")) { error(format("keyboard.{} must be a string", binding.id)) }
                else { binding.setTrigger(byteSpan(raw, 1, raw.length)) }
            }
            i = i + 1
        }
        i = 0
        while (i < commands.length) {
            CommandBinding binding = commands[i] as CommandBinding
            String problem = bindingError(binding, binding.trigger)
            if (!problem.equals("")) {
                binding.valid = false
                error(problem)
            }
            i = i + 1
        }
        String key = Gtk.Config().key(original, "keyboard", 0)
        i = 0
        while (!key.equals("")) {
            if (command(key) == null) { error(format("Unknown keyboard command: {}", key)) }
            i = i + 1
            key = Gtk.Config().key(original, "keyboard", i)
        }
    }

    void resetKeyboard() {
        int64 i = 0
        while (i < commands.length) {
            CommandBinding binding = commands[i] as CommandBinding
            binding.setTrigger(binding.defaultTrigger)
            i = i + 1
        }
    }

    String serialize() {
        String text = format("version = 1\n[editor]\nfont_family = {}\nfont_size = {}\ntab_width = {}\ninsert_spaces = {}\nline_numbers = {}\nshow_whitespace = {}\nshow_line_ends = {}\nshow_indent_markers = {}\nshow_project_manager = {}\nlsp_command = {}\nwrap = {}\nhighlight_current_line = {}\nsave_on_tab_loss = {}\nsave_on_window_loss = {}\nstrip_trailing_spaces = {}\nauto_complete_brackets = {}\n[keyboard]\n",
            Gtk.Config().quote(fontFamily), fontSize, tabWidth, insertSpaces, lineNumbers,
            showWhitespace, showLineEnds, showIndentMarkers, showProjectManager,
            Gtk.Config().quote(lspCommand), wrap, highlightLine, saveOnTabLoss, saveOnWindowLoss,
            stripTrailingSpaces, autoCompleteBrackets)
        int64 i = 0
        while (i < commands.length) {
            CommandBinding binding = commands[i] as CommandBinding
            text.append(format("{} = {}\n", binding.id, Gtk.Config().quote(binding.trigger)))
            i = i + 1
        }
        text.append(format("[project]\nreopen_last = {}\nlast_root = {}\n", reopenLast, Gtk.Config().quote(lastRoot)))
        return(Gtk.Config().merge(original, text))
    }

    int64 byteSpanBound(int64 value, int64 length) {
        int64 index = value
        if (index < 0) { index = index + length }
        if (index < 0) { return(0) }
        if (index > length) { return(length) }
        return(index)
    }
    String byteSpan(String text, int64 first, int64 last) {
        int64 lower = byteSpanBound(first, text.length)
        int64 end = byteSpanBound(last, text.length)
        if (end <= lower) { return("") }
        return(text[lower..(end - 1)])
    }
}
