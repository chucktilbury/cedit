/*
 * src/overrideRow.cw - Project-configure row for one setting override.
 *
 * Created: 2026-10-29
 * Author: Auto
 *
 * Changelog:
 *   2026-10-29  Initial file.
 *   2026-11-13  CODING headers and method comments.
 */

/*
 * OverrideRow for cedit; see method comments below.
 */
class OverrideRow {
    /*
     * _self
     *
     * Purpose: _self.
     *
     * Parameters:
     *   settingKey.
     *   label.
     *   flag.
     *
     * Returns: OverrideRow.
     */

    OverrideRow _self()
    String key
    bool boolean
    Gtk.Box row
    Gtk.CheckButton override
    Gtk.Entry entry
    Gtk.CheckButton value

    /*
     * OverrideRow
     *
     * Purpose: OverrideRow for the editor.
     *
     * Parameters:
     *   settingKey.
     *   label.
     *   flag.
     *
     * Returns: OverrideRow.
     */

    OverrideRow(String settingKey, String label, bool flag) {
        key = settingKey
        boolean = flag
        row = Gtk.Box(Gtk.Box.HORIZONTAL, 6)
        override = Gtk.CheckButton(format("Override {}", label))
        row.append(override)
        if (boolean) {
            value = Gtk.CheckButton("Enabled")
            row.append(value)
        } else {
            entry = Gtk.Entry("")
            entry.setHExpand(true)
            row.append(entry)
        }
        override.onToggled(_self().toggled)
    }

    /*
     * toggled
     *
     * Purpose: toggled for the editor.
     *
     * Parameters:
     *   active.
     *
     * Returns: nothing.
     */

    void toggled(bool active) {
        if (boolean) { value.setSensitive(active) } else { entry.setSensitive(active) }
    }

    /*
     * show
     *
     * Purpose: show for the editor.
     *
     * Parameters:
     *   overridden.
     *   text.
     *   flag.
     *
     * Returns: nothing.
     */

    void show(bool overridden, String text, bool flag) {
        override.setActive(overridden)
        if (boolean) { value.setActive(flag) } else { entry.setText(text) }
        toggled(overridden)
    }
}
OverrideRow OverrideRow._self() from "cwhip_gtk_self"
