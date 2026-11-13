/*
 * src/language.cw — LSP client for the editor (LanguageClient).
 *
 * Created: 2026-10-29
 * Author: Auto
 *
 * Changelog:
 *   2026-10-29  Initial file.
 *   2026-11-13  CODING headers and method comments.
 */

/*
 * LanguageClient talks JSON-RPC over a stdio language server process:
 * launch/stop, didOpen/didChange/didClose, and publishDiagnostics.
 */
class LanguageClient {
    Cedit editor
    Process.AsyncProcess process
    Process.OutputDecoder decoder
    String pending
    String command
    bool running
    bool ready
    int64 generation
    int64 sentGeneration
    String diagnostics

    /*
     * Create a language client owned by the editor.
     *
     * Purpose: store owner and reset runtime fields to idle defaults.
     *
     * Parameters:
     *   owner — Cedit that schedules polls and owns documents.
     *
     * Returns: LanguageClient ready for launch().
     */
    LanguageClient(Cedit owner) {
        editor = owner
        decoder = Process.OutputDecoder()
        pending = ""
        command = ""
        running = false
        ready = false
        generation = 0
        sentGeneration = 0
        diagnostics = ""
    }

    /*
     * Escape a string for embedding in a JSON string value.
     *
     * Purpose: backslash-escape quotes/backslashes and map LF/CR/TAB to escaped forms.
     *
     * Parameters:
     *   text — raw document or message text.
     *
     * Returns: escaped string safe inside JSON quotes.
     */
    String escape(String text) {
        String out = ""
        int64 index = 0
        while (index < text.length) {
            uint8 byte = text[index]
            if (byte == 34 || byte == 92) {
                out.append("\\")
                out.append(text[index..(index)])
            } else {
                if (byte == 10) { out.append("\\n") }
                else {
                    if (byte == 13) { out.append("\\r") }
                    else {
                        if (byte == 9) { out.append("\\t") }
                        else { out.append(text[index..(index)]) }
                    }
                }
            }
            index = index + 1
        }
        return(out)
    }

    /*
     * Build a file:// URI from a filesystem path.
     *
     * Purpose: percent-encode spaces as %20; pass other bytes through.
     *
     * Parameters:
     *   path — absolute file path.
     *
     * Returns: file:// URI string.
     */
    String fileUri(String path) {
        String uri = "file://"
        int64 index = 0
        while (index < path.length) {
            if (path[index] == 32) { uri.append("%20") }
            else { uri.append(path[index..(index)]) }
            index = index + 1
        }
        return(uri)
    }

    /*
     * Basename of the configured server executable, lowercased.
     *
     * Purpose: identify server kind from the command line string.
     *
     * Parameters:
     *   none.
     *
     * Returns: executable basename, or empty if command is empty.
     */
    String executableName() {
        String executable = command.trim()
        if (executable.equals("")) { return("") }
        list parts = executable.split(" ")
        int64 index = 0
        while (index < parts.length) {
            String part = parts[index] as String
            if (!part.equals("")) { return(System.FileSystem().basename(part).toLower()) }
            index = index + 1
        }
        return("")
    }

    /*
     * Whether the configured server is cwhip-lsp.
     *
     * Purpose: gate document handling to .cw / cwhip language id.
     *
     * Parameters:
     *   none.
     *
     * Returns: true if executable is cwhip-lsp or ends with -cwhip-lsp.
     */
    bool isCwhipServer() {
        String name = executableName()
        return(name.equals("cwhip-lsp") || name.endsWith("-cwhip-lsp"))
    }

    /*
     * Whether the configured server is clangd.
     *
     * Purpose: gate document handling to C/C++ language ids.
     *
     * Parameters:
     *   none.
     *
     * Returns: true if executable is clangd or starts with clangd-.
     */
    bool isClangServer() {
        String name = executableName()
        return(name.equals("clangd") || name.startsWith("clangd-"))
    }

