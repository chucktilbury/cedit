/*
 * src/projectNode.cw - One tree row that may scan a directory.
 *
 * Created: 2026-10-29
 * Author: Auto
 *
 * Changelog:
 *   2026-10-29  Initial file.
 *   2026-11-13  CODING headers and method comments.
 */

/*
 * ProjectNode for cedit; see method comments below.
 */
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

    /*
     * ProjectNode
     *
     * Purpose: ProjectNode for the editor.
     *
     * Parameters:
     *   owner.
     *   row.
     *   filePath.
     *   entryKind.
     *
     * Returns: ProjectNode.
     */

    ProjectNode(ProjectExplorer owner, int64 row, String filePath, int64 entryKind) {
        explorer = owner
        path = filePath
        kind = entryKind
        generation = owner.generation
        id = row
        error = ""
    }

    /*
     * load
     *
     * Purpose: load for the editor.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */

    void load() {
        if (kind != 1 || started) { return }
        started = true
        explorer.addMessage(id, "Loading...", "content-loading-symbolic")
        scan = Gtk.DirectoryScan(explorer.tree, path, explorer.hidden.active(), explorer.rootPath,
            explorer.excludes, _self().received)
    }

    /*
     * received
     *
     * Purpose: received for the editor.
     *
     * Parameters:
     *   count.
     *   message.
     *
     * Returns: nothing.
     */

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
