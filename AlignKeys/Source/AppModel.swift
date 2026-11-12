import AppKit
import Carbon
import SwiftUI
import os

let log = Logger(subsystem: "jp.dtp-transit.alignkeys", category: "hotkeys")

/// One finished run, shown under the table (not saved).
struct RunRecord: Identifiable {
    let id = UUID()
    let date: Date
    let name: String
    let text: String
    let isError: Bool
}

@MainActor final class AppModel: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var keyMap = KeyMap.load() { didSet { keyMap.save(); registerHotkeys() } }
    /// 「上下左右は矢印キーでも」: ⌃⌘←↑→↓ (and their ⌥ / ⇧ forms) run the four edge buttons too.
    @Published var arrowKeys = UserDefaults.standard.object(forKey: "arrowKeys") as? Bool ?? true {
        didSet { defaults.set(arrowKeys, forKey: "arrowKeys"); registerHotkeys() }
    }
    /// Keys that InDesign's own shortcut set uses are left to InDesign (not registered).
    @Published var preferInDesign = UserDefaults.standard.object(forKey: "preferInDesign") as? Bool ?? true {
        didSet { defaults.set(preferInDesign, forKey: "preferInDesign"); registerHotkeys() }
    }
    /// The forms left to InDesign, and the shortcut set file they were read from.
    @Published var yieldedHotkeys: Set<Trigger> = []
    @Published var shortcutSet: URL?
    private var inDesignKeys: Set<String> = []
    private var shortcutSetStamp: Date?
    @Published var hotkeysEnabled = UserDefaults.standard.object(forKey: "hotkeysEnabled") as? Bool ?? true {
        didSet { defaults.set(hotkeysEnabled, forKey: "hotkeysEnabled"); registerHotkeys() }
    }
    @Published var records: [RunRecord] = []
    @Published var inDesignFront = InDesign.front != nil
    /// Triggers whose hotkey could not be registered (another app holds the key) or repeats an earlier one.
    @Published var failedHotkeys: Set<Trigger> = []
    @Published var duplicateHotkeys: Set<Trigger> = []
    let runner = ScriptRunner()
    private let actionKeys = HotkeySet(signature: "AKsc")
    private var numbers: [UInt32: Trigger] = [:]
    private var observers: [NSObjectProtocol] = []
    /// The bundled script, read once (it changes only with a new build of the app).
    private lazy var script: String? = Bundle.main.url(forResource: "IdAlignToNearestEdgePalette", withExtension: "jsx")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) }

    init() {
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.frontChanged(InDesign.isInDesign(app)) }
        })
        // Recording a key suspends every hotkey; leaving the app mid-recording would keep them suspended in InDesign.
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { HotkeyRecorder.shared.stop() }
        })
        actionKeys.action = { [weak self] number in
            log.info("hotkey \(number) pressed, InDesign front: \(InDesign.front != nil)")
            guard let self, let trigger = self.numbers[number] else { return }
            // Checked again at the moment of the press: the key must not run anything outside InDesign.
            guard InDesign.front != nil else { return }
            self.start(trigger)
        }
        registerHotkeys()
    }

    /// The settings shared between Macs changed in UserDefaults (sync or import).
    func reloadSharedSettings() {
        keyMap = KeyMap.load()
        arrowKeys = defaults.object(forKey: "arrowKeys") as? Bool ?? true
        preferInDesign = defaults.object(forKey: "preferInDesign") as? Bool ?? true
        hotkeysEnabled = defaults.object(forKey: "hotkeysEnabled") as? Bool ?? true
    }

    // MARK: Hotkeys

    private func frontChanged(_ front: Bool) {
        guard front != inDesignFront else { return }
        inDesignFront = front
        registerHotkeys()
    }

    /// Reads the running InDesign's shortcut set again when the file changed (InDesign writes it when a shortcut is edited).
    private func loadInDesignShortcuts() {
        guard let app = InDesign.running, let appURL = app.bundleURL else { return }
        let version = (Bundle(url: appURL)?.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        guard let major = Int(version.split(separator: ".").first ?? ""), let file = InDesignShortcuts.activeSetFile(appURL: appURL, major: major) else { return }
        let stamp = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        guard file != shortcutSet || stamp != shortcutSetStamp else { return }
        guard let xml = try? String(contentsOf: file, encoding: .utf8) else { return }
        inDesignKeys = InDesignShortcuts.parse(xml)
        shortcutSet = file; shortcutSetStamp = stamp
        log.info("read \(self.inDesignKeys.count) InDesign shortcuts from \(file.lastPathComponent, privacy: .public)")
    }

    /// The hotkeys exist only while InDesign is in front, so the keys keep their meaning in other apps.
    func registerHotkeys() {
        actionKeys.unregisterAll()
        numbers = [:]
        loadInDesignShortcuts()
        var (winners, duplicates) = keyMap.active(arrows: arrowKeys)
        var yielded: Set<Trigger> = []
        if preferInDesign {
            winners = winners.filter { hotkey, trigger in
                guard let name = InDesignShortcuts.name(of: hotkey), inDesignKeys.contains(name) else { return true }
                yielded.insert(trigger); return false
            }
        }
        if yieldedHotkeys != yielded { yieldedHotkeys = yielded }
        var failed: Set<Trigger> = []
        if hotkeysEnabled && inDesignFront {
            for (index, (hotkey, trigger)) in winners.enumerated() {
                let number = UInt32(index + 1)
                numbers[number] = trigger
                if actionKeys.register(number, KeyCombo(code: hotkey.code, modifiers: hotkey.modifiers)) != noErr { failed.insert(trigger) }
            }
        }
        log.info("registered \(self.numbers.count) (failed \(failed.count)), enabled \(self.hotkeysEnabled), InDesign front \(self.inDesignFront)")
        if failedHotkeys != failed { failedHotkeys = failed }
        if duplicateHotkeys != duplicates { duplicateHotkeys = duplicates }
    }

    /// Every key the other cells register (with their ⌥ / ⇧ forms, and the arrow keys when on), for the duplicate check of a hotkey field.
    func otherHotkeys(except cell: Trigger?) -> [(String, KeyCombo)] {
        var cells = Trigger.cells.compactMap { other in other == cell ? nil : keyMap[other].map { ($0, other) } }
        if arrowKeys { cells += KeyMap.arrowCells }
        return cells.flatMap { hotkey, other in
            hotkey.variants(of: other).map { ($0.1.title, KeyCombo(code: $0.0.code, modifiers: $0.0.modifiers)) }
        }
    }
    /// The arrow-key forms that did not register or lose to a key in the table.
    var arrowProblems: [String] {
        guard arrowKeys else { return [] }
        return KeyMap.arrowCells.flatMap { $0.0.variants(of: $0.1) }
            .filter { failedHotkeys.contains($0.1) || duplicateHotkeys.contains($0.1) || yieldedHotkeys.contains($0.1) }
            .map { KeyCombo(code: $0.0.code, modifiers: $0.0.modifiers).label }
    }
    /// The forms of a cell that did not register or lose to an earlier key, as 「⌃⌥⌘J」 labels.
    func problems(of cell: Trigger) -> (failed: [String], duplicate: [String], yielded: [String]) {
        guard let hotkey = keyMap[cell] else { return ([], [], []) }
        let forms = hotkey.variants(of: cell)
        func labels(_ set: Set<Trigger>) -> [String] { forms.filter { set.contains($0.1) }.map { KeyCombo(code: $0.0.code, modifiers: $0.0.modifiers).label } }
        return (labels(failedHotkeys), labels(duplicateHotkeys), labels(yieldedHotkeys))
    }

    // MARK: Running

    /// From the window: bring InDesign to the front first, as the hotkey would find it. No trigger opens the palette.
    func runFromWindow(_ trigger: Trigger?) {
        guard let app = InDesign.running else { record(title(trigger), L("result.noInDesign"), error: true); return }
        app.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.start(trigger) }
    }
    private func title(_ trigger: Trigger?) -> String { trigger?.title ?? L("palette") }
    private func start(_ trigger: Trigger?) {
        let name = title(trigger)
        guard let script else { record(name, L("result.noScript"), error: true); return }
        let code: String
        do { code = try AlignScript.source(script, trigger: trigger) }
        catch { record(name, String(format: L("result.failed"), error.localizedDescription), error: true); return }
        let accepted = runner.run(code, undoName: trigger.map { String(format: L("undoName"), $0.title) } ?? name) { [weak self] outcome in
            MainActor.assumeIsolated { self?.finish(name, outcome) }
        }
        if !accepted { record(name, L("result.busy"), error: true) }
    }
    private func finish(_ name: String, _ outcome: RunOutcome) {
        switch outcome {
        case .success: record(name, L("result.success"), error: false)
        case .noInDesign: record(name, L("result.noInDesign"), error: true)
        case .automationDenied: record(name, L("result.automation"), error: true)
        case .failed(let reason): record(name, String(format: L("result.failed"), reason), error: true)
        }
    }
    private func record(_ name: String, _ text: String, error: Bool) {
        records.insert(RunRecord(date: Date(), name: name, text: text, isError: error), at: 0)
        if records.count > 30 { records.removeLast(records.count - 30) }
    }
}
