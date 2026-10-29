void Cedit.confirmPreferencesReset() {
        if (resetSection.equals("Editor")) {
            settings.resetEditor()
            refreshingPreferences = true
            fontEntry.setText(settings.fontFamily)
            sizeEntry.setText(format("{}", settings.fontSize))
            tabsEntry.setText(format("{}", settings.tabWidth))
            spacesCheck.setActive(settings.insertSpaces)
            numbersCheck.setActive(settings.lineNumbers)
            wrapCheck.setActive(settings.wrap)
            highlightCheck.setActive(settings.highlightLine)
            saveTabCheck.setActive(settings.saveOnTabLoss)
            saveWindowCheck.setActive(settings.saveOnWindowLoss)
            stripCheck.setActive(settings.stripTrailingSpaces)
            bracketsCheck.setActive(settings.autoCompleteBrackets)
            refreshingPreferences = false
        }
        if (resetSection.equals("Keyboard")) {
            settings.resetKeyboard()
            settings.shortcutRevision = settings.shortcutRevision + 1
            int64 i = 0
            while (i < keyboardRows.length) {
                (keyboardRows[i] as KeyboardPreference).refresh()
                i = i + 1
            }
        }
        cancelPreferencesReset()
        settingsChanged()
    }

void Cedit.settingsChanged() {
        int64 i = 0
        while (i < documents.length) {
            applyDocumentSettings(documents[i] as EditorDocument)
            i = i + 1
        }
        applyProjectManagerVisibility()
        syncViewMenu()
        if (!settings.writable) {
            String message = diagnostic("CEDIT2001", format(
                "{}: {}; changes apply for this session only and saving is disabled.",
                settings.path, settings.errors))
            if (preferencesMessage != null) { preferencesMessage.setText(message) }
            else { status.setText(message) }
            return
        }
        if (savePending) {
            saveAgain = true
            return
        }
        saveSettings()
    }

bool Cedit.effectiveLineNumbers() {
        if (activeProject != null && activeProject.hasNumbers) { return(activeProject.lineNumbers) }
        return(settings.lineNumbers)
    }

void Cedit.publishLineNumbers(bool active) {
        settings.lineNumbers = active
        if (activeProject != null && activeProject.hasNumbers) {
            activeProject.lineNumbers = active
            if (activeProject.writable && projectSaves == 0 && projectOp.equals("")) {
                writeProject(activeProject, true, false, "configure")
            }
        }
        if (numbersCheck != null) {
            refreshingPreferences = true
            numbersCheck.setActive(active)
            refreshingPreferences = false
        }
    }

void Cedit.lineNumbersChecked(bool active) {
        if (syncingView) { return }
        publishLineNumbers(active)
        settingsChanged()
    }

void Cedit.toggleLineNumbers() { lineNumbersChecked(!effectiveLineNumbers()) }

void Cedit.whitespaceChecked(bool active) {
        if (syncingView) { return }
        settings.showWhitespace = active
        settingsChanged()
    }

void Cedit.toggleWhitespace() { whitespaceChecked(!settings.showWhitespace) }

void Cedit.indentMarkersChecked(bool active) {
        if (syncingView) { return }
        settings.showIndentMarkers = active
        settingsChanged()
    }

void Cedit.toggleIndentMarkers() { indentMarkersChecked(!settings.showIndentMarkers) }

void Cedit.projectManagerChecked(bool active) {
        if (syncingView) { return }
        settings.showProjectManager = active
        settingsChanged()
    }

void Cedit.toggleProjectManager() { projectManagerChecked(!settings.showProjectManager) }

void Cedit.closeSidePanel() { projectManagerChecked(false) }

void Cedit.scheduleLanguagePoll() {
        if (client == null || !client.running) { return }
        Gtk.Application().schedule(100, languagePollAction)
    }

void Cedit.languagePoll() {
        if (client != null) { client.poll() }
    }

void Cedit.languageFlush() {
        if (client == null || !client.running) { return }
        if (client.generation == client.sentGeneration) { return }
        client.sendChange(currentDocument())
    }

void Cedit.scheduleDiskPoll() {
        if (!presented || window == null || window.disposed()) { return }
        Gtk.Application().schedule(2000, diskPollAction)
    }

