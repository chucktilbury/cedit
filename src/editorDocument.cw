/*
 * src/editorDocument.cw - One open editor tab (view, path, disk text).
 *
 * Created: 2026-10-29
 * Author: Auto
 *
 * Changelog:
 *   2026-10-29  Initial file.
 *   2026-11-13  CODING headers and method comments.
 */

/*
 * EditorDocument for cedit; see method comments below.
 */
class EditorDocument {
    /*
     * _self
     *
     * Purpose: _self.
     *
     * Parameters:
     *   filePath.
     *   contents.
     *
     * Returns: EditorDocument.
     */

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

    /*
     * EditorDocument
     *
     * Purpose: EditorDocument for the editor.
     *
     * Parameters:
     *   filePath.
     *   contents.
     *
     * Returns: EditorDocument.
     */

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
        // Automatic policy: GTK #6057 (adjustment updates during TextView
        // snapshot) is worse with POLICY_ALWAYS; cwhip filters that warning.
        scroller.setHExpand(true)
        scroller.setVExpand(true)
        view.widget().setHExpand(true)
        view.widget().setVExpand(true)
        scroller.setChild(view.widget())
    }

    /*
     * updatePath
     *
     * Purpose: updatePath for the editor.
     *
     * Parameters:
     *   newPath.
     *
     * Returns: nothing.
     */

    void updatePath(String newPath) {
        path = newPath
        if (!path.equals("")) {
            baseName = System.FileSystem().basename(path)
        } else {
            baseName = ""
        }
    }

    /*
     * tabTitle
     *
     * Purpose: Update the notebook page title when the document tab title changed.
     *
     * Parameters:
     *   none.
     *
     * Returns: String.
     */

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
    /*
     * stripTrailingSpaces
     *
     * Purpose: stripTrailingSpaces for the editor.
     *
     * Parameters:
     *   none.
     *
     * Returns: bool.
     */

    bool stripTrailingSpaces() { return(view.stripTrailingSpaces()) }
    /*
     * close
     *
     * Purpose: close for the editor.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */

    void close() { closeAction(_self()) }
}
EditorDocument EditorDocument._self() from "cwhip_gtk_self"
