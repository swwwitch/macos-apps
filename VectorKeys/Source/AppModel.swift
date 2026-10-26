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
    private let defaults = UserDefaults.standard
    @Published var library = Library.load() { didSet { scheduleSave(); registerHotkeys() } }
    @Published var selection: String?
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
    private var numbers: [UInt32: String] = [:]
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
            guard let self, let id = self.numbers[number], let script = self.library.scripts.first(where: { $0.id == id }) else { return }
            // Checked again at the moment of the press: the key must not run anything outside Illustrator.
            guard Illustrator.front != nil else { return }
            self.start(script)
        }
        registerHotkeys()
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
    func registerHotkeys() {
        scriptKeys.unregisterAll()
        numbers = [:]
        let (winners, duplicates) = library.activeHotkeys()
        var failed: Set<String> = []
        if hotkeysEnabled && illustratorFront {
            for (index, (hotkey, id)) in winners.enumerated() {
                let number = UInt32(index + 1)
                numbers[number] = id
                if scriptKeys.register(number, KeyCombo(code: hotkey.code, modifiers: hotkey.modifiers)) != noErr { failed.insert(id) }
            }
        }
        log.info("registered \(self.numbers.count) (failed \(failed.count)), enabled \(self.hotkeysEnabled), Illustrator front \(self.illustratorFront)")
        if failedHotkeys != failed { failedHotkeys = failed }
        if duplicateHotkeys != duplicates { duplicateHotkeys = duplicates }
    }

    /// Other scripts' hotkeys, for the duplicate check of the hotkey field.
    func otherHotkeys(except id: String) -> [(String, KeyCombo)] {
        library.scripts.compactMap { script in
            guard script.id != id, script.enabled, let hotkey = script.hotkey else { return nil }
            return (script.name, KeyCombo(code: hotkey.code, modifiers: hotkey.modifiers))
        }
    }

    // MARK: Running

    /// From the window: bring Illustrator to the front first, as the hotkey would find it.
    func runFromWindow(_ script: ScriptEntry) {
        guard let app = Illustrator.running else { record(script.name, L("result.noIllustrator"), error: true); return }
        app.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.start(script) }
    }
    private func start(_ script: ScriptEntry) {
        let accepted = runner.run(script) { [weak self] outcome in
            MainActor.assumeIsolated { self?.finish(script, outcome) }
        }
        if !accepted { record(script.name, L("result.busy"), error: true) }
    }
    private func finish(_ script: ScriptEntry, _ outcome: RunOutcome) {
        switch outcome {
        case .success:
            if let index = library.scripts.firstIndex(where: { $0.id == script.id }) { library.scripts[index].recordRun() }
            record(script.name, L("result.success"), error: false)
        case .noIllustrator: record(script.name, L("result.noIllustrator"), error: true)
        case .automationDenied: record(script.name, L("result.automation"), error: true)
        case .fileMissing: record(script.name, L("result.fileMissing"), error: true)
        case .failed(let reason): record(script.name, String(format: L("result.failed"), reason), error: true)
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
        if skipped > 0 { record("VectorKeys", String(format: L("add.skipped"), skipped), error: true) }
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
