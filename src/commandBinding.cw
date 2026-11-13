/*
 * src/commandBinding.cw - Named editor command plus keyboard trigger.
 *
 * Created: 2026-10-29
 * Author: Auto
 *
 * Changelog:
 *   2026-10-29  Initial file.
 *   2026-11-13  CODING headers and method comments.
 */

/*
 * CommandBinding for cedit; see method comments below.
 */
class CommandBinding {
    String id
    String name
    String defaultTrigger
    String trigger
    String normalized
    bool valid
    void<> action
    /*
     * CommandBinding
     *
     * Purpose: CommandBinding for the editor.
     *
     * Parameters:
     *   command.
     *   label.
     *   shortcut.
     *
     * Returns: CommandBinding.
     */

    CommandBinding(String command, String label, String shortcut) {
        id = command
        name = label
        defaultTrigger = shortcut
        setTrigger(shortcut)
    }
    /*
     * setTrigger
     *
     * Purpose: setTrigger for the editor.
     *
     * Parameters:
     *   shortcut.
     *
     * Returns: nothing.
     */

    void setTrigger(String shortcut) {
        trigger = shortcut
        normalized = ""
        if (!shortcut.equals("")) { normalized = Gtk.Keyboard().normalize(shortcut) }
        valid = shortcut.equals("") || normalized.length > 0
    }
}
