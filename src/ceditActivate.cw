void Cedit.activate() {
        if (window != null) {
            if (!window.disposed()) {
                window.present()
                return
            }
        }
        documents = []
        focusedDocument = null
        automaticSaving = false
        changingDocuments = false
        recentFiles = []
        openFailures = []
        collectingFailures = false
        pendingCloseDocument = null
        pendingCloseAll = false
        closingAll = false
        syncingView = false
        allowWindowClose = false
        searchDialogOpen = false
        fileDialog = null
        dialogDocument = null
        dialogClosing = false
        activeProject = null
        nextProject = null
        savingProject = null
        nextFolder = ""
        switchOp = ""
        projectOp = ""
        projectSaveErrors = ""
        chooserPurpose = ""
        projectSaves = 0
        quitReady = false
        presented = false
        confirmOp = ""
        overrideRows = []
        hasAutomaticSaveErrors = false
        settings = CeditSettings()
        int64 commandIndex = 0
        while (commandIndex < settings.commands.length) {
            CommandBinding binding = settings.commands[commandIndex] as CommandBinding
            binding.action = commandAction(binding.id)
            commandIndex = commandIndex + 1
        }
        persistedText = settings.original
        savePending = false
        saveAgain = false
        closeAfterSave = false
        window = Gtk.Window("cedit")
        window.setDefaultSize(1000, 700)
        layout = Gtk.Box(Gtk.Box.VERTICAL, 5)
        window.setChild(layout)
        menu = Gtk.MenuBar()
        layout.append(menu)
        documentItems = []
        int64 fileMenu = menu.addMenu("File")
        newItem = menu.addItem(fileMenu, "New", commandAction("new"))
        openItem = menu.addItem(fileMenu, "Open...", commandAction("open"))
        openFolderItem = menu.addItem(fileMenu, "Open Folder...", _self().chooseFolder)
        recentItem = menu.addItem(fileMenu, "Recent", recentAction)
        menu.addSeparator(fileMenu)
        documentItems.append(menu.addItem(fileMenu, "Save", commandAction("save")))
        documentItems.append(menu.addItem(fileMenu, "Save As...", commandAction("save-as")))
        documentItems.append(menu.addItem(fileMenu, "Save All", commandAction("save-all")))
        menu.addSeparator(fileMenu)
        documentItems.append(menu.addItem(fileMenu, "Close", commandAction("close")))
        documentItems.append(menu.addItem(fileMenu, "Close All", commandAction("close-all")))
        reloadItem = menu.addItem(fileMenu, "Reload", commandAction("reload"))
        menu.addSeparator(fileMenu)
        quitItem = menu.addItem(fileMenu, "Quit", commandAction("quit"))
        int64 editMenu = menu.addMenu("Edit")
        undoItem = menu.addItem(editMenu, "Undo", commandAction("undo"))
        redoItem = menu.addItem(editMenu, "Redo", commandAction("redo"))
        cutItem = menu.addItem(editMenu, "Cut", commandAction("cut"))
        copyItem = menu.addItem(editMenu, "Copy", commandAction("copy"))
        documentItems.append(menu.addItem(editMenu, "Paste", commandAction("paste")))
        documentItems.append(menu.addItem(editMenu, "Select All", commandAction("select-all")))
        documentItems.append(menu.addItem(editMenu, "Find", commandAction("find")))
        documentItems.append(menu.addItem(editMenu, "Replace", commandAction("replace")))
        documentItems.append(menu.addItem(editMenu, "Strip Trailing Spaces", commandAction("strip-trailing-spaces")))
        documentItems.append(reloadItem)
        preferencesItem = menu.addItem(editMenu, "Preferences...", commandAction("preferences"))
        int64 viewMenu = menu.addMenu("View")
        lineNumbersItem = menu.addCheckItem(viewMenu, "Show Line Numbers", effectiveLineNumbers(), _self().lineNumbersChecked)
        whitespaceItem = menu.addCheckItem(viewMenu, "Show White Space", settings.showWhitespace, _self().whitespaceChecked)
        indentMarkersItem = menu.addCheckItem(viewMenu, "Show Indent Markers", settings.showIndentMarkers, _self().indentMarkersChecked)
        projectManagerItem = menu.addCheckItem(viewMenu, "Show Project Manager", settings.showProjectManager, _self().projectManagerChecked)
        int64 projectMenu = menu.addMenu("Project")
        projectNewItem = menu.addItem(projectMenu, "New Project...", commandAction("project-new"))
        projectOpenItem = menu.addItem(projectMenu, "Open Project...", commandAction("project-open"))
        projectCloseItem = menu.addItem(projectMenu, "Close Project", commandAction("project-close"))
        menu.addSeparator(projectMenu)
        int64 saveProjectItem = menu.addItem(projectMenu, "Save Project", commandAction("project-save"))
        int64 saveProjectAsItem = menu.addItem(projectMenu, "Save Project As...", commandAction("project-save-as"))
        menu.addSeparator(projectMenu)
        int64 configureProjectItem = menu.addItem(projectMenu, "Configure Project...", commandAction("project-configure"))
        menu.addSeparator(projectMenu)
        int64 deleteProjectItem = menu.addItem(projectMenu, "Delete Project...", commandAction("project-delete"))
        projectItems = []
        projectItems.append(saveProjectItem)
        projectItems.append(saveProjectAsItem)
        projectItems.append(deleteProjectItem)
        projectItems.append(configureProjectItem)
        int64 helpMenu = menu.addMenu("Help")
        aboutItem = menu.addItem(helpMenu, "About cedit...", commandAction("about"))
        searchWindow = Gtk.TransientWindow("Find")
        searchWindow.setDefaultSize(520, 150)
        searchWindow.setTransientFor(window)
        searchWindow.setVisible(false)
        searchLayout = Gtk.Box(Gtk.Box.VERTICAL, 6)
        searchWindow.setChild(searchLayout)
        findRow = Gtk.Box(Gtk.Box.HORIZONTAL, 4)
        findEntry = Gtk.Entry("")
        replaceEntry = Gtk.Entry("")
        findButton = Gtk.Button("Find next")
        replaceButton = Gtk.Button("Replace next")
        replaceAllButton = Gtk.Button("Replace all")
        wholeWordsCheck = Gtk.CheckButton("Whole words")
        caseCheck = Gtk.CheckButton("Case sensitive")
        selectionCheck = Gtk.CheckButton("In selection")
        findRow.append(findEntry)
        findRow.append(findButton)
        searchLayout.append(findRow)
        replaceRow = Gtk.Box(Gtk.Box.HORIZONTAL, 4)
        replaceRow.append(replaceEntry)
        replaceRow.append(replaceButton)
        replaceRow.append(replaceAllButton)
        searchLayout.append(replaceRow)
        optionsRow = Gtk.Box(Gtk.Box.HORIZONTAL, 4)
        optionsRow.append(wholeWordsCheck)
        optionsRow.append(caseCheck)
        optionsRow.append(selectionCheck)
        searchLayout.append(optionsRow)
        replaceRow.setVisible(false)
        notebook = Gtk.Notebook()
        notebook.setHExpand(true)
        notebook.setVExpand(true)
        project = ProjectExplorer(_self().openFile)
        files = ProjectExplorer(_self().openFile)
        files.setProject(System.FileSystem().getCwd(), "Files", "", [])
        sidePanel = Gtk.Box(Gtk.Box.VERTICAL, 4)
        sidePanel.setVExpand(true)
        Gtk.Box sideHeader = Gtk.Box(Gtk.Box.HORIZONTAL, 4)
        sideHeader.append(Gtk.Label("Sidebar"))
        sideClose = Gtk.Button("Close")
        sideClose.onClicked(_self().closeSidePanel)
        sideHeader.append(sideClose)
        sidePanel.append(sideHeader)
        sideNotebook = Gtk.Notebook()
        sideNotebook.setScrollable(true)
        sideNotebook.setVExpand(true)
        sideNotebook.appendPage(project.sidebar, "Project")
        sideNotebook.appendPage(files.sidebar, "Files")
        sidePanel.append(sideNotebook)
        workspace = Gtk.Paned()
        workspace.setHExpand(true)
        workspace.setVExpand(true)
        workspace.append(sidePanel)
        workspace.append(notebook)
        projectManagerWidth = 250
        workspace.setPosition(projectManagerWidth)
        applyProjectManagerVisibility()
        layout.append(workspace)
        notebook.onPageChanged(pageChangedAction)
        closeChoices = Gtk.Box(Gtk.Box.HORIZONTAL, 4)
        closeSaveButton = Gtk.Button("Save")
        closeDiscardButton = Gtk.Button("Discard")
        closeCancelButton = Gtk.Button("Cancel")
        closeChoices.append(closeSaveButton)
        closeChoices.append(closeDiscardButton)
        closeChoices.append(closeCancelButton)
        layout.append(closeChoices)
        closeChoices.setVisible(false)
        diskChoices = Gtk.Box(Gtk.Box.HORIZONTAL, 4)
        diskReloadButton = Gtk.Button("Reload")
        diskSaveButton = Gtk.Button("Save")
        diskCloseButton = Gtk.Button("Close")
        diskChoices.append(Gtk.Label("File changed on disk"))
        diskChoices.append(diskReloadButton)
        diskChoices.append(diskSaveButton)
        diskChoices.append(diskCloseButton)
        diskReloadButton.onClicked(_self().reloadFromDisk)
        diskSaveButton.onClicked(_self().saveOverDisk)
        diskCloseButton.onClicked(_self().closeDiskDocument)
        layout.append(diskChoices)
        diskChoices.setVisible(false)
        confirmChoices = Gtk.Box(Gtk.Box.HORIZONTAL, 4)
        confirmLabel = Gtk.Label("")
        confirmButton = Gtk.Button("Confirm")
        confirmCancelButton = Gtk.Button("Cancel")
        confirmChoices.append(confirmLabel)
        confirmChoices.append(confirmButton)
        confirmChoices.append(confirmCancelButton)
        confirmButton.onClicked(_self().acceptConfirm)
        confirmCancelButton.onClicked(_self().cancelConfirm)
        layout.append(confirmChoices)
        confirmChoices.setVisible(false)
        status = Gtk.Label("Ready")
        status.setHExpand(true)
        layout.append(status)
        client = LanguageClient(_self())
        client.launch(settings.lspCommand)
        findButton.onClicked(findAction)
        replaceButton.onClicked(replaceAction)
        replaceAllButton.onClicked(replaceAllAction)
        searchWindow.onCloseRequest(searchCloseAction)
        closeSaveButton.onClicked(closeSaveAction)
        closeDiscardButton.onClicked(closeDiscardAction)
        closeCancelButton.onClicked(closeCancelAction)
        window.onCloseRequest(closeAction)
        window.onFocusChanged(_self().windowFocusChanged)

        System.Process process = System.Process()
        bool explicitRequest = false
        int64 index = 1
        while (index < process.argc()) {
            String argument = process.arg(index)
            if (!argument.equals("--test")) { explicitRequest = true }
            if (!argument.equals("--test") && !argument.contains("://") && System.FileSystem().isDir(argument)) {
                openRootArgument(argument)
            } else { openFile(argument) }
            index = index + 1
        }
        // Explicit files or folders on the command line take precedence over reopening.
        if (!explicitRequest && settings.reopenLast && !settings.lastRoot.equals("")) {
            CwhipProject last = loadProject(settings.lastRoot, "Could not reopen last project")
            if (last != null) { activateProject(last, true) }
        }
        if (notebook.pageCount() == 0) {
            newDocument()
        }
        window.present()
        presented = true
        scheduleDiskPoll()
        if (!settings.errors.equals("")) {
            Gtk.AlertDialog().show(window, "Settings errors", diagnostic(
                "CEDIT2001", format(
                    "{}\n{}\nAutomatic saving is disabled; repair the file and restart.",
                    settings.path, settings.errors)))
        }
        if (process.argc() > 1 && process.arg(1).equals("--test")) {
            Gtk.Application().post(testAction)
        }
    }

