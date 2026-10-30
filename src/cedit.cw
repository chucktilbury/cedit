import gtk
import process
import sourceview
import system
import time

include "language.cw"

include "commandBinding.cw"
include "ceditSettings.cw"
include "keyboardPreference.cw"
include "workspaceFile.cw"
include "cwhipProject.cw"
include "overrideRow.cw"
include "editorDocument.cw"
include "projectNode.cw"
include "projectExplorer.cw"
include "recentEntry.cw"

class Cedit {
    Cedit _self()
    CeditSettings settings
    Gtk.TransientWindow preferencesWindow
    Gtk.Box editorPreferences
    Gtk.Box keyboardPreferences
    Gtk.Box startupPreferences
    Gtk.Label preferencesMessage
    Gtk.Entry fontEntry
    Gtk.Entry sizeEntry
    Gtk.Entry tabsEntry
    Gtk.Entry marginEntry
    Gtk.CheckButton spacesCheck
    Gtk.CheckButton numbersCheck
    Gtk.CheckButton wrapCheck
    Gtk.CheckButton highlightCheck
    Gtk.CheckButton saveTabCheck
    Gtk.CheckButton saveWindowCheck
    Gtk.CheckButton stripCheck
    Gtk.CheckButton bracketsCheck
    Gtk.CheckButton autoIndentCheck
    Gtk.CheckButton unsavedMarksCheck
    Gtk.Entry commandSearch
    list keyboardRows
    Gtk.Grid keyboardRowsBox
    Gtk.Box resetChoices
    Gtk.Button confirmResetButton
    Gtk.Button cancelResetButton
    String resetSection
    bool refreshingPreferences
    bool savePending
    bool saveAgain
    bool closeAfterSave
    String savingText
    String persistedText
    int64 preferencesItem
    void<> preferencesAction
    Gtk.Window window
    Gtk.Box layout
    Gtk.MenuBar menu
    ProjectExplorer project
    ProjectExplorer files
    Gtk.Box sidePanel
    Gtk.Notebook sideNotebook
    Gtk.Button sideClose
    Gtk.Paned workspace
    LanguageClient client
    Gtk.Box diskChoices
    Gtk.Button diskReloadButton
    Gtk.Button diskSaveButton
    Gtk.Button diskCloseButton
    EditorDocument diskDocument
    bool diskMissing
    Gtk.Entry lspEntry
    void<> languagePollAction
    void<> languageFlushAction
    void<> diskPollAction
    int64 recentMenu
    list recentEntries
    int64 openFolderItem
    list documentItems
    int64 undoItem
    int64 redoItem
    int64 cutItem
    int64 copyItem
    int64 newItem
    int64 openItem
    int64 quitItem
    int64 reloadItem
    bool menuInitialized
    bool menuReady
    bool menuEditable
    bool menuQuit
    bool menuProjectActive
    bool menuCanUndo
    bool menuCanRedo
    bool menuSelected
    Gtk.FileDialog fileDialog
    EditorDocument dialogDocument
    bool dialogClosing
    Gtk.TransientWindow searchWindow
    Gtk.Box searchLayout
    Gtk.Box findRow
    Gtk.Box replaceRow
    Gtk.Box optionsRow
    Gtk.Entry findEntry
    Gtk.Entry replaceEntry
    Gtk.Notebook notebook
    Gtk.Label status
    Gtk.Button findButton
    Gtk.Button replaceButton
    Gtk.Button replaceAllButton
    Gtk.CheckButton wholeWordsCheck
    Gtk.CheckButton caseCheck
    Gtk.CheckButton selectionCheck
    list openFailures
    bool collectingFailures
    Gtk.Box closeChoices
    Gtk.Button closeSaveButton
    Gtk.Button closeDiscardButton
    Gtk.Button closeCancelButton
    list documents
    list recentFiles
    EditorDocument pendingCloseDocument
    bool pendingCloseAll
    bool closingAll
    bool allowWindowClose
    bool searchDialogOpen
    int64 pageChanges
    EditorDocument focusedDocument
    bool automaticSaving
    bool changingDocuments
    void<> changedAction
    void<> cursorAction
    void<> pageChangedAction
    void<> openAction
    void<> recentAction
    void<> saveAction
    void<> saveAsAction
    void<> newAction
    void<> closeTabAction
    void<> closeSaveAction
    void<> closeDiscardAction
    void<> closeCancelAction
    void<> findAction
    void<> replaceAction
    void<> replaceAllAction
    void<> undoAction
    void<> redoAction
    void<> quitAction
    void<> cutAction
    void<> copyAction
    void<> pasteAction
    void<> selectAllAction
    void<> showFindAction
    void<> showReplaceAction
    bool<> searchCloseAction
    void<list> openResultAction
    void<String> saveResultAction
    bool<> closeAction
    void<> testAction
    CwhipProject activeProject
    CwhipProject nextProject
    CwhipProject savingProject
    String nextFolder
    String switchOp
    String projectOp
    String projectSaveErrors
    String chooserPurpose
    int64 projectSaves
    bool quitReady
    bool presented
    int64 projectNewItem
    int64 projectCloseItem
    int64 lineNumbersItem
    int64 whitespaceItem
    int64 lineEndsItem
    int64 indentMarkersItem
    int64 projectManagerItem
    bool syncingView
    int64 projectManagerWidth
    int64 projectOpenItem
    list projectItems
    int64 aboutItem
    Gtk.Box confirmChoices
    Gtk.Label confirmLabel
    Gtk.Button confirmButton
    Gtk.Button confirmCancelButton
    String confirmOp
    Gtk.CheckButton reopenCheck
    Gtk.Button saveGlobalButton
    Gtk.Button configureProjectButton
    Gtk.Label settingsPathLabel
    Gtk.Label projectNote
    Gtk.TransientWindow aboutWindow
    Gtk.TransientWindow gotoWindow
    Gtk.Entry gotoEntry
    Gtk.Label gotoStatus
    Gtk.TransientWindow projectFindWindow
    Gtk.Entry projectFindEntry
    Gtk.CheckButton projectFindCase
    Gtk.CheckButton projectFindWords
    Gtk.Label projectFindStatus
    GtkSource.View projectFindResults
    list projectFindPaths
    list projectFindLines
    EditorDocument pendingRecoveryDocument
    String pendingRecoveryText
    void<> recoveryPollAction
    list plugins
    list pluginTitles
    int64 lineSpanStart
    int64 lineSpanEnd
    Gtk.TransientWindow configureWindow
    Gtk.Entry configureName
    Gtk.Entry configureExcludes
    list overrideRows
    Gtk.Label configureMessage
    bool hasAutomaticSaveErrors

