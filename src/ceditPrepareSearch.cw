void Cedit.prepareSearch() {
        EditorDocument document = currentDocument()
        if (document == null) {
            return
        }
        String selected = document.view.selectedText()
        document.view.captureSearchScope()
        if (!selected.equals("") && !selected.contains("\n")) {
            findEntry.setText(selected)
        }
    }

void Cedit.showFind() {
        if (!commandsBlocked()) {
            searchWindow.setTitle("Find")
            replaceRow.setVisible(false)
            prepareSearch()
            searchDialogOpen = true
            searchWindow.present()
            findEntry.focus()
        }
    }

void Cedit.showReplace() {
        if (!commandsBlocked()) {
            searchWindow.setTitle("Find and Replace")
            replaceRow.setVisible(true)
            prepareSearch()
            searchDialogOpen = true
            searchWindow.present()
            replaceEntry.focus()
        }
    }

bool Cedit.hideSearchDialog() {
        searchDialogOpen = false
        searchWindow.setVisible(false)
        return(true)
    }

void Cedit.closeSearchDialog() {
        searchDialogOpen = false
        if (searchWindow != null && !searchWindow.disposed()) {
            searchWindow.dispose()
        }
    }

void Cedit.changed() {
        if (window == null || window.disposed() || changingDocuments) { return }
        EditorDocument document = currentDocument()
        if (document != null) {
            refreshTab(document)
            updateUnsavedMarks(document)
            if (client != null) { client.noteEdit() }
        }
        updateEditActions()
    }

void Cedit.cursorMoved() {
        if (window == null || window.disposed() || changingDocuments) { return }
        updateStatusText()
        updateSelectionActions()
    }

void Cedit.pageChanged() {
        pageChanges = pageChanges + 1
        if (changingDocuments || window.disposed()) { return }
        // Defer tab-loss work so it does not run inside GtkNotebook's arrow
        // press handler (which can drop the matching release and stick the
        // scroll arrows until another tab is clicked).
        Gtk.Application().post(_self().pageChangedDeferred)
    }

void Cedit.pageChangedDeferred() {
        if (changingDocuments || window.disposed()) { return }
        EditorDocument previous = focusedDocument
        focusedDocument = currentDocument()
        if (!changingDocuments && previous != focusedDocument && settings.saveOnTabLoss) {
            automaticSave(previous)
        }
        if (searchDialogOpen) {
            EditorDocument document = currentDocument()
            if (document != null && document.view.hasSelection()) {
                document.view.captureSearchScope()
            }
        }
        updateStatus()
        checkDiskChange()
    }

void Cedit.automaticSave(EditorDocument document) {
        if (!presented || automaticSaving || changingDocuments || commandsBlocked() ||
            document == null || document.path.equals("") || !document.view.modified()) { return }
        automaticSaving = true
        if (!writeDocument(document, document.path)) {
            document.automaticSaveError = status.text()
            hasAutomaticSaveErrors = true
        }
        automaticSaving = false
    }

String Cedit.automaticSaveErrors() {
        if (!hasAutomaticSaveErrors) { return("") }
        String errors = ""
        int64 index = 0
        while (index < documents.length) {
            EditorDocument document = documents[index] as EditorDocument
            if (!document.automaticSaveError.equals("")) {
                errors.append(format("  {}", document.automaticSaveError))
            }
            index = index + 1
        }
        return(errors)
    }

bool Cedit.recomputeAutomaticSaveErrors() {
        int64 index = 0
        while (index < documents.length) {
            EditorDocument document = documents[index] as EditorDocument
            if (!document.automaticSaveError.equals("")) {
                return(true)
            }
            index = index + 1
        }
        return(false)
    }

void Cedit.windowFocusChanged(bool active) {
        if (active) { checkDiskChange() }
        if (active || !presented || window.disposed() || !settings.saveOnWindowLoss) { return }
        int64 index = 0
        while (index < documents.length) {
            automaticSave(documents[index] as EditorDocument)
            index = index + 1
        }
        updateStatus()
    }

void Cedit.refreshTab(EditorDocument document) {
        String title = document.tabTitle()
        if (title.equals(document.lastTitle)) { return }
        document.lastTitle = title
        int64 index = 0
        while (index < documents.length) {
            EditorDocument item = documents[index] as EditorDocument
            if (item == document) {
                notebook.setPageTitle(index, title)
                return
            }
            index = index + 1
        }
    }

void Cedit.updateStatusText() {
        if (status == null || window.disposed() || changingDocuments) { return }
        EditorDocument document = currentDocument()
        if (document == null) {
            return
        }
        String message = format("Ln {}, Col {}", document.view.line(), document.view.column())
        if (document.view.modified()) {
            message.append("  Modified")
        }
        message.append(automaticSaveErrors())
        status.setText(message)
    }

void Cedit.updateStatus() {
        if (window == null || window.disposed() || changingDocuments) { return }
        updateMenu()
        updateStatusText()
    }

void Cedit.updateSelectionActions() {
        if (menu == null || window.disposed()) { return }
        EditorDocument document = currentDocument()
        bool selected = menuReady && document != null && document.view.hasSelection()
        if (selected != menuSelected) {
            menuSelected = selected
            menu.setItemEnabled(cutItem, selected)
            menu.setItemEnabled(copyItem, selected)
        }
    }