    /*
     * Map a path to an LSP languageId string.
     *
     * Purpose: prefer extension rules for .cw/.c/.h/C++; else GtkSource languageFor; else empty.
     *
     * Parameters:
     *   path — document path.
     *
     * Returns: language id such as cwhip, c, cpp, or empty.
     */
    String languageId(String path) {
        String lower = path.toLower()
        if (lower.endsWith(".cw")) { return("cwhip") }
        if (lower.endsWith(".c") || lower.endsWith(".h")) { return("c") }
        if (lower.endsWith(".cc") || lower.endsWith(".cpp") || lower.endsWith(".cxx") ||
            lower.endsWith(".hpp") || lower.endsWith(".hxx") || lower.endsWith(".hh")) {
            return("cpp")
        }
        String language = GtkSource.Content().languageFor(path)
        if (!language.equals("")) { return(language) }
        return("")
    }

    // cwhip-lsp only sees .cw; clangd only C/C++ headers and sources; other
    // servers skip plain text (empty GtkSource language), including .txt/.md.
    /*
     * Whether this server should receive events for a path.
     *
     * Purpose: cwhip-lsp only .cw; clangd only C/C++; other servers skip empty language.
     *
     * Parameters:
     *   path — document path.
     *
     * Returns: true if the path is in scope for the running server.
     */
    bool handles(String path) {
        if (path.equals("")) { return(false) }
        String language = languageId(path)
        if (isCwhipServer()) { return(language.equals("cwhip")) }
        if (isClangServer()) { return(language.equals("c") || language.equals("cpp")) }
        return(!language.equals(""))
    }

    /*
     * Send one Content-Length framed JSON-RPC body on stdin.
     *
     * Purpose: no-op when not running; on write failure mark stopped and set status.
     *
     * Parameters:
     *   body — JSON payload without the Content-Length header.
     *
     * Returns: nothing.
     */
    void writeFrame(String body) {
        if (!running) { return }
        String frame = format("Content-Length: {}\r\n\r\n{}", body.length, body)
        if (!process.write(frame)) {
            running = false
            editor.status.setText(format("Language server write failed: {}", process.inputError()))
        }
    }

    /*
     * Start or restart the language server process.
     *
     * Purpose: stop any prior server; parse command; spawn AsyncProcess; send initialize; schedule poll.
     *
     * Parameters:
     *   requested — whitespace-separated executable and arguments.
     *
     * Returns: nothing.
     */
    void launch(String requested) {
        stop()
        command = requested.trim()
        diagnostics = ""
        if (command.equals("")) { return }
        list parts = command.split(" ")
        list arguments = []
        String executable = ""
        int64 index = 0
        while (index < parts.length) {
            String part = parts[index] as String
            if (!part.equals("")) {
                if (executable.equals("")) { executable = part }
                else { arguments.append(part) }
            }
            index = index + 1
        }
        if (executable.equals("")) { return }
        String directory = editor.project.rootPath
        if (directory.equals("")) { directory = System.FileSystem().getCwd() }
        process = Process.AsyncProcess(executable, arguments, directory, true)
        if (!process.started()) {
            editor.status.setText(format("Language server did not start: {}", process.error()))
            return
        }
        running = true
        ready = false
        writeFrame("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"processId\":null,\"capabilities\":{}}}")
        editor.scheduleLanguagePoll()
    }

    /*
     * Shut down the language server process.
     *
     * Purpose: send shutdown/exit when running; clear running/ready/pending and drop the process handle.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */
    void stop() {
        if (running) {
            writeFrame("{\"jsonrpc\":\"2.0\",\"method\":\"shutdown\",\"params\":null}")
            writeFrame("{\"jsonrpc\":\"2.0\",\"method\":\"exit\"}")
            process.close()
        }
        running = false
        ready = false
        pending = ""
        process = null
    }

    /*
     * Notify the server that a document was opened.
     *
     * Purpose: send textDocument/didOpen when running and handles path.
     *
     * Parameters:
     *   document — open EditorDocument (may be null).
     *
     * Returns: nothing.
     */
    void sendOpen(EditorDocument document) {
        if (!running || document == null || !handles(document.path)) { return }
        String body = format("{{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{{\"textDocument\":{{\"uri\":\"{}\",\"languageId\":\"{}\",\"version\":{},\"text\":\"{}\"}}}}}}",
            fileUri(document.path), languageId(document.path), document.lspVersion,
            escape(document.view.text()))
        writeFrame(body)
    }

