void Cedit.applyDocumentSettings(EditorDocument document) {
        String font = settings.fontFamily
        int64 size = settings.fontSize
        int64 tabs = settings.tabWidth
        bool spaces = settings.insertSpaces
        bool numbers = settings.lineNumbers
        bool wrapLines = settings.wrap
        bool highlight = settings.highlightLine
        CwhipProject current = activeProject
        if (current != null) {
            if (current.hasFont) { font = current.fontFamily }
            if (current.hasSize) { size = current.fontSize }
            if (current.hasTabs) { tabs = current.tabWidth }
            if (current.hasSpaces) { spaces = current.insertSpaces }
            if (current.hasNumbers) { numbers = current.lineNumbers }
            if (current.hasWrap) { wrapLines = current.wrap }
            if (current.hasHighlight) { highlight = current.highlightLine }
        }
        document.view.configure(font, size, tabs, spaces, numbers, wrapLines, highlight)
        document.view.setShowWhitespace(settings.showWhitespace)
        document.view.setShowLineEnds(settings.showLineEnds)
        document.view.setShowIndentMarkers(settings.showIndentMarkers)
        document.view.setAutoCompleteBrackets(settings.autoCompleteBrackets)
        document.view.setSelectedLinesEdit(true)
        if (settings.rightMargin > 0) {
            document.view.setRightMargin(true, settings.rightMargin)
        } else {
            document.view.setRightMargin(false, 80)
        }
        if (document.shortcutRevision == settings.shortcutRevision) { return }
        document.shortcutRevision = settings.shortcutRevision
        document.view.clearShortcuts()
        document.shortcuts = []
        document.shortcutConflict = settings.legacyConflict
        int64 i = 0
        while (i < settings.commands.length) {
            CommandBinding binding = settings.commands[i] as CommandBinding
            if (binding.trigger.length > 0 && binding.valid) {
                if (document.view.bindShortcut(binding.trigger, binding.action)) {
                    document.shortcuts.append(binding.trigger)
                } else {
                    status.setText(format("Invalid shortcut trigger: {}", binding.trigger))
                }
            }
            i = i + 1
        }
    }