void Cedit.updateEditActions() {
        if (menu == null || window.disposed()) { return }
        EditorDocument document = currentDocument()
        bool editable = menuReady && document != null
        bool canUndo = false
        bool canRedo = false
        bool selected = false
        if (editable) {
            canUndo = document.view.canUndo()
            canRedo = document.view.canRedo()
            selected = document.view.hasSelection()
        }
        if (!menuInitialized || canUndo != menuCanUndo) {
            menuCanUndo = canUndo
            menu.setItemEnabled(undoItem, canUndo)
        }
        if (!menuInitialized || canRedo != menuCanRedo) {
            menuCanRedo = canRedo
            menu.setItemEnabled(redoItem, canRedo)
        }
        if (!menuInitialized || selected != menuSelected) {
            menuSelected = selected
            menu.setItemEnabled(cutItem, selected)
            menu.setItemEnabled(copyItem, selected)
        }
    }

void Cedit.updateMenu() {
        if (menu == null || status == null || window.disposed()) { return }
        bool ready = !commandsBlocked()
        EditorDocument document = currentDocument()
        bool editable = ready && document != null
        bool quit = fileDialog == null
        bool projectActive = ready && activeProject != null

        if (!menuInitialized || ready != menuReady) {
            menuReady = ready
            menu.setItemEnabled(newItem, ready)
            menu.setItemEnabled(openItem, ready)
            menu.setItemEnabled(openFolderItem, ready)
            project.sidebar.setSensitive(ready)
            menu.setItemEnabled(projectNewItem, ready)
            menu.setItemEnabled(projectOpenItem, ready)
            findRow.setSensitive(ready)
            replaceRow.setSensitive(ready)
            optionsRow.setSensitive(ready)
        }
        if (!menuInitialized || quit != menuQuit) {
            menuQuit = quit
            menu.setItemEnabled(quitItem, quit)
            menu.setItemEnabled(aboutItem, quit)
            confirmChoices.setSensitive(quit)
            notebook.setSensitive(quit)
            closeChoices.setSensitive(quit)
        }
        if (!menuInitialized || projectActive != menuProjectActive) {
            menuProjectActive = projectActive
            int64 projectIndex = 0
            while (projectIndex < projectItems.length) {
                menu.setItemEnabled(projectItems[projectIndex] as int64, projectActive)
                projectIndex = projectIndex + 1
            }
            menu.setItemEnabled(projectCloseItem, projectActive)
        }
        if (!menuInitialized || editable != menuEditable) {
            menuEditable = editable
            int64 index = 0
            while (index < documentItems.length) {
                menu.setItemEnabled(documentItems[index] as int64, editable)
                index = index + 1
            }
        }
        updateEditActions()
        syncViewMenu()
        menuInitialized = true
    }

bool Cedit.workspaceNeedsSave() {
        return(activeProject != null && activeProject.workspaceWritable &&
            !activeProject.workspaceText.equals(activeProject.workspaceOriginal))
    }

bool Cedit.requestClose() {
        writeAllRecoveries()
        if (savePending || projectSaves > 0) {
            closeAfterSave = true
            status.setText("Waiting for settings to save")
            return(true)
        }
        if (allowWindowClose) {
            // Checked synchronously so window.close() is never re-entered from this handler.
            if (!quitReady && workspaceNeedsSave()) {
                writeProject(activeProject, false, true, "quit")
                return(true)
            }
            closePreferencesWindows()
            return(false)
        }
        if (fileDialog != null) {
            fileDialog.cancel()
            fileDialog = null
            dialogDocument = null
            dialogClosing = false
            chooserPurpose = ""
        }
        if (!confirmOp.equals("")) {
            confirmOp = ""
            confirmChoices.setVisible(false)
        }
        switchOp = ""
        nextProject = null
        nextFolder = ""
        if (activeProject != null) {
            activeProject.workspaceText = captureWorkspace(activeProject.root, activeProject.root)
        }
        int64 index = 0
        while (index < documents.length) {
            EditorDocument document = documents[index] as EditorDocument
            if (document.view.modified()) {
                pendingCloseAll = true
                pendingCloseDocument = null
                closeChoices.setVisible(true)
                status.setText("Unsaved changes: Save, Discard, or Cancel closing")
                updateMenu()
                return(true)
            }
            index = index + 1
        }
        if (workspaceNeedsSave()) {
            allowWindowClose = true
            writeProject(activeProject, false, true, "quit")
            return(true)
        }
        return(false)
    }

void Cedit.closePreferencesWindows() {
        closeSearchDialog()
        if (aboutWindow != null && !aboutWindow.disposed()) {
            aboutWindow.setVisible(false)
            aboutWindow.dispose()
        }
        if (configureWindow != null && !configureWindow.disposed()) {
            configureWindow.setVisible(false)
            configureWindow.dispose()
        }
        if (preferencesWindow != null && !preferencesWindow.disposed()) {
            hidePreferences()
            preferencesWindow.dispose()
        }
    }

void Cedit.closeAll() {
        if (commandsBlocked()) { return }
        closingAll = true
        closeNextInBatch()
    }

