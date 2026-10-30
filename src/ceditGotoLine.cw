bool Cedit.digitsOnly(String text) {
        if (text.equals("")) { return(false) }
        int64 i = 0
        while (i < text.length) {
            int64 b = text[i]
            if (b < 48 || b > 57) { return(false) }
            i = i + 1
        }
        return(true)
    }

void Cedit.createGotoLine() {
        gotoWindow = Gtk.TransientWindow("Go to Line")
        gotoWindow.setDefaultSize(320, 100)
        gotoWindow.setTransientFor(window)
        gotoWindow.setVisible(false)
        gotoWindow.onCloseRequest(_self().hideGotoLine)
        Gtk.Box layout = Gtk.Box(Gtk.Box.VERTICAL, 6)
        gotoWindow.setChild(layout)
        layout.append(Gtk.Label("Line or line:column"))
        gotoEntry = Gtk.Entry("")
        layout.append(gotoEntry)
        gotoStatus = Gtk.Label("")
        layout.append(gotoStatus)
        Gtk.Box buttons = Gtk.Box(Gtk.Box.HORIZONTAL, 6)
        layout.append(buttons)
        Gtk.Button go = Gtk.Button("Go")
        go.onClicked(_self().acceptGotoLine)
        buttons.append(go)
        Gtk.Button cancel = Gtk.Button("Cancel")
        cancel.onClicked(_self().closeGotoLine)
        buttons.append(cancel)
    }

void Cedit.showGotoLine() {
        if (commandsBlocked()) { return }
        EditorDocument document = currentDocument()
        if (document == null) {
            status.setText("No document")
            return
        }
        if (gotoWindow == null || gotoWindow.disposed()) { createGotoLine() }
        gotoEntry.setText(format("{}", document.view.line()))
        gotoStatus.setText("")
        gotoWindow.present()
        gotoEntry.focus()
    }

bool Cedit.hideGotoLine() {
        if (gotoWindow != null && !gotoWindow.disposed()) { gotoWindow.setVisible(false) }
        return(true)
    }

void Cedit.closeGotoLine() { hideGotoLine() }

void Cedit.acceptGotoLine() {
        if (commandsBlocked()) { return }
        EditorDocument document = currentDocument()
        if (document == null) {
            gotoStatus.setText("No document")
            return
        }
        String raw = gotoEntry.text().trim()
        if (raw.equals("")) {
            gotoStatus.setText("Enter a line number")
            return
        }
        int64 line = 0
        int64 column = 1
        int64 colon = raw.find(":")
        String lineText = raw
        String columnText = ""
        if (colon >= 0) {
            lineText = byteSpan(raw, 0, colon)
            columnText = byteSpan(raw, colon + 1, raw.length)
        }
        if (!digitsOnly(lineText)) {
            gotoStatus.setText("Invalid line")
            return
        }
        line = lineText.toInt64()
        if (line < 1) {
            gotoStatus.setText("Line must be >= 1")
            return
        }
        if (!columnText.equals("")) {
            if (!digitsOnly(columnText)) {
                gotoStatus.setText("Invalid column")
                return
            }
            column = columnText.toInt64()
            if (column < 1) {
                gotoStatus.setText("Column must be >= 1")
                return
            }
        }
        document.view.centerCursor(line, column)
        document.view.focus()
        hideGotoLine()
        updateStatusText()
    }
