// Trusted in-process plugin hooks. Demos are compile-in until dynamic .cw
// loading exists; registerPlugin records menu entries whose ids are handled
// in commandAction like built-in commands.

void Cedit.registerPlugin(String id, String title) {
        if (id.equals("")) { return }
        plugins.append(id)
        pluginTitles.append(title)
    }

void Cedit.loadBuiltinPlugins() {
        plugins = []
        pluginTitles = []
        registerPlugin("plugin-insert-date", "Insert date/time")
        registerPlugin("plugin-toggle-debug", "Toggle debug marker")
    }

void Cedit.pluginInsertDate() {
        if (commandsBlocked()) { return }
        EditorDocument document = currentDocument()
        if (document == null) { return }
        String stamp = format("{}", Time.Clock().epochSeconds())
        document.view.insertText(document.view.line(), document.view.column(), stamp)
        document.view.focus()
        status.setText("Plugin: inserted epoch seconds")
    }

void Cedit.pluginToggleDebug() {
        if (commandsBlocked()) { return }
        EditorDocument document = currentDocument()
        if (document == null) { return }
        String marker = "# debug: "
        loadSelectedLineSpan()
        if (!document.view.hasSelection()) {
            lineSpanStart = document.view.line()
            lineSpanEnd = lineSpanStart
        }
        document.view.beginUserAction()
        int64 line = lineSpanStart
        while (line <= lineSpanEnd) {
            String text = lineText(document, line)
            if (text.startsWith(marker)) {
                document.view.replaceRange(line, 1, line, marker.length + 1, "")
            } else {
                document.view.insertText(line, 1, marker)
            }
            line = line + 1
        }
        document.view.endUserAction()
        document.view.focus()
        status.setText("Plugin: toggled debug marker")
    }

void Cedit.addPluginMenus() {
        if (menu == null) { return }
        int64 pluginsMenu = menu.addMenu("Plugins")
        int64 i = 0
        while (i < plugins.length) {
            String id = plugins[i] as String
            String title = pluginTitles[i] as String
            menu.addItem(pluginsMenu, title, commandAction(id))
            i = i + 1
        }
    }