    void activate()

    void<> commandAction(String command)

    void configureShortcuts(EditorDocument document)

    // Precedence: active project override, then user preference, then default.
    void applyDocumentSettings(EditorDocument document)

    void createPreferences()

    Gtk.Entry preferenceEntry(Gtk.Box page, String label, String text)

    Gtk.CheckButton preferenceCheck(String label, bool active)

    void showPreferences()
    void refreshProjectNote()
    void refreshSettingsPathLabel()
    String settingsRoot()
    void ensureGlobalSettingsFile()
    void recoverStartupFrom(String disk)
    String startupPatch()
    String globalSettingsBase(String disk)
    String seedLocalSettings(String globalText)
    bool writeSettingsFile(String path, String text)
    bool writeMirroredGlobal(String editorText)
    bool writeStartupToGlobal()
    void adoptSettingsRoot(String root)
    void reopenChanged(bool active)
    void persistSettings()
    // The user config stores only the root locator; workspace state stays with the project.
    void rememberProject(String root)
    void forgetProject(String root)
    bool hidePreferences()
    void stopRecording()
    void showEditorPreferences()
    void showKeyboardPreferences()
    void showProjectPreferences()
    void showStartupPreferences()
    void filterCommands(String query)
    int64 preferenceNumber(String text, int64 minimum, int64 maximum)
    void editorCheckChanged(bool active)
    void editorSettingChanged(String text)
    void saveGlobalClicked()
    String readSettingsDisk(String path)
    void resetEditorPreferences()
    void resetKeyboardPreferences()
    void cancelPreferencesReset()
    void confirmPreferencesReset()
    void settingsChanged()
    bool effectiveLineNumbers()
    void publishLineNumbers(bool active)
    void lineNumbersChecked(bool active)
    void toggleLineNumbers()
    void whitespaceChecked(bool active)
    void toggleWhitespace()
    void lineEndsChecked(bool active)
    void toggleLineEnds()
    void indentMarkersChecked(bool active)
    void toggleIndentMarkers()
    void projectManagerChecked(bool active)
    void toggleProjectManager()
    void closeSidePanel()
    void scheduleLanguagePoll()
    void languagePoll()
    void languageFlush()
    void scheduleDiskPoll()
    void diskPoll()
    void openRecentPath(String path)
    void syncViewMenu()
    void applyProjectManagerVisibility()
    void keyboardSettingsChanged()
    bool saveSettings()
    bool makeSettingsDirectory(String directory)
    String diagnostic(String code, String explanation)
    void reportDiagnostic(String code, String explanation)
    void settingsSaveFailure(String detail)
    void settingsSaved(String error)

    // ---- Projects -------------------------------------------------------

    String version()

    void projectFailure(String title, String detail)

    String canonicalFolder(String path, String title)