    /*
     * Notify the server of a full-document change.
     *
     * Purpose: bump lspVersion; send didChange; record sentGeneration.
     *
     * Parameters:
     *   document — open EditorDocument (may be null).
     *
     * Returns: nothing. Requires ready and handles(path).
     */
    void sendChange(EditorDocument document) {
        if (!running || !ready || document == null || !handles(document.path)) { return }
        document.lspVersion = document.lspVersion + 1
        String body = format("{{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didChange\",\"params\":{{\"textDocument\":{{\"uri\":\"{}\",\"version\":{}}},\"contentChanges\":[{{\"text\":\"{}\"}}]}}}}",
            fileUri(document.path), document.lspVersion, escape(document.view.text()))
        writeFrame(body)
        sentGeneration = generation
    }

    /*
     * Notify the server that a document was closed.
     *
     * Purpose: send textDocument/didClose for a path still in scope.
     *
     * Parameters:
     *   path — closed document path.
     *
     * Returns: nothing.
     */
    void sendClose(String path) {
        if (!running || !handles(path)) { return }
        writeFrame(format("{{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didClose\",\"params\":{{\"textDocument\":{{\"uri\":\"{}\"}}}}}}",
            fileUri(path)))
    }

    /*
     * Schedule a deferred didChange after an edit.
     *
     * Purpose: bump generation and schedule languageFlushAction in 200ms when current doc is handled.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */
    void noteEdit() {
        if (!running) { return }
        EditorDocument document = editor.currentDocument()
        if (document == null || !handles(document.path)) { return }
        generation = generation + 1
        Gtk.Application().schedule(200, editor.languageFlushAction)
    }

    /*
     * Parse a JSON string value starting at origin.
     *
     * Purpose: decode common escapes and stop at the closing quote.
     *
     * Parameters:
     *   body — JSON text.
     *   origin — index of the first character inside the quotes.
     *
     * Returns: decoded string contents (may be incomplete at EOF).
     */
    String readString(String body, int64 origin) {
        String value = ""
        int64 index = origin
        while (index < body.length) {
            uint8 byte = body[index]
            if (byte == 92 && index + 1 < body.length) {
                uint8 escaped = body[index + 1]
                if (escaped == 110) { value.append("\n") }
                else {
                    if (escaped == 114) { value.append("\r") }
                    else {
                        if (escaped == 116) { value.append("\t") }
                        else { value.append(body[(index + 1)..(index + 1)]) }
                    }
                }
                index = index + 2
            } else {
                if (byte == 34) { return(value) }
                value.append(body[index..(index)])
                index = index + 1
            }
        }
        return(value)
    }

    /*
     * Find an open document matching a file:// URI.
     *
     * Purpose: scan editor.documents for path whose fileUri equals uri.
     *
     * Parameters:
     *   uri — LSP document URI.
     *
     * Returns: matching EditorDocument, or null.
     */
    EditorDocument documentForUri(String uri) {
        int64 index = 0
        while (index < editor.documents.length) {
            EditorDocument document = editor.documents[index] as EditorDocument
            if (!document.path.equals("") && fileUri(document.path).equals(uri)) {
                return(document)
            }
            index = index + 1
        }
        return(null)
    }

