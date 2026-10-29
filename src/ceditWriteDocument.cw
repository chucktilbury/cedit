bool Cedit.writeDocument(EditorDocument document, String destination) {
        if (destination.equals("")) {
            reportSaveFailure("empty file path")
            closeSearchDialog()
            return(false)
        }
        if (destination.contains("://")) {
            reportSaveFailure(format("{}: only local filesystem paths are supported", destination))
            return(false)
        }
        String absoluteDestination = destination
        if (!absoluteDestination.startsWith("/")) {
            absoluteDestination = System.FileSystem().join(
                System.FileSystem().getCwd(), absoluteDestination)
        }
        absoluteDestination = System.FileSystem().normalize(absoluteDestination)
        if (System.FileSystem().exists(absoluteDestination)) {
            if (!System.FileSystem().isFile(absoluteDestination)) {
                reportSaveFailure(format("{}: destination is not a regular file", absoluteDestination))
                return(false)
            }
            absoluteDestination = System.FileSystem().absolutePath(absoluteDestination)
        } else {
            String parent = System.FileSystem().absolutePath(
                System.FileSystem().dirname(absoluteDestination))
            if (parent.equals("")) {
                reportSaveFailure(format("{}: could not resolve destination folder", destination))
                return(false)
            }
            absoluteDestination = System.FileSystem().join(parent,
                System.FileSystem().basename(absoluteDestination))
        }
        int64 index = 0
        while (index < documents.length) {
            EditorDocument other = documents[index] as EditorDocument
            if (other != document && other.path.equals(absoluteDestination)) {
                reportSaveFailure(format("{}: destination belongs to another open document",
                                         absoluteDestination))
                return(false)
            }
            index = index + 1
        }
        if (settings.stripTrailingSpaces) { document.stripTrailingSpaces() }
        System.File output = null
        try {
            output = System.File(absoluteDestination, "w")
        } except(Exception) {
            reportSaveFailure(format("{}: {}", absoluteDestination,
                                     System.System().lastError()))
            return(false)
        }
        String contents = document.view.text()
        int64 written = output.write(contents)
        String writeError = System.System().lastError()
        if (written != contents.length) {
            output.close()
            if (writeError.equals("")) { writeError = "incomplete write" }
            reportSaveFailure(format("{}: {}", absoluteDestination, writeError))
            return(false)
        }
        output.flush()
        String flushError = System.System().lastError()
        output.close()
        String closeError = System.System().lastError()
        if (!flushError.equals("") || !closeError.equals("")) {
            String writeProblem = flushError
            if (!closeError.equals("")) {
                if (!writeProblem.equals("")) { writeProblem.append("; ") }
                writeProblem.append(closeError)
            }
            reportSaveFailure(format("{}: {}", absoluteDestination, writeProblem))
            return(false)
        }
        if (!document.path.equals(absoluteDestination)) {
            document.view.setLanguage(GtkSource.Content().languageFor(absoluteDestination))
        }
        document.updatePath(absoluteDestination)
        rememberRecent(absoluteDestination)
        document.view.markSaved()
        document.diskText = contents
        refreshTab(document)
        if (client != null && client.ready) { client.sendChange(document) }
        document.automaticSaveError = ""
        hasAutomaticSaveErrors = recomputeAutomaticSaveErrors()
        status.setText(format("Saved{}", automaticSaveErrors()))
        project.fileSaved(absoluteDestination)
        if (diskDocument == document) { clearDiskPrompt() }
        updateMenu()
        return(true)
    }

void Cedit.reportSaveFailure(String detail) {
        String operation = "Save"
        if (automaticSaving) { operation = "Automatic Save" }
        reportDiagnostic("CEDIT1002", format(
            "{} failed: {}; your edits remain unsaved. Choose a valid writable local destination and retry.",
            operation, detail))
    }

bool Cedit.commandsBlocked() {
        return(fileDialog != null || pendingCloseAll || pendingCloseDocument != null ||
            projectSaves > 0 || !confirmOp.equals(""))
    }

