import AppKit
import Carbon
import SwiftUI
import UniformTypeIdentifiers
import os

let log = Logger(subsystem: "jp.dtp-transit.vectorkeys", category: "hotkeys")

/// One finished run, shown under the list (not saved).
struct RunRecord: Identifiable {
    let id = UUID()
    let date: Date
    let name: String
    let text: String
    let isError: Bool
}

@MainActor final class AppModel: ObservableObject {
    var didExecute: ((ScriptEntry) -> Void)?
    var showQuickLook: ((URL) -> Void)?
    var showPalette: ((String) -> Void)?
    var paletteRenamed: ((String, String) -> Void)?
    @Published var failedPaletteHotkeys: Set<String> = []
    @Published var scriptVersions: [String: String] = [:]
    @Published var scriptMetadata: [String: ScriptMetadata.Info] = [:]
    @Published var scriptReadmes: [String: URL] = [:]
    @Published var scriptCodeURLs: [String: URL] = [:]
    @Published var updatingInformation = false
    private var remoteCodeURLs: [String: URL] = [:]
    /// User-requested refresh; preferences, item names and script files are never changed.
    func updateScriptInformation() {
        guard !updatingInformation else { return }
        updatingInformation = true
        let paths = Set(library.scripts.flatMap { $0.actions.compactMap(\.scriptPath) })
        Task {
            var found: [String: URL] = [:]
            var failed = 0
            for path in paths {
                let info = ScriptMetadata.read(at: path)
                guard info?.codeURL == nil,
                      let readme = info?.readmeURL(language: Locale.preferredLanguages.first ?? "en"),
                      let requestURL = ScriptMetadata.readmeRequestURL(readme) else { continue }
                do {
                    var request = URLRequest(url: requestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
                    request.setValue("text/plain, text/markdown", forHTTPHeaderField: "Accept")
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count <= 1_048_576,
                          let text = String(data: data, encoding: .utf8) else { failed += 1; continue }
                    found[path] = ScriptMetadata.codeURL(in: text, scriptFilename: (path as NSString).lastPathComponent, relativeTo: readme)
                } catch { failed += 1 }
            }
            let currentPaths = Set(library.scripts.flatMap { $0.actions.compactMap(\.scriptPath) })
            remoteCodeURLs = found.filter { currentPaths.contains($0.key) }
            updatingInformation = false
            refreshVersions()
            record("VectorKeys", failed == 0 ? L("meta.refreshed") : String(format: L("meta.refreshPartial"), failed), error: failed > 0)
        }
    }
    func metadata(for step: Step) -> ScriptMetadata.Info? {
        switch step {
        case .script(let path): return scriptMetadata[path]
        case .code(let source): return ScriptMetadata.parse(source)
        default: return nil
        }
    }
    private let paletteKeys = HotkeySet(signature: "VKpl")
    private var paletteNumbers: [UInt32: String] = [:]
    private var metadataGeneration = UUID()
    private var metadataWork: DispatchWorkItem?
    var paletteCategories: [String] { [Self.allCategories] + library.categoryList + [Self.uncategorized] }
    func categoryTitle(_ category: String) -> String {
        category == Self.allCategories ? L("category.all") : category == Self.uncategorized ? L("category.none") : category
    }
    func sortSelected(_ ids: Set<String>, by order: SortOrder) {
        undoable(L("sort.label")) { library.sortSelected(ids, by: order) { KeyCombo.keyName($0.code) } }
    }
    func setPaletteEnabled(_ enabled: Bool, for category: String) {
        undoable(L("palette.show")) {
            if library.paletteEnabled == nil { library.paletteEnabled = [:] }
            library.paletteEnabled?[category] = enabled
        }
    }
    func setPaletteMode(_ mode: Int, for category: String) {
        undoable(L("palette.behavior")) {
            if library.paletteModes == nil { library.paletteModes = [:] }
            library.paletteModes?[category] = mode
        }
    }
    func setPaletteHotkey(_ combo: KeyCombo?, for category: String) {
        undoable(L("hotkey")) {
            if library.paletteHotkeys == nil { library.paletteHotkeys = [:] }
            library.paletteHotkeys?[category] = combo.map { Hotkey(code: $0.code, modifiers: $0.modifiers) }
        }
    }
    func paletteConflicts(except category: String) -> [(String, KeyCombo)] {
        library.scripts.compactMap { script in
            guard script.enabled, let key = script.hotkey else { return nil }
            return (script.name, KeyCombo(code: key.code, modifiers: key.modifiers))
        } + paletteCategories.filter { $0 != category }.compactMap { name in
            library.paletteHotkeys?[name].map { (categoryTitle(name), KeyCombo(code: $0.code, modifiers: $0.modifiers)) }
        }
    }
    func version(for step: Step) -> String? {
        switch step {
        case .script(let path): return scriptVersions[path]
        case .code(let source): return ScriptMetadata.version(in: source)
        default: return nil
        }
    }
    func version(for script: ScriptEntry) -> String? {
        script.actions.count == 1 ? version(for: script.actions[0]) : nil
    }
    func refreshVersions() {
        metadataWork?.cancel()
        let generation = UUID(); metadataGeneration = generation
        let paths = Set(library.scripts.flatMap { $0.actions.compactMap(\.scriptPath) })
        let work = DispatchWorkItem { [weak self] in
            var versions: [String: String] = [:]
            var metadata: [String: ScriptMetadata.Info] = [:]
            var readmes: [String: URL] = [:]
            var codeURLs: [String: URL] = [:]
            for path in paths {
                metadata[path] = ScriptMetadata.read(at: path)
                versions[path] = metadata[path]?.version
                readmes[path] = ScriptMetadata.readme(for: path)
                codeURLs[path] = metadata[path]?.codeURL
                if codeURLs[path] == nil, let readme = readmes[path], let text = ScriptMetadata.readText(at: readme) {
                    codeURLs[path] = ScriptMetadata.codeURL(in: text, scriptFilename: (path as NSString).lastPathComponent)
                }
            }
            DispatchQueue.main.async {
                guard let self, self.metadataGeneration == generation else { return }
                if self.scriptVersions != versions { self.scriptVersions = versions }
                if self.scriptMetadata != metadata { self.scriptMetadata = metadata }
                if self.scriptReadmes != readmes { self.scriptReadmes = readmes }
                let currentPaths = Set(paths)
                let merged = self.remoteCodeURLs.filter { currentPaths.contains($0.key) }.merging(codeURLs) { _, local in local }
                if self.scriptCodeURLs != merged { self.scriptCodeURLs = merged }
            }
        }
        metadataWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3, execute: work)
    }
    private let defaults = UserDefaults.standard
    @Published var library = Library.load() { didSet { scheduleSave(); registerHotkeys(); refreshVersions() } }
    /// Selected scripts in the list (⌘-click / ⇧-click for several). The detail pane edits one of them.
    @Published var selection: Set<String> = []
    var selectedID: String? { selection.count == 1 ? selection.first : nil }
    /// The sidebar choice: allCategories, uncategorized, or a category name.
    @Published var categoryFilter = AppModel.allCategories { didSet { selection = [] } }
    static let allCategories = "\u{0}all", uncategorized = "\u{0}none"
    @Published var records: [RunRecord] = []
    @Published var illustratorFront = Illustrator.front != nil
    /// Script ids whose hotkey could not be registered (another app holds the key) or repeats an earlier script's key.
    @Published var failedHotkeys: Set<String> = []
    @Published var duplicateHotkeys: Set<String> = []
    @Published var hotkeysEnabled = UserDefaults.standard.object(forKey: "hotkeysEnabled") as? Bool ?? true {
        didSet { defaults.set(hotkeysEnabled, forKey: "hotkeysEnabled"); registerHotkeys() }
    }
    let runner = ScriptRunner()
    private let scriptKeys = HotkeySet(signature: "VKsc")
    /// Registration number → the scripts for a single and a double press of that key.
    private var numbers: [UInt32: (single: String?, double: String?)] = [:]
    /// A first press of a key that also has a double-press script waits here for the second one.
    private var pendingTap: (number: UInt32, work: DispatchWorkItem)?
    /// How long the second press of a double press may take.
    static let doubleTapInterval: TimeInterval = 0.3
    private var observers: [NSObjectProtocol] = []

