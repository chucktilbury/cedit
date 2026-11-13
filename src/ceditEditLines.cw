/*
 * src/ceditEditLines.cw — indent, outdent, and comment helpers on Cedit.
 *
 * Created: 2026-10-30
 * Author: Auto
 *
 * Changelog:
 *   2026-10-30  Initial file.
 *   2026-11-13  CODING headers and method comments.
 */

/*
 * Resolve the effective tab width for the active document.
 *
 * Purpose: use settings.tabWidth unless the active project overrides tabs.
 *
 * Parameters:
 *   none.
 *
 * Returns: tab width in columns.
 */
int64 Cedit.effectiveTabWidth() {
        int64 tabs = settings.tabWidth
        if (activeProject != null && activeProject.hasTabs) { tabs = activeProject.tabWidth }
        return(tabs)
    }

/*
 * Resolve whether to insert spaces for indentation.
 *
 * Purpose: use settings.insertSpaces unless the active project overrides.
 *
 * Parameters:
 *   none.
 *
 * Returns: true to insert spaces; false for tabs.
 */
bool Cedit.effectiveInsertSpaces() {
        bool spaces = settings.insertSpaces
        if (activeProject != null && activeProject.hasSpaces) { spaces = activeProject.insertSpaces }
        return(spaces)
    }

/*
 * Build one indent unit string (spaces or a tab).
 *
 * Purpose: spaces of effectiveTabWidth when insert-spaces; else a tab character.
 *
 * Parameters:
 *   none.
 *
 * Returns: indent unit string.
 */
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

/*
 * Fill lineSpanStart/lineSpanEnd from the current selection.
 *
 * Purpose: a selection ending at column 1 excludes that end line.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing. Updates lineSpanStart/lineSpanEnd.
 */
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

/*
 * Indent the caret or selected line block.
 *
 * Purpose: insert indentUnit at column 1 for a block selection, else at caret.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */
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

/*
 * Outdent each line in the selection (or the current line).
 *
 * Purpose: load the line span; if no selection use caret line; outdent each.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */
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

/*
 * Remove one leading tab or up to width leading spaces on a line.
 *
 * Purpose: select the line text; strip a leading tab, else spaces.
 *
 * Parameters:
 *   document — EditorDocument being edited.
 *   line — 1-based line number.
 *   width — max spaces to remove when not a tab.
 *
 * Returns: nothing.
 */
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

/*
 * Choose the line-comment marker for the current language.
 *
 * Purpose: hash for python/sh/yaml/ruby/desktop; slash-slash for cwhip/c/cpp family; else hash.
 *
 * Parameters:
 *   none.
 *
 * Returns: comment prefix string.
 */
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

/*
 * Whether block comments (slash-star) are supported.
 *
 * Purpose: true when lineCommentPrefix is slash-slash.
 *
 * Parameters:
 *   none.
 *
 * Returns: true for C-family languages using slash-slash markers.
 */
bool Cedit.supportsBlockComment() {
        String prefix = lineCommentPrefix()
        return(prefix.equals("//"))
    }

/*
 * Read one line of text without a trailing newline.
 *
 * Purpose: select the line range and strip a final newline character.
 *
 * Parameters:
 *   document — EditorDocument to read.
 *   line — 1-based line number.
 *
 * Returns: line contents without trailing newline.
 */
String Cedit.lineText(EditorDocument document, int64 line) {
        document.view.selectRange(line, 1, line + 1, 1)
        String text = document.view.selectedText()
        if (text.endsWith("\n")) { text = byteSpan(text, 0, text.length - 1) }
        return(text)
    }

/*
 * Whether a line already starts with a comment prefix.
 *
 * Purpose: skip leading spaces/tabs, then test startsWith(prefix).
 *
 * Parameters:
 *   text — full line text.
 *   prefix — comment marker (slash-slash or hash).
 *
 * Returns: true if the first non-whitespace starts with prefix.
 */
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

/*
 * Toggle line comments on the selection or current line.
 *
 * Purpose: if every line is commented, uncomment; else comment lines lacking prefix.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */
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

/*
 * Remove a line-comment prefix from one line.
 *
 * Purpose: find first non-whitespace; if prefix matches, delete it and a following space.
 *
 * Parameters:
 *   document — EditorDocument being edited.
 *   line — 1-based line number.
 *   text — current line text.
 *   prefix — comment marker to remove.
 *
 * Returns: nothing.
 */
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

/*
 * Toggle a slash-star block comment around the selection.
 *
 * Purpose: fall back to toggleComment when unsupported or no selection; else wrap or unwrap.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */
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