void Cedit.createPreferences() {
        preferencesWindow = Gtk.TransientWindow("cedit Preferences")
        preferencesWindow.setTransientFor(window)
        preferencesWindow.setDefaultSize(850, 600)
        Gtk.Box root = Gtk.Box(Gtk.Box.VERTICAL, 8)
        Gtk.Box content = Gtk.Box(Gtk.Box.HORIZONTAL, 12)
        Gtk.Box categories = Gtk.Box(Gtk.Box.VERTICAL, 6)
        Gtk.Button editorCategory = Gtk.Button("Editor")
        Gtk.Button keyboardCategory = Gtk.Button("Keyboard")
        configureProjectButton = Gtk.Button("Project")
        Gtk.Button startupCategory = Gtk.Button("Startup")
        categories.append(editorCategory)
        categories.append(keyboardCategory)
        categories.append(configureProjectButton)
        categories.append(startupCategory)
        editorCategory.onClicked(_self().showEditorPreferences)
        keyboardCategory.onClicked(_self().showKeyboardPreferences)
        configureProjectButton.onClicked(_self().showProjectPreferences)
        startupCategory.onClicked(_self().showStartupPreferences)
        content.append(categories)
        Gtk.Box pages = Gtk.Box(Gtk.Box.VERTICAL, 8)
        pages.setHExpand(true)
        pages.setVExpand(true)
        content.append(pages)
        editorPreferences = Gtk.Box(Gtk.Box.VERTICAL, 6)
        editorPreferences.append(Gtk.Label("Editor"))
        projectNote = Gtk.Label("")
        editorPreferences.append(projectNote)
        fontEntry = preferenceEntry(editorPreferences, "Monospace font family", settings.fontFamily)
        sizeEntry = preferenceEntry(editorPreferences, "Font size (6-72 pt)", format("{}", settings.fontSize))
        tabsEntry = preferenceEntry(editorPreferences, "Tab width (1-16 columns)", format("{}", settings.tabWidth))
        marginEntry = preferenceEntry(editorPreferences, "Right margin column (0 = off)",
            format("{}", settings.rightMargin))
        saveGlobalCheck = Gtk.CheckButton("Save to global settings")
        saveGlobalCheck.setActive(mirrorGlobal)
        saveGlobalCheck.onToggled(_self().saveGlobalChanged)
        editorPreferences.append(saveGlobalCheck)
        spacesCheck = preferenceCheck("Insert spaces instead of tabs", settings.insertSpaces)
        numbersCheck = preferenceCheck("Show line numbers", settings.lineNumbers)
        wrapCheck = preferenceCheck("Wrap long lines", settings.wrap)
        highlightCheck = preferenceCheck("Highlight current line", settings.highlightLine)
        saveTabCheck = preferenceCheck("Save on loss of tab focus", settings.saveOnTabLoss)
        saveWindowCheck = preferenceCheck("Save on loss of window focus", settings.saveOnWindowLoss)
        stripCheck = preferenceCheck("Strip trailing spaces on save", settings.stripTrailingSpaces)
        bracketsCheck = preferenceCheck("Auto-close brackets and quotes", settings.autoCompleteBrackets)
        lspEntry = preferenceEntry(editorPreferences, "Language server (empty, cwhip-lsp, clangd, or a command)", settings.lspCommand)
        fontEntry.onChanged(_self().editorSettingChanged)
        sizeEntry.onChanged(_self().editorSettingChanged)
        tabsEntry.onChanged(_self().editorSettingChanged)
        marginEntry.onChanged(_self().editorSettingChanged)
        Gtk.Button editorReset = Gtk.Button("Reset Editor to Defaults")
        editorReset.onClicked(_self().resetEditorPreferences)
        editorPreferences.append(editorReset)
        pages.append(editorPreferences)
        keyboardPreferences = Gtk.Box(Gtk.Box.VERTICAL, 6)
        commandSearch = Gtk.Entry("")
        keyboardPreferences.append(Gtk.Label("Search commands; empty binding disables a command"))
        keyboardPreferences.append(commandSearch)
        commandSearch.onChanged(_self().filterCommands)
        Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
        scroll.setVExpand(true)
        keyboardRowsBox = Gtk.Grid(6)
        scroll.setChild(keyboardRowsBox)
        keyboardRows = []
        keyboardPreferences.append(scroll)
        Gtk.Button keyboardReset = Gtk.Button("Reset Keyboard to Defaults")
        keyboardReset.onClicked(_self().resetKeyboardPreferences)
        keyboardPreferences.append(keyboardReset)
        pages.append(keyboardPreferences)
        keyboardPreferences.setVisible(false)
        startupPreferences = Gtk.Box(Gtk.Box.VERTICAL, 6)
        startupPreferences.append(Gtk.Label("Startup"))
        reopenCheck = Gtk.CheckButton("Reopen last project on startup")
        reopenCheck.setActive(settings.reopenLast)
        reopenCheck.onToggled(_self().reopenChanged)
        startupPreferences.append(reopenCheck)
        pages.append(startupPreferences)
        startupPreferences.setVisible(false)
        root.append(content)
        String settingsError = ""
        if (!settings.errors.equals("")) {
            settingsError = diagnostic("CEDIT2001",
                format("{}: {}", settings.path, settings.errors))
        }
        preferencesMessage = Gtk.Label(settingsError)
        root.append(preferencesMessage)
        settingsPathLabel = Gtk.Label(format("Automatically saved to {}", settings.path))
        root.append(settingsPathLabel)
        resetChoices = Gtk.Box(Gtk.Box.HORIZONTAL, 6)
        resetChoices.append(Gtk.Label("Reset this section?"))
        confirmResetButton = Gtk.Button("Confirm Reset")
        cancelResetButton = Gtk.Button("Cancel")
        confirmResetButton.onClicked(_self().confirmPreferencesReset)
        cancelResetButton.onClicked(_self().cancelPreferencesReset)
        resetChoices.append(confirmResetButton)
        resetChoices.append(cancelResetButton)
        root.append(resetChoices)
        resetChoices.setVisible(false)
        preferencesWindow.setChild(root)
        preferencesWindow.onCloseRequest(_self().hidePreferences)
        preferencesWindow.setVisible(false)
    }