    CwhipProject loadProject(String path, String title)

    void openRootArgument(String path)

    void chooseProjectFolder(String purpose)

    void newProject()
    void openProject()
    void saveProjectAs()

    void projectFolderChosen(String path)

    void openProjectAt(String path)

    // New and Save As create metadata for a chosen root; source files are never touched.
    void prepareNewProject(String path, bool copy)

    void startNewProject(String op)

    void saveProject()

    void deleteProject()

    void deleteProjectMetadata()

    void beginSwitch(String op)

    void continueSwitch(String op)

    // Starts guarded asynchronous writes; op runs once all writes finish.
    void writeProject(CwhipProject target, bool config, bool workspaceState, String op)

    String projectSaveMessage(String path, String error)

    void addProjectSaveError(String message)

    void projectConfigSaved(String error)

    void projectWorkspaceSaved(String error)

    void finishProjectSave()

    void projectSaveFailed(String op, String errors)

    void performProjectOp(String op)

    void askConfirm(String op, String message, String accept)

    void acceptConfirm()

    void cancelConfirm()

    void closeAllDocuments()

    void detachProject()

    void reapplyDocumentSettings()

    list absolutePaths(CwhipProject target, list paths)

    void activateProject(CwhipProject target, bool restore)

    // Workspace TOML for open documents and explorer state. Paths inside source
    // are root-relative. Files outside source are absolute. When source and
    // target differ (Save As), a path is kept only when that file exists.
    String captureWorkspace(String source, String target)

    // Root-relative path inside origin, or an absolute path outside it.
    String storedDocumentPath(CwhipProject origin, String path, String target, bool filter)

    void noteOpenFiles()

    // ---- Configure Project ------------------------------------------------

    void createConfigure()

    void addOverride(Gtk.Box root, OverrideRow row)

    OverrideRow overrideRow(String key)

    void showConfigure()

    void refreshConfigure()

    void inheritAll()

    void applyConfigure()

    bool hideConfigure()
    void closeConfigure()

    // ---- About ---------------------------------------------------------------

    void showAbout()

    bool hideAbout()
    void closeAbout()

    void newDocument()

    EditorDocument openDocument(String requestedPath)

    // Single opens report on the status line (and in a dialog for files that
    // are not text); a chooser batch collects failures for one dialog.
    void reportOpenFailure(String message, bool dialog)

    void activateDocument(EditorDocument document)

    void openFile(String requestedPath)

    EditorDocument currentDocument()

    void saveCurrent()

    // Saves every modified document that already has a path; untitled
    // documents are left for an explicit Save As.
    void saveAll()

    void stripTrailingSpacesCurrent()

    void saveAsCurrent()

    bool writeDocument(EditorDocument document, String destination)

    void reportSaveFailure(String detail)

    bool commandsBlocked()

    void chooseOpen()

    void chooseFolder()

    void folderOpened(String path)

    void opened(list paths)

    void chooseSave(EditorDocument document, bool closing)

    void savedAs(String path)

    void quit()

    void refreshRecentMenu()
    void openRecent()
    void rememberRecent(String path)
    void attachDocumentMenu(EditorDocument document)

    int64 searchOptions()

    EditorDocument searchDocument()

    void findNext()

    void replaceNext()

    void replaceAll()

    void undoCurrent()

    void redoCurrent()

    void cutCurrent()

    void copyCurrent()

    void pasteCurrent()

    void selectAllCurrent()

    // Captures the selection as the "In selection" scope before focus moves
    // to the search bar, and copies a single-line selection into Find.
    void prepareSearch()

    bool digitsOnly(String text)
    void createGotoLine()
    void showGotoLine()
    bool hideGotoLine()
    void closeGotoLine()
    void acceptGotoLine()

    int64 effectiveTabWidth()
    bool effectiveInsertSpaces()
    String indentUnit()
    void loadSelectedLineSpan()
    void indentCurrent()
    void outdentCurrent()
    void outdentLine(EditorDocument document, int64 line, int64 width)
    String lineCommentPrefix()
    bool supportsBlockComment()
    String lineText(EditorDocument document, int64 line)
    bool lineHasCommentPrefix(String text, String prefix)
    void toggleComment()
    void uncommentLine(EditorDocument document, int64 line, String text, String prefix)
    void toggleBlockComment()
    void updateUnsavedMarks(EditorDocument document)
    void clearUnsavedMarks(EditorDocument document)
    void createProjectFind()
    void showProjectFind()
    bool hideProjectFind()
    bool projectFindMatch(String haystack, String needle, bool caseSensitive, bool wholeWords)
    void appendProjectFindHit(String path, int64 line, String snippet)
    void scanProjectFindText(String path, String contents, String query, bool caseSensitive,
                             bool wholeWords)
    void scanProjectFindDir(String dir, String query, bool caseSensitive, bool wholeWords,
                            bool showHidden)
    void runProjectFind()
    void projectFindActivated(int64 line)
    String recoveryDir()
    String recoveryPathFor(String documentPath)
    void ensureRecoveryDir()
    void writeRecovery(EditorDocument document)
    void clearRecovery(EditorDocument document)
    void writeAllRecoveries()
    void scheduleRecoveryPoll()
    void recoveryPoll()
    String readRecoveryBody(String recoveryFile, String expectedPath)
    void offerRecoveryForDocuments()
    void acceptRecovery()
    void discardRecovery()
    void registerPlugin(String id, String title)
    void loadBuiltinPlugins()
    void pluginInsertDate()
    void pluginToggleDebug()
    void addPluginMenus()

