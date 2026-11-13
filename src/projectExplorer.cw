/*
 * src/projectExplorer.cw — project folder tree sidebar.
 *
 * Created: 2026-10-29
 * Author: Auto
 *
 * Changelog:
 *   2026-10-29  Initial file.
 *   2026-11-13  CODING headers and method comments.
 */

/*
 * ProjectExplorer owns the sidebar tree, show-hidden state, pending
 * expand restores, and open-file callback for activated leaves.
 */
class ProjectExplorer {
    ProjectExplorer _self()
    Gtk.Box sidebar
    Gtk.Tree tree
    Gtk.Label title
    Gtk.CheckButton hidden
    Gtk.Button refreshButton
    Gtk.ContextMenu contextMenu
    int64 contextRefresh
    int64 contextHidden
    bool syncingHidden
    String excludes
    list pending
    list nodes
    list externalFiles
    int64 nextId
    int64 generation
    String rootPath
    String icons
    void<String> open

    /*
     * Build the empty project explorer sidebar.
     *
     * Purpose: create tree, context menu, unparented Show Hidden check, and a placeholder message until a folder is opened.
     *
     * Parameters:
     *   openFile — callback invoked with a path when a file activates.
     *
     * Returns: ProjectExplorer with sidebar ready to pack.
     */
    ProjectExplorer(void<String> openFile) {
        open = openFile
        nodes = []
        externalFiles = []
        rootPath = ""
        excludes = ""
        pending = []
        icons = "0=text-x-generic-symbolic\n1=folder-symbolic\n2=emblem-symbolic-link-symbolic\n3=dialog-warning-symbolic\n.cw=text-x-script-symbolic\n.c=text-x-script-symbolic\n.h=text-x-script-symbolic\n.py=text-x-script-symbolic\n.png=image-x-generic-symbolic\n.jpg=image-x-generic-symbolic\n.svg=image-x-generic-symbolic"
        sidebar = Gtk.Box(Gtk.Box.VERTICAL, 4)
        sidebar.setVExpand(true)
        title = Gtk.Label("Project Explorer")
        sidebar.append(title)
        refreshButton = Gtk.Button("Refresh")
        refreshButton.setSensitive(false)
        refreshButton.onClicked(_self().refresh)
        // Refresh and hidden-file toggles live in the tree context menu; this
        // unparented check button keeps the shared Show Hidden state.
        hidden = Gtk.CheckButton("Show Hidden Files")
        hidden.onToggled(_self().hiddenChanged)
        tree = Gtk.Tree(_self().expand, _self().activateFile)
        tree.setSingleClickActivate(true)
        contextMenu = Gtk.ContextMenu(tree)
        contextRefresh = contextMenu.addItem("Refresh", _self().refresh)
        contextMenu.setItemEnabled(contextRefresh, false)
        contextHidden = contextMenu.addCheckItem("Show Hidden", false, _self().contextHiddenChanged)
        tree.setHExpand(true)
        tree.setVExpand(true)
        Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
        scroll.setHExpand(true)
        scroll.setVExpand(true)
        scroll.setChild(tree)
        sidebar.append(scroll)
        addMessage(0, "Use File > Open Folder...", "folder-open-symbolic")
    }

    /*
     * Append a non-file message row under a parent.
     *
     * Purpose: allocate nextId and tree.add a leaf message.
     *
     * Parameters:
     *   parent — parent tree row id (0 for root).
     *   text — message label.
     *   image — icon name.
     *
     * Returns: nothing.
     */
    void addMessage(int64 parent, String text, String image) {
        nextId = nextId + 1
        tree.add(parent, nextId, text, image, false, "", -1)
    }

    /*
     * Cancel in-flight directory scans and bump generation.
     *
     * Purpose: invalidate stale ProjectNode scans before rebuild.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */
    void cancelLoads() {
        generation = generation + 1
        int64 i = 0
        while (i < nodes.length) {
            ProjectNode node = nodes[i] as ProjectNode
            if (node.scan != null) {
                node.scan.cancel()
                node.scan = null
            }
            i = i + 1
        }
    }