void<> Cedit.commandAction(String command) {
        if (command.equals("save")) { return(saveAction) }
        if (command.equals("save-as")) { return(saveAsAction) }
        if (command.equals("save-all")) { return(_self().saveAll) }
        if (command.equals("strip-trailing-spaces")) { return(_self().stripTrailingSpacesCurrent) }
        if (command.equals("open")) { return(openAction) }
        if (command.equals("new")) { return(newAction) }
        if (command.equals("close")) { return(closeTabAction) }
        if (command.equals("close-all")) { return(_self().closeAll) }
        if (command.equals("reload")) { return(_self().reloadCurrent) }
        if (command.equals("quit")) { return(quitAction) }
        if (command.equals("find")) { return(showFindAction) }
        if (command.equals("replace")) { return(showReplaceAction) }
        if (command.equals("undo")) { return(undoAction) }
        if (command.equals("redo")) { return(redoAction) }
        if (command.equals("cut")) { return(cutAction) }
        if (command.equals("copy")) { return(copyAction) }
        if (command.equals("paste")) { return(pasteAction) }
        if (command.equals("select-all")) { return(selectAllAction) }
        if (command.equals("preferences")) { return(preferencesAction) }
        if (command.equals("project-new")) { return(_self().newProject) }
        if (command.equals("project-open")) { return(_self().openProject) }
        if (command.equals("project-save")) { return(_self().saveProject) }
        if (command.equals("project-save-as")) { return(_self().saveProjectAs) }
        if (command.equals("project-delete")) { return(_self().deleteProject) }
        if (command.equals("project-configure")) { return(_self().showConfigure) }
        if (command.equals("project-close")) { return(_self().closeProject) }
        if (command.equals("view-line-numbers")) { return(_self().toggleLineNumbers) }
        if (command.equals("view-whitespace")) { return(_self().toggleWhitespace) }
        if (command.equals("view-indent-markers")) { return(_self().toggleIndentMarkers) }
        if (command.equals("view-project-manager")) { return(_self().toggleProjectManager) }
        if (command.equals("about")) { return(_self().showAbout) }
        return(null)
    }

void Cedit.configureShortcuts(EditorDocument document) {
        applyDocumentSettings(document)
        document.view.setMarkStyle("diagnostic", "dialog-error-symbolic", "#ffcccc")
        document.view.onChanged(changedAction)
        document.view.onCursorMoved(cursorAction)
        attachDocumentMenu(document)
    }

