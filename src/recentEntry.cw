class RecentEntry {
    RecentEntry _self()
    Cedit editor
    String path
    Gtk.Button button

    RecentEntry(Cedit owner, String filePath) {
        editor = owner
        path = filePath
        button = Gtk.Button(filePath)
        button.onClicked(_self().choose)
    }

    void choose() {
        editor.openRecentPath(path)
    }
}
RecentEntry RecentEntry._self() from "cwhip_gtk_self"
