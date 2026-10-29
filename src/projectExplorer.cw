class ProjectExplorer {
    ProjectExplorer _self()
    Gtk.Box sidebar
    Gtk.Tree tree
    Gtk.Label title
    Gtk.CheckButton hidden
    Gtk.Button refreshButton
    Gtk.ContextMenu contextMenu
    Gtk.CheckButton contextHidden
    Gtk.Button contextRefresh
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
        // Refresh and hidden-file toggles live in the tree context menu; these
        // unparented widgets keep the shared state and callbacks.
        hidden = Gtk.CheckButton("Show Hidden Files")
        hidden.onToggled(_self().hiddenChanged)
        tree = Gtk.Tree(_self().expand, _self().activateFile)
        tree.setSingleClickActivate(true)
        contextMenu = Gtk.ContextMenu(tree)
        Gtk.Box actions = Gtk.Box(Gtk.Box.VERTICAL, 4)
        contextRefresh = Gtk.Button("Refresh")
        contextRefresh.setSensitive(false)
        contextRefresh.onClicked(_self().refresh)
        contextHidden = Gtk.CheckButton("Show Hidden")
        contextHidden.onToggled(_self().contextHiddenChanged)
        actions.append(contextRefresh)
        actions.append(contextHidden)
        contextMenu.setChild(actions)
        tree.setHExpand(true)
        tree.setVExpand(true)
        Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
        scroll.setHExpand(true)
        scroll.setVExpand(true)
        scroll.setChild(tree)
        sidebar.append(scroll)
        addMessage(0, "Use File > Open Folder...", "folder-open-symbolic")
    }

    void addMessage(int64 parent, String text, String image) {
        nextId = nextId + 1
        tree.add(parent, nextId, text, image, false, "", -1)
    }

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

    void setRoot(String path) { setProject(path, "Project Explorer", "", []) }

    // expandedPaths are absolute directories re-expanded as their parents load.
    void setProject(String path, String label, String patterns, list expandedPaths) {
        rootPath = path
        excludes = patterns
        externalFiles = []
        title.setText(label)
        refreshButton.setSensitive(true)
        contextRefresh.setSensitive(true)
        rebuild(expandedPaths)
    }

    bool inRoot(String path) {
        if (rootPath.equals("") || !path.startsWith("/")) { return(false) }
        String head = rootPath
        if (!head.endsWith("/")) { head = format("{}/", head) }
        return(path.startsWith(head))
    }

    // Remember a file that lives outside the project root and show it in the tree.
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

    void refresh() {
        if (rootPath.equals("") || tree.disposed()) { return }
        rebuild(expandedPaths())
    }

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

    void hiddenChanged(bool value) {
        if (syncingHidden) { return }
        syncingHidden = true
        contextHidden.setActive(value)
        syncingHidden = false
        refresh()
    }
    void contextHiddenChanged(bool value) {
        if (syncingHidden) { return }
        hidden.setActive(value)
    }

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

    void activateFile(int64 id) {
        int64 kind = tree.data(id)
        if (kind >= 0 && kind != 1) { open(tree.value(id)) }
    }
}
ProjectExplorer ProjectExplorer._self() from "cwhip_gtk_self"
