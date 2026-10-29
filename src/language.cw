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

    void writeFrame(String body) {
        if (!running) { return }
        String frame = format("Content-Length: {}\r\n\r\n{}", body.length, body)
        if (!process.write(frame)) {
            running = false
            editor.status.setText(format("Language server write failed: {}", process.inputError()))
        }
    }

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

    void sendOpen(EditorDocument document) {
        if (!running || document == null || document.path.equals("")) { return }
        String body = format("{{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{{\"textDocument\":{{\"uri\":\"{}\",\"languageId\":\"cwhip\",\"version\":{},\"text\":\"{}\"}}}}}}",
            fileUri(document.path), document.lspVersion, escape(document.view.text()))
        writeFrame(body)
    }

    void sendChange(EditorDocument document) {
        if (!running || !ready || document == null || document.path.equals("")) { return }
        document.lspVersion = document.lspVersion + 1
        String body = format("{{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didChange\",\"params\":{{\"textDocument\":{{\"uri\":\"{}\",\"version\":{}}},\"contentChanges\":[{{\"text\":\"{}\"}}]}}}}",
            fileUri(document.path), document.lspVersion, escape(document.view.text()))
        writeFrame(body)
        sentGeneration = generation
    }

    void sendClose(String path) {
        if (!running || path.equals("")) { return }
        writeFrame(format("{{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didClose\",\"params\":{{\"textDocument\":{{\"uri\":\"{}\"}}}}}}",
            fileUri(path)))
    }

    void noteEdit() {
        if (!running) { return }
        generation = generation + 1
        Gtk.Application().schedule(200, editor.languageFlushAction)
    }

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
        if (document == null) { return }
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
        diagnostics = lines
        if (editor.diagnostics != null) { editor.diagnostics.setText(lines) }
        EditorDocument current = editor.currentDocument()
        if (current == document) {
            if (count == 0) {
                if (editor.status.text().contains("diagnostic")) {
                    editor.status.setText("Ready")
                }
            } else {
                if (count == 1) { editor.status.setText(lines) }
                else {
                    editor.status.setText(format("{} diagnostics (see marked lines)", count))
                }
            }
        }
    }

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
    String byteSpan(String text, int64 first, int64 last) {
        if (first < 0) { first = 0 }
        if (last > text.length) { last = text.length }
        if (last <= first) { return("") }
        return(text[first..(last - 1)])
    }

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
