void Cedit.closeAllDocuments() {
        changingDocuments = true
        int64 index = 0
        while (index < documents.length) {
            EditorDocument document = documents[index] as EditorDocument
            notebook.remove(document.scroller)
            document.scroller.dispose()
            index = index + 1
        }
        documents = []
        focusedDocument = null
        hasAutomaticSaveErrors = false
        changingDocuments = false
    }

void Cedit.detachProject() {
        activeProject = null
        reapplyDocumentSettings()
        refreshProjectNote()
        if (configureWindow != null && !configureWindow.disposed()) { configureWindow.setVisible(false) }
        updateMenu()
    }

void Cedit.reapplyDocumentSettings() {
        int64 index = 0
        while (index < documents.length) {
            applyDocumentSettings(documents[index] as EditorDocument)
            index = index + 1
        }
    }

list Cedit.absolutePaths(CwhipProject target, list paths) {
        list result = []
        int64 index = 0
        while (index < paths.length) {
            result.append(System.FileSystem().join(target.root, paths[index] as String))
            index = index + 1
        }
        return(result)
    }

void Cedit.activateProject(CwhipProject target, bool restore) {
        activeProject = target
        adoptSettingsRoot(target.root)
        project.setProject(target.root, target.name, target.excludeLines(), absolutePaths(target, target.expanded))
        if (files != null) { files.setProject(target.root, "Files", "", []) }
        reapplyDocumentSettings()
        refreshProjectNote()
        if (restore) {
            // Window size is restored only before the window is first shown.
            if (!presented && target.windowWidth > 0 && target.windowHeight > 0) {
                window.setDefaultSize(target.windowWidth, target.windowHeight)
            }
            if (target.explorerWidth >= 0) { workspace.setPosition(target.explorerWidth) }
            openFailures = []
            collectingFailures = true
            EditorDocument chosen = null
            int64 index = 0
            while (index < target.files.length) {
                WorkspaceFile item = target.files[index] as WorkspaceFile
                String path = item.path
                if (!path.startsWith("/")) { path = System.FileSystem().join(target.root, item.path) }
                if (!System.FileSystem().exists(path)) {
                    openFailures.append(format("Missing: {}", path))
                } else {
                    EditorDocument document = openDocument(path)
                    if (document != null) {
                        document.view.setCursor(item.line, item.column)
                        if (chosen == null || item.path.equals(target.active)) { chosen = document }
                    }
                }
                index = index + 1
            }
            collectingFailures = false
            if (documents.length == 0) { newDocument() } else { activateDocument(chosen) }
            if (openFailures.length > 0) {
                String details = ""
                index = 0
                while (index < openFailures.length) {
                    if (index > 0) { details.append("\n") }
                    details.append(openFailures[index] as String)
                    index = index + 1
                }
                Gtk.AlertDialog().show(window, "Some workspace files could not be reopened", details)
                openFailures = []
            }
        }
        noteOpenFiles()
        rememberProject(target.root)
        updateMenu()
        status.setText(format("Project: {} ({})", target.name, target.root))
        offerRecoveryForDocuments()
        if (!target.errors.equals("")) {
            Gtk.AlertDialog().show(window, "Project configuration errors", format("{}\n{}\nInvalid values are ignored; saving project configuration is disabled until the file is repaired and the project reopened.", target.configPath, target.errors))
        }
        if (!target.workspaceErrors.equals("")) {
            Gtk.AlertDialog().show(window, "Workspace state ignored", format("{}\nThe workspace was not restored and will not be overwritten; repair or remove {} and reopen the project.", target.workspaceErrors, target.workspacePath))
        }
    }

