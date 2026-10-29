class CwhipProject {
    String root
    String directory
    String configPath
    String workspacePath
    String name
    list excludes
    String original
    String base
    String workspaceOriginal
    String workspaceText
    String savingConfig
    String savingWorkspace
    String errors
    String workspaceErrors
    bool writable
    bool workspaceWritable
    bool hasFont
    String fontFamily
    bool hasSize
    int64 fontSize
    bool hasTabs
    int64 tabWidth
    bool hasSpaces
    bool insertSpaces
    bool hasNumbers
    bool lineNumbers
    bool hasWrap
    bool wrap
    bool hasHighlight
    bool highlightLine
    String active
    int64 explorerWidth
    int64 windowWidth
    int64 windowHeight
    list expanded
    list files
    String readError
    bool readMissing
    bool readContent
    String acceptedPath

    CwhipProject(String projectRoot) {
        root = projectRoot
        directory = System.FileSystem().join(root, ".cwhip")
        configPath = System.FileSystem().join(directory, "project.toml")
        workspacePath = System.FileSystem().join(directory, "workspace.toml")
        name = System.FileSystem().basename(root)
        if (name.equals("") || name.length > 128) { name = "Project" }
        excludes = []
        original = ""
        base = ""
        workspaceOriginal = ""
        workspaceText = ""
        savingConfig = ""
        savingWorkspace = ""
        errors = ""
        workspaceErrors = ""
        writable = true
        workspaceWritable = true
        fontFamily = "monospace"
        fontSize = 12
        tabWidth = 4
        insertSpaces = true
        lineNumbers = true
        wrap = false
        highlightLine = false
        resetWorkspace()
        readError = ""
        acceptedPath = ""
    }

    void resetWorkspace() {
        active = ""
        explorerWidth = -1
        windowWidth = -1
        windowHeight = -1
        expanded = []
        files = []
    }

    void error(String message) {
        if (!errors.equals("")) { errors.append("\n") }
        errors.append(message)
        writable = false
    }

    void workspaceError(String message) {
        if (!workspaceErrors.equals("")) { workspaceErrors.append("\n") }
        workspaceErrors.append(message)
        workspaceWritable = false
        resetWorkspace()
    }

    String prefix() {
        if (root.endsWith("/")) { return(root) }
        return(format("{}/", root))
    }

    // Root-relative path, or "" when path is outside the root.
    String relative(String path) {
        String head = prefix()
        if (!path.startsWith(head) || path.length == head.length) { return("") }
        String rest = byteSpan(path, head.length, path.length)
        if (!validRelative(rest)) { return("") }
        return(rest)
    }

    bool hasControl(String text) {
        return(text.contains("\n") || text.contains("\r") || text.contains("\t"))
    }

    bool validRelative(String path) {
        if (path.equals("") || path.length > 4096 || path.startsWith("/") || hasControl(path)) { return(false) }
        list parts = path.split("/")
        int64 i = 0
        while (i < parts.length) {
            String part = parts[i] as String
            if (part.equals("") || part.equals(".") || part.equals("..")) { return(false) }
            i = i + 1
        }
        return(true)
    }

    // Absolute file path that is not inside this project. `.` and `..` segments are rejected.
    bool validExternal(String path) {
        if (!path.startsWith("/") || path.equals("/") || path.length > 4096 || hasControl(path)) { return(false) }
        if (path.equals(root) || !relative(path).equals("")) { return(false) }
        String body = byteSpan(path, 1, path.length)
        if (body.endsWith("/")) { return(false) }
        return(validRelative(body))
    }

    // Accepts a root-relative path, or an absolute path outside the root.
    // An absolute path inside the root is stored in root-relative form.
    bool acceptWorkspacePath(String stored) {
        acceptedPath = ""
        if (stored.startsWith("/")) {
            String rel = relative(stored)
            if (!rel.equals("")) {
                acceptedPath = rel
                return(true)
            }
            if (!validExternal(stored)) { return(false) }
            acceptedPath = stored
            return(true)
        }
        if (!validRelative(stored)) { return(false) }
        acceptedPath = stored
        return(true)
    }

    String nameError(String text) {
        if (text.trim().equals("") || text.length > 128 || hasControl(text)) {
            return("Project name must be 1-128 characters, without control characters")
        }
        return("")
    }

    String excludeError(String pattern) {
        if (pattern.trim().equals("") || pattern.length > 256 || hasControl(pattern)) {
            return("Exclusion patterns must be 1-256 characters, without control characters")
        }
        if (pattern.startsWith("/") || pattern.endsWith("/") || !validRelative(pattern)) {
            return(format("Invalid exclusion pattern {}: use a name or root-relative path without leading/trailing /, ., or .. segments", pattern))
        }
        return("")
    }

    // Refuses symlinked or non-regular metadata so writes and deletes stay
    // inside the project's metadata directory.
    String metadataProblem() {
        if (!System.FileSystem().exists(directory)) { return("") }
        if (!System.FileSystem().isDir(directory) ||
            !System.FileSystem().absolutePath(directory).equals(directory)) {
            return(format("{} must be a real directory, not a file or symbolic link", directory))
        }
        String problem = fileProblem(configPath)
        if (problem.equals("")) { problem = fileProblem(workspacePath) }
        return(problem)
    }

    String fileProblem(String path) {
        if (!System.FileSystem().exists(path)) { return("") }
        if (!System.FileSystem().isFile(path) ||
            !System.FileSystem().absolutePath(path).equals(path)) {
            return(format("{} must be a regular file, not a symbolic link", path))
        }
        return("")
    }

    // readMissing: no file; readContent: bytes were read (readError may still
    // report malformed contents).
    String readMetadata(String path, int64 limit) {
        readError = ""
        readMissing = false
        readContent = false
        String presence = Gtk.Config().fileStatus(path)
        if (presence.equals("missing")) {
            readMissing = true
            return("")
        }
        if (presence.length > 0) {
            readError = format("Could not read {}: {}", path, presence)
            return("")
        }
        if (!System.FileSystem().isFile(path) || System.FileSystem().fileSize(path) > limit) {
            readError = format("{} must be a regular file no larger than {} KiB", path, limit / 1024)
            return("")
        }
        System.File file = null
        try {
            file = System.File(path, "r")
        } except(Exception) {
            readError = format("Could not read {}: {}", path, System.System().lastError())
            return("")
        }
        String text = ""
        try { text = file.readAll() }
        except(Exception) as failure { readError = format("Could not read {}: {}", path, failure.message) }
        String lastError = System.System().lastError()
        file.close()
        if (readError.equals("") && !lastError.equals("")) {
            readError = format("Could not read {}: {}", path, lastError)
        }
        if (!readError.equals("")) { return("") }
        readContent = true
        if (!GtkSource.Content().isText(text)) {
            readError = format("Malformed {}: not UTF-8 text", path)
            return(text)
        }
        String malformed = Gtk.Config().validate(text)
        if (!malformed.equals("")) { readError = format("Malformed TOML in {}: {}", path, malformed) }
        return(text)
    }

    String value(String section, String key) { return(Gtk.Config().value(base, section, key)) }

    void table(String text, String key) {
        String kind = Gtk.Config().value(text, "", key)
        if (!kind.equals("") && !kind.equals("t")) { error(format("{} must be a table", key)) }
    }

    int64 integer(String key, int64 minimum, int64 maximum) {
        String raw = value("editor", key)
        if (raw.equals("")) { return(-1) }
        if (raw.startsWith("i")) {
            int64 number = byteSpan(raw, 1, raw.length).toInt64()
            if (number >= minimum && number <= maximum) { return(number) }
        }
        error(format("editor.{} must be an integer from {} to {}", key, minimum, maximum))
        return(-1)
    }

    // -1 inherit (absent or invalid), 0 false, 1 true.
    int64 boolean(String key) {
        String raw = value("editor", key)
        if (raw.equals("")) { return(-1) }
        if (raw.equals("btrue")) { return(1) }
        if (raw.equals("bfalse")) { return(0) }
        error(format("editor.{} must be a boolean", key))
        return(-1)
    }

    // Returns "" when the project can be opened. Invalid individual values
    // keep it open with errors shown and its configuration unwritable.
    String load(CeditSettings settings) {
        String problem = metadataProblem()
        if (!problem.equals("")) { return(problem) }
        original = readMetadata(configPath, 65536)
        if (readMissing) { return(format("No Cwhip project in {} (missing {}/project.toml); use Project > New Project... to create one", root, directory)) }
        if (!readError.equals("")) { return(readError) }
        base = original
        if (!value("", "version").equals("i1")) {
            return(format("Unsupported project version in {}: expected version = 1", configPath))
        }
        table(base, "project")
        table(base, "explorer")
        table(base, "editor")
        String raw = value("project", "name")
        if (!raw.equals("")) {
            if (!raw.startsWith("s")) { error("project.name must be a string") }
            else {
                String text = byteSpan(raw, 1, raw.length)
                String nameProblem = nameError(text)
                if (nameProblem.equals("")) { name = text } else { error(nameProblem) }
            }
        }
        raw = value("explorer", "exclude")
        if (!raw.equals("")) {
            if (!raw.equals("x")) { error("explorer.exclude must be an array of strings") }
            else {
                int64 i = 0
                String item = Gtk.Config().item(base, "explorer", "exclude", 0, "")
                while (!item.equals("")) {
                    if (!item.startsWith("s")) { error("explorer.exclude must be an array of strings") }
                    else {
                        String pattern = byteSpan(item, 1, item.length)
                        String patternProblem = excludeError(pattern)
                        if (patternProblem.equals("")) { excludes.append(pattern) } else { error(patternProblem) }
                    }
                    i = i + 1
                    item = Gtk.Config().item(base, "explorer", "exclude", i, "")
                }
            }
        }
        raw = value("editor", "font_family")
        if (!raw.equals("")) {
            if (!raw.startsWith("s")) { error("editor.font_family must be a string") }
            else {
                String font = byteSpan(raw, 1, raw.length)
                String fontProblem = settings.fontError(font)
                if (fontProblem.equals("")) {
                    hasFont = true
                    fontFamily = font
                } else { error(format("editor.font_family: {}", fontProblem)) }
            }
        }
        int64 number = integer("font_size", 6, 72)
        hasSize = number > 0
        if (hasSize) { fontSize = number }
        number = integer("tab_width", 1, 16)
        hasTabs = number > 0
        if (hasTabs) { tabWidth = number }
        number = boolean("insert_spaces")
        hasSpaces = number >= 0
        insertSpaces = number == 1
        number = boolean("line_numbers")
        hasNumbers = number >= 0
        lineNumbers = number == 1
        number = boolean("wrap")
        hasWrap = number >= 0
        wrap = number == 1
        number = boolean("highlight_current_line")
        hasHighlight = number >= 0
        highlightLine = number == 1
        loadWorkspace()
        return("")
    }

    void loadWorkspace() {
        workspaceOriginal = readMetadata(workspacePath, 1048576)
        if (readMissing) {
            workspaceOriginal = ""
            return
        }
        if (!readError.equals("")) {
            workspaceError(readError)
            return
        }
        String problem = parseWorkspace(workspaceOriginal)
        if (!problem.equals("")) { workspaceError(problem) }
    }

    String wsInteger(String text, String key, int64 minimum, int64 maximum) {
        String raw = Gtk.Config().value(text, "workspace", key)
        if (raw.equals("")) { return("") }
        if (raw.startsWith("i")) {
            int64 number = byteSpan(raw, 1, raw.length).toInt64()
            if (number >= minimum && number <= maximum) { return(format("{}", number)) }
        }
        return(format("workspace.{} must be an integer from {} to {}", key, minimum, maximum))
    }

    int64 wsNumber(String text, String key) {
        String raw = Gtk.Config().value(text, "workspace", key)
        if (raw.equals("")) { return(-1) }
        return(byteSpan(raw, 1, raw.length).toInt64())
    }

    // Parses workspace TOML; returns "" or the first problem. Any problem
    // discards the whole workspace rather than restoring part of it.
    String parseWorkspace(String text) {
        resetWorkspace()
        if (!Gtk.Config().value(text, "", "version").equals("i1")) {
            return(format("Unsupported workspace version in {}: expected version = 1", workspacePath))
        }
        String kind = Gtk.Config().value(text, "", "workspace")
        if (kind.equals("")) { return("") }
        if (!kind.equals("t")) { return("workspace must be a table") }
        String raw = Gtk.Config().value(text, "workspace", "active")
        if (!raw.equals("")) {
            if (!raw.startsWith("s") || !acceptWorkspacePath(byteSpan(raw, 1, raw.length))) {
                return("workspace.active must be a path inside the project or an absolute path outside it")
            }
            active = acceptedPath
        }
        // wsInteger yields digits when valid; messages always contain spaces.
        String problem = wsInteger(text, "explorer_width", 0, 5000)
        if (problem.contains(" ")) { return(problem) }
        problem = wsInteger(text, "window_width", 200, 10000)
        if (problem.contains(" ")) { return(problem) }
        problem = wsInteger(text, "window_height", 150, 10000)
        if (problem.contains(" ")) { return(problem) }
        explorerWidth = wsNumber(text, "explorer_width")
        windowWidth = wsNumber(text, "window_width")
        windowHeight = wsNumber(text, "window_height")
        raw = Gtk.Config().value(text, "workspace", "expanded")
        if (!raw.equals("") && !raw.equals("x")) { return("workspace.expanded must be an array of paths") }
        int64 i = 0
        String item = Gtk.Config().item(text, "workspace", "expanded", 0, "")
        while (!item.equals("")) {
            if (!item.startsWith("s") || !validRelative(byteSpan(item, 1, item.length))) {
                resetWorkspace()
                return("workspace.expanded must contain root-relative paths")
            }
            expanded.append(byteSpan(item, 1, item.length))
            i = i + 1
            item = Gtk.Config().item(text, "workspace", "expanded", i, "")
        }
        raw = Gtk.Config().value(text, "workspace", "files")
        if (!raw.equals("") && !raw.equals("x")) { return("workspace.files must be an array of tables") }
        i = 0
        item = Gtk.Config().item(text, "workspace", "files", 0, "")
        while (!item.equals("")) {
            String path = Gtk.Config().item(text, "workspace", "files", i, "path")
            String line = Gtk.Config().item(text, "workspace", "files", i, "line")
            String column = Gtk.Config().item(text, "workspace", "files", i, "column")
            if (!item.equals("t") || !path.startsWith("s") ||
                !acceptWorkspacePath(byteSpan(path, 1, path.length)) ||
                !validPosition(line) || !validPosition(column)) {
                resetWorkspace()
                return("workspace.files entries must be tables with a path inside the project or an absolute path outside it, and a positive line/column")
            }
            files.append(WorkspaceFile(acceptedPath, byteSpan(line, 1, line.length).toInt64(),
                byteSpan(column, 1, column.length).toInt64()))
            i = i + 1
            item = Gtk.Config().item(text, "workspace", "files", i, "")
        }
        return("")
    }

    bool validPosition(String raw) {
        if (!raw.startsWith("i")) { return(false) }
        int64 number = byteSpan(raw, 1, raw.length).toInt64()
        return(number >= 1 && number <= 100000000)
    }

    String quotedList(list values) {
        String text = "["
        int64 i = 0
        while (i < values.length) {
            if (i > 0) { text.append(", ") }
            text.append(Gtk.Config().quote(values[i] as String))
            i = i + 1
        }
        text.append("]")
        return(text)
    }

    String excludeLines() {
        String text = ""
        int64 i = 0
        while (i < excludes.length) {
            if (i > 0) { text.append("\n") }
            text.append(excludes[i] as String)
            i = i + 1
        }
        return(text)
    }

    // Keeps unknown keys from the merge base; removed overrides fall back to
    // inheritance by deleting their keys.
    String serialize() {
        String text = base
        if (text.equals("")) { text = "version = 1\n" }
        if (!hasFont) { text = Gtk.Config().remove(text, "editor", "font_family") }
        if (!hasSize) { text = Gtk.Config().remove(text, "editor", "font_size") }
        if (!hasTabs) { text = Gtk.Config().remove(text, "editor", "tab_width") }
        if (!hasSpaces) { text = Gtk.Config().remove(text, "editor", "insert_spaces") }
        if (!hasNumbers) { text = Gtk.Config().remove(text, "editor", "line_numbers") }
        if (!hasWrap) { text = Gtk.Config().remove(text, "editor", "wrap") }
        if (!hasHighlight) { text = Gtk.Config().remove(text, "editor", "highlight_current_line") }
        String updates = format("version = 1\n[project]\nname = {}\n[explorer]\nexclude = {}\n",
            Gtk.Config().quote(name), quotedList(excludes))
        String editor = ""
        if (hasFont) { editor.append(format("font_family = {}\n", Gtk.Config().quote(fontFamily))) }
        if (hasSize) { editor.append(format("font_size = {}\n", fontSize)) }
        if (hasTabs) { editor.append(format("tab_width = {}\n", tabWidth)) }
        if (hasSpaces) { editor.append(format("insert_spaces = {}\n", insertSpaces)) }
        if (hasNumbers) { editor.append(format("line_numbers = {}\n", lineNumbers)) }
        if (hasWrap) { editor.append(format("wrap = {}\n", wrap)) }
        if (hasHighlight) { editor.append(format("highlight_current_line = {}\n", highlightLine)) }
        if (!editor.equals("")) {
            updates.append("[editor]\n")
            updates.append(editor)
        }
        return(Gtk.Config().merge(text, updates))
    }

    // Copies configuration (including unknown keys) for Save As.
    void copyConfiguration(CwhipProject source) {
        base = source.base
        name = source.name
        excludes = []
        int64 i = 0
        while (i < source.excludes.length) {
            excludes.append(source.excludes[i] as String)
            i = i + 1
        }
        hasFont = source.hasFont
        fontFamily = source.fontFamily
        hasSize = source.hasSize
        fontSize = source.fontSize
        hasTabs = source.hasTabs
        tabWidth = source.tabWidth
        hasSpaces = source.hasSpaces
        insertSpaces = source.insertSpaces
        hasNumbers = source.hasNumbers
        lineNumbers = source.lineNumbers
        hasWrap = source.hasWrap
        wrap = source.wrap
        hasHighlight = source.hasHighlight
        highlightLine = source.highlightLine
    }

    String overrideSummary() {
        list names = []
        if (hasFont) { names.append("font family") }
        if (hasSize) { names.append("font size") }
        if (hasTabs) { names.append("tab width") }
        if (hasSpaces) { names.append("insert spaces") }
        if (hasNumbers) { names.append("line numbers") }
        if (hasWrap) { names.append("wrap") }
        if (hasHighlight) { names.append("highlight current line") }
        String text = ""
        int64 i = 0
        while (i < names.length) {
            if (i > 0) { text.append(", ") }
            text.append(names[i] as String)
            i = i + 1
        }
        return(text)
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
