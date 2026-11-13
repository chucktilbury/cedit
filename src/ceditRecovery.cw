/*
 * src/ceditRecovery.cw - Dirty-buffer snapshots under .cedit/recovery.
 *
 * Created: 2026-10-30
 * Author: Auto
 *
 * Changelog:
 *   2026-10-30  Initial file.
 *   2026-11-13  CODING headers and method comments.
 */

/*
 * Cedit.recoveryDir
 *
 * Purpose: recoveryDir.
 *
 * Parameters:
 *   none.
 *
 * Returns: String.
 */

String Cedit.recoveryDir() {
        if (activeProject == null) { return("") }
        return(System.FileSystem().join(activeProject.root, ".cedit/recovery"))
    }

/*
 * Cedit.recoveryPathFor
 *
 * Purpose: recoveryPathFor.
 *
 * Parameters:
 *   documentPath.
 *
 * Returns: String.
 */

String Cedit.recoveryPathFor(String documentPath) {
        String dir = recoveryDir()
        if (dir.equals("") || documentPath.equals("")) { return("") }
        String name = documentPath.replace("/", "_")
        name = name.replace("\\", "_")
        if (name.length > 180) { name = byteSpan(name, name.length - 180, name.length) }
        return(System.FileSystem().join(dir, format("{}.txt", name)))
    }

/*
 * Cedit.ensureRecoveryDir
 *
 * Purpose: ensureRecoveryDir.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.ensureRecoveryDir() {
        String dir = recoveryDir()
        if (dir.equals("")) { return }
        String parent = System.FileSystem().dirname(dir)
        if (!System.FileSystem().isDir(parent)) { System.FileSystem().mkdir(parent) }
        if (!System.FileSystem().isDir(dir)) { System.FileSystem().mkdir(dir) }
    }

/*
 * Cedit.writeRecovery
 *
 * Purpose: writeRecovery.
 *
 * Parameters:
 *   document.
 *
 * Returns: nothing.
 */

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

/*
 * Cedit.clearRecovery
 *
 * Purpose: clearRecovery.
 *
 * Parameters:
 *   document.
 *
 * Returns: nothing.
 */

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

/*
 * Cedit.writeAllRecoveries
 *
 * Purpose: writeAllRecoveries.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.writeAllRecoveries() {
        int64 i = 0
        while (i < documents.length) {
            writeRecovery(documents[i] as EditorDocument)
            i = i + 1
        }
    }

/*
 * Cedit.scheduleRecoveryPoll
 *
 * Purpose: scheduleRecoveryPoll.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.scheduleRecoveryPoll() {
        if (!presented || window == null || window.disposed()) { return }
        Gtk.Application().schedule(15000, recoveryPollAction)
    }

/*
 * Cedit.recoveryPoll
 *
 * Purpose: recoveryPoll.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.recoveryPoll() {
        if (!presented || window == null || window.disposed()) { return }
        writeAllRecoveries()
        scheduleRecoveryPoll()
    }

/*
 * Cedit.readRecoveryBody
 *
 * Purpose: readRecoveryBody.
 *
 * Parameters:
 *   recoveryFile.
 *   expectedPath.
 *
 * Returns: String.
 */

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

/*
 * Cedit.offerRecoveryForDocuments
 *
 * Purpose: offerRecoveryForDocuments.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.offerRecoveryForDocuments() {
        if (activeProject == null) { return }
        if (!confirmOp.equals("")) { return }
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
                        // Use the path basename; tabTitle may already include "*".
                        askConfirm("recover-buffer",
                            format("Recover unsaved edits for {}?", document.baseName),
                            "Restore")
                        return
                    }
                    clearRecovery(document)
                }
            }
            i = i + 1
        }
    }

/*
 * Cedit.acceptRecovery
 *
 * Purpose: acceptRecovery.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.acceptRecovery() {
        if (pendingRecoveryDocument == null) { return }
        EditorDocument document = pendingRecoveryDocument
        String body = pendingRecoveryText
        // Remove the snapshot before re-scanning; otherwise the same prompt returns.
        clearRecovery(document)
        pendingRecoveryDocument = null
        pendingRecoveryText = ""
        document.view.setText(body)
        // Leave modified so Save is required; do not overwrite disk.
        activateDocument(document)
        updateUnsavedMarks(document)
        refreshTab(document)
        status.setText("Restored unsaved buffer; save to keep changes")
        offerRecoveryForDocuments()
    }

/*
 * Cedit.discardRecovery
 *
 * Purpose: discardRecovery.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.discardRecovery() {
        if (pendingRecoveryDocument != null) {
            clearRecovery(pendingRecoveryDocument)
            pendingRecoveryDocument = null
            pendingRecoveryText = ""
            status.setText("Discarded recovery; kept saved file")
        }
        offerRecoveryForDocuments()
    }
