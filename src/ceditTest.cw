void Cedit.test() {
        EditorDocument document = currentDocument()
        openFile("/path/that/does/not/exist/test.cw")
        bool badOpen = status.text().contains("Open failed") && documents.length == 2
        openFile(System.FileSystem().tempDir())
        bool directoryRejected = status.text().contains("not a regular file") && documents.length == 2
        document.view.setText("class Demo {\n  // note\n  String name = \"Cwhip\"\n  int64 count = 12\n}\n")
        bool tabs = documents.length == 2 && notebook.pageCount() == 2 && recentFiles.length == 2
        bool tabSwitchUpdatesStatus = pageChanges > 0
        bool remapped = false
        bool defaults = false
        if (System.FileSystem().exists("cwhip-shortcuts.conf")) {
            remapped = document.view.hasShortcut("<Control><Alt>s") && !document.view.hasShortcut("<Control>s")
        } else {
            defaults = document.view.hasShortcut("<Control>s") && document.view.hasShortcut("<Control>o")
        }
        bool conflicted = document.shortcutConflict
        bool plainText = GtkSource.Content().languageFor("notes.txt").equals("") && document.view.language().equals("cwhip")
        bool highlighted = plainText && document.view.hasContextAt("keyword", 0) && document.view.hasContextAt("comment", 17) && document.view.hasContextAt("string", 39) && document.view.hasContextAt("number", 64)
        bool searched = document.view.find("Cwhip")
        bool replaced = document.view.replaceNext("Cwhip", "Cwhip language")
        bool dirtyBlocked = requestClose()
        window.close()
        bool dirtyCloseCancelled = !window.disposed()
        cancelPendingClose()
        closeCurrentDocument()
        cancelPendingClose()
        bool tabCloseCancelled = documents.length == 2 && document.view.modified()
        document.view.undo()
        bool undoRestored = document.view.text().contains("name = \"Cwhip\"") && !document.view.text().contains("Cwhip language")
        document.view.redo()
        bool undoRedo = document.view.text().contains("Cwhip language")
        closeCurrentDocument()
        savePendingClose()
        bool saved = false
        System.File savedFile = null
        try {
            savedFile = System.File(document.path, "r")
            if (savedFile.isOpen()) {
                String savedContents = savedFile.readAll()
                saved = savedContents.contains("String name = \"Cwhip language\"")
                savedFile.close()
            }
        } except(Exception) {
            saved = false
        }
        bool savedTabClosed = documents.length == 1 && notebook.pageCount() == 1
        bool closeProtected = !requestClose()
        newDocument()
        EditorDocument discarded = currentDocument()
        discarded.view.setText("discard this")
        closeCurrentDocument()
        discardPendingClose()
        bool tabDiscarded = documents.length == 1 && notebook.pageCount() == 1
        EditorDocument remaining = currentDocument()
        remaining.view.setText("discard all")
        bool windowClosePrompted = requestClose()
        cancelPendingClose()
        bool windowCloseCancelled = !window.disposed() && documents.length == 1
        remaining.view.setText("discard all")
        bool windowClosePromptedAgain = requestClose()
        discardPendingClose()
        bool windowDiscarded = windowClosePrompted && windowClosePromptedAgain && window.disposed()
        print(badOpen && directoryRejected && tabs && tabSwitchUpdatesStatus &&
              (remapped || defaults) && conflicted == remapped && highlighted &&
              searched && replaced && undoRestored && undoRedo && dirtyBlocked &&
              dirtyCloseCancelled && tabCloseCancelled && saved && savedTabClosed &&
              closeProtected && tabDiscarded && windowCloseCancelled && windowDiscarded)
    }

int64 Cedit.byteSpanBound(int64 value, int64 length) {
        int64 index = value
        if (index < 0) { index = index + length }
        if (index < 0) { return(0) }
        if (index > length) { return(length) }
        return(index)
    }

String Cedit.byteSpan(String text, int64 first, int64 last) {
        int64 lower = byteSpanBound(first, text.length)
        int64 end = byteSpanBound(last, text.length)
        if (end <= lower) { return("") }
        return(text[lower..(end - 1)])
    }

