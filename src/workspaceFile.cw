/*
 * src/workspaceFile.cw - One open-tab path plus caret for workspace persistence.
 *
 * Created: 2026-10-29
 * Author: Auto
 *
 * Changelog:
 *   2026-10-29  Initial file.
 *   2026-11-13  CODING headers and method comments.
 */

/*
 * WorkspaceFile for cedit; see method comments below.
 */
class WorkspaceFile {
    String path
    int64 line
    int64 column
    /*
     * WorkspaceFile
     *
     * Purpose: WorkspaceFile for the editor.
     *
     * Parameters:
     *   file.
     *   row.
     *   col.
     *
     * Returns: WorkspaceFile.
     */

    WorkspaceFile(String file, int64 row, int64 col) {
        path = file
        line = row
        column = col
    }
}

// Project metadata paths are always derived from the canonical root, never
// from persisted contents.
