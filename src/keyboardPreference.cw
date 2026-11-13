/*
 * src/keyboardPreference.cw — one command row in keyboard preferences.
 *
 * Created: 2026-10-29
 * Author: Auto
 *
 * Changelog:
 *   2026-10-29  Initial file.
 *   2026-11-13  CODING headers and method comments.
 */

/*
 * KeyboardPreference is a preferences-grid row for one CommandBinding:
 * name, trigger entry, Record/Reset/Disable, and an error label.
 */
class KeyboardPreference {
    KeyboardPreference _self()
    CommandBinding binding
    CeditSettings settings
    Gtk.Label name
    Gtk.Entry entry
    Gtk.Button recordButton
    Gtk.Button resetButton
    Gtk.Button disableButton
    Gtk.Label errorLabel
    void<> applied
    void<> prepareRecord
    int64 recording
    bool refreshing

    /*
     * Build a keyboard preference row and attach it to the grid.
     *
     * Purpose: wire widgets, place them on two grid rows, and connect change/record/reset/disable handlers.
     *
     * Parameters:
     *   model — CeditSettings used for bindingError checks.
     *   command — CommandBinding this row edits.
     *   changed — callback after a valid trigger is applied.
     *   prepare — callback before starting keyboard capture.
     *   grid — preferences Gtk.Grid to attach into.
     *   index — zero-based row pair index (name on 2*index).
     *
     * Returns: KeyboardPreference with widgets attached.
     */
    KeyboardPreference(CeditSettings model, CommandBinding command, void<> changed,
                       void<> prepare, Gtk.Grid grid, int64 index) {
        settings = model
        binding = command
        applied = changed
        prepareRecord = prepare
        name = Gtk.Label(binding.name)
        entry = Gtk.Entry(binding.trigger)
        entry.setEditable(false)
        entry.setHExpand(true)
        recordButton = Gtk.Button("Record")
        resetButton = Gtk.Button("Reset")
        disableButton = Gtk.Button("Disable")
        errorLabel = Gtk.Label("")
        grid.attach(name, 0, index * 2, 1, 1)
        grid.attach(entry, 1, index * 2, 1, 1)
        grid.attach(recordButton, 2, index * 2, 1, 1)
        grid.attach(resetButton, 3, index * 2, 1, 1)
        grid.attach(disableButton, 4, index * 2, 1, 1)
        grid.attach(errorLabel, 0, index * 2 + 1, 5, 1)
        entry.onChanged(_self().changedTrigger)
        recordButton.onClicked(_self().record)
        resetButton.onClicked(_self().reset)
        disableButton.onClicked(_self().disable)
    }

    /*
     * Validate and apply a typed or recorded trigger string.
     *
     * Purpose: ignore programmatic refresh; reject empty (use Disable); show bindingError; on success setTrigger and notify applied.
     *
     * Parameters:
     *   text — accelerator text from the entry.
     *
     * Returns: nothing.
     */
    void changedTrigger(String text) {
        if (refreshing) { return }
        if (text.equals("")) {
            errorLabel.setText("Use Disable to remove this binding")
            return
        }
        String problem = settings.bindingError(binding, text)
        errorLabel.setText(problem)
        if (!problem.equals("")) { return }
        binding.setTrigger(text)
        applied()
    }
    /*
     * Start capturing a keyboard shortcut into the entry.
     *
     * Purpose: notify prepareRecord, prompt the user, and begin Gtk.Keyboard record with recorded as completion.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */
    void record() {
        prepareRecord()
        errorLabel.setText("Press shortcut; Escape cancels")
        recording = Gtk.Keyboard().record(entry, _self().recorded)
    }
    /*
     * Finish a keyboard capture session.
     *
     * Purpose: cancel recording state; apply non-empty trigger via setTrigger.
     *
     * Parameters:
     *   trigger — captured accelerator, or empty if cancelled.
     *
     * Returns: nothing.
     */
    void recorded(String trigger) {
        cancelRecording()
        if (!trigger.equals("")) { setTrigger(trigger) }
    }
    /*
     * Abort an in-progress keyboard capture.
     *
     * Purpose: cancel Gtk.Keyboard session id and clear the prompt.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */
    void cancelRecording() {
        if (recording != 0) {
            Gtk.Keyboard().cancel(recording)
            recording = 0
            errorLabel.setText("")
        }
    }
    /*
     * Restore the binding default trigger.
     *
     * Purpose: cancel capture then setTrigger(defaultTrigger).
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */
    void reset() {
        cancelRecording()
        setTrigger(binding.defaultTrigger)
    }
    /*
     * Clear the binding so it has no accelerator.
     *
     * Purpose: cancel capture, clear the entry without validation, set empty trigger, and notify applied.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */
    void disable() {
        cancelRecording()
        refreshing = true
        entry.setText("")
        refreshing = false
        binding.setTrigger("")
        errorLabel.setText("")
        applied()
    }
    /*
     * Push a trigger into the entry and run validation.
     *
     * Purpose: set entry text under refreshing, then changedTrigger.
     *
     * Parameters:
     *   trigger — accelerator string to show and apply.
     *
     * Returns: nothing.
     */
    void setTrigger(String trigger) {
        refreshing = true
        entry.setText(trigger)
        refreshing = false
        changedTrigger(trigger)
    }
    /*
     * Reload widgets from the current CommandBinding.
     *
     * Purpose: cancel capture, sync entry text, clear errors.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */
    void refresh() {
        refreshing = true
        cancelRecording()
        entry.setText(binding.trigger)
        errorLabel.setText("")
        refreshing = false
    }
    /*
     * Show or hide every widget in this preference row.
     *
     * Purpose: toggle visibility of name, entry, buttons, and error.
     *
     * Parameters:
     *   visible — true to show the row.
     *
     * Returns: nothing.
     */
    void setVisible(bool visible) {
        name.setVisible(visible)
        entry.setVisible(visible)
        recordButton.setVisible(visible)
        resetButton.setVisible(visible)
        disableButton.setVisible(visible)
        errorLabel.setVisible(visible)
    }
}

KeyboardPreference KeyboardPreference._self() from "cwhip_gtk_self"