    /*
     * Open a project root with default label and no excludes.
     *
     * Purpose: delegate to setProject with empty patterns/expands.
     *
     * Parameters:
     *   path — absolute project root directory.
     *
     * Returns: nothing.
     */
    void setRoot(String path) { setProject(path, "Project Explorer", "", []) }

    // expandedPaths are absolute directories re-expanded as their parents load.
    /*
     * Bind the explorer to a project root and rebuild the tree.
     *
     * Purpose: store root/excludes; enable refresh; rebuild with expandedPaths restored as parents load.
     *
     * Parameters:
     *   path — absolute project root.
     *   label — sidebar title text.
     *   patterns — exclude patterns string.
     *   expandedPaths — absolute directories to re-expand.
     *
     * Returns: nothing.
     */
    void setProject(String path, String label, String patterns, list expandedPaths) {
        rootPath = path
        excludes = patterns
        externalFiles = []
        title.setText(label)
        refreshButton.setSensitive(true)
        contextMenu.setItemEnabled(contextRefresh, true)
        rebuild(expandedPaths)
    }

    /*
     * Whether a path lives under the current project root.
     *
     * Purpose: require absolute path; compare against root with a trailing slash.
     *
     * Parameters:
     *   path — filesystem path to test.
     *
     * Returns: true if path is under rootPath.
     */
    bool inRoot(String path) {
        if (rootPath.equals("") || !path.startsWith("/")) { return(false) }
        String head = rootPath
        if (!head.endsWith("/")) { head = format("{}/", head) }
        return(path.startsWith(head))
    }

    // Remember a file that lives outside the project root and show it in the tree.
    /*
     * Remember a file outside the project root and show it.
     *
     * Purpose: append unique absolute paths to externalFiles, then showExternal.
     *
     * Parameters:
     *   path — absolute file path outside the root.
     *
     * Returns: nothing.
     */
    void noteFile(String path) {
        if (rootPath.equals("") || tree.disposed() || !path.startsWith("/")) { return }
        if (inRoot(path)) { return }
        int64 i = 0
        bool found = false
        while (i < externalFiles.length) {
            if ((externalFiles[i] as String).equals(path)) { found = true }
            i = i + 1
        }
        if (!found) { externalFiles.append(path) }
        showExternal()
    }

    /*
     * Ensure external file rows exist under the project root row.
     *
     * Purpose: add missing externalFiles as leaves on the root node.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */
    void showExternal() {
        if (rootPath.equals("") || tree.disposed()) { return }
        int64 parent = tree.findValue(rootPath)
        if (parent == 0) { return }
        int64 i = 0
        while (i < externalFiles.length) {
            String path = externalFiles[i] as String
            if (tree.findValue(path) == 0) {
                nextId = nextId + 1
                tree.add(parent, nextId, path, "text-x-generic-symbolic", false, path, 0)
            }
            i = i + 1
        }
    }

    /*
     * Expand pending children whose parent directory just loaded.
     *
     * Purpose: move matching pending paths to ready and expand folder rows.
     *
     * Parameters:
     *   parent — absolute directory path that finished loading.
     *
     * Returns: nothing.
     */
    void restoreChildren(String parent) {
        list ready = []
        list remaining = []
        int64 i = 0
        while (i < pending.length) {
            String path = pending[i] as String
            if (System.FileSystem().dirname(path).equals(parent)) { ready.append(path) } else { remaining.append(path) }
            i = i + 1
        }
        pending = remaining
        i = 0
        while (i < ready.length) {
            int64 id = tree.findValue(ready[i] as String)
            if (id > 1 && tree.data(id) == 1) { tree.setExpanded(id, true) }
            i = i + 1
        }
    }