void Cedit.chooseOpen() {
        if (commandsBlocked()) { return }
        String initialPath = ""
        if (currentDocument() != null) {
            initialPath = currentDocument().path
        }
        fileDialog = Gtk.FileDialog(window, initialPath, openResultAction)
        updateMenu()
    }

void Cedit.chooseFolder() {
        if (commandsBlocked()) { return }
        String initialPath = project.rootPath
        if (initialPath.equals("") && currentDocument() != null && !currentDocument().path.equals("")) {
            initialPath = System.FileSystem().dirname(currentDocument().path)
        }
        fileDialog = Gtk.FileDialog(window, initialPath, _self().folderOpened)
        updateMenu()
    }

void Cedit.folderOpened(String path) {
        fileDialog = null
        updateMenu()
        if (path.equals("")) {
            currentDocument().view.focus()
            return
        }
        if (path.contains("://")) {
            reportDiagnostic("CEDIT2002", format(
                "Open folder failed: {}: only local filesystem paths are supported. Choose a local folder and retry.",
                path))
            return
        }
        if (!path.startsWith("/")) {
            path = System.FileSystem().join(System.FileSystem().getCwd(), path)
        }
        if (activeProject != null) {
            String root = canonicalFolder(path, "Open folder failed")
            if (root.equals("")) { return }
            // Leaving a project saves its workspace state, then opens the folder without project settings.
            nextFolder = root
            beginSwitch("folder")
            return
        }
        project.setRoot(System.FileSystem().normalize(path))
        noteOpenFiles()
    }

void Cedit.opened(list paths) {
        fileDialog = null
        openFailures = []
        collectingFailures = true
        EditorDocument last = null
        int64 index = 0
        while (index < paths.length) {
            EditorDocument document = openDocument(paths[index] as String)
            if (document != null) {
                last = document
            }
            index = index + 1
        }
        collectingFailures = false
        if (last != null) {
            activateDocument(last)
        }
        if (openFailures.length > 0) {
            String details = ""
            index = 0
            while (index < openFailures.length) {
                if (index > 0) {
                    details.append("\n")
                }
                details.append(openFailures[index] as String)
                index = index + 1
            }
            String title = "Some files could not be opened"
            if (openFailures.length == 1) {
                title = "Could not open file"
                status.setText(openFailures[0] as String)
            } else {
                reportDiagnostic("CEDIT1001", format(
                    "Open failed for {} of {} files; see the dialog for paths and reasons.",
                    openFailures.length, paths.length))
            }
            Gtk.AlertDialog().show(window, title, details)
            openFailures = []
        }
        updateMenu()
    }

void Cedit.chooseSave(EditorDocument document, bool closing) {
        dialogDocument = document
        dialogClosing = closing
        String initialPath = document.path
        if (initialPath.equals("")) { initialPath = "untitled.cw" }
        fileDialog = Gtk.FileDialog(window, true, initialPath, saveResultAction)
        updateMenu()
    }

void Cedit.savedAs(String path) {
        EditorDocument document = dialogDocument
        bool closing = dialogClosing
        fileDialog = null
        dialogDocument = null
        dialogClosing = false
        if (path.equals("")) {
            if (closing) { cancelPendingClose() }
            status.setText("Save As cancelled")
        } else {
            if (writeDocument(document, path) && closing) {
                continueSavedClose()
            }
        }
        updateMenu()
    }

void Cedit.quit() { window.close() }

void Cedit.openRecent() {
        if (commandsBlocked()) { return }
        if (recentFiles.length == 0) {
            status.setText("No recent files in this session")
            return
        }
        if (recentWindow == null || recentWindow.disposed()) {
            recentWindow = Gtk.TransientWindow("Recent Files")
            recentWindow.setTransientFor(window)
            recentWindow.setDefaultSize(520, 360)
            recentWindow.onCloseRequest(_self().hideRecent)
        }
        recentList = Gtk.Box(Gtk.Box.VERTICAL, 4)
        int64 index = recentFiles.length - 1
        while (index >= 0) {
            RecentEntry entry = RecentEntry(_self(), recentFiles[index] as String)
            recentList.append(entry.button)
            index = index - 1
        }
        Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
        scroll.setHExpand(true)
        scroll.setVExpand(true)
        scroll.setChild(recentList)
        Gtk.Box root = Gtk.Box(Gtk.Box.VERTICAL, 8)
        root.append(Gtk.Label("Open a recent file"))
        root.append(scroll)
        Gtk.Button dismiss = Gtk.Button("Close")
        dismiss.onClicked(_self().closeRecent)
        root.append(dismiss)
        recentWindow.setChild(root)
        recentWindow.present()
    }

