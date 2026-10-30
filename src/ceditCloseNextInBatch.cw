void Cedit.closeNextInBatch() {
        if (!closingAll) { return }
        EditorDocument dirty = firstModifiedDocument()
        if (dirty != null) {
            pendingCloseDocument = dirty
            activateDocument(dirty)
            closeChoices.setVisible(true)
            status.setText(format("Unsaved changes in {}: Save, Discard, or Cancel", dirty.tabTitle()))
            updateMenu()
            return
        }
        closeAllDocuments()
        closingAll = false
        pendingCloseDocument = null
        closeChoices.setVisible(false)
        newDocument()
        status.setText("Closed all documents")
        updateMenu()
    }

void Cedit.closeProject() {
        if (commandsBlocked()) { return }
        if (activeProject == null) {
            status.setText("No project is open")
            return
        }
        activeProject.workspaceText = captureWorkspace(activeProject.root, activeProject.root)
        writeProject(activeProject, false, true, "close")
    }

void Cedit.closeCurrentDocument() {
        if (commandsBlocked()) { return }
        EditorDocument document = currentDocument()
        closeDocument(document)
    }

String Cedit.readDiskFile(String path) {
        diskMissing = !System.FileSystem().isFile(path)
        if (diskMissing) { return("") }
        System.File input = null
        try { input = System.File(path, "r") }
        except(Exception) {
            diskMissing = true
            return("")
        }
        String text = ""
        try { text = input.readAll() }
        except(Exception) {
            input.close()
            diskMissing = true
            return("")
        }
        input.close()
        if (!System.System().lastError().equals("")) {
            diskMissing = true
            return("")
        }
        return(text)
    }

void Cedit.clearDiskPrompt() {
        diskDocument = null
        if (diskChoices != null) { diskChoices.setVisible(false) }
        updateMenu()
    }

void Cedit.checkDiskChange() {
        if (diskDocument != null || changingDocuments || !presented) { return }
        EditorDocument document = currentDocument()
        if (document == null || document.path.equals("")) { return }
        String disk = readDiskFile(document.path)
        if (diskMissing || !disk.equals(document.diskText)) {
            diskDocument = document
            diskChoices.setVisible(true)
            status.setText(format("{} changed on disk. Reload, Save, or Close", document.tabTitle()))
            updateMenu()
        }
    }

void Cedit.reloadFromDisk() {
        EditorDocument document = diskDocument
        if (document == null) { document = currentDocument() }
        if (document == null || document.path.equals("")) { return }
        String disk = readDiskFile(document.path)
        if (diskMissing) {
            status.setText("Cannot reload; the file is not readable")
            return
        }
        document.view.setText(disk)
        document.view.markSaved()
        document.diskText = disk
        clearUnsavedMarks(document)
        clearDiskPrompt()
        refreshTab(document)
        if (client != null && client.ready) { client.sendChange(document) }
        status.setText("Reloaded")
    }

void Cedit.saveOverDisk() {
        EditorDocument document = diskDocument
        if (document == null) { return }
        if (writeDocument(document, document.path)) { clearDiskPrompt() }
    }

void Cedit.closeDiskDocument() {
        EditorDocument document = diskDocument
        clearDiskPrompt()
        if (document != null) { removeDocument(document) }
    }

void Cedit.reloadCurrent() {
        if (diskDocument != null) { return }
        if (commandsBlocked()) { return }
        EditorDocument document = currentDocument()
        if (document == null || document.path.equals("")) {
            status.setText("No file to reload")
            return
        }
        String disk = readDiskFile(document.path)
        if (document.view.modified() || diskMissing || !disk.equals(document.diskText)) {
            diskDocument = document
            diskChoices.setVisible(true)
            status.setText(format("{} changed on disk. Reload, Save, or Close", document.tabTitle()))
            updateMenu()
            return
        }
        status.setText("Already current")
    }

void Cedit.closeDocument(EditorDocument document) {
        if (commandsBlocked()) { return }
        if (document == null) {
            return
        }
        if (document.view.modified()) {
            pendingCloseDocument = document
            pendingCloseAll = false
            closeChoices.setVisible(true)
            status.setText(format("Unsaved changes in {}: Save, Discard, or Cancel",
                                  document.tabTitle()))
            updateMenu()
            return
        }
        removeDocument(document)
    }

