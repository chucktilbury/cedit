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

String Cedit.lineCommentPrefix() {
        EditorDocument document = currentDocument()
        String language = ""
        if (document != null) { language = document.view.language() }
        if (language.equals("python3") || language.equals("python") || language.equals("sh") ||
            language.equals("desktop") || language.equals("yaml") || language.equals("ruby")) {
            return("#")
        }
        if (language.equals("cwhip") || language.equals("c") || language.equals("cpp") ||
            language.equals("chdr") || language.equals("cpphdr") || language.equals("java") ||
            language.equals("javascript") || language.equals("js") || language.equals("typescript") ||
            language.equals("rust") || language.equals("go") || language.equals("objc") ||
            language.equals("vala")) {
            return("//")
        }
        return("#")
    }

bool Cedit.supportsBlockComment() {
        String prefix = lineCommentPrefix()
        return(prefix.equals("//"))
    }

String Cedit.lineText(EditorDocument document, int64 line) {
        document.view.selectRange(line, 1, line + 1, 1)
        String text = document.view.selectedText()
        if (text.endsWith("\n")) { text = byteSpan(text, 0, text.length - 1) }
        return(text)
    }

bool Cedit.lineHasCommentPrefix(String text, String prefix) {
        int64 i = 0
        while (i < text.length) {
            int64 b = text[i]
            if (b != 32 && b != 9) { break }
            i = i + 1
        }
        String rest = byteSpan(text, i, text.length)
        return(rest.startsWith(prefix))
    }

void Cedit.toggleComment() {
        if (commandsBlocked()) { return }
        EditorDocument document = currentDocument()
        if (document == null) { return }
        String prefix = lineCommentPrefix()
        String marked = format("{} ", prefix)
        loadSelectedLineSpan()
        if (!document.view.hasSelection()) {
            lineSpanStart = document.view.line()
            lineSpanEnd = lineSpanStart
        }
        bool allCommented = true
        int64 line = lineSpanStart
        while (line <= lineSpanEnd) {
            if (!lineHasCommentPrefix(lineText(document, line), prefix)) { allCommented = false }
            line = line + 1
        }
        document.view.beginUserAction()
        line = lineSpanStart
        while (line <= lineSpanEnd) {
            String text = lineText(document, line)
            if (allCommented) {
                uncommentLine(document, line, text, prefix)
            } else {
                if (!lineHasCommentPrefix(text, prefix)) {
                    document.view.insertText(line, 1, marked)
                }
            }
            line = line + 1
        }
        document.view.endUserAction()
        document.view.focus()
    }

void Cedit.uncommentLine(EditorDocument document, int64 line, String text, String prefix) {
        int64 i = 0
        while (i < text.length) {
            int64 b = text[i]
            if (b != 32 && b != 9) { break }
            i = i + 1
        }
        int64 prefixLen = prefix.length
        if (i + prefixLen > text.length) { return }
        String rest = byteSpan(text, i, text.length)
        if (!rest.startsWith(prefix)) { return }
        int64 end = i + prefixLen + 1
        if (i + prefixLen < text.length && text[i + prefixLen] == 32) {
            // drop the conventional space after the marker
        } else {
            end = i + prefixLen + 1
            // end is exclusive column = i+prefixLen+1 when no space... column is 1-based
            end = i + prefixLen + 1
        }
        int64 startCol = i + 1
        int64 endCol = i + prefixLen + 1
        if (i + prefixLen < text.length && text[i + prefixLen] == 32) {
            endCol = endCol + 1
        }
        document.view.replaceRange(line, startCol, line, endCol, "")
    }

void Cedit.toggleBlockComment() {
        if (commandsBlocked()) { return }
        EditorDocument document = currentDocument()
        if (document == null) { return }
        if (!supportsBlockComment()) {
            toggleComment()
            return
        }
        if (!document.view.hasSelection()) {
            toggleComment()
            return
        }
        int64 startLine = document.view.selectionStartLine()
        int64 startCol = document.view.selectionStartColumn()
        int64 endLine = document.view.selectionEndLine()
        int64 endCol = document.view.selectionEndColumn()
        String selected = document.view.selectedText()
        document.view.beginUserAction()
        if (selected.startsWith("/*") && selected.endsWith("*/")) {
            String inner = byteSpan(selected, 2, selected.length - 2)
            if (inner.startsWith(" ") && inner.endsWith(" ") && inner.length >= 2) {
                inner = byteSpan(inner, 1, inner.length - 1)
            }
            document.view.replaceRange(startLine, startCol, endLine, endCol, inner)
        } else {
            document.view.replaceRange(startLine, startCol, endLine, endCol,
                format("/* {} */", selected))
        }
        document.view.endUserAction()
        document.view.focus()
    }