    void showFind()

    void showReplace()

    bool hideSearchDialog()

    void closeSearchDialog()

    void changed()

    void cursorMoved()

    void pageChanged()
    void pageChangedDeferred()

    void automaticSave(EditorDocument document)

    String automaticSaveErrors()

    bool recomputeAutomaticSaveErrors()

    void windowFocusChanged(bool active)

    void refreshTab(EditorDocument document)

    void updateStatusText()

    void updateStatus()

    void updateSelectionActions()

    void updateEditActions()

    void updateMenu()

    bool workspaceNeedsSave()

    bool requestClose()

    void closePreferencesWindows()

    void closeAll()

    void closeNextInBatch()

    void closeProject()

    void closeCurrentDocument()

    String readDiskFile(String path)
    void clearDiskPrompt()
    void checkDiskChange()
    void reloadFromDisk()
    void saveOverDisk()
    void closeDiskDocument()
    void reloadCurrent()
    void closeDocument(EditorDocument document)

    void removeDocument(EditorDocument document)

    void focusAfterClose()

    EditorDocument firstModifiedDocument()

    void savePendingClose()

    void continueSavedClose()

    void discardPendingClose()

    void cancelPendingClose()

    void finishPendingClose()

    void test()

    int64 byteSpanBound(int64 value, int64 length)
    String byteSpan(String text, int64 first, int64 last)
}

include "ceditActivate.cw"
include "ceditApplyDocumentSettings.cw"
include "ceditConfirmPreferencesReset.cw"
include "ceditOpenProjectAt.cw"
include "ceditCloseAllDocuments.cw"
include "ceditApplyConfigure.cw"
include "ceditWriteDocument.cw"
include "ceditPrepareSearch.cw"
include "ceditGotoLine.cw"
include "ceditEditLines.cw"
include "ceditDirtyMarks.cw"
include "ceditProjectFind.cw"
include "ceditRecovery.cw"
include "ceditPlugins.cw"
include "ceditCloseNextInBatch.cw"
include "ceditTest.cw"


Cedit Cedit._self() from "cwhip_gtk_self"

start {
    Gtk.Application app = Gtk.Application("org.cw.Editor")
    Cedit editor = Cedit()
    editor.changedAction = editor.changed
    editor.cursorAction = editor.cursorMoved
    editor.pageChangedAction = editor.pageChanged
    editor.openAction = editor.chooseOpen
    editor.recentAction = editor.openRecent
    editor.saveAction = editor.saveCurrent
    editor.saveAsAction = editor.saveAsCurrent
    editor.newAction = editor.newDocument
    editor.closeTabAction = editor.closeCurrentDocument
    editor.closeSaveAction = editor.savePendingClose
    editor.closeDiscardAction = editor.discardPendingClose
    editor.closeCancelAction = editor.cancelPendingClose
    editor.findAction = editor.findNext
    editor.replaceAction = editor.replaceNext
    editor.replaceAllAction = editor.replaceAll
    editor.undoAction = editor.undoCurrent
    editor.redoAction = editor.redoCurrent
    editor.quitAction = editor.quit
    editor.cutAction = editor.cutCurrent
    editor.copyAction = editor.copyCurrent
    editor.pasteAction = editor.pasteCurrent
    editor.selectAllAction = editor.selectAllCurrent
    editor.showFindAction = editor.showFind
    editor.showReplaceAction = editor.showReplace
    editor.searchCloseAction = editor.hideSearchDialog
    editor.openResultAction = editor.opened
    editor.saveResultAction = editor.savedAs
    editor.closeAction = editor.requestClose
    editor.testAction = editor.test
    editor.preferencesAction = editor.showPreferences
    editor.languagePollAction = editor.languagePoll
    editor.languageFlushAction = editor.languageFlush
    editor.diskPollAction = editor.diskPoll
    editor.recoveryPollAction = editor.recoveryPoll
    app.onActivate(editor.activate)
    app.run()
    app.shutdown()
}
