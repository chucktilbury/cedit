void Cedit.createProjectFind() {
        projectFindWindow = Gtk.TransientWindow("Find in Project")
        projectFindWindow.setDefaultSize(640, 420)
        projectFindWindow.setTransientFor(window)
        projectFindWindow.setVisible(false)
        projectFindWindow.onCloseRequest(_self().hideProjectFind)
        Gtk.Box layout = Gtk.Box(Gtk.Box.VERTICAL, 6)
        projectFindWindow.setChild(layout)
        projectFindEntry = Gtk.Entry("")
        layout.append(projectFindEntry)
        Gtk.Box options = Gtk.Box(Gtk.Box.HORIZONTAL, 6)
        layout.append(options)
        projectFindCase = Gtk.CheckButton("Case sensitive")
        projectFindWords = Gtk.CheckButton("Whole words")
        options.append(projectFindCase)
        options.append(projectFindWords)
        Gtk.Button search = Gtk.Button("Find")
        search.onClicked(_self().runProjectFind)
        options.append(search)
        projectFindStatus = Gtk.Label("")
        layout.append(projectFindStatus)
        projectFindResults = GtkSource.View()
        projectFindResults.configure("monospace", 11, 4, true, false, false, true)
        projectFindResults.setEditable(false)
        projectFindResults.setEmojiMenu(false)
        projectFindResults.setLineSelection(true)
        projectFindResults.onLineActivated(_self().projectFindActivated)
        Gtk.ScrolledWindow scroll = Gtk.ScrolledWindow()
        scroll.setVExpand(true)
        scroll.setChild(projectFindResults.widget())
        layout.append(scroll)
        projectFindPaths = []
        projectFindLines = []
    }

void Cedit.showProjectFind() {
        if (commandsBlocked()) { return }
        if (project == null || project.rootPath.equals("")) {
            status.setText("Open a project folder to search")
            return
        }
        if (projectFindWindow == null || projectFindWindow.disposed()) { createProjectFind() }
        projectFindWindow.present()
        projectFindEntry.focus()
    }

bool Cedit.hideProjectFind() {
        if (projectFindWindow != null && !projectFindWindow.disposed()) {
            projectFindWindow.setVisible(false)
        }
        return(true)
    }

bool Cedit.projectFindMatch(String haystack, String needle, bool caseSensitive, bool wholeWords) {
        String text = haystack
        String query = needle
        if (!caseSensitive) {
            text = text.toLower()
            query = query.toLower()
        }
        if (query.equals("")) { return(false) }
        if (!wholeWords) { return(text.contains(query)) }
        int64 at = text.find(query)
        while (at >= 0) {
            bool leftOk = true
            bool rightOk = true
            if (at > 0) {
                int64 b = text[at - 1]
                if ((b >= 48 && b <= 57) || (b >= 65 && b <= 90) || (b >= 97 && b <= 122) || b == 95) {
                    leftOk = false
                }
            }
            int64 after = at + query.length
            if (after < text.length) {
                int64 b = text[after]
                if ((b >= 48 && b <= 57) || (b >= 65 && b <= 90) || (b >= 97 && b <= 122) || b == 95) {
                    rightOk = false
                }
            }
            if (leftOk) {
                if (rightOk) { return(true) }
            }
            String rest = byteSpan(text, at + 1, text.length)
            int64 next = rest.find(query)
            if (next < 0) { return(false) }
            at = at + 1 + next
        }
        return(false)
    }

void Cedit.appendProjectFindHit(String path, int64 line, String snippet) {
        if (projectFindPaths.length >= 500) { return }
        projectFindPaths.append(path)
        projectFindLines.append(line)
        String row = format("{}:{}:{}\n", path, line, snippet)
        projectFindResults.setText(format("{}{}", projectFindResults.text(), row))
    }

void Cedit.scanProjectFindText(String path, String contents, String query, bool caseSensitive,
                               bool wholeWords) {
        list lines = contents.split("\n")
        int64 i = 0
        while (i < lines.length) {
            if (projectFindPaths.length >= 500) { return }
            String line = lines[i] as String
            if (projectFindMatch(line, query, caseSensitive, wholeWords)) {
                String snippet = line
                if (snippet.length > 120) { snippet = byteSpan(snippet, 0, 120) }
                appendProjectFindHit(path, i + 1, snippet)
            }
            i = i + 1
        }
    }

void Cedit.scanProjectFindDir(String dir, String query, bool caseSensitive, bool wholeWords,
                              bool showHidden) {
        if (projectFindPaths.length >= 500) { return }
        list names = System.FileSystem().listDir(dir)
        int64 i = 0
        while (i < names.length) {
            String name = names[i] as String
            if (name.equals(".") || name.equals("..")) {
                i = i + 1
                continue
            }
            if (!showHidden) {
                if (name.startsWith(".")) {
                    i = i + 1
                    continue
                }
            }
            if (name.equals(".cedit") || name.equals(".git")) {
                i = i + 1
                continue
            }
            String path = System.FileSystem().join(dir, name)
            if (System.FileSystem().isDir(path)) {
                scanProjectFindDir(path, query, caseSensitive, wholeWords, showHidden)
            } else {
                if (System.FileSystem().isFile(path)) {
                    bool openHit = false
                    int64 d = 0
                    while (d < documents.length) {
                        EditorDocument document = documents[d] as EditorDocument
                        if (document.path.equals(path)) {
                            scanProjectFindText(path, document.view.text(), query, caseSensitive,
                                wholeWords)
                            openHit = true
                        }
                        d = d + 1
                    }
                    if (!openHit) {
                        try {
                            System.File file = System.File(path, "r")
                            String data = file.readAll()
                            file.close()
                            if (GtkSource.Content().isText(data)) {
                                scanProjectFindText(path, data, query, caseSensitive, wholeWords)
                            }
                        } except(Exception) {
                        }
                    }
                }
            }
            i = i + 1
        }
    }

void Cedit.runProjectFind() {
        if (commandsBlocked()) { return }
        String query = projectFindEntry.text()
        if (query.equals("")) {
            projectFindStatus.setText("Enter a search string")
            return
        }
        projectFindPaths = []
        projectFindLines = []
        projectFindResults.setText("")
        bool caseSensitive = projectFindCase.active()
        bool wholeWords = projectFindWords.active()
        bool showHidden = false
        if (project != null) { showHidden = project.hidden.active() }
        int64 d = 0
        while (d < documents.length) {
            EditorDocument document = documents[d] as EditorDocument
            if (!document.path.equals("")) {
                scanProjectFindText(document.path, document.view.text(), query, caseSensitive,
                    wholeWords)
            }
            d = d + 1
        }
        if (project != null) {
            if (!project.rootPath.equals("")) {
                scanProjectFindDir(project.rootPath, query, caseSensitive, wholeWords, showHidden)
            }
        }
        if (projectFindPaths.length >= 500) {
            projectFindStatus.setText("Results truncated at 500")
        } else {
            projectFindStatus.setText(format("{} result(s)", projectFindPaths.length))
        }
    }

void Cedit.projectFindActivated(int64 line) {
        int64 row = line - 1
        if (row < 0 || row >= projectFindPaths.length) { return }
        String path = projectFindPaths[row] as String
        int64 at = projectFindLines[row] as int64
        EditorDocument document = openDocument(path)
        if (document == null) { return }
        activateDocument(document)
        document.view.centerCursor(at, 1)
        document.view.focus()
    }
