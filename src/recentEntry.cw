class RecentEntry {
    RecentEntry _self()
    Cedit editor
    String path

    RecentEntry(Cedit owner, String filePath) {
        editor = owner
        path = filePath
    }

    void choose() {
        editor.openRecentPath(path)
    }
}
RecentEntry RecentEntry._self() from "cwhip_gtk_self"
