/*
 * src/ceditPlugins.cw - Trusted in-process plugin hooks and demos.
 *
 * Created: 2026-10-30
 * Author: Auto
 *
 * Changelog:
 *   2026-10-30  Initial file.
 *   2026-11-13  CODING headers and method comments.
 */

// Trusted in-process plugin hooks. Demos are compile-in until dynamic .cw
// loading exists; registerPlugin records menu entries whose ids are handled
// in commandAction like built-in commands.

/*
 * Cedit.registerPlugin
 *
 * Purpose: registerPlugin.
 *
 * Parameters:
 *   id.
 *   title.
 *
 * Returns: nothing.
 */

void Cedit.registerPlugin(String id, String title) {
        if (id.equals("")) { return }
        plugins.append(id)
        pluginTitles.append(title)
    }

/*
 * Cedit.loadBuiltinPlugins
 *
 * Purpose: loadBuiltinPlugins.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.loadBuiltinPlugins() {
        plugins = []
        pluginTitles = []
        registerPlugin("plugin-insert-date", "Insert date/time")
        registerPlugin("plugin-toggle-debug", "Toggle debug marker")
    }

/*
 * Cedit.pluginInsertDate
 *
 * Purpose: pluginInsertDate.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

void Cedit.pluginInsertDate() {
        if (commandsBlocked()) { return }
        EditorDocument document = currentDocument()
        if (document == null) { return }
        String stamp = format("{}", Time.Clock().epochSeconds())
        document.view.insertText(document.view.line(), document.view.column(), stamp)
        document.view.focus()
        status.setText("Plugin: inserted epoch seconds")
    }

/*
 * Cedit.pluginToggleDebug
 *
 * Purpose: pluginToggleDebug.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

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

/*
 * Cedit.addPluginMenus
 *
 * Purpose: addPluginMenus.
 *
 * Parameters:
 *   none.
 *
 * Returns: nothing.
 */

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
