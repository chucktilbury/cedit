class OverrideRow {
    OverrideRow _self()
    String key
    bool boolean
    Gtk.Box row
    Gtk.CheckButton override
    Gtk.Entry entry
    Gtk.CheckButton value

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

    void toggled(bool active) {
        if (boolean) { value.setSensitive(active) } else { entry.setSensitive(active) }
    }

    void show(bool overridden, String text, bool flag) {
        override.setActive(overridden)
        if (boolean) { value.setActive(flag) } else { entry.setText(text) }
        toggled(overridden)
    }
}
OverrideRow OverrideRow._self() from "cwhip_gtk_self"
