/*
 * src/recentEntry.cw - Recent menu row that reopens a remembered path.
 *
 * Created: 2026-10-29
 * Author: Auto
 *
 * Changelog:
 *   2026-10-29  Initial file.
 *   2026-11-13  CODING headers and method comments.
 */

/*
 * RecentEntry for cedit; see method comments below.
 */
class RecentEntry {
    RecentEntry _self()
    Cedit editor
    String path

    /*
     * RecentEntry
     *
     * Purpose: RecentEntry for the editor.
     *
     * Parameters:
     *   owner.
     *   filePath.
     *
     * Returns: RecentEntry.
     */

    RecentEntry(Cedit owner, String filePath) {
        editor = owner
        path = filePath
    }

    /*
     * choose
     *
     * Purpose: choose for the editor.
     *
     * Parameters:
     *   none.
     *
     * Returns: nothing.
     */

    void choose() {
        editor.openRecentPath(path)
    }
}
RecentEntry RecentEntry._self() from "cwhip_gtk_self"
