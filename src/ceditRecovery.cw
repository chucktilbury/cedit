String Cedit.recoveryDir() {
        if (activeProject == null) { return("") }
        return(System.FileSystem().join(activeProject.root, ".cedit/recovery"))
    }

String Cedit.recoveryPathFor(String documentPath) {
        String dir = recoveryDir()
        if (dir.equals("") || documentPath.equals("")) { return("") }
        String name = documentPath.replace("/", "_")
        name = name.replace("\\", "_")
        if (name.length > 180) { name = byteSpan(name, name.length - 180, name.length) }
        return(System.FileSystem().join(dir, format("{}.txt", name)))
    }

void Cedit.ensureRecoveryDir() {
        String dir = recoveryDir()
        if (dir.equals("")) { return }
        String parent = System.FileSystem().dirname(dir)
        if (!System.FileSystem().isDir(parent)) { System.FileSystem().mkdir(parent) }
        if (!System.FileSystem().isDir(dir)) { System.FileSystem().mkdir(dir) }
    }

void Cedit.writeRecovery(EditorDocument document) {
        if (document == null || document.path.equals("") || !document.view.modified()) { return }
        String path = recoveryPathFor(document.path)
        if (path.equals("")) { return }
        ensureRecoveryDir()
        String payload = format("# cedit-recovery: {}\n{}", document.path, document.view.text())
        try {
            System.File file = System.File(path, "w")
            file.write(payload)
            file.close()
        } except(Exception) {
        }
    }

void Cedit.clearRecovery(EditorDocument document) {
        if (document == null || document.path.equals("")) { return }
        String path = recoveryPathFor(document.path)
        if (path.equals("")) { return }
        if (System.FileSystem().isFile(path)) {
            try {
                System.FileSystem().remove(path)
            } except(Exception) {
            }
        }
    }

void Cedit.writeAllRecoveries() {
        int64 i = 0
        while (i < documents.length) {
            writeRecovery(documents[i] as EditorDocument)
            i = i + 1
        }
    }

void Cedit.scheduleRecoveryPoll() {
        if (!presented || window == null || window.disposed()) { return }
        Gtk.Application().schedule(15000, recoveryPollAction)
    }

void Cedit.recoveryPoll() {
        if (!presented || window == null || window.disposed()) { return }
        writeAllRecoveries()
        scheduleRecoveryPoll()
    }

String Cedit.readRecoveryBody(String recoveryFile, String expectedPath) {
        try {
            System.File file = System.File(recoveryFile, "r")
            String data = file.readAll()
            file.close()
            String marker = "# cedit-recovery: "
            if (!data.startsWith(marker)) { return("") }
            int64 nl = data.find("\n")
            if (nl < 0) { return("") }
            String headerPath = byteSpan(data, marker.length, nl)
            if (!headerPath.equals(expectedPath)) { return("") }
            return(byteSpan(data, nl + 1, data.length))
        } except(Exception) {
            return("")
        }
    }

void Cedit.offerRecoveryForDocuments() {
        if (activeProject == null) { return }
        int64 i = 0
        while (i < documents.length) {
            EditorDocument document = documents[i] as EditorDocument
            if (!document.path.equals("")) {
                String recovery = recoveryPathFor(document.path)
                if (System.FileSystem().isFile(recovery)) {
                    String body = readRecoveryBody(recovery, document.path)
                    if (!body.equals("") && !body.equals(document.diskText)) {
                        pendingRecoveryDocument = document
                        pendingRecoveryText = body
                        askConfirm("recover-buffer",
                            format("Recover unsaved edits for {}?", document.tabTitle()),
                            "Restore")
                        return
                    }
                    clearRecovery(document)
                }
            }
            i = i + 1
        }
    }

void Cedit.acceptRecovery() {
        if (pendingRecoveryDocument == null) { return }
        EditorDocument document = pendingRecoveryDocument
        document.view.setText(pendingRecoveryText)
        // Leave modified so Save is required; do not overwrite disk.
        pendingRecoveryDocument = null
        pendingRecoveryText = ""
        activateDocument(document)
        updateUnsavedMarks(document)
        refreshTab(document)
        status.setText("Restored unsaved buffer; save to keep changes")
        offerRecoveryForDocuments()
    }

void Cedit.discardRecovery() {
        if (pendingRecoveryDocument != null) {
            clearRecovery(pendingRecoveryDocument)
            pendingRecoveryDocument = null
            pendingRecoveryText = ""
        }
        offerRecoveryForDocuments()
    }