void Cedit.diskPoll() {
        if (!presented || window == null || window.disposed()) { return }
        checkDiskChange()
        scheduleDiskPoll()
    }

void Cedit.openRecentPath(String path) {
        closeRecent()
        if (commandsBlocked()) { return }
        openFile(path)
    }

bool Cedit.hideRecent() {
        closeRecent()
        return(true)
    }

void Cedit.closeRecent() {
        if (recentWindow != null && !recentWindow.disposed()) {
            recentWindow.setVisible(false)
        }
    }

void Cedit.syncViewMenu() {
        if (menu == null) { return }
        syncingView = true
        menu.setItemChecked(lineNumbersItem, effectiveLineNumbers())
        menu.setItemChecked(whitespaceItem, settings.showWhitespace)
        menu.setItemChecked(indentMarkersItem, settings.showIndentMarkers)
        menu.setItemChecked(projectManagerItem, settings.showProjectManager)
        syncingView = false
    }

void Cedit.applyProjectManagerVisibility() {
        if (workspace == null || project == null) { return }
        if (!settings.showProjectManager) {
            int64 width = workspace.position()
            if (width > 0) { projectManagerWidth = width }
        }
        if (sidePanel != null) { sidePanel.setVisible(settings.showProjectManager) }
        project.sidebar.setVisible(settings.showProjectManager)
        if (settings.showProjectManager && projectManagerWidth > 0) {
            workspace.setPosition(projectManagerWidth)
        }
    }

void Cedit.keyboardSettingsChanged() {
        settings.shortcutRevision = settings.shortcutRevision + 1
        settingsChanged()
    }

bool Cedit.saveSettings() {
        String text = settings.serialize()
        if (text.equals(persistedText)) { return(true) }
        String directory = System.FileSystem().dirname(settings.path)
        if (!makeSettingsDirectory(directory)) {
            settingsSaveFailure(System.System().lastError())
            return(false)
        }
        // Refuse to overwrite a file edited externally since the last load/save.
        if (System.FileSystem().exists(settings.path)) {
            if (!System.FileSystem().isFile(settings.path) ||
                System.FileSystem().fileSize(settings.path) > 65536) {
                settingsSaveFailure("current settings must be a regular file no larger than 64 KiB")
                return(false)
            }
            System.File file = null
            try {
                file = System.File(settings.path, "r")
            } except(Exception) {
                settingsSaveFailure("cannot read current settings")
                return(false)
            }
            String disk = ""
            try { disk = file.readAll() }
            except(Exception) as failure {
                file.close()
                settingsSaveFailure(failure.message)
                return(false)
            }
            String readError = System.System().lastError()
            file.close()
            if (!readError.equals("") || !disk.equals(persistedText)) {
                settingsSaveFailure("settings changed on disk; restart before saving preferences")
                return(false)
            }
        } else {
            if (!persistedText.equals("")) {
                settingsSaveFailure("settings removed on disk; restart before saving preferences")
                return(false)
            }
        }
        savingText = text
        savePending = true
        if (preferencesMessage != null) { preferencesMessage.setText("Saving settings...") }
        Gtk.Config().save(settings.path, text, persistedText, _self().settingsSaved)
        return(true)
    }

bool Cedit.makeSettingsDirectory(String directory) {
        if (System.FileSystem().isDir(directory)) { return(true) }
        String parent = System.FileSystem().dirname(directory)
        if (parent.equals(directory) || directory.equals("")) { return(false) }
        if (!makeSettingsDirectory(parent)) { return(false) }
        return(System.FileSystem().mkdir(directory))
    }

String Cedit.diagnostic(String code, String explanation) {
        return(format("cedit: error[{}]: {}", code, explanation))
    }

void Cedit.reportDiagnostic(String code, String explanation) {
        status.setText(diagnostic(code, explanation))
    }

void Cedit.settingsSaveFailure(String detail) {
        String message = diagnostic("CEDIT2001", format(
            "Settings save failed: {} at {}; changes remain session-only. Check the settings path and permissions, then retry.",
            detail, settings.path))
        if (preferencesMessage != null) { preferencesMessage.setText(message) }
        else { status.setText(message) }
    }

