void Cedit.updateUnsavedMarks(EditorDocument document) {
        if (document == null) { return }
        document.view.clearLineMarks("unsaved")
        if (!document.view.modified()) { return }
        list diskLines = document.diskText.split("\n")
        list liveLines = document.view.text().split("\n")
        int64 limit = 2000
        int64 marked = 0
        int64 maxLine = liveLines.length
        if (diskLines.length > maxLine) { maxLine = diskLines.length }
        int64 line = 1
        while (line <= maxLine) {
            String disk = ""
            String live = ""
            if (line <= diskLines.length) { disk = diskLines[line - 1] as String }
            if (line <= liveLines.length) { live = liveLines[line - 1] as String }
            if (!disk.equals(live)) {
                if (marked >= limit) {
                    status.setText("Unsaved marks truncated")
                    return
                }
                if (line <= liveLines.length) {
                    document.view.addLineMark("unsaved", line)
                    marked = marked + 1
                }
            }
            line = line + 1
        }
    }

void Cedit.clearUnsavedMarks(EditorDocument document) {
        if (document == null) { return }
        document.view.clearLineMarks("unsaved")
    }
