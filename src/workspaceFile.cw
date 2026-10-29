class WorkspaceFile {
    String path
    int64 line
    int64 column
    WorkspaceFile(String file, int64 row, int64 col) {
        path = file
        line = row
        column = col
    }
}

// Project metadata paths are always derived from the canonical root, never
// from persisted contents.
