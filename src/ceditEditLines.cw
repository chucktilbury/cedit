int64 Cedit.effectiveTabWidth() {
        int64 tabs = settings.tabWidth
        if (activeProject != null && activeProject.hasTabs) { tabs = activeProject.tabWidth }
        return(tabs)
    }

bool Cedit.effectiveInsertSpaces() {
        bool spaces = settings.insertSpaces
        if (activeProject != null && activeProject.hasSpaces) { spaces = activeProject.insertSpaces }
        return(spaces)
    }

String Cedit.indentUnit() {
        if (effectiveInsertSpaces()) {
            String spaces = ""
            int64 n = 0
            while (n < effectiveTabWidth()) {
                spaces.append(" ")
                n = n + 1
            }
            return(spaces)
        }
        return("\t")
    }

// Fills lineSpanStart/lineSpanEnd. A selection ending at column 1 excludes that line.
void Cedit.loadSelectedLineSpan() {
        EditorDocument document = currentDocument()
        lineSpanStart = document.view.selectionStartLine()
        lineSpanEnd = document.view.selectionEndLine()
        if (document.view.hasSelection()) {
            if (document.view.selectionEndColumn() == 1) {
                if (lineSpanEnd > lineSpanStart) { lineSpanEnd = lineSpanEnd - 1 }
            }
        }
    }

void Cedit.indentCurrent() {
        if (commandsBlocked()) { return }
        EditorDocument document = currentDocument()
        if (document == null) { return }
        String unit = indentUnit()
        loadSelectedLineSpan()
        bool block = false
        if (document.view.hasSelection()) {
            if (lineSpanStart < lineSpanEnd) { block = true }
            else(document.view.selectionStartColumn() == 1) { block = true }
        }
        document.view.beginUserAction()
        if (block) {
            int64 line = lineSpanStart
            while (line <= lineSpanEnd) {
                document.view.insertText(line, 1, unit)
                line = line + 1
            }
        } else {
            document.view.insertText(document.view.line(), document.view.column(), unit)
        }
        document.view.endUserAction()
        document.view.focus()
    }

void Cedit.outdentCurrent() {
        if (commandsBlocked()) { return }
        EditorDocument document = currentDocument()
        if (document == null) { return }
        loadSelectedLineSpan()
        if (!document.view.hasSelection()) {
            lineSpanStart = document.view.line()
            lineSpanEnd = lineSpanStart
        }
        int64 width = effectiveTabWidth()
        document.view.beginUserAction()
        int64 line = lineSpanStart
        while (line <= lineSpanEnd) {
            outdentLine(document, line, width)
            line = line + 1
        }
        document.view.endUserAction()
        document.view.focus()
    }

void Cedit.outdentLine(EditorDocument document, int64 line, int64 width) {
        document.view.selectRange(line, 1, line + 1, 1)
        String text = document.view.selectedText()
        if (text.endsWith("\n")) { text = byteSpan(text, 0, text.length - 1) }
        if (text.startsWith("\t")) {
            document.view.replaceRange(line, 1, line, 2, "")
            return
        }
        int64 removed = 0
        while (removed < width && removed < text.length && text[removed] == 32) {
            removed = removed + 1
        }
        if (removed > 0) { document.view.replaceRange(line, 1, line, removed + 1, "") }
    }
