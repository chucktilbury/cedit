int64 Cedit.findMatchingLine(list lines, int64 fromIndex, String target, int64 limit) {
        int64 end = fromIndex + limit
        if (end > lines.length) { end = lines.length }
        int64 index = fromIndex
        while (index < end) {
            if ((lines[index] as String).equals(target)) { return(index) }
            index = index + 1
        }
        return(-1)
    }

void Cedit.updateUnsavedMarks(EditorDocument document) {
        if (document == null) { return }
        document.view.clearLineMarks("unsaved")
        if (!settings.showUnsavedMarks) { return }
        if (!document.view.modified()) { return }
        list diskLines = document.diskText.split("\n")
        list liveLines = document.view.text().split("\n")
        int64 limit = 2000
        int64 marked = 0
        int64 lookAhead = 200
        int64 diskIndex = 0
        int64 liveIndex = 0
        while (diskIndex < diskLines.length || liveIndex < liveLines.length) {
            if (marked >= limit) {
                status.setText("Unsaved marks truncated")
                return
            }
            if (diskIndex < diskLines.length && liveIndex < liveLines.length &&
                (diskLines[diskIndex] as String).equals(liveLines[liveIndex] as String)) {
                diskIndex = diskIndex + 1
                liveIndex = liveIndex + 1
                continue
            }
            if (diskIndex >= diskLines.length) {
                document.view.addLineMark("unsaved", liveIndex + 1)
                marked = marked + 1
                liveIndex = liveIndex + 1
                continue
            }
            if (liveIndex >= liveLines.length) {
                diskIndex = diskIndex + 1
                continue
            }
            int64 diskInLive = findMatchingLine(liveLines, liveIndex + 1,
                diskLines[diskIndex] as String, lookAhead)
            int64 liveInDisk = findMatchingLine(diskLines, diskIndex + 1,
                liveLines[liveIndex] as String, lookAhead)
            if (diskInLive >= 0 && (liveInDisk < 0 ||
                diskInLive - liveIndex <= liveInDisk - diskIndex)) {
                while (liveIndex < diskInLive) {
                    if (marked >= limit) {
                        status.setText("Unsaved marks truncated")
                        return
                    }
                    document.view.addLineMark("unsaved", liveIndex + 1)
                    marked = marked + 1
                    liveIndex = liveIndex + 1
                }
                continue
            }
            if (liveInDisk >= 0) {
                diskIndex = liveInDisk
                continue
            }
            document.view.addLineMark("unsaved", liveIndex + 1)
            marked = marked + 1
            diskIndex = diskIndex + 1
            liveIndex = liveIndex + 1
        }
    }

void Cedit.clearUnsavedMarks(EditorDocument document) {
        if (document == null) { return }
        document.view.clearLineMarks("unsaved")
    }

void Cedit.scheduleUnsavedMarks() {
        if (unsavedMarksPending) { return }
        unsavedMarksPending = true
        Gtk.Application().schedule(50, unsavedMarksAction)
    }

void Cedit.flushUnsavedMarks() {
        unsavedMarksPending = false
        if (window == null || window.disposed()) { return }
        updateUnsavedMarks(currentDocument())
    }
