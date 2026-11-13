/*
 * src/ceditWriteDocument.cw - Write/save/open dialogs and edit clipboard actions.
 *
 * Created: 2026-10-29
 * Author: Auto
 *
 * Changelog:
 *   2026-10-29  Initial file.
 *   2026-11-13  CODING headers and method comments.
 */

/*
 * Cedit.writeDocument
 *
 * Purpose: writeDocument.
 *
 * Parameters:
 *   document.
 *   destination.
 *
 * Returns: bool.
 */

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
        clearUnsavedMarks(document)
        clearRecovery(document)
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

/*
 * Cedit.reportSaveFailure
 *
 * Purpose: reportSaveFailure.
 *
 * Parameters:
 *   detail.
 *
 * Returns: nothing.
 */

void Cedit.reportSaveFailure(String detail) {
        String operation = "Save"
        if (automaticSaving) { operation = "Automatic Save" }
        reportDiagnostic("CEDIT1002", format(
            "{} failed: {}; your edits remain unsaved. Choose a valid writable local destination and retry.",
            operation, detail))
    }

/*
 * Cedit.commandsBlocked
 *
 * Purpose: commandsBlocked.
 *
 * Parameters:
 *   none.
 *
 * Returns: bool.
 */

bool Cedit.commandsBlocked() {
        return(fileDialog != null || pendingCloseAll || pendingCloseDocument != null ||
            projectSaves > 0 || !confirmOp.equals(""))
    }

/*
 * Cedit.chooseOpen
 *
 * Purpose: chooseOpen.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.chooseOpen() {
        if (commandsBlocked()) { return }
        String initialPath = ""
        if (currentDocument() != null) {
            initialPath = currentDocument().path
        }
        fileDialog = Gtk.FileDialog(window, initialPath, openResultAction)
        updateMenu()
    }

/*
 * Cedit.chooseFolder
 *
 * Purpose: chooseFolder.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.chooseFolder() {
        if (commandsBlocked()) { return }
        String initialPath = project.rootPath
        if (initialPath.equals("") && currentDocument() != null && !currentDocument().path.equals("")) {
            initialPath = System.FileSystem().dirname(currentDocument().path)
        }
        fileDialog = Gtk.FileDialog(window, initialPath, _self().folderOpened)
        updateMenu()
    }

/*
 * Cedit.folderOpened
 *
 * Purpose: folderOpened.
 *
 * Parameters:
 *   path.
 *
 * Returns: nothing.
 */

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
        String root = System.FileSystem().normalize(path)
        project.setRoot(root)
        adoptSettingsRoot(root)
        noteOpenFiles()
    }

/*
 * Cedit.opened
 *
 * Purpose: opened.
 *
 * Parameters:
 *   paths.
 *
 * Returns: nothing.
 */

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

/*
 * Cedit.chooseSave
 *
 * Purpose: chooseSave.
 *
 * Parameters:
 *   document.
 *   closing.
 *
 * Returns: nothing.
 */

void Cedit.chooseSave(EditorDocument document, bool closing) {
        dialogDocument = document
        dialogClosing = closing
        String initialPath = document.path
        if (initialPath.equals("")) { initialPath = "untitled.cw" }
        fileDialog = Gtk.FileDialog(window, true, initialPath, saveResultAction)
        updateMenu()
    }

/*
 * Cedit.savedAs
 *
 * Purpose: savedAs.
 *
 * Parameters:
 *   path.
 *
 * Returns: nothing.
 */

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

/*
 * Cedit.quit
 *
 * Purpose: quit.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.quit() { window.close() }

/*
 * Cedit.refreshRecentMenu
 *
 * Purpose: refreshRecentMenu.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.refreshRecentMenu() {
        if (menu == null) { return }
        menu.clearMenu(recentMenu)
        recentEntries = []
        if (recentFiles.length == 0) { return }
        int64 index = recentFiles.length - 1
        while (index >= 0) {
            RecentEntry entry = RecentEntry(_self(), recentFiles[index] as String)
            recentEntries.append(entry)
            menu.addItem(recentMenu, entry.path, entry._self().choose)
            index = index - 1
        }
    }

/*
 * Cedit.openRecent
 *
 * Purpose: openRecent.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.openRecent() {
        // Kept for command wiring; Recent is a submenu rebuilt by refreshRecentMenu.
        if (recentFiles.length == 0) { status.setText("No recent files in this session") }
    }

/*
 * Cedit.rememberRecent
 *
 * Purpose: rememberRecent.
 *
 * Parameters:
 *   path.
 *
 * Returns: nothing.
 */

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
        refreshRecentMenu()
    }

/*
 * Cedit.attachDocumentMenu
 *
 * Purpose: attachDocumentMenu.
 *
 * Parameters:
 *   document.
 *
 * Returns: nothing.
 */

void Cedit.attachDocumentMenu(EditorDocument document) {
        if (document == null || document.view == null) { return }
        // Append to the native edit menu; do not replace Cut/Copy/Paste.
        document.view.addContextAction("Reload", _self().reloadCurrent)
        document.view.addContextAction("Insert date/time", _self().pluginInsertDate)
        document.view.addContextAction("Toggle debug marker", _self().pluginToggleDebug)
    }

/*
 * Cedit.searchOptions
 *
 * Purpose: searchOptions.
 *
 * Parameters:
 *   none.
 *
 * Returns: int64.
 */

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

/*
 * Cedit.searchDocument
 *
 * Purpose: searchDocument.
 *
 * Parameters:
 *   none.
 *
 * Returns: EditorDocument.
 */

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

/*
 * Cedit.findNext
 *
 * Purpose: findNext.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

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

/*
 * Cedit.replaceNext
 *
 * Purpose: replaceNext.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

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

/*
 * Cedit.replaceAll
 *
 * Purpose: replaceAll.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

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

/*
 * Cedit.undoCurrent
 *
 * Purpose: undoCurrent.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.undoCurrent() {
        if (commandsBlocked()) { return }
        EditorDocument document = currentDocument()
        if (document != null) {
            document.view.undo()
        }
    }

/*
 * Cedit.redoCurrent
 *
 * Purpose: redoCurrent.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.redoCurrent() {
        if (commandsBlocked()) { return }
        EditorDocument document = currentDocument()
        if (document != null) {
            document.view.redo()
        }
    }

/*
 * Cedit.cutCurrent
 *
 * Purpose: cutCurrent.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.cutCurrent() {
        if (!commandsBlocked() && currentDocument() != null) { currentDocument().view.cut() }
    }

/*
 * Cedit.copyCurrent
 *
 * Purpose: copyCurrent.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.copyCurrent() {
        if (!commandsBlocked() && currentDocument() != null) { currentDocument().view.copy() }
    }

/*
 * Cedit.pasteCurrent
 *
 * Purpose: pasteCurrent.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.pasteCurrent() {
        if (!commandsBlocked() && currentDocument() != null) { currentDocument().view.paste() }
    }

/*
 * Cedit.selectAllCurrent
 *
 * Purpose: selectAllCurrent.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.selectAllCurrent() {
        if (!commandsBlocked() && currentDocument() != null) { currentDocument().view.selectAll() }
    }

