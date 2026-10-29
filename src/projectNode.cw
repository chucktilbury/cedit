class ProjectNode {
    ProjectNode _self()
    ProjectExplorer explorer
    Gtk.DirectoryScan scan
    int64 id
    int64 generation
    int64 kind
    String path
    bool started
    bool populated
    bool complete
    String error

    ProjectNode(ProjectExplorer owner, int64 row, String filePath, int64 entryKind) {
        explorer = owner
        path = filePath
        kind = entryKind
        generation = owner.generation
        id = row
        error = ""
    }

    void load() {
        if (kind != 1 || started) { return }
        started = true
        explorer.addMessage(id, "Loading...", "content-loading-symbolic")
        scan = Gtk.DirectoryScan(explorer.tree, path, explorer.hidden.active(), explorer.rootPath,
            explorer.excludes, _self().received)
    }

    void received(int64 count, String message) {
        if (generation != explorer.generation || explorer.tree.disposed()) { return }
        if (!populated) {
            populated = true
            explorer.tree.clear(id)
        }
        if (count == -1) {
            complete = true
            scan = null
            error = message
            explorer.showExternal()
            if (!error.equals("")) {
                explorer.addMessage(id, format("Could not read directory: {}", error), "dialog-error-symbolic")
            } else {
                if (explorer.tree.childCount(id) == 0) {
                    explorer.addMessage(id, "(Empty folder)", "folder-symbolic")
                }
                explorer.restoreChildren(path)
            }
            return
        }
        scan.append(explorer.tree, id, explorer.nextId + 1, count, explorer.icons)
        explorer.nextId = explorer.nextId + count
        explorer.showExternal()
    }
}
ProjectNode ProjectNode._self() from "cwhip_gtk_self"
