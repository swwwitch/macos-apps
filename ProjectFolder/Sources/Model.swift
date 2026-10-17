import AppKit
import ServiceManagement
import ApplicationServices

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// The form, settings, the app hotkey and folder creation.
@MainActor
final class Model: ObservableObject {
    private let defaults = UserDefaults.standard

    // MARK: Form (クライアント・地域・チェックの状態は次回も残す。月・日・備考は毎回空に)
    @Published var client = UserDefaults.standard.string(forKey: "client") ?? ""
    @Published var region = UserDefaults.standard.string(forKey: "region") ?? ""
    @Published var year = String(FolderName.defaultYear(for: Date()))
    @Published var month = ""
    @Published var day = ""
    @Published var memo = ""
    @Published var useToday = UserDefaults.standard.object(forKey: "useToday") as? Bool ?? true
    /// Where folders go: 指定（the chosen folder）, 最前面のフォルダー, 最近使ったフォルダー.
    enum DestinationKind: String, CaseIterable { case specified, front, recent }
    /// 1.0's 「最前面のフォルダー」 checkbox carries over: off = 指定.
    @Published var destinationKind = DestinationKind(rawValue: UserDefaults.standard.string(forKey: "destinationKind") ?? "")
        ?? ((UserDefaults.standard.object(forKey: "useFrontFolder") as? Bool ?? true) ? .front : .specified)
    var useFrontFolder: Bool { destinationKind == .front }
    /// Finder and Path Finder history, read when the window opens.
    @Published var recentFolders: [URL] = []
    @Published var recentChoice = UserDefaults.standard.string(forKey: "recentChoice").map { URL(fileURLWithPath: $0, isDirectory: true) }
    /// Bulk mode: one folder per line of `bulkText` (the text is kept until the folders are made).
    /// 1件ずつ・まとめて（テキストから）・プロジェクト. 1.1's bulkMode carries over.
    enum Mode: String, CaseIterable { case single, bulk, project }
    @Published var mode = Mode(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "")
        ?? (UserDefaults.standard.bool(forKey: "bulkMode") ? .bulk : .single)
    var bulkMode: Bool { mode == .bulk }
    @Published var bulkText = ""
    /// Folder structures from Settings › プロジェクト; the sample is there until the user changes the list.
    @Published var projects = UserDefaults.standard.data(forKey: "projects").flatMap { try? JSONDecoder().decode([Project].self, from: $0) } ?? Project.samples
    @Published var selectedProjectID = UserDefaults.standard.string(forKey: "selectedProject").flatMap(UUID.init(uuidString:))
    /// Folder that holds the structure; empty = straight into the location.
    @Published var projectRoot = ""
    /// Folder of the front Finder / Path Finder window when the window was shown (re-read when creating).
    @Published var frontFolder: URL?
    @Published var frontFolderProblem: String?