    /*
     * Handle one complete JSON-RPC body from the server.
     *
     * Purpose: on initialize result set ready and didOpen all docs; on publishDiagnostics mark lines and set short status.
     *
     * Parameters:
     *   body — JSON-RPC message body.
     *
     * Returns: nothing.
     */
    void accept(String body) {
        if (body.contains("\"id\":1") && body.contains("\"result\"")) {
            ready = true
            writeFrame("{\"jsonrpc\":\"2.0\",\"method\":\"initialized\",\"params\":{}}")
            int64 index = 0
            while (index < editor.documents.length) {
                sendOpen(editor.documents[index] as EditorDocument)
                index = index + 1
            }
            return
        }
        if (!body.contains("textDocument/publishDiagnostics")) { return }
        int64 uriAt = body.find("\"uri\":\"")
        if (uriAt < 0) { return }
        String uri = readString(body, uriAt + 7)
        EditorDocument document = documentForUri(uri)
        if (document == null || !handles(document.path)) { return }
        document.view.clearLineMarks("diagnostic")
        String lines = ""
        int64 count = 0
        String rest = body
        while (true) {
            int64 messageAt = rest.find("\"message\":\"")
            if (messageAt < 0) { break }
            String message = readString(rest, messageAt + 11)
            int64 line = 0
            int64 lineAt = rest.find("\"line\":")
            if (lineAt >= 0 && lineAt < messageAt) {
                line = leadingInteger(byteSpan(rest, lineAt + 7, messageAt).trim()) + 1
            }
            if (line > 0) {
                document.view.addLineMarkTooltip("diagnostic", line, message)
            }
            if (count > 0) { lines.append("\n") }
            lines.append(format("{}:{}: {}", document.baseName, line, message))
            count = count + 1
            rest = byteSpan(rest, messageAt + 11, rest.length)
        }
        // Keep only a short single-line status note. Putting the full message
        // list (or even one long message) into a packed label grows the window.
        diagnostics = lines
        EditorDocument current = editor.currentDocument()
        if (current == document) {
            if (count == 0) {
                if (editor.status.text().contains("diagnostic")) {
                    editor.status.setText("Ready")
                }
            } else {
                if (count == 1) {
                    editor.status.setText("1 diagnostic (see marked line)")
                } else {
                    editor.status.setText(format("{} diagnostics (see marked lines)", count))
                }
            }
        }
    }

    /*
     * Parse a leading decimal integer from text.
     *
     * Purpose: collect ASCII digits from the start; fail if none.
     *
     * Parameters:
     *   text — string that may start with digits.
     *
     * Returns: parsed int64, or -1 if no digits.
     */
    int64 leadingInteger(String text) {
        String digits = ""
        int64 index = 0
        while (index < text.length) {
            uint8 byte = text[index]
            if (byte < 48 || byte > 57) { break }
            digits.append(text[index..(index)])
            index = index + 1
        }
        if (digits.equals("")) { return(-1) }
        return(digits.toInt64())
    }
    /*
     * Slice text by exclusive end index (byte-oriented).
     *
     * Purpose: clamp first/last to [0, length] and return the span.
     *
     * Parameters:
     *   text — source string.
     *   first — inclusive start index.
     *   last — exclusive end index.
     *
     * Returns: substring, or empty if empty after clamp.
     */
    String byteSpan(String text, int64 first, int64 last) {
        if (first < 0) { first = 0 }
        if (last > text.length) { last = text.length }
        if (last <= first) { return("") }
        return(text[first..(last - 1)])
    }

    /*
     * Drain stdout and process complete LSP frames.
     *
     * Purpose: append decoded stdout; parse Content-Length frames into accept(); stop on exit; else reschedule poll.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */
    void poll() {
        if (!running || process == null) { return }
        int64 guard = 0
        while (guard < 20) {
            Process.ProcessEvent event = process.next(0)
            if (event == null) { break }
            if (event.isStdout()) { pending.append(decoder.decode(event.data())) }
            guard = guard + 1
        }
        while (true) {
            int64 header = pending.find("Content-Length:")
            if (header < 0) { break }
            int64 end = pending.find("\r\n\r\n")
            if (end < 0 || end < header) { break }
            int64 length = leadingInteger(byteSpan(pending, header + 15, end).trim())
            if (length < 0) { break }
            int64 bodyAt = end + 4
            if (pending.length < bodyAt + length) { break }
            accept(byteSpan(pending, bodyAt, bodyAt + length))
            pending = byteSpan(pending, bodyAt + length, pending.length)
        }
        if (process.finished()) {
            running = false
            if (!process.error().equals("")) {
                editor.status.setText(format("Language server stopped: {}", process.error()))
            }
            return
        }
        editor.scheduleLanguagePoll()
    }
}