void Cedit.removeDocument(EditorDocument document) {
        int64 index = 0
        while (index < documents.length) {
            if ((documents[index] as EditorDocument) == document) {
                if (client != null) { client.sendClose(document.path) }
                changingDocuments = true
                notebook.remove(document.scroller)
                document.scroller.dispose()
                list remaining = []
                int64 itemIndex = 0
                while (itemIndex < documents.length) {
                    EditorDocument item = documents[itemIndex] as EditorDocument
                    if (item != document) {
                        remaining.append(item)
                    }
                    itemIndex = itemIndex + 1
                }
                documents = remaining
                focusedDocument = currentDocument()
                changingDocuments = false
                if (hasAutomaticSaveErrors) {
                    hasAutomaticSaveErrors = recomputeAutomaticSaveErrors()
                }
                if (pendingCloseDocument == document) {
                    pendingCloseDocument = null
                }
                if (!pendingCloseAll) {
                    closeChoices.setVisible(false)
                }
                if (documents.length == 0 && !pendingCloseAll && !closingAll) {
                    newDocument()
                } else {
                    updateStatus()
                    EditorDocument next = currentDocument()
                    if (next != null && !pendingCloseAll) {
                        next.view.focus()
                    }
                }
                // The closing shortcut's controller must unwind before restoring focus.
                if (!pendingCloseAll && !closingAll) { Gtk.Application().post(_self().focusAfterClose) }
                return
            }
            index = index + 1
        }
    }

void Cedit.focusAfterClose() {
        if (window.disposed() || commandsBlocked() || searchDialogOpen) { return }
        EditorDocument document = currentDocument()
        if (document != null) { document.view.focus() }
    }

EditorDocument Cedit.firstModifiedDocument() {
        int64 index = 0
        while (index < documents.length) {
            EditorDocument document = documents[index] as EditorDocument
            if (document.view.modified()) {
                return(document)
            }
            index = index + 1
        }
        return(null)
    }

void Cedit.savePendingClose() {
        if (fileDialog != null) { return }
        EditorDocument document = pendingCloseDocument
        if (pendingCloseAll) {
            document = firstModifiedDocument()
        }
        if (document == null) {
            finishPendingClose()
            return
        }
        activateDocument(document)
        String destination = document.path
        if (destination.equals("")) {
            chooseSave(document, true)
            return
        }
        if (!writeDocument(document, destination)) {
            return
        }
        continueSavedClose()
    }

void Cedit.continueSavedClose() {
        if (closingAll) {
            pendingCloseDocument = null
            closeNextInBatch()
            return
        }
        if (!pendingCloseAll) {
            finishPendingClose()
            return
        }
        if (firstModifiedDocument() == null) {
            finishPendingClose()
        } else {
            status.setText("Saved. Save or discard the remaining modified tabs")
        }
    }

void Cedit.discardPendingClose() {
        if (closingAll) {
            EditorDocument document = pendingCloseDocument
            if (document == null) { document = firstModifiedDocument() }
            pendingCloseDocument = null
            if (document != null) { removeDocument(document) }
            closeNextInBatch()
            return
        }
        if (pendingCloseAll && !switchOp.equals("")) {
            pendingCloseAll = false
            closeChoices.setVisible(false)
            continueSwitch(switchOp)
            return
        }
        if (pendingCloseAll) {
            window.setVisible(false)
            closeAllDocuments()
            pendingCloseAll = false
            pendingCloseDocument = null
            closeChoices.setVisible(false)
            allowWindowClose = true
            window.close()
            return
        }
        EditorDocument document = pendingCloseDocument
        if (document != null) {
            removeDocument(document)
        }
        pendingCloseDocument = null
        closeChoices.setVisible(false)
    }

void Cedit.cancelPendingClose() {
        if (!switchOp.equals("")) {
            switchOp = ""
            nextProject = null
            status.setText("Cancelled opening the project")
        }
        pendingCloseDocument = null
        pendingCloseAll = false
        closingAll = false
        closeChoices.setVisible(false)
        updateStatus()
    }

void Cedit.finishPendingClose() {
        if (pendingCloseAll && !switchOp.equals("")) {
            pendingCloseAll = false
            closeChoices.setVisible(false)
            continueSwitch(switchOp)
            return
        }
        if (pendingCloseAll) {
            pendingCloseAll = false
            pendingCloseDocument = null
            closeChoices.setVisible(false)
            allowWindowClose = true
            window.close()
            return
        }
        EditorDocument document = pendingCloseDocument
        pendingCloseDocument = null
        closeChoices.setVisible(false)
        if (document != null) {
            removeDocument(document)
        }
    }