    // Expanded directories (absolute), including restores still waiting for a parent scan.
    /*
     * Collect expanded directory paths, including pending restores.
     *
     * Purpose: snapshot currently expanded folders plus pending paths still waiting for a parent scan.
     *
     * Parameters:
     *   none.
     *
     * Returns: list of absolute directory paths.
     */
    list expandedPaths() {
        list result = []
        if (rootPath.equals("") || tree.disposed()) { return(result) }
        int64 i = 0
        while (i < nodes.length) {
            ProjectNode node = nodes[i] as ProjectNode
            if (node.id != 1 && tree.expanded(node.id)) { result.append(node.path) }
            i = i + 1
        }
        i = 0
        while (i < pending.length) {
            result.append(pending[i] as String)
            i = i + 1
        }
        return(result)
    }

    /*
     * Rebuild the tree preserving expanded folders.
     *
     * Purpose: no-op without a root; else rebuild(expandedPaths()).
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */
    void refresh() {
        if (rootPath.equals("") || tree.disposed()) { return }
        rebuild(expandedPaths())
    }

    /*
     * React to a saved file path for tree freshness.
     *
     * Purpose: note external files; if under root and missing from the tree, bump generation and refresh.
     *
     * Parameters:
     *   path — absolute saved file path.
     *
     * Returns: nothing.
     */
    void fileSaved(String path) {
        if (rootPath.equals("") || tree.disposed()) { return }
        if (!inRoot(path)) {
            noteFile(path)
            return
        }
        generation = generation + 1
        int64 id = tree.findValue(path)
        if (id > 0) { return }
        refresh()
    }

    /*
     * Clear and recreate the tree for the current root.
     *
     * Purpose: cancelLoads; add root folder row expanded; show external files; keep expanded list as pending.
     *
     * Parameters:
     *   expanded — absolute directories to restore after scans.
     *
     * Returns: nothing.
     */
    void rebuild(list expanded) {
        cancelLoads()
        tree.clear(0)
        nodes = []
        nextId = 1
        pending = expanded
        tree.add(0, 1, rootPath, "folder-open-symbolic", true, rootPath, 1)
        tree.setExpanded(1, true)
        showExternal()
    }

    /*
     * Sync Show Hidden from the unparented check button.
     *
     * Purpose: mirror into the context menu check and refresh.
     *
     * Parameters:
     *   value — new hidden visibility.
     *
     * Returns: nothing.
     */
    void hiddenChanged(bool value) {
        if (syncingHidden) { return }
        syncingHidden = true
        contextMenu.setItemChecked(contextHidden, value)
        syncingHidden = false
        refresh()
    }
    /*
     * Sync Show Hidden from the context menu into the check button.
     *
     * Purpose: set hidden.active without re-entering sync.
     *
     * Parameters:
     *   value — new hidden visibility.
     *
     * Returns: nothing.
     */
    void contextHiddenChanged(bool value) {
        if (syncingHidden) { return }
        hidden.setActive(value)
    }

    /*
     * Lazy-load a folder row when the user expands it.
     *
     * Purpose: skip if a ProjectNode already exists; for folders, create ProjectNode and load().
     *
     * Parameters:
     *   id — tree row id being expanded.
     *
     * Returns: nothing.
     */
    void expand(int64 id) {
        int64 i = 0
        while (i < nodes.length) {
            if ((nodes[i] as ProjectNode).id == id) { return }
            i = i + 1
        }
        if (tree.data(id) == 1) {
            ProjectNode node = ProjectNode(_self(), id, tree.value(id), 1)
            nodes.append(node)
            node.load()
        }
    }

    /*
     * Open a file when a non-folder tree row is activated.
     *
     * Purpose: call open(value) for kinds other than directory (1).
     *
     * Parameters:
     *   id — activated tree row id.
     *
     * Returns: nothing.
     */
    void activateFile(int64 id) {
        int64 kind = tree.data(id)
        if (kind >= 0 && kind != 1) { open(tree.value(id)) }
    }
}
ProjectExplorer ProjectExplorer._self() from "cwhip_gtk_self"