    // MARK: Settings
    @Published var baseFolder = UserDefaults.standard.string(forKey: "baseFolder") ?? Model.defaultBaseFolder
    @Published var openAfter = UserDefaults.standard.object(forKey: "openAfter") as? Bool ?? true
    @Published var revealInParent = UserDefaults.standard.bool(forKey: "revealInParent")
    @Published var viewer = FileViewers.Choice(rawValue: UserDefaults.standard.string(forKey: "viewer") ?? "") ?? .automatic
    @Published var addToSidebar = UserDefaults.standard.bool(forKey: "addToSidebar")
    /// Finder's sidebar too (ファイル › サイドバーに追加), separate from Path Finder's.
    @Published var addToFinderSidebar = UserDefaults.standard.bool(forKey: "addToFinderSidebar")
    var needsAccessibility: Bool { addToSidebar || addToFinderSidebar }
    @Published var makeLink = UserDefaults.standard.object(forKey: "makeLink") as? Bool ?? FileManager.default.fileExists(atPath: Model.defaultLinkFolder)
    @Published var linkFolder = UserDefaults.standard.string(forKey: "linkFolder") ?? Model.defaultLinkFolder
    @Published var closeAfter = UserDefaults.standard.object(forKey: "closeAfter") as? Bool ?? true
    @Published var keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true
    /// Names are written NFC (Foundation writes NFD), so Dropbox and Windows see the usual spelling.
    @Published var normalizeNFC = UserDefaults.standard.object(forKey: "normalizeNFC") as? Bool ?? true
    /// Refuse names Windows cannot open (\ * ? " < > |, trailing dot or space, CON …).
    @Published var windowsSafe = UserDefaults.standard.object(forKey: "windowsSafe") as? Bool ?? true
    /// 1件ずつ: also make the chosen project's structure inside the new folder.
    @Published var singleWithProject = UserDefaults.standard.bool(forKey: "singleWithProject")
    /// 名前の規則 (stored with the projects; shared when a shared folder is set).
    @Published var rule = UserDefaults.standard.data(forKey: "namingRule").flatMap { try? JSONDecoder().decode(NamingRule.self, from: $0) }?.migrated() ?? NamingRule()
    /// Folder (Dropbox …) holding ProjectFolder/Library.json and Templates for several Macs; empty = this Mac only.
    @Published var sharedFolder = UserDefaults.standard.string(forKey: "sharedFolder") ?? ""
    @Published var sharedProblem: String?
    private var libraryLoaded: Date?
    /// 直前の作成を取り消す: what the last creation made (memory only).
    @Published var lastCreation: CreationRecord?

    // MARK: App hotkey (アプリを呼び出すホットキー). ⇧⌥⌘N by default, only while Finder or Path Finder (or this app) is in front.
    static let defaultShortcut = Shortcut.km(45, Shortcut.command | Shortcut.shift | Shortcut.option, "N")
    /// Empty data means the key was cleared on purpose (a missing key means the default).
    @Published var appShortcut: Shortcut? = {
        guard let data = UserDefaults.standard.data(forKey: "appShortcut") else { return Model.defaultShortcut }
        return try? JSONDecoder().decode(Shortcut.self, from: data)
    }()
    @Published var appHotkeyEnabled = UserDefaults.standard.object(forKey: "appHotkeyEnabled") as? Bool ?? true
    /// Apps that must be in front for the hotkey to be registered.
    static var hotkeyApps: [String] { ["com.apple.finder"] + FileViewers.pathFinderIDs + [Bundle.main.bundleIdentifier ?? ""] }
    private var hotkeyRegistered = false
    @Published var hotkeyFailure: OSStatus?
    var onAppHotkey: (() -> Void)?
    /// Paused by HotkeySet while a key is recorded in Settings.
    let hotkeys = HotkeySet(signature: "FMKR")

    // MARK: State
    @Published var status = L("ready")
    @Published var statusIsError = false
    @Published var busy = false
    @Published var loginStatus = ""
    @Published var loginOn = false
    var onCreated: (() -> Void)?

    /// The macro's destination (Dropbox-shared) when it exists here, else Documents.
    static var defaultBaseFolder: String {
        let shared = NSString(string: "~/sw Dropbox/takano masahiro/Dropbox-shared").expandingTildeInPath
        return FileManager.default.fileExists(atPath: shared) ? shared : FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").path
    }
    static var defaultLinkFolder: String { NSString(string: "~/sw Dropbox/takano masahiro/Dropbox-shared/AT-Recent").expandingTildeInPath }

    private var observers: [NSObjectProtocol] = []