Gtk.Entry Cedit.preferenceEntry(Gtk.Box page, String label, String text) {
        Gtk.Box row = Gtk.Box(Gtk.Box.HORIZONTAL, 6)
        row.append(Gtk.Label(label))
        Gtk.Entry entry = Gtk.Entry(text)
        entry.setHExpand(true)
        row.append(entry)
        page.append(row)
        return(entry)
    }

Gtk.CheckButton Cedit.preferenceCheck(String label, bool active) {
        Gtk.CheckButton check = Gtk.CheckButton(label)
        check.setActive(active)
        check.onToggled(_self().editorCheckChanged)
        editorPreferences.append(check)
        return(check)
    }

void Cedit.showPreferences() {
        if (commandsBlocked()) { return }
        if (preferencesWindow == null) { createPreferences() }
        refreshProjectNote()
        preferencesWindow.present()
    }

void Cedit.refreshProjectNote() {
        if (projectNote == null) { return }
        String overrides = ""
        if (activeProject != null) { overrides = activeProject.overrideSummary() }
        if (overrides.equals("")) { projectNote.setText("") }
        else { projectNote.setText(format("Project {} overrides: {}", activeProject.name, overrides)) }
        if (configureProjectButton != null) {
            configureProjectButton.setSensitive(activeProject != null && !commandsBlocked())
        }
        refreshSettingsPathLabel()
    }

void Cedit.refreshSettingsPathLabel() {
        if (settingsPathLabel == null) { return }
        settingsPathLabel.setText(format("Automatically saved to {}", settings.path))
    }

String Cedit.settingsRoot() {
        if (activeProject != null) { return(activeProject.root) }
        return(System.FileSystem().getCwd())
    }

String Cedit.startupPatch() {
        return(format("version = 1\n[project]\nreopen_last = {}\nlast_root = {}\n",
            settings.reopenLast, Gtk.Config().quote(settings.lastRoot)))
    }

String Cedit.globalSettingsBase(String disk) {
        if (disk.equals("")) { return("") }
        if (Gtk.Config().validate(disk).equals("")) { return(disk) }
        // Preserve sdk_prefix from a corrupt shared settings file when repairing.
        // Config.value cannot parse invalid TOML, so scan the raw text.
        list lines = disk.split("\n")
        int64 index = 0
        while (index < lines.length) {
            String trimmed = (lines[index] as String).trim()
            if (trimmed.startsWith("sdk_prefix") || trimmed.startsWith("\"sdk_prefix\"")) {
                list fields = trimmed.split("=")
                if (fields.length >= 2) {
                    String raw = (fields[1] as String).trim()
                    if (raw.startsWith("\"") && raw.endsWith("\"") && raw.length >= 2) {
                        return(format("version = 1\nsdk_prefix = {}\n", raw))
                    }
                }
            }
            index = index + 1
        }
        return("version = 1\n")
    }

void Cedit.recoverStartupFrom(String disk) {
        if (disk.equals("") || Gtk.Config().validate(disk).equals("")) { return }
        list lines = disk.split("\n")
        int64 index = 0
        while (index < lines.length) {
            String trimmed = (lines[index] as String).trim()
            if (trimmed.startsWith("reopen_last") || trimmed.startsWith("\"reopen_last\"")) {
                list fields = trimmed.split("=")
                if (fields.length >= 2) {
                    String raw = (fields[1] as String).trim()
                    if (raw.equals("true")) { settings.reopenLast = true }
                    if (raw.equals("false")) { settings.reopenLast = false }
                }
            }
            if (trimmed.startsWith("last_root") || trimmed.startsWith("\"last_root\"")) {
                list fields = trimmed.split("=")
                if (fields.length >= 2) {
                    String raw = (fields[1] as String).trim()
                    if (raw.startsWith("\"") && raw.endsWith("\"") && raw.length >= 3) {
                        String path = raw[1..(raw.length - 2)]
                        if (path.startsWith("/")) { settings.lastRoot = path }
                    }
                }
            }
            index = index + 1
        }
    }