String Cedit.captureWorkspace(String source, String target) {
        CwhipProject origin = CwhipProject(source)
        bool filter = !source.equals(target)
        String text = "version = 1\n\n[workspace]\n"
        EditorDocument current = currentDocument()
        String activePath = ""
        String fileList = "["
        list recorded = []
        int64 count = 0
        int64 index = 0
        while (index < documents.length) {
            EditorDocument document = documents[index] as EditorDocument
            String rel = storedDocumentPath(origin, document.path, target, filter)
            if (!rel.equals("")) {
                if (count > 0) { fileList.append(", ") }
                fileList.append("{ path = ")
                fileList.append(Gtk.Config().quote(rel))
                fileList.append(format(", line = {}, column = {} ", document.view.line(), document.view.column()))
                fileList.append("}")
                count = count + 1
                recorded.append(rel)
                if (document == current) { activePath = rel }
            }
            index = index + 1
        }
        if (project.rootPath.equals(source)) {
            index = 0
            while (index < project.externalFiles.length) {
                String external = project.externalFiles[index] as String
                String rel = storedDocumentPath(origin, external, target, filter)
                bool seen = false
                int64 seenIndex = 0
                while (seenIndex < recorded.length) {
                    if ((recorded[seenIndex] as String).equals(rel)) { seen = true }
                    seenIndex = seenIndex + 1
                }
                if (!rel.equals("") && !seen) {
                    if (count > 0) { fileList.append(", ") }
                    fileList.append("{ path = ")
                    fileList.append(Gtk.Config().quote(rel))
                    fileList.append(", line = 1, column = 1 }")
                    count = count + 1
                    recorded.append(rel)
                }
                index = index + 1
            }
        }
        fileList.append("]")
        if (!activePath.equals("")) { text.append(format("active = {}\n", Gtk.Config().quote(activePath))) }
        int64 width = workspace.position()
        if (!settings.showProjectManager && projectManagerWidth > 0) { width = projectManagerWidth }
        if (width >= 0 && width <= 5000) { text.append(format("explorer_width = {}\n", width)) }
        int64 windowWidth = window.defaultWidth()
        int64 windowHeight = window.defaultHeight()
        if (windowWidth >= 200 && windowWidth <= 10000 && windowHeight >= 150 && windowHeight <= 10000) {
            text.append(format("window_width = {}\nwindow_height = {}\n", windowWidth, windowHeight))
        }
        list folders = []
        if (project.rootPath.equals(source)) {
            list paths = project.expandedPaths()
            index = 0
            while (index < paths.length) {
                String rel = origin.relative(paths[index] as String)
                if (!rel.equals("") && filter && !System.FileSystem().isDir(System.FileSystem().join(target, rel))) { rel = "" }
                if (!rel.equals("")) { folders.append(rel) }
                index = index + 1
            }
        }
        text.append(format("expanded = {}\n", origin.quotedList(folders)))
        text.append("files = ")
        text.append(fileList)
        text.append("\n")
        return(text)
    }

String Cedit.storedDocumentPath(CwhipProject origin, String path, String target, bool filter) {
        if (path.equals("")) { return("") }
        String stored = origin.relative(path)
        if (stored.equals("") && origin.validExternal(path)) { stored = path }
        if (stored.equals("") || !filter) { return(stored) }
        String check = stored
        if (!stored.startsWith("/")) { check = System.FileSystem().join(target, stored) }
        if (!System.FileSystem().isFile(check)) { return("") }
        return(stored)
    }

void Cedit.noteOpenFiles() {
        int64 index = 0
        while (index < documents.length) {
            project.noteFile((documents[index] as EditorDocument).path)
            index = index + 1
        }
    }