    init() {
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.frontChanged(Illustrator.isIllustrator(app)) }
        })
        // Recording a key suspends every hotkey; leaving the app mid-recording would keep them suspended in Illustrator.
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { HotkeyRecorder.shared.stop() }
        })
        scriptKeys.action = { [weak self] number in
            log.info("hotkey \(number) pressed, Illustrator front: \(Illustrator.front != nil)")
            self?.pressed(number)
        }
        paletteKeys.action = { [weak self] number in
            guard let self, self.hotkeysEnabled, let category = self.paletteNumbers[number] else { return }
            self.showPalette?(category)
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshVersions() }
        })
        registerHotkeys()
        refreshVersions()
    }

    func reloadSharedSettings() {
        hotkeysEnabled = defaults.object(forKey: "hotkeysEnabled") as? Bool ?? true
    }

    // MARK: Saving

    private var saveWork: DispatchWorkItem?
    /// Typing a name changes the library on every key; the file is written half a second after the last change.
    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.saveLibrary() } }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
    func saveNow() {
        guard let work = saveWork, !work.isCancelled else { return }
        work.cancel(); saveLibrary()
    }
    private func saveLibrary() {
        saveWork = nil
        do { try library.save() } catch { record("VectorKeys", String(format: L("saveFailed"), error.localizedDescription), error: true) }
    }

    // MARK: Hotkeys

    private func frontChanged(_ front: Bool) {
        guard front != illustratorFront else { return }
        illustratorFront = front
        registerHotkeys()
    }

    /// The script hotkeys exist only while Illustrator is in front, so the keys keep their meaning in other apps.
    /// A key is registered once; a single and a double press of it are told apart in pressed(_:).
    func registerHotkeys() {
        scriptKeys.unregisterAll()
        paletteKeys.unregisterAll()
        paletteNumbers = [:]
        numbers = [:]
        pendingTap?.work.cancel(); pendingTap = nil
        let duplicates = library.activeHotkeys().duplicates
        var failed: Set<String> = []
        if hotkeysEnabled && illustratorFront {
            let blocked = Set(paletteCategories.filter { library.allowsPalette($0) && library.paletteMode($0) == 1 }.flatMap { scripts(in: $0).map(\.id) })
            var available = library
            for index in available.scripts.indices where blocked.contains(available.scripts[index].id) { available.scripts[index].enabled = false }
            for (index, target) in available.keyTargets().enumerated() {
                let number = UInt32(index + 1)
                numbers[number] = (target.single, target.double)
                if scriptKeys.register(number, KeyCombo(code: target.key.code, modifiers: target.key.modifiers)) != noErr {
                    failed.formUnion([target.single, target.double].compactMap { $0 })
                }
            }
        }
        var paletteFailed: Set<String> = []
        var occupied = Set(library.scripts.filter { $0.enabled }.compactMap { $0.hotkey?.key })
        if hotkeysEnabled {
            for (index, category) in paletteCategories.enumerated() {
                guard library.allowsPalette(category), let key = library.paletteHotkeys?[category] else { continue }
                let number = UInt32(index + 1)
                guard occupied.insert(key.key).inserted else { paletteFailed.insert(category); continue }
                if paletteKeys.register(number, KeyCombo(code: key.code, modifiers: key.modifiers)) == noErr {
                    paletteNumbers[number] = category
                } else { paletteFailed.insert(category) }
            }
        }
        if failedPaletteHotkeys != paletteFailed { failedPaletteHotkeys = paletteFailed }
        log.info("registered \(self.numbers.count) (failed \(failed.count)), enabled \(self.hotkeysEnabled), Illustrator front \(self.illustratorFront)")
        if failedHotkeys != failed { failedHotkeys = failed }
        if duplicateHotkeys != duplicates { duplicateHotkeys = duplicates }
    }

    /// A press of a registered key. With only a single-press script it runs at once; with a double-press script
    /// the first press waits doubleTapInterval for the second, and runs the single-press script (if any) when none comes.
    private func pressed(_ number: UInt32) {
        // Checked at the moment of the press: the key must not run anything outside Illustrator.
        guard let target = numbers[number], Illustrator.front != nil else { return }
        if let pending = pendingTap, pending.number == number {
            pending.work.cancel(); pendingTap = nil
            if let id = target.double { run(id) }
            return
        }
        if let pending = pendingTap { pending.work.perform(); pendingTap = nil }   // another key: settle the earlier one now
        guard target.double != nil else { if let id = target.single { run(id) }; return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.pendingTap?.number == number else { return }
                self.pendingTap = nil
                if let id = target.single, Illustrator.front != nil { self.run(id) }
            }
        }
        pendingTap = (number, work)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.doubleTapInterval, execute: work)
    }
    private func run(_ id: String) {
        if let script = library.scripts.first(where: { $0.id == id }) { start(script) }
    }

    /// Other scripts' hotkeys, for the duplicate check of a hotkey field. With `taps`, only the same press kind
    /// counts (a single and a double press of one key are different hotkeys); without it, every script key does.
    func otherHotkeys(except id: String, taps: Int?? = .none) -> [(String, KeyCombo)] {
        let scripts = library.scripts.compactMap { script -> (String, KeyCombo)? in
            guard script.id != id, script.enabled, script.scriptsOnly, let hotkey = script.hotkey else { return nil }
            if case .some(let wanted) = taps, hotkey.taps != wanted { return nil }
            return (script.name, KeyCombo(code: hotkey.code, modifiers: hotkey.modifiers))
        }
        return scripts + paletteCategories.compactMap { category in
            library.paletteHotkeys?[category].map { (categoryTitle(category), KeyCombo(code: $0.code, modifiers: $0.modifiers)) }
        }
    }

    /// Open via a text editor explicitly, never via the JSX handler (which may execute the script).
    func openSource(_ path: String) {
        guard FileManager.default.fileExists(atPath: path), (path as NSString).pathExtension.lowercased() != "jsxbin" else { return }
        let workspace = NSWorkspace.shared
        let textURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("VectorKeys-source.txt")
        let preferred = workspace.urlForApplication(toOpen: textURL)
        let bundleID = preferred.flatMap { Bundle(url: $0)?.bundleIdentifier } ?? ""
        let editors: Set<String> = ["com.apple.TextEdit", "jp.co.artman21.Jedit-Pro", "jp.co.artman21.JeditOmega", "com.microsoft.VSCode", "com.barebones.bbedit", "com.coteditor.CotEditor", "com.sublimetext.4", "com.macromates.TextMate"]
        guard let editor = editors.contains(bundleID) ? preferred : workspace.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") else {
            record("VectorKeys", L("source.failed"), error: true); return
        }
        workspace.open([URL(fileURLWithPath: path)], withApplicationAt: editor, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            if let error { DispatchQueue.main.async { self?.record("VectorKeys", L("source.failed") + " " + error.localizedDescription, error: true) } }
        }
    }

    // MARK: Running

    /// From the window: bring Illustrator to the front first, as the hotkey would find it.
    func runFromWindow(_ script: ScriptEntry) {
        guard script.scriptsOnly else { record(script.name, L("legacy.unsupported"), error: true); return }
        guard let app = Illustrator.running else { record(script.name, L("result.noIllustrator"), error: true); return }
        app.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.start(script) }
    }
    private func start(_ script: ScriptEntry) {
        let accepted = runner.run(script) { [weak self] outcome in
            MainActor.assumeIsolated { self?.finish(script, outcome) }
        }
        if accepted { didExecute?(script) }
        if !accepted { record(script.name, L("result.busy"), error: true) }
    }
    private func finish(_ script: ScriptEntry, _ outcome: RunOutcome) {
        switch outcome {
        case .success:
            if let index = library.scripts.firstIndex(where: { $0.id == script.id }) { library.scripts[index].recordRun() }
            record(script.name, L("result.success"), error: false)
        case .noIllustrator: record(script.name, L("result.noIllustrator"), error: true)
        case .automationDenied: record(script.name, L("result.automation"), error: true)
        case .unsupportedSteps: record(script.name, L("legacy.unsupported"), error: true)
        case .fileMissing(let step): record(script.name, String(format: L("result.fileMissingStep"), step), error: true)
        case .failed(let step, let reason): record(script.name, String(format: L("result.failedStep"), step, reason), error: true)
        }
    }
    private func record(_ name: String, _ text: String, error: Bool) {
        records.insert(RunRecord(date: Date(), name: name, text: text, isError: error), at: 0)
        if records.count > 30 { records.removeLast(records.count - 30) }
    }

    // MARK: Editing

    func addCode() {
        var entry = ScriptEntry(steps: [.code(source: "")], name: L("code.title"))
        entry.category = currentCategory
        undoable(L("undo.add")) { library.scripts.append(entry); selection = [entry.id] }
    }
    func updateCode(_ id: String, at index: Int, source: String) {
        editSteps(id) { steps in
            guard steps.indices.contains(index), case .code = steps[index] else { return }
            steps[index] = .code(source: source)
        }
    }
    func add(urls: [URL]) {
        let accepted = urls.filter(ScriptEntry.accepts)
        // Added while a category is chosen in the sidebar: the scripts go into it.
        let added = library.add(entries: accepted.map { url in
            var entry = ScriptEntry(path: url.path); entry.category = currentCategory; return entry
        })
        if !added.isEmpty { selection = Set(added.map(\.id)) }
        else if let path = accepted.first?.path, let existing = library.scripts.first(where: { $0.path == path }) { selection = [existing.id] }
        let skipped = urls.count - accepted.count
        if skipped > 0 { record("VectorKeys", String(format: L("add.skipped"), skipped), error: true) }
    }
    /// Drops and the open panel bring .kmmacros files here; scripts go to add(urls:).
    func open(urls: [URL]) {
        let exports = urls.filter { $0.pathExtension.lowercased() == "kmmacros" }
        let others = urls.filter { $0.pathExtension.lowercased() != "kmmacros" }
        if !others.isEmpty { add(urls: others) }
        if !exports.isEmpty { importKM(exports) }
    }

    /// Imports the macros of Keyboard Maestro exports whose steps VectorKeys can run. Code written in a macro
    /// is saved as a .jsx file in Application Support/VectorKeys/Imported (the same code reuses its file).
    func importKM(_ urls: [URL]) {
        var items: [KMImport.Item] = [], skipped: [KMImport.Skipped] = [], unreadable: [String] = []
        for url in urls {
            guard let data = try? Data(contentsOf: url), let result = KMImport.parse(data) else { unreadable.append(url.lastPathComponent); continue }
            items += result.items; skipped += result.skipped
        }
        var entries: [ScriptEntry] = [], failed: [String] = []
        for item in items {
            var steps: [Step] = []
            do {
                for part in item.parts {
                    switch part {
                    case .file(let path): steps.append(.script(path: path))
                    case .code(let code): steps.append(.script(path: try saveImportedCode(code, name: item.name)))
                    }
                }
            } catch { failed.append(item.name); continue }
            var entry = ScriptEntry(steps: steps, name: item.name, hotkey: item.hotkey, enabled: item.enabled)
            if !item.group.isEmpty { entry.category = item.group }
            entry.kmUID = item.uid
            entries.append(entry)
        }
        // Imports before 1.3.0 lost the double press and the group: fill them in when the same macro comes again
        // with the same key, without touching what was edited since (a changed key, an assigned category).
        // The same macro is found by its Keyboard Maestro UID, or by its one step.
        var library = self.library
        var existing: Set<String> = []
        for entry in entries {
            guard let index = library.scripts.firstIndex(where: { ($0.kmUID != nil && $0.kmUID == entry.kmUID) || $0.identity == entry.identity }) else { continue }
            existing.insert(entry.id)
            if let new = entry.hotkey, let old = library.scripts[index].hotkey, old.key == new.key, old.taps == nil { library.scripts[index].hotkey = new }
            if library.scripts[index].category == nil, let category = entry.category { library.scripts[index].category = category }
            if library.scripts[index].kmUID == nil { library.scripts[index].kmUID = entry.kmUID }
        }
        for name in entries.compactMap(\.category) { library.addCategory(name) }
        let added = library.add(entries: entries.filter { !existing.contains($0.id) })
        undoable(L("undo.import")) { self.library = library }
        if !added.isEmpty { selection = Set(added.map(\.id)) }
        var lines = [String(format: L("km.added"), added.count)]
        if entries.count > added.count { lines.append(String(format: L("km.already"), entries.count - added.count)) }
        if !skipped.isEmpty {
            lines.append(String(format: L("km.skipped"), skipped.count))
            lines += skipped.prefix(12).map { "・\($0.name)（\(L("km.reason." + $0.reason.rawValue))）" }
            if skipped.count > 12 { lines.append(String(format: L("km.more"), skipped.count - 12)) }
        }
        if !failed.isEmpty { lines.append(String(format: L("km.saveFailed"), failed.joined(separator: L("listSeparator")))) }
        if !unreadable.isEmpty { lines.append(String(format: L("km.unreadable"), unreadable.joined(separator: L("listSeparator")))) }
        if added.contains(where: { $0.hotkey != nil && $0.enabled }) { lines.append(L("km.turnOff")) }
        record("Keyboard Maestro", String(format: L("km.added"), added.count), error: added.isEmpty)
        let alert = NSAlert()
        alert.messageText = L("km.title")
        alert.informativeText = lines.joined(separator: "\n")
        alert.addButton(withTitle: "OK")
        // The originals of everything in the export that is now in the list (new or already there).
        let uids = Set(entries.compactMap(\.kmUID))
        if !uids.isEmpty { alert.addButton(withTitle: String(format: L("km.turnOffButton"), uids.count)) }
        if alert.runModal() == .alertSecondButtonReturn { setInKM(Array(uids), enabled: false) }
    }
    private func saveImportedCode(_ code: String, name: String) throws -> String {
        let folder = Library.folder.appendingPathComponent("Imported", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let existing = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for file in existing where file.lowercased().hasSuffix(".jsx") {
            let path = folder.appendingPathComponent(file).path
            if (try? String(contentsOfFile: path, encoding: .utf8)) == code { return path }
        }
        let url = folder.appendingPathComponent(KMImport.fileName(for: name, taken: Set(existing.map { $0.lowercased() })))
        try code.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }
    func chooseKMFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "kmmacros")].compactMap { $0 }
        panel.prompt = L("km.import")
        if panel.runModal() == .OK { importKM(panel.urls) }
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.allowedContentTypes = ScriptEntry.extensions.compactMap { UTType(filenameExtension: $0) }
        panel.prompt = L("add")
        if panel.runModal() == .OK { add(urls: panel.urls) }
    }
    /// Points an entry at another file (the script was moved or renamed). The name follows the file unless it was changed.
    /// Points a script step at another file (the script was moved or renamed). The item name follows the file
    /// when it was the file name and this is the only step.
    func relink(_ id: String, step: Int) {
        guard let index = library.scripts.firstIndex(where: { $0.id == id }), case .script(let old)? = library.scripts[index].actions[safe: step] else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ScriptEntry.extensions.compactMap { UTType(filenameExtension: $0) }
        panel.directoryURL = URL(fileURLWithPath: (old as NSString).deletingLastPathComponent)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        undoable(L("undo.steps")) {
            var item = library.scripts[index]
            if item.actions.count == 1 && item.name == ScriptEntry.defaultName(for: old) { item.name = ScriptEntry.defaultName(for: url.path) }
            item.actions[step] = .script(path: url.path)
            library.scripts[index] = item
        }
    }

    // MARK: Steps

    private func editSteps(_ id: String, _ change: (inout [Step]) -> Void) {
        guard let index = library.scripts.firstIndex(where: { $0.id == id }) else { return }
        undoable(L("undo.steps")) {
            var steps = library.scripts[index].actions
            change(&steps)
            library.scripts[index].actions = steps
        }
    }
    /// Asks for script files and adds each as a step (after `index`, or at the end).
    func addScriptSteps(to id: String) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.allowedContentTypes = ScriptEntry.extensions.compactMap { UTType(filenameExtension: $0) }
        panel.prompt = L("add")
        guard panel.runModal() == .OK else { return }
        editSteps(id) { $0 += panel.urls.filter(ScriptEntry.accepts).map { .script(path: $0.path) } }
    }
    func addStep(_ step: Step, to id: String) { editSteps(id) { $0.append(step) } }
    func moveStep(_ id: String, from: Int, by offset: Int) {
        editSteps(id) { steps in
            let to = from + offset
            guard steps.indices.contains(from), steps.indices.contains(to) else { return }
            steps.swapAt(from, to)
        }
    }
    func removeStep(_ id: String, at index: Int) { editSteps(id) { if $0.indices.contains(index) { $0.remove(at: index) } } }
    func binding(for id: String) -> Binding<ScriptEntry>? {
        guard library.scripts.contains(where: { $0.id == id }) else { return nil }
        return Binding(get: { self.library.scripts.first { $0.id == id } ?? ScriptEntry(id: id, path: "") },
                       set: { new in
                           guard let index = self.library.scripts.firstIndex(where: { $0.id == id }) else { return }
                           self.library.scripts[index] = new
                       })
    }
    /// Removes scripts from the list. Code saved by an import (in Imported) goes to the Trash when nothing else uses it;
    /// ⌘Z brings back both the entries and those files.
    func delete(_ ids: Set<String>) {
        let removed = library.scripts.filter { ids.contains($0.id) }
        let remaining = Set(library.scripts.filter { !ids.contains($0.id) }.flatMap { $0.actions.compactMap(\.scriptPath) })
        let imported = Library.folder.appendingPathComponent("Imported", isDirectory: true).path + "/"
        let paths = Set(removed.flatMap { $0.actions.compactMap(\.scriptPath) })
        let files = TrashedFiles(paths.filter { $0.hasPrefix(imported) && !remaining.contains($0) }.map { URL(fileURLWithPath: $0) })
        undoable(L("undo.delete"), files: files) {
            library.scripts.removeAll { ids.contains($0.id) }
            files.trash()
        }
        selection.subtract(ids)
    }
    func move(ids: [String], from source: IndexSet, to destination: Int) { library.move(ids: ids, from: source, to: destination) }

    // MARK: Categories

    /// The category new scripts go into: the one chosen in the sidebar, or none.
    var currentCategory: String? {
        categoryFilter == Self.allCategories || categoryFilter == Self.uncategorized ? nil : categoryFilter
    }
    func scripts(in filter: String) -> [ScriptEntry] {
        switch filter {
        case Self.allCategories: return library.scripts
        case Self.uncategorized: return library.scripts.filter { $0.category == nil }
        default: return library.scripts.filter { $0.category == filter }
        }
    }
    func newCategory() {
        guard let name = askName(title: L("category.newTitle"), value: "") else { return }
        var added: String?
        undoable(L("undo.newCategory")) { added = library.addCategory(name) }
        if let added { categoryFilter = added }
    }
    func setColor(_ color: ItemTag?, for ids: Set<String>) {
        undoable(L("item.color")) {
            for index in library.scripts.indices where ids.contains(library.scripts[index].id) { library.scripts[index].tagColor = color }
        }
    }
    func renameCategory(_ name: String) {
        guard let new = askName(title: L("category.renameTitle"), value: name) else { return }
        _ = renameCategory(name, to: new)
    }
    @discardableResult func renameCategory(_ name: String, to new: String) -> Bool {
        let clean = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, name != Self.allCategories, name != Self.uncategorized,
              clean == name || !library.categoryList.contains(clean) else { return false }
        guard clean != name else { return true }
        undoable(L("undo.renameCategory")) { library.renameCategory(name, to: new) }
        let renamed = new.trimmingCharacters(in: .whitespacesAndNewlines)
        if !renamed.isEmpty && renamed != name { paletteRenamed?(name, renamed) }
        if categoryFilter == name && !renamed.isEmpty { categoryFilter = renamed }
        return true
    }
    func deleteCategory(_ name: String) {
        undoable(L("undo.deleteCategory")) { library.deleteCategory(name) }
        if categoryFilter == name { categoryFilter = Self.allCategories }
    }
    func setCategory(_ name: String?, for ids: Set<String>) { undoable(L("undo.category")) { library.setCategory(name, for: ids) } }
    /// Tools › アイテム名の検索と置換… opens the sheet in the main window.
    @Published var showReplace = false
    func replaceNames(find: String, with replacement: String, regex: Bool, caseSensitive: Bool) {
        var count = 0
        undoable(L("undo.rename")) { count = library.replaceNames(ids: selection, find: find, with: replacement, regex: regex, caseSensitive: caseSensitive) }
        record("VectorKeys", String(format: L("replace.done"), count), error: false)
    }
    /// Tools › KMマクロのナンバリングを削除, on the selected scripts.
    func stripNumbering() {
        var count = 0
        undoable(L("undo.rename")) { count = library.stripNumbering(ids: selection) }
        record("VectorKeys", String(format: L("tools.stripped"), count), error: false)
    }
    /// A row dropped on a category: when it is one of the selected rows, the whole selection goes along.
    func dropped(_ id: String, on category: String?) {
        setCategory(category, for: selection.contains(id) ? selection : [id])
    }
    // MARK: Undo

    /// The main window's undo manager (Delegate hands it out with windowWillReturnUndoManager).
    let undoManager = UndoManager()
    /// Runs a change of the list and lets ⌘Z put the list back (and ⇧⌘Z redo it). Typing in a name field has its
    /// own undo; this covers the list operations: renaming by tools, categories, deleting, importing.
    private func undoable(_ name: String, files: TrashedFiles? = nil, _ change: () -> Void) {
        let before = library
        change()
        let after = library
        guard after != before else { return }
        registerUndo(name, undo: { [weak self] in files?.restore(); self?.library = before },
                     redo: { [weak self] in self?.library = after; files?.trash() })
    }
    private func registerUndo(_ name: String, undo: @escaping () -> Void, redo: @escaping () -> Void) {
        undoManager.registerUndo(withTarget: self) { model in
            undo()
            model.registerUndo(name, undo: redo, redo: undo)
        }
        undoManager.setActionName(name)
    }

    // MARK: Keyboard Maestro

    /// Turns the original macros off (or back on) with Keyboard Maestro's AppleScript `setMacroEnable`.
    func setInKM(_ uids: [String], enabled: Bool) {
        guard !uids.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "tell application \"Keyboard Maestro\"\n" + uids.map { "setMacroEnable \(ScriptText.quote($0)) enable \(enabled)" }.joined(separator: "\n") + "\nend tell"
            let result = OSAScript.run(script)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    switch result {
                    case .output: self.record("Keyboard Maestro", String(format: L(enabled ? "km.turnedOn" : "km.turnedOff"), uids.count), error: false)
                    case .automationDenied: self.record("Keyboard Maestro", L("km.denied"), error: true)
                    case .failed(let message): self.record("Keyboard Maestro", String(format: L("km.failed"), message), error: true)
                    }
                }
            }
        }
    }
    /// Tools › KMの元のマクロをオフにする / オンに戻す, for the selected scripts that came from Keyboard Maestro.
    var selectedKMUIDs: [String] { library.scripts.filter { selection.contains($0.id) }.compactMap(\.kmUID) }

    /// A small name prompt (an alert with a text field). Returns nil on cancel or an empty name.
    private func askName(title: String, value: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        let field = NSTextField(string: value)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        field.placeholderString = L("category.name")
        alert.accessoryView = field
        alert.addButton(withTitle: "OK"); alert.addButton(withTitle: L("cancel"))
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}

/// Files moved to the Trash by a delete, kept so undo can put them back (and redo trash them again).
final class TrashedFiles {
    private var items: [(original: URL, inTrash: URL?)]
    init(_ files: [URL]) { items = files.map { ($0, nil) } }
    func trash() {
        for index in items.indices where items[index].inTrash == nil {
            var result: NSURL?
            if (try? FileManager.default.trashItem(at: items[index].original, resultingItemURL: &result)) != nil { items[index].inTrash = result as URL? }
        }
    }
    func restore() {
        for index in items.indices {
            guard let inTrash = items[index].inTrash else { continue }
            if (try? FileManager.default.moveItem(at: inTrash, to: items[index].original)) != nil { items[index].inTrash = nil }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