void Cedit.ensureGlobalSettingsFile() {
        String disk = readSettingsDisk(settings.globalPath)
        if (System.FileSystem().isFile(settings.globalPath)) {
            // Config.validate fatals on embedded NUL; leave binary/corrupt files alone
            // unless startup keys are present to recover.
            if (!GtkSource.Content().isText(disk)) { return }
            if (Gtk.Config().validate(disk).equals("")) { return }
            // Only rewrite a malformed global file when startup keys are present in
            // the raw text. Other invalid files must keep failing load so Preferences
            // can show the error and refuse to clobber them.
            if (!disk.contains("reopen_last") && !disk.contains("last_root")) { return }
            bool reopen = settings.reopenLast
            String lastRoot = settings.lastRoot
            settings.reopenLast = false
            settings.lastRoot = ""
            recoverStartupFrom(disk)
            if (!settings.reopenLast && settings.lastRoot.equals("")) {
                settings.reopenLast = reopen
                settings.lastRoot = lastRoot
                return
            }
            String text = Gtk.Config().merge(globalSettingsBase(disk), startupPatch())
            if (!writeSettingsFile(settings.globalPath, text)) {
                settings.reopenLast = reopen
                settings.lastRoot = lastRoot
                return
            }
            if (settings.path.equals(settings.globalPath)) {
                settings.errors = ""
                settings.writable = true
                settings.resetEditor()
                settings.resetKeyboard()
                settings.load()
                persistedText = settings.original
            }
            return
        }
        if (!settings.path.equals(settings.globalPath)) { return }
        if (!settings.errors.equals("")) { return }
        String text = settings.serialize()
        if (!writeSettingsFile(settings.globalPath, text)) { return }
        settings.original = text
        persistedText = text
    }

bool Cedit.writeSettingsFile(String path, String text) {
        String directory = System.FileSystem().dirname(path)
        if (!makeSettingsDirectory(directory)) { return(false) }
        System.File output = null
        try { output = System.File(path, "w") }
        except(Exception) { return(false) }
        int64 written = output.write(text)
        String writeError = System.System().lastError()
        if (written != text.length) {
            output.close()
            return(false)
        }
        output.flush()
        String flushError = System.System().lastError()
        output.close()
        String closeError = System.System().lastError()
        if (!writeError.equals("") || !flushError.equals("") || !closeError.equals("")) { return(false) }
        return(true)
    }

bool Cedit.writeStartupToGlobal() {
        String disk = readSettingsDisk(settings.globalPath)
        String base = globalSettingsBase(disk)
        if (base.equals("")) {
            return(writeSettingsFile(settings.globalPath, startupPatch()))
        }
        return(writeSettingsFile(settings.globalPath,
            Gtk.Config().merge(base, startupPatch())))
    }

String Cedit.seedLocalSettings(String globalText) {
        // Editor/keyboard only: startup reopen keys stay in the global file.
        if (globalText.equals("") || !GtkSource.Content().isText(globalText) ||
            !Gtk.Config().validate(globalText).equals("")) {
            return("")
        }
        // Config.remove rewrites/normalizes the document; skip when nothing to strip
        // so SDK-only and minimal templates stay byte-identical.
        if (!globalText.contains("reopen_last") && !globalText.contains("last_root")) {
            return(globalText)
        }
        String seed = Gtk.Config().remove(globalText, "project", "reopen_last")
        seed = Gtk.Config().remove(seed, "project", "last_root")
        return(seed)
    }

bool Cedit.writeMirroredGlobal(String editorText) {
        // Keep reopen_last/last_root when mirroring editor/keyboard into the global file.
        String disk = readSettingsDisk(settings.globalPath)
        String base = globalSettingsBase(disk)
        String merged = editorText
        if (!base.equals("")) { merged = Gtk.Config().merge(base, editorText) }
        return(writeSettingsFile(settings.globalPath,
            Gtk.Config().merge(merged, startupPatch())))
    }