void Cedit.createConfigure() {
        configureWindow = Gtk.TransientWindow("Configure Project")
        configureWindow.setTransientFor(window)
        configureWindow.setDefaultSize(640, 480)
        Gtk.Box root = Gtk.Box(Gtk.Box.VERTICAL, 6)
        configureName = preferenceEntry(root, "Project name", "")
        configureExcludes = preferenceEntry(root, "Explorer exclusions (comma-separated)", "")
        root.append(Gtk.Label("Editor overrides (unchecked settings inherit your Preferences)"))
        overrideRows = []
        addOverride(root, OverrideRow("font_family", "font family", false))
        addOverride(root, OverrideRow("font_size", "font size", false))
        addOverride(root, OverrideRow("tab_width", "tab width", false))
        addOverride(root, OverrideRow("insert_spaces", "insert spaces", true))
        addOverride(root, OverrideRow("line_numbers", "line numbers", true))
        addOverride(root, OverrideRow("wrap", "wrap", true))
        addOverride(root, OverrideRow("highlight_current_line", "highlight current line", true))
        Gtk.Box buttons = Gtk.Box(Gtk.Box.HORIZONTAL, 6)
        Gtk.Button inherit = Gtk.Button("Reset All to Inherit")
        Gtk.Button apply = Gtk.Button("Apply")
        Gtk.Button close = Gtk.Button("Close")
        inherit.onClicked(_self().inheritAll)
        apply.onClicked(_self().applyConfigure)
        close.onClicked(_self().closeConfigure)
        buttons.append(inherit)
        buttons.append(apply)
        buttons.append(close)
        root.append(buttons)
        configureMessage = Gtk.Label("")
        root.append(configureMessage)
        configureWindow.setChild(root)
        configureWindow.onCloseRequest(_self().hideConfigure)
        configureWindow.setVisible(false)
    }

void Cedit.addOverride(Gtk.Box root, OverrideRow row) {
        overrideRows.append(row)
        root.append(row.row)
    }

OverrideRow Cedit.overrideRow(String key) {
        int64 index = 0
        while (index < overrideRows.length) {
            OverrideRow row = overrideRows[index] as OverrideRow
            if (row.key.equals(key)) { return(row) }
            index = index + 1
        }
        return(null)
    }

void Cedit.showConfigure() {
        if (commandsBlocked() || activeProject == null) { return }
        if (configureWindow == null || configureWindow.disposed()) { createConfigure() }
        refreshConfigure()
        configureWindow.present()
    }

void Cedit.refreshConfigure() {
        CwhipProject current = activeProject
        configureName.setText(current.name)
        String patterns = ""
        int64 index = 0
        while (index < current.excludes.length) {
            if (index > 0) { patterns.append(", ") }
            patterns.append(current.excludes[index] as String)
            index = index + 1
        }
        configureExcludes.setText(patterns)
        String font = settings.fontFamily
        if (current.hasFont) { font = current.fontFamily }
        int64 size = settings.fontSize
        if (current.hasSize) { size = current.fontSize }
        int64 tabs = settings.tabWidth
        if (current.hasTabs) { tabs = current.tabWidth }
        overrideRow("font_family").show(current.hasFont, font, false)
        overrideRow("font_size").show(current.hasSize, format("{}", size), false)
        overrideRow("tab_width").show(current.hasTabs, format("{}", tabs), false)
        bool flag = settings.insertSpaces
        if (current.hasSpaces) { flag = current.insertSpaces }
        overrideRow("insert_spaces").show(current.hasSpaces, "", flag)
        flag = settings.lineNumbers
        if (current.hasNumbers) { flag = current.lineNumbers }
        overrideRow("line_numbers").show(current.hasNumbers, "", flag)
        flag = settings.wrap
        if (current.hasWrap) { flag = current.wrap }
        overrideRow("wrap").show(current.hasWrap, "", flag)
        flag = settings.highlightLine
        if (current.hasHighlight) { flag = current.highlightLine }
        overrideRow("highlight_current_line").show(current.hasHighlight, "", flag)
        if (!current.errors.equals("")) {
            configureMessage.setText(diagnostic("CEDIT2002",
                format("{}: {}", current.configPath, current.errors)))
        } else { configureMessage.setText("") }
    }

void Cedit.inheritAll() {
        int64 index = 0
        while (index < overrideRows.length) {
            OverrideRow row = overrideRows[index] as OverrideRow
            row.override.setActive(false)
            index = index + 1
        }
        configureMessage.setText("All editor settings inherit Preferences; press Apply to save")
    }

