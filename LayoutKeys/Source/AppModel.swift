import AppKit
import Carbon
import SwiftUI
import UniformTypeIdentifiers
import os

let log = Logger(subsystem: "jp.dtp-transit.layoutkeys", category: "hotkeys")

/// One finished run, shown under the list (not saved).
struct RunRecord: Identifiable {
    let id = UUID()
    let date: Date
    let name: String
    let text: String
    let isError: Bool
}

@MainActor final class AppModel: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var library = Library.load() { didSet { scheduleSave(); registerHotkeys() } }
    @Published var selection: String?
    @Published var records: [RunRecord] = []
    @Published var inDesignFront = InDesign.front != nil
    /// Script ids whose hotkey could not be registered (another app holds the key) or repeats an earlier script's key.
    @Published var failedHotkeys: Set<Trigger> = []
    @Published var duplicateHotkeys: Set<Trigger> = []
    @Published var hotkeysEnabled = UserDefaults.standard.object(forKey: "hotkeysEnabled") as? Bool ?? true {
        didSet { defaults.set(hotkeysEnabled, forKey: "hotkeysEnabled"); registerHotkeys() }
    }
    let runner = ScriptRunner()
    private let scriptKeys = HotkeySet(signature: "LKsc")
    private var numbers: [UInt32: Trigger] = [:]
    private var observers: [NSObjectProtocol] = []

    init() {
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.frontChanged(InDesign.isInDesign(app)) }
        })
        // Recording a key suspends every hotkey; leaving the app mid-recording would keep them suspended in InDesign.
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { HotkeyRecorder.shared.stop() }
        })
        scriptKeys.action = { [weak self] number in
            log.info("hotkey \(number) pressed, InDesign front: \(InDesign.front != nil)")
            guard let self, let trigger = self.numbers[number], let script = self.library.scripts.first(where: { $0.id == trigger.script }) else { return }
            // Checked again at the moment of the press: the key must not run anything outside InDesign.
            guard InDesign.front != nil else { return }
            self.start(script, key: trigger.key.flatMap { id in script.keys.first { $0.id == id } })
        }
        registerHotkeys()
        selection = library.scripts.first?.id   // Opens on the first script instead of an empty detail pane.
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
    /// The settings shared between Macs changed in UserDefaults (sync or import).
    func reloadSharedSettings() {
        hotkeysEnabled = defaults.object(forKey: "hotkeysEnabled") as? Bool ?? true
    }

    // MARK: Moving to another Mac (manual export and import only, never synced)

    static let transferKey = "LayoutKeysScripts"
    /// The script list with variables and keys, as JSON text in the settings file.
    func exportLibrary() throws -> NSDictionary {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return [Self.transferKey: String(decoding: try encoder.encode(library), as: UTF8.self)]
    }
    /// Replaces the script list with the file's. A file without it (settings only) leaves the list as it is.
    func importLibrary(_ values: NSDictionary) throws -> Bool {
        guard let text = values[Self.transferKey] as? String else { return true }
        guard let imported = try? JSONDecoder().decode(Library.self, from: Data(text.utf8)) else {
            throw NSError(domain: "LayoutKeys", code: 1, userInfo: [NSLocalizedDescriptionKey: L("sharing.badLibrary")])
        }
        library = imported
        selection = library.scripts.first?.id
        saveNow()
        return true
    }

    func saveNow() {
        guard let work = saveWork, !work.isCancelled else { return }
        work.cancel(); saveLibrary()
    }
    private func saveLibrary() {
        saveWork = nil
        do { try library.save() } catch { record("LayoutKeys", String(format: L("saveFailed"), error.localizedDescription), error: true) }
    }

    // MARK: Hotkeys

    private func frontChanged(_ front: Bool) {
        guard front != inDesignFront else { return }
        inDesignFront = front
        registerHotkeys()
    }

    /// The script hotkeys exist only while InDesign is in front, so the keys keep their meaning in other apps.
    func registerHotkeys() {
        scriptKeys.unregisterAll()
        numbers = [:]
        let (winners, duplicates) = library.activeHotkeys()
        var failed: Set<Trigger> = []
        if hotkeysEnabled && inDesignFront {
            for (index, (hotkey, trigger)) in winners.enumerated() {
                let number = UInt32(index + 1)
                numbers[number] = trigger
                if scriptKeys.register(number, KeyCombo(code: hotkey.code, modifiers: hotkey.modifiers)) != noErr { failed.insert(trigger) }
            }
        }
        log.info("registered \(self.numbers.count) (failed \(failed.count)), enabled \(self.hotkeysEnabled), InDesign front \(self.inDesignFront)")
        if failedHotkeys != failed { failedHotkeys = failed }
        if duplicateHotkeys != duplicates { duplicateHotkeys = duplicates }
    }

    /// Every other hotkey (scripts and their variable keys), for the duplicate check of a hotkey field.
    func otherHotkeys(except trigger: Trigger?) -> [(String, KeyCombo)] {
        var result: [(String, KeyCombo)] = []
        for script in library.scripts where script.enabled {
            if let hotkey = script.hotkey, trigger != Trigger(script: script.id) { result.append((script.name, KeyCombo(code: hotkey.code, modifiers: hotkey.modifiers))) }
            for key in script.keys {
                guard let hotkey = key.hotkey, trigger != Trigger(script: script.id, key: key.id) else { continue }
                result.append((script.title(for: key), KeyCombo(code: hotkey.code, modifiers: hotkey.modifiers)))
            }
        }
        return result
    }

    // MARK: Running

    /// From the window: bring InDesign to the front first, as the hotkey would find it.
    func runFromWindow(_ script: ScriptEntry, key: VariableKey? = nil) {
        guard let app = InDesign.running else { record(script.title(for: key), L("result.noInDesign"), error: true); return }
        app.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.start(script, key: key) }
    }
    private func start(_ script: ScriptEntry, key: VariableKey? = nil) {
        let title = script.title(for: key)
        let accepted = runner.run(script, key: key) { [weak self] outcome in
            MainActor.assumeIsolated { self?.finish(script, title, outcome) }
        }
        if !accepted { record(title, L("result.busy"), error: true) }
    }
    private func finish(_ script: ScriptEntry, _ title: String, _ outcome: RunOutcome) {
        switch outcome {
        case .success:
            if let index = library.scripts.firstIndex(where: { $0.id == script.id }) { library.scripts[index].recordRun() }
            record(title, L("result.success"), error: false)
        case .noInDesign: record(title, L("result.noInDesign"), error: true)
        case .automationDenied: record(title, L("result.automation"), error: true)
        case .fileMissing: record(title, L("result.fileMissing"), error: true)
        case .failed(let reason): record(title, String(format: L("result.failed"), reason), error: true)
        }
    }
    private func record(_ name: String, _ text: String, error: Bool) {
        records.insert(RunRecord(date: Date(), name: name, text: text, isError: error), at: 0)
        if records.count > 30 { records.removeLast(records.count - 30) }
    }

    // MARK: Editing

    func add(urls: [URL]) {
        let accepted = urls.filter(ScriptEntry.accepts)
        let added = library.add(paths: accepted.map(\.path))
        if let first = added.first { selection = first.id }
        else if let path = accepted.first?.path, let existing = library.scripts.first(where: { $0.path == path }) { selection = existing.id }
        let skipped = urls.count - accepted.count
        if skipped > 0 { record("LayoutKeys", String(format: L("add.skipped"), skipped), error: true) }
    }
    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.allowedContentTypes = ScriptEntry.extensions.compactMap { UTType(filenameExtension: $0) }
        panel.prompt = L("add")
        if panel.runModal() == .OK { add(urls: panel.urls) }
    }
    /// Points an entry at another file (the script was moved or renamed). The name follows the file unless it was changed.
    func relink(_ id: String) {
        guard let index = library.scripts.firstIndex(where: { $0.id == id }) else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ScriptEntry.extensions.compactMap { UTType(filenameExtension: $0) }
        panel.directoryURL = URL(fileURLWithPath: (library.scripts[index].path as NSString).deletingLastPathComponent)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let old = library.scripts[index]
        if old.name == ScriptEntry.defaultName(for: old.path) { library.scripts[index].name = ScriptEntry.defaultName(for: url.path) }
        library.scripts[index].path = url.path
    }
    func binding(for id: String) -> Binding<ScriptEntry>? {
        guard library.scripts.contains(where: { $0.id == id }) else { return nil }
        return Binding(get: { self.library.scripts.first { $0.id == id } ?? ScriptEntry(id: id, path: "") },
                       set: { new in
                           guard let index = self.library.scripts.firstIndex(where: { $0.id == id }) else { return }
                           self.library.scripts[index] = new
                       })
    }
    func delete(_ ids: Set<String>) {
        library.scripts.removeAll { ids.contains($0.id) }
        if let selection, ids.contains(selection) { self.selection = nil }
    }
    func move(from source: IndexSet, to destination: Int) { library.scripts.move(fromOffsets: source, toOffset: destination) }
}
