/*
 * src/ceditProjectFind.cw — find-in-project UI and scan on Cedit.
 *
 * Created: 2026-10-30
 * Author: Auto
 *
 * Changelog:
 *   2026-10-30  Initial file.
 *   2026-11-13  CODING headers and method comments.
 */

/*
 * Build the Find in Project transient window and widgets.
 *
 * Purpose: create entry, options, results view, and empty path/line lists; keep hidden.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */
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

/*
 * Present the Find in Project window.
 *
 * Purpose: require an open project root; recreate the window if needed; focus entry.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */
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

/*
 * Hide the Find in Project window without destroying it.
 *
 * Purpose: setVisible(false) when the window still exists.
 *
 * Parameters:
 *   none.
 *
 * Returns: true (consume the close request).
 */
bool Cedit.hideProjectFind() {
        if (projectFindWindow != null && !projectFindWindow.disposed()) {
            projectFindWindow.setVisible(false)
        }
        return(true)
    }

/*
 * Test whether haystack matches needle under find options.
 *
 * Purpose: optional case fold; substring or whole-word (alnum and underscore).
 *
 * Parameters:
 *   haystack — line text to search.
 *   needle — query string.
 *   caseSensitive — true to keep case.
 *   wholeWords — true to require word boundaries.
 *
 * Returns: true if a match is found.
 */
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

/*
 * Append one hit to the results lists and view (cap 500).
 *
 * Purpose: store path/line; append a path:line:snippet row.
 *
 * Parameters:
 *   path — file path for the hit.
 *   line — 1-based line number.
 *   snippet — line text (may already be truncated).
 *
 * Returns: nothing.
 */
void Cedit.appendProjectFindHit(String path, int64 line, String snippet) {
        if (projectFindPaths.length >= 500) { return }
        projectFindPaths.append(path)
        projectFindLines.append(line)
        String row = format("{}:{}:{}\n", path, line, snippet)
        projectFindResults.setText(format("{}{}", projectFindResults.text(), row))
    }

/*
 * Scan one file text for matches and append hits.
 *
 * Purpose: split on newlines; match each line; truncate snippets at 120 chars.
 *
 * Parameters:
 *   path — file path shown in results.
 *   contents — full file text.
 *   query — search string.
 *   caseSensitive — match option.
 *   wholeWords — match option.
 *
 * Returns: nothing.
 */
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

/*
 * Recursively scan a directory tree for matches.
 *
 * Purpose: skip dot/.cedit/.git; honor showHidden; prefer open buffers; text files only.
 *
 * Parameters:
 *   dir — directory to list.
 *   query — search string.
 *   caseSensitive — match option.
 *   wholeWords — match option.
 *   showHidden — include dot-named entries when true.
 *
 * Returns: nothing.
 */
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

/*
 * Run a project-wide find using the dialog options.
 *
 * Purpose: clear prior results; scan open documents then project tree; report count.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */
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

/*
 * Open the file for an activated results row and center the caret.
 *
 * Purpose: map 1-based view line to projectFindPaths/Lines; open and centerCursor.
 *
 * Parameters:
 *   line — 1-based line in the results view.
 *
 * Returns: nothing.
 */
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