void Cedit.adoptSettingsRoot(String root) {
        if (root.equals("")) { return }
        String local = settings.localPath(root)
        bool reopen = settings.reopenLast
        String lastRoot = settings.lastRoot
        if (!System.FileSystem().isFile(local)) {
            ensureGlobalSettingsFile()
            String seed = seedLocalSettings(readSettingsDisk(settings.globalPath))
            // Only invent a template when the global file is truly missing, not unreadable.
            if (seed.equals("") && settings.path.equals(settings.globalPath) &&
                settings.errors.equals("") && !System.FileSystem().isFile(settings.globalPath)) {
                String previous = settings.path
                settings.path = settings.globalPath
                seed = seedLocalSettings(settings.serialize())
                settings.path = previous
            }
            if (!seed.equals("")) { writeSettingsFile(local, seed) }
        }
        if (!System.FileSystem().isFile(local)) { return }
        if (settings.path.equals(local)) { return }
        settings.path = local
        settings.errors = ""
        settings.writable = true
        settings.resetEditor()
        settings.resetKeyboard()
        settings.load()
        settings.reopenLast = reopen
        settings.lastRoot = lastRoot
        persistedText = settings.original
        reapplyDocumentSettings()
        syncViewMenu()
        refreshSettingsPathLabel()
    }

void Cedit.reopenChanged(bool active) {
        if (refreshingPreferences) { return }
        settings.reopenLast = active
        settings.lastRoot = ""
        if (active && activeProject != null) { settings.lastRoot = activeProject.root }
        // Startup keys are global-only; local serialize ignores them, so skip
        // settingsChanged and write the global file directly.
        if (!writeStartupToGlobal()) {
            settingsSaveFailure(format("could not update {}", settings.globalPath))
            return
        }
        if (preferencesMessage != null) { preferencesMessage.setText("Settings saved") }
    }

void Cedit.persistSettings() {
        if (preferencesWindow == null) { createPreferences() }
        settingsChanged()
    }

void Cedit.rememberProject(String root) {
        if (settings.reopenLast && !settings.lastRoot.equals(root)) {
            settings.lastRoot = root
            writeStartupToGlobal()
        }
    }

void Cedit.forgetProject(String root) {
        if (settings.lastRoot.equals(root)) {
            settings.lastRoot = ""
            writeStartupToGlobal()
        }
    }

bool Cedit.hidePreferences() {
        if (preferencesWindow == null || preferencesWindow.disposed()) { return(true) }
        stopRecording()
        cancelPreferencesReset()
        preferencesWindow.setVisible(false)
        return(true)
    }

void Cedit.stopRecording() {
        int64 i = 0
        while (i < keyboardRows.length) {
            (keyboardRows[i] as KeyboardPreference).cancelRecording()
            i = i + 1
        }
    }

void Cedit.showEditorPreferences() {
        hidePreferences()
        editorPreferences.setVisible(true)
        keyboardPreferences.setVisible(false)
        startupPreferences.setVisible(false)
        preferencesWindow.present()
    }

void Cedit.showKeyboardPreferences() {
        hidePreferences()
        if (keyboardRows.length == 0) {
            int64 i = 0
            while (i < settings.commands.length) {
                KeyboardPreference row = KeyboardPreference(settings, settings.commands[i] as CommandBinding,
                    _self().keyboardSettingsChanged, _self().stopRecording, keyboardRowsBox, i)
                keyboardRows.append(row)
                i = i + 1
            }
        }
        editorPreferences.setVisible(false)
        keyboardPreferences.setVisible(true)
        startupPreferences.setVisible(false)
        preferencesWindow.present()
    }

void Cedit.showProjectPreferences() {
        if (activeProject == null || commandsBlocked()) { return }
        showConfigure()
    }

void Cedit.showStartupPreferences() {
        hidePreferences()
        editorPreferences.setVisible(false)
        keyboardPreferences.setVisible(false)
        startupPreferences.setVisible(true)
        preferencesWindow.present()
    }