void Cedit.settingsSaved(String error) {
        savePending = false
        if (!error.equals("")) {
            settingsSaveFailure(error)
            saveAgain = false
            closeAfterSave = false
            if (preferencesWindow != null && !preferencesWindow.disposed()) { preferencesWindow.present() }
            return
        }
        persistedText = savingText
        settings.original = savingText
        if (preferencesMessage != null) { preferencesMessage.setText("Settings saved") }
        if (saveAgain) {
            saveAgain = false
            if (!saveSettings()) {
                closeAfterSave = false
                preferencesWindow.present()
                return
            }
        }
        if (closeAfterSave && !savePending && projectSaves == 0 && !window.disposed()) {
            closeAfterSave = false
            window.close()
        }
    }

String Cedit.version() {
        // Keep in sync with project(cedit VERSION ...) in CMakeLists.txt.
        return("0.0.1")
    }

void Cedit.projectFailure(String title, String detail) {
        String recovery = "Review the path and details, correct the issue, then retry."
        String message = diagnostic("CEDIT2002", format("{}: {}", title, detail))
        reportDiagnostic("CEDIT2002", format("{}: {}; {}", title, detail, recovery))
        Gtk.AlertDialog().show(window, title, format("{}\n\n{}", message, recovery))
    }

String Cedit.canonicalFolder(String path, String title) {
        if (path.contains("://")) {
            projectFailure(title, "only local filesystem paths are supported")
            return("")
        }
        String requested = path
        if (!requested.startsWith("/")) {
            requested = System.FileSystem().join(System.FileSystem().getCwd(), requested)
        }
        String canonical = System.FileSystem().absolutePath(requested)
        if (canonical.equals("") || !System.FileSystem().isDir(canonical)) {
            projectFailure(title, format("{} is not an accessible folder", path))
            return("")
        }
        return(canonical)
    }

CwhipProject Cedit.loadProject(String path, String title) {
        String root = canonicalFolder(path, title)
        if (root.equals("")) { return(null) }
        // Choosing a metadata folder itself selects its project root.
        if (System.FileSystem().basename(root).equals(".cwhip") &&
            System.FileSystem().isFile(System.FileSystem().join(root, "project.toml"))) {
            root = System.FileSystem().dirname(root)
        }
        CwhipProject candidate = CwhipProject(root)
        String problem = candidate.load(settings)
        if (!problem.equals("")) {
            projectFailure(title, problem)
            return(null)
        }
        return(candidate)
    }

void Cedit.openRootArgument(String path) {
        if (activeProject != null || !project.rootPath.equals("")) {
            status.setText(format("Ignored extra folder argument: {}", path))
            return
        }
        String root = canonicalFolder(path, "Could not open folder")
        if (root.equals("")) { return }
        if (System.FileSystem().isFile(System.FileSystem().join(root, ".cwhip/project.toml"))) {
            CwhipProject candidate = loadProject(root, "Could not open project")
            if (candidate != null) { activateProject(candidate, true) }
            return
        }
        project.setRoot(root)
        noteOpenFiles()
    }

void Cedit.chooseProjectFolder(String purpose) {
        if (commandsBlocked()) { return }
        chooserPurpose = purpose
        String initialPath = project.rootPath
        if (purpose.equals("project-save-as") && activeProject != null) {
            initialPath = System.FileSystem().dirname(activeProject.root)
        }
        fileDialog = Gtk.FileDialog(window, initialPath, _self().projectFolderChosen)
        updateMenu()
    }

void Cedit.newProject() { chooseProjectFolder("project-new") }

void Cedit.openProject() { chooseProjectFolder("project-open") }

void Cedit.saveProjectAs() {
        if (activeProject == null) {
            status.setText("No project is open")
            return
        }
        chooseProjectFolder("project-save-as")
    }

void Cedit.projectFolderChosen(String path) {
        fileDialog = null
        String purpose = chooserPurpose
        chooserPurpose = ""
        updateMenu()
        if (purpose.equals("")) { return }
        if (path.equals("")) {
            status.setText("Cancelled")
            return
        }
        if (purpose.equals("project-open")) { openProjectAt(path) }
        if (purpose.equals("project-new")) { prepareNewProject(path, false) }
        if (purpose.equals("project-save-as")) { prepareNewProject(path, true) }
    }

