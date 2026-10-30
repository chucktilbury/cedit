class EditorDocument {
    EditorDocument _self()
    void<EditorDocument> closeAction
    GtkSource.View view
    Gtk.ScrolledWindow scroller
    String path
    String baseName
    list shortcuts
    bool shortcutConflict
    int64 shortcutRevision
    String automaticSaveError
    String lastTitle
    String diskText
    int64 lspVersion

    EditorDocument(String filePath, String contents) {
        path = filePath
        baseName = ""
        if (!path.equals("")) {
            baseName = System.FileSystem().basename(path)
        }
        shortcuts = []
        shortcutConflict = false
        automaticSaveError = ""
        lastTitle = ""
        diskText = contents
        lspVersion = 1
        view = GtkSource.View()
        view.setMonospace(true)
        view.setEmojiMenu(false)
        view.setLanguage(GtkSource.Content().languageFor(filePath))
        view.setText(contents)
        view.markSaved()
        scroller = Gtk.ScrolledWindow()
        // Keep the vertical scrollbar allocated so GTK4 does not warn about
        // snapshotting a scrollbar GtkGizmo when content first becomes scrollable.
        scroller.setPolicy(Gtk.ScrolledWindow.POLICY_AUTOMATIC, Gtk.ScrolledWindow.POLICY_ALWAYS)
        scroller.setHExpand(true)
        scroller.setVExpand(true)
        view.widget().setHExpand(true)
        view.widget().setVExpand(true)
        scroller.setChild(view.widget())
    }

    void updatePath(String newPath) {
        path = newPath
        if (!path.equals("")) {
            baseName = System.FileSystem().basename(path)
        } else {
            baseName = ""
        }
    }

    String tabTitle() {
        String title = "Untitled"
        if (!baseName.equals("")) {
            title = baseName
        }
        if (view.modified()) {
            title.append("*")
        }
        return(title)
    }
    bool stripTrailingSpaces() { return(view.stripTrailingSpaces()) }
    void close() { closeAction(_self()) }
}
EditorDocument EditorDocument._self() from "cwhip_gtk_self"