void Cedit.filterCommands(String query) {
        int64 i = 0
        while (i < keyboardRows.length) {
            KeyboardPreference row = keyboardRows[i] as KeyboardPreference
            row.setVisible(row.binding.name.toLower().contains(query.toLower()) ||
                               row.binding.id.contains(query.toLower()))
            i = i + 1
        }
    }

int64 Cedit.preferenceNumber(String text, int64 minimum, int64 maximum) {
        if (text.length == 0 || text.length > 2) { return(-1) }
        int64 i = 0
        while (i < text.length) {
            if (!"0123456789".contains(byteSpan(text, i, i + 1))) { return(-1) }
            i = i + 1
        }
        int64 number = text.toInt64()
        if (number < minimum || number > maximum) { return(-1) }
        return(number)
    }

void Cedit.editorCheckChanged(bool active) { editorSettingChanged("") }

void Cedit.editorSettingChanged(String text) {
        if (refreshingPreferences) { return }
        if (fontEntry == null || sizeEntry == null || tabsEntry == null || marginEntry == null) {
            return
        }
        String problem = settings.fontError(fontEntry.text())
        int64 size = preferenceNumber(sizeEntry.text(), 6, 72)
        int64 tabs = preferenceNumber(tabsEntry.text(), 1, 16)
        int64 margin = preferenceNumber(marginEntry.text(), 0, 512)
        if (size < 0) { problem = "Font size must be an integer from 6 to 72" }
        if (tabs < 0) { problem = "Tab width must be an integer from 1 to 16" }
        if (margin < 0) { problem = "Right margin must be an integer from 0 to 512" }
        if (!problem.equals("")) {
            preferencesMessage.setText(problem)
            return
        }
        settings.fontFamily = fontEntry.text()
        settings.fontSize = size
        settings.tabWidth = tabs
        settings.rightMargin = margin
        settings.insertSpaces = spacesCheck.active()
        settings.lineNumbers = numbersCheck.active()
        if (activeProject != null && activeProject.hasNumbers) {
            activeProject.lineNumbers = settings.lineNumbers
            if (activeProject.writable && projectSaves == 0 && projectOp.equals("")) {
                writeProject(activeProject, true, false, "configure")
            }
        }
        settings.wrap = wrapCheck.active()
        settings.highlightLine = highlightCheck.active()
        settings.saveOnTabLoss = saveTabCheck.active()
        settings.saveOnWindowLoss = saveWindowCheck.active()
        settings.stripTrailingSpaces = stripCheck.active()
        settings.autoCompleteBrackets = bracketsCheck.active()
        if (lspEntry != null && !lspEntry.text().equals(settings.lspCommand)) {
            settings.lspCommand = lspEntry.text()
            if (client != null) { client.launch(settings.lspCommand) }
        }
        settingsChanged()
    }

void Cedit.saveGlobalChanged(bool active) {
        if (refreshingPreferences) { return }
        mirrorGlobal = active
        if (active) {
            if (!writeMirroredGlobal(settings.serialize())) {
                if (preferencesMessage != null) {
                    preferencesMessage.setText(diagnostic("CEDIT2001", format(
                        "Could not update global settings at {}", settings.globalPath)))
                }
                return
            }
        }
        refreshSettingsPathLabel()
    }

String Cedit.readSettingsDisk(String path) {
        if (!System.FileSystem().isFile(path)) { return("") }
        System.File file = null
        try { file = System.File(path, "r") }
        except(Exception) { return("") }
        String text = ""
        try { text = file.readAll() }
        except(Exception) {
            file.close()
            return("")
        }
        file.close()
        return(text)
    }

void Cedit.resetEditorPreferences() {
        resetSection = "Editor"
        resetChoices.setVisible(true)
    }

void Cedit.resetKeyboardPreferences() {
        resetSection = "Keyboard"
        resetChoices.setVisible(true)
    }

void Cedit.cancelPreferencesReset() {
        resetSection = ""
        resetChoices.setVisible(false)
    }