    init() {
        hotkeys.action = { [weak self] _ in self?.onAppHotkey?() }
        // After recording, register again so a conflict with another app is reported.
        HotkeyRecorder.shared.onRecordingChanged.append { [weak self] recording in if !recording { self?.refreshHotkey() } }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLogin(); self?.reloadLibraryIfChanged() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateHotkeyRegistration() }
        })
        Library.sharedPath = sharedFolder
        reloadLibraryIfChanged()
        refreshLogin(); refreshHotkey()
    }

    func save() {
        defaults.set(baseFolder, forKey: "baseFolder")
        defaults.set(openAfter, forKey: "openAfter")
        defaults.set(revealInParent, forKey: "revealInParent")
        defaults.set(viewer.rawValue, forKey: "viewer")
        defaults.set(addToSidebar, forKey: "addToSidebar")
        defaults.set(addToFinderSidebar, forKey: "addToFinderSidebar")
        defaults.set(makeLink, forKey: "makeLink")
        defaults.set(linkFolder, forKey: "linkFolder")
        defaults.set(closeAfter, forKey: "closeAfter")
        defaults.set(keepRunning, forKey: "keepRunning")
        defaults.set(normalizeNFC, forKey: "normalizeNFC")
        defaults.set(windowsSafe, forKey: "windowsSafe")
        defaults.set(appShortcut.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: "appShortcut")
        defaults.set(appHotkeyEnabled, forKey: "appHotkeyEnabled")
        refreshHotkey()
    }
    /// Re-reads the settings shared by SettingsSync (projects and the naming rule are shared through Library.json instead).
    func reloadSharedSettings() {
        openAfter = defaults.object(forKey: "openAfter") as? Bool ?? true
        revealInParent = defaults.bool(forKey: "revealInParent")
        viewer = FileViewers.Choice(rawValue: defaults.string(forKey: "viewer") ?? "") ?? .automatic
        addToSidebar = defaults.bool(forKey: "addToSidebar")
        addToFinderSidebar = defaults.bool(forKey: "addToFinderSidebar")
        makeLink = defaults.object(forKey: "makeLink") as? Bool ?? FileManager.default.fileExists(atPath: Model.defaultLinkFolder)
        closeAfter = defaults.object(forKey: "closeAfter") as? Bool ?? true
        normalizeNFC = defaults.object(forKey: "normalizeNFC") as? Bool ?? true
        windowsSafe = defaults.object(forKey: "windowsSafe") as? Bool ?? true
    }
    func saveForm() {
        defaults.set(client.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "client")
        defaults.set(region.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "region")
        defaults.set(useToday, forKey: "useToday")
        defaults.set(destinationKind.rawValue, forKey: "destinationKind")
        defaults.set(recentChoice?.path, forKey: "recentChoice")
        defaults.set(mode.rawValue, forKey: "mode")
        defaults.set(selectedProjectID?.uuidString, forKey: "selectedProject")
        defaults.set(singleWithProject, forKey: "singleWithProject")
    }

    // MARK: Form

    var name: FolderName {
        FolderName(client: client, region: region, year: year, month: month, day: day, memo: memo, useToday: useToday,
                   pattern: rule.pattern, dateStyle: rule.style)
    }
    var preview: Result<String, FolderName.Problem> {
        let result = name.build()
        if case .success(let value) = result, windowsSafe, FileNames.windowsProblem(value) { return .failure(.windowsName) }
        return result
    }
    enum Field { case client, region, memo }
    /// The field names from 名前の規則, or the standard ones.
    func label(_ field: Field) -> String {
        switch field {
        case .client: return rule.clientLabel.isEmpty ? L("client") : rule.clientLabel
        case .region: return rule.regionLabel.isEmpty ? L("region") : rule.regionLabel
        case .memo: return rule.memoLabel.isEmpty ? L("memo") : rule.memoLabel
        }
    }
    var options: BulkNames.Options {
        BulkNames.Options(windowsSafe: windowsSafe, caseSensitive: destination.map(FileNames.caseSensitive) ?? false)
    }
    static func dateText(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    /// {{project}} and {{date}} for names in a structure.
    func variables(project: String) -> [String: String] { ["project": project, "date": Model.dateText()] }
    /// 1件ずつ with a project: the structure inside the folder about to be made.
    var singleProjectEntries: [BulkNames.Entry] {
        guard singleWithProject, let project = selectedProject, case .success(let name) = preview else { return [] }
        return Project.entries(project.structure, root: "", variables: variables(project: name), options: options)
    }
    var baseURL: URL { URL(fileURLWithPath: NSString(string: baseFolder).expandingTildeInPath, isDirectory: true) }
    /// Where the folder goes: the front window's folder when chosen and available, else the base folder.
    var destination: URL? {
        switch destinationKind {
        case .specified: return baseURL
        case .front: return frontFolder
        case .recent: return recentChoice.flatMap { recentFolders.contains($0) ? $0 : nil }
        }
    }
    func refreshRecentFolders() {
        recentFolders = FileViewers.recentFolders(limit: 15).map { $0.standardizedFileURL }
        // Keep the last choice when it is still in the history, else the newest folder.
        if recentChoice == nil || !recentFolders.contains(recentChoice!) { recentChoice = recentFolders.first }
    }
    /// 「指定」: a folder chosen in the form is the default location from then on (the same setting as 設定 › 作成先).
    func chooseSpecifiedFolder(_ url: URL) { baseFolder = url.path; save() }

    /// A fresh form each time the window opens: the date fields go back to their defaults.
    func prepareForm() {
        year = String(FolderName.defaultYear(for: Date())); month = ""; day = ""; memo = ""
        refreshFrontFolder(); refreshRecentFolders()
    }
    var destinationProblem: String {
        destinationKind == .recent ? L("noRecentFolder") : (frontFolderProblem ?? L("noFrontFolder"))
    }
    func refreshFrontFolder() {
        switch FileViewers.frontFolder() {
        case .success(let url): frontFolder = url; frontFolderProblem = url == nil ? L("noFrontFolder") : nil
        case .failure(.denied(let viewer)): frontFolder = nil; frontFolderProblem = String(format: L("frontDenied"), viewer)
        case .failure(.failed(let message)): frontFolder = nil; frontFolderProblem = L("frontFailed") + message
        }
    }

    // MARK: Creating

    func report(_ text: String, error: Bool) {
        status = text; statusIsError = error
        if error { NSSound.beep() }
    }

    // MARK: Bulk

    var bulkEntries: [BulkNames.Entry] { BulkNames.parse(bulkText, options: options) }
    enum BulkState { case new, exists, invalid }
    func state(of entry: BulkNames.Entry) -> BulkState {
        guard let path = entry.path else { return .invalid }
        guard let parent = destination else { return .new }
        return FileManager.default.fileExists(atPath: parent.appendingPathComponent(path).path) ? .exists : .new
    }
    var bulkCanCreate: Bool { destination != nil && bulkEntries.contains { state(of: $0) == .new } }

    // MARK: Projects

    var selectedProject: Project? { projects.first { $0.id == selectedProjectID } ?? projects.first }
    var projectRootName: String { projectRoot.trimmingCharacters(in: .whitespaces) }
    /// {{project}}: the folder name, or the project's name when the structure goes straight into the location.
    var projectVariableName: String { projectRootName.isEmpty ? (selectedProject?.name ?? "") : projectRootName }
    var projectEntries: [BulkNames.Entry] {
        selectedProject.map { Project.entries($0.structure, root: projectRoot, variables: variables(project: projectVariableName), options: options) } ?? []
    }
    var projectCanCreate: Bool { destination != nil && projectEntries.contains { state(of: $0) == .new } }
    func saveProjects() {
        defaults.set(try? JSONEncoder().encode(projects), forKey: "projects")
        saveLibrary()
    }
    func saveRule() {
        defaults.set(try? JSONEncoder().encode(rule), forKey: "namingRule")
        saveLibrary()
    }
    @discardableResult
    func addProject(copying source: Project? = nil) -> Project {
        let project = source.map { Project(name: $0.name + " " + L("project.copySuffix"), structure: $0.structure) } ?? Project(name: L("project.newName"), structure: "")
        projects.append(project); saveProjects()
        return project
    }
    func removeProject(_ id: UUID) {
        projects.removeAll { $0.id == id }; saveProjects()
        if selectedProjectID == id { selectedProjectID = projects.first?.id; saveForm() }
    }
    func updateProject(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index] = project; saveProjects()
    }

    // MARK: Shared library

    /// Choosing a shared folder: its Library.json wins when it exists (another Mac set it up), else this Mac's
    /// projects and rule are written there. Templates are filled in without overwriting.
    func setSharedFolder(_ path: String) {
        sharedFolder = path
        defaults.set(path, forKey: "sharedFolder")
        Library.sharedPath = path
        libraryLoaded = nil
        if Library.load() != nil { reloadLibraryIfChanged() } else { saveLibrary() }
        FileTemplates.installDefaults()
    }
    func reloadLibraryIfChanged() {
        guard !sharedFolder.isEmpty else { sharedProblem = nil; return }
        guard let modified = Library.modified() else { sharedProblem = nil; return }
        guard libraryLoaded == nil || modified > libraryLoaded! else { return }
        guard let contents = Library.load() else { sharedProblem = String(format: L("shared.unreadable"), Library.file.path); return }
        sharedProblem = nil
        libraryLoaded = modified
        projects = contents.projects; rule = contents.rule.migrated()
        defaults.set(try? JSONEncoder().encode(projects), forKey: "projects")
        defaults.set(try? JSONEncoder().encode(rule), forKey: "namingRule")
    }
    private func saveLibrary() {
        guard !sharedFolder.isEmpty else { return }
        do {
            try Library.save(Library.Contents(projects: projects, rule: rule))
            libraryLoaded = Library.modified(); sharedProblem = nil
        } catch {
            sharedProblem = L("shared.saveFailed") + error.localizedDescription
        }
    }

    // MARK: Undo

    /// 直前の作成を取り消す: unchanged items go to the Trash; anything edited since stays (B10).
    func undoLast() {
        guard let record = lastCreation, !busy else { return }
        let result = record.undo()
        lastCreation = nil
        var lines = [String(format: L("undo.result"), String(result.trashed))]
        if !result.kept.isEmpty { lines.append(String(format: L("undo.kept"), result.kept.prefix(5).joined(separator: "、") + (result.kept.count > 5 ? "…" : ""))) }
        report(lines.joined(separator: "\n"), error: false)
    }

    private var linkFolderURL: URL { URL(fileURLWithPath: NSString(string: linkFolder).expandingTildeInPath, isDirectory: true) }
    /// AT-Recent link; the warning (if any) is returned for the result.
    private func link(_ folder: URL, into record: inout CreationRecord) -> String? {
        switch RecentLink.make(to: folder, in: linkFolderURL) {
        case .success(let link): record.links.append((link, folder)); return nil
        case .failure(.noFolder): return String(format: L("linkNoFolder"), linkFolder)
        case .failure(.occupied): return L("linkOccupied")
        case .failure(.failed(let message)): return L("linkFailed") + message
        }
    }

    // MARK: Creating in bulk / project

    /// Creates every new line; existing items and unusable lines are skipped and counted (never overwritten).
    func createBulk() {
        guard !busy else { return }
        if useFrontFolder { refreshFrontFolder() }
        guard let parent = destination else { return report(destinationProblem, error: true) }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return report(String(format: L("noDestination"), parent.path), error: true)
        }
        let project = mode == .project
        let entries = project ? projectEntries : bulkEntries
        guard !entries.isEmpty else { return report(L(project ? "project.empty" : "bulk.empty"), error: true) }
        busy = true
        defer { busy = false }
        // AT-Recent links are made for 1件ずつ only.
        let made = Creator.make(entries, in: parent, projectName: project ? projectVariableName : "", nfc: normalizeNFC)
        saveForm()
        if !made.record.items.isEmpty { lastCreation = made.record }
        var lines = [String(format: L("bulk.result"), String(made.created.count), parent.path)]
        if made.existing > 0 { lines.append(String(format: L("bulk.skippedExisting"), String(made.existing))) }
        if made.invalid > 0 { lines.append(String(format: L("bulk.skippedInvalid"), String(made.invalid))) }
        lines += made.failures
        if !made.missingTemplates.isEmpty { lines.append(String(format: L("template.missing"), made.missingTemplates.sorted().joined(separator: "、"))) }
        let problem = !made.failures.isEmpty || made.created.isEmpty
        report(lines.joined(separator: "\n"), error: problem)
        guard !made.created.isEmpty else { return }
        if openAfter {
            if project && !projectRootName.isEmpty { FileViewers.show(made.record.items.first?.url ?? parent.appendingPathComponent(projectRootName), choice: viewer, reveal: revealInParent) }
            else { FileViewers.show(made.created[0], choice: viewer, reveal: true) }
        }
        // A project into an existing folder only fills what is missing, so existing items do not count as a problem there.
        if !problem && made.invalid == 0 && made.missingTemplates.isEmpty && (project || made.existing == 0) {
            if project { projectRoot = "" } else { bulkText = "" }
            onCreated?()
        }
    }

    // MARK: Creating one folder

    func create() {
        guard !busy else { return }
        if mode != .single { return createBulk() }
        let folderName: String
        switch preview {
        case .failure(let problem): return report(L(problem.key), error: true)
        case .success(let value): folderName = normalizeNFC ? value.precomposedStringWithCanonicalMapping : value
        }
        // The front window may have changed since the form opened.
        if useFrontFolder { refreshFrontFolder() }
        guard let parent = destination else { return report(destinationProblem, error: true) }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return report(String(format: L("noDestination"), parent.path), error: true)
        }
        var folder = parent.appendingPathComponent(folderName, isDirectory: true)
        // Never reuse or overwrite an existing item (B10).
        if FileManager.default.fileExists(atPath: folder.path) { return report(String(format: L("exists"), folderName), error: true) }
        let structure = singleProjectEntries
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false) }
        catch { return report(L("createFailed") + error.localizedDescription, error: true) }
        if normalizeNFC { folder = FileNames.makeNFC(folder) }
        var record = CreationRecord()
        record.addFolder(folder)
        // Until the Path Finder steps finish, a second press is ignored (B11).
        busy = true
        saveForm()

        var warnings: [String] = []
        if !structure.isEmpty {
            let made = Creator.make(structure, in: folder, projectName: folderName, nfc: normalizeNFC)
            record.items += made.record.items
            warnings += made.failures
            if made.invalid > 0 { warnings.append(String(format: L("bulk.skippedInvalid"), String(made.invalid))) }
            if !made.missingTemplates.isEmpty { warnings.append(String(format: L("template.missing"), made.missingTemplates.sorted().joined(separator: "、"))) }
        }
        if makeLink, let warning = link(folder, into: &record) { warnings.append(warning) }
        lastCreation = record
        let finish = { [weak self] (sidebarWarnings: [String]) in
            guard let self else { return }
            self.busy = false
            warnings += sidebarWarnings
            if self.openAfter { FileViewers.show(folder, choice: self.viewer, reveal: self.revealInParent) }
            if warnings.isEmpty { self.report(String(format: L("created"), folder.path), error: false) }
            else { self.report(String(format: L("createdWithWarnings"), folder.path) + "\n" + warnings.joined(separator: "\n"), error: true) }
            if warnings.isEmpty { self.onCreated?() }
        }
        // Path Finder first, then Finder; each reports its own reason.
        func message(_ error: FileViewers.SidebarError, finder: Bool) -> String {
            switch error {
            case .noPathFinder: return L("sidebar.noPathFinder")
            case .noAccessibility: return AccessibilityText.text("blocked")
            case .denied: return L("sidebar.denied")
            case .revealFailed(let text): return L("sidebar.failed") + text
            case .menuNotFound: return L(finder ? "sidebar.finderMenuNotFound" : "sidebar.menuNotFound")
            }
        }
        let finderStep = { [weak self] (earlier: [String]) in
            guard let self, self.addToFinderSidebar else { return finish(earlier) }
            FileViewers.addToFinderSidebar(folder) { result in
                if case .failure(let error) = result { finish(earlier + [message(error, finder: true)]) } else { finish(earlier) }
            }
        }
        if addToSidebar {
            FileViewers.addToPathFinderSidebar(folder) { result in
                if case .failure(let error) = result { finderStep([message(error, finder: false)]) } else { finderStep([]) }
            }
        } else {
            finderStep([])
        }
    }

    // MARK: App hotkey

    /// The 「アプリを呼び出すホットキー」 field: the stored Shortcut (JSON; empty data = cleared on purpose) as a KeyCombo.
    var appCombo: KeyCombo? {
        get { appShortcut?.combo }
        set {
            appShortcut = newValue.map { Shortcut($0) }
            appHotkeyEnabled = newValue != nil
            save()
        }
    }
    static let appHotkeyFieldID = "appHotkey"
    /// Starts recording the app hotkey (from the toggle with no key yet, or from the first-launch offer).
    func recordAppHotkey() {
        let recorder = HotkeyRecorder.shared
        guard recorder.recordingID != Self.appHotkeyFieldID else { return }
        recorder.start(Self.appHotkeyFieldID) { [weak self] combo in self?.appCombo = combo; recorder.touch(); return nil }
    }
    func refreshHotkey() {
        hotkeys.unregisterAll(); hotkeyRegistered = false; hotkeyFailure = nil
        updateHotkeyRegistration()
        var items: [HotkeyManifest.Item] = []
        if let appShortcut {
            items.append(.init(id: "showApp", title: L("appHotkey"), keyCode: Int(appShortcut.code), modifiers: Int(appShortcut.modifiers),
                               enabled: appHotkeyEnabled, scope: "only", apps: Model.hotkeyApps))
        }
        HotkeyManifest.publish(items)
    }
    /// Registers the hotkey only while one of hotkeyApps is in front, so other apps keep the key.
    func updateHotkeyRegistration() {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        let wanted = appHotkeyEnabled && appShortcut != nil && Model.hotkeyApps.contains(front)
        if wanted == hotkeyRegistered { return }
        hotkeys.unregisterAll(); hotkeyRegistered = false
        guard wanted, let appShortcut else { return }
        let status = hotkeys.register(1, appShortcut.combo)
        if status == noErr { hotkeyRegistered = true } else { hotkeyFailure = status }
    }

    // MARK: Permissions and login item


    func refreshLogin() {
        let state = SMAppService.mainApp.status
        loginOn = state == .enabled || state == .requiresApproval
        switch state {
        case .enabled: loginStatus = L("loginEnabled")
        case .requiresApproval: loginStatus = L("loginApproval")
        case .notFound: loginStatus = Model.isInApplicationsFolder ? L("loginDisabled") : L("loginNotFound")
        default: loginStatus = L("loginDisabled")
        }
    }
    static var isInApplicationsFolder: Bool {
        let parent = Bundle.main.bundleURL.resolvingSymlinksInPath().deletingLastPathComponent().standardizedFileURL.path
        let folders = ["/Applications", FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").standardizedFileURL.path]
        return folders.contains { parent == $0 || parent.hasPrefix($0 + "/") }
    }
    func changeLogin(_ value: Bool) {
        do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; refreshLogin() }
        catch { refreshLogin(); loginStatus = L("loginFailed") + error.localizedDescription }
    }

    func stop() {
        hotkeys.unregisterAll()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