void Cedit.rememberRecent(String path) {
        list kept = []
        int64 index = 0
        while (index < recentFiles.length) {
            String existing = recentFiles[index] as String
            if (!existing.equals(path)) { kept.append(existing) }
            index = index + 1
        }
        kept.append(path)
        recentFiles = kept
        while (recentFiles.length > 20) {
            list trimmed = []
            index = 1
            while (index < recentFiles.length) {
                trimmed.append(recentFiles[index] as String)
                index = index + 1
            }
            recentFiles = trimmed
        }
    }

void Cedit.attachDocumentMenu(EditorDocument document) {
        if (document == null || document.view == null) { return }
        Gtk.ContextMenu menu = Gtk.ContextMenu(document.view.widget())
        Gtk.Box actions = Gtk.Box(Gtk.Box.VERTICAL, 4)
        Gtk.Button reload = Gtk.Button("Reload")
        reload.onClicked(_self().reloadCurrent)
        actions.append(reload)
        menu.setChild(actions)
    }

int64 Cedit.searchOptions() {
        int64 options = 0
        if (caseCheck.active()) {
            options = options + GtkSource.View.CASE_SENSITIVE
        }
        if (wholeWordsCheck.active()) {
            options = options + GtkSource.View.WHOLE_WORDS
        }
        if (selectionCheck.active()) {
            options = options + GtkSource.View.IN_SELECTION
        }
        return(options)
    }

EditorDocument Cedit.searchDocument() {
        if (commandsBlocked()) { return(null) }
        EditorDocument document = currentDocument()
        if (document == null) {
            return(null)
        }
        if (selectionCheck.active() && !document.view.hasSearchScope()) {
            status.setText("In selection: select text, then press Find or Replace")
            return(null)
        }
        return(document)
    }

void Cedit.findNext() {
        EditorDocument document = searchDocument()
        if (document == null) {
            return
        }
        if (!document.view.findWith(findEntry.text(), searchOptions())) {
            status.setText("No match")
        } else {
            updateStatus()
        }
    }

void Cedit.replaceNext() {
        EditorDocument document = searchDocument()
        if (document == null) {
            return
        }
        if (!document.view.replaceWith(findEntry.text(), replaceEntry.text(), searchOptions())) {
            status.setText("No match")
        } else {
            updateStatus()
        }
    }

void Cedit.replaceAll() {
        EditorDocument document = searchDocument()
        if (document == null) {
            return
        }
        int64 count = document.view.replaceAll(findEntry.text(), replaceEntry.text(),
                                             searchOptions())
        if (count == 0) {
            status.setText("No match")
        } else {
            updateMenu()
            status.setText(format("Replaced {} occurrences", count))
        }
    }

void Cedit.undoCurrent() {
        if (commandsBlocked()) { return }
        EditorDocument document = currentDocument()
        if (document != null) {
            document.view.undo()
        }
    }

void Cedit.redoCurrent() {
        if (commandsBlocked()) { return }
        EditorDocument document = currentDocument()
        if (document != null) {
            document.view.redo()
        }
    }

void Cedit.cutCurrent() {
        if (!commandsBlocked() && currentDocument() != null) { currentDocument().view.cut() }
    }

void Cedit.copyCurrent() {
        if (!commandsBlocked() && currentDocument() != null) { currentDocument().view.copy() }
    }

void Cedit.pasteCurrent() {
        if (!commandsBlocked() && currentDocument() != null) { currentDocument().view.paste() }
    }

void Cedit.selectAllCurrent() {
        if (!commandsBlocked() && currentDocument() != null) { currentDocument().view.selectAll() }
    }

