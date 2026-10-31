import AppKit
import Carbon
import SwiftUI

extension DefaultKey {
    var combo: KeyCombo { KeyCombo(code: code, modifiers: modifiers) }
}

struct StatusLine: Equatable {
    let text: String
    let isError: Bool
}

@MainActor final class Model: ObservableObject {
    private let defaults = UserDefaults.standard
    /// Keys shared by 設定の共有. Script paths, startup, residency and the app hotkey stay per Mac.
    nonisolated static let sharedKeys: Set<String> = ["hiddenCommands", "commandKeys", "commandKeysKnown", "commandValues", "paletteHotkey", "paletteHotkeyEnabled"]

    // MARK: Palette items

    @Published var hidden: Set<String> = Model.storedHidden() { didSet { defaults.set(hidden.sorted(), forKey: "hiddenCommands"); updateRegistrations() } }
    /// Every command's key; a missing entry means none. Until the first change the original keys are used.
    @Published var keys: [String: KeyCombo] = Model.storedKeys() {
        didSet {
            defaults.set((try? JSONEncoder().encode(keys)) ?? Data(), forKey: "commandKeys")
            defaults.set(Catalog.all.map(\.id), forKey: "commandKeysKnown")
            updateRegistrations()
        }
    }
    @Published var values: [String: [String: Double]] = Model.storedValues() { didSet { defaults.set(values, forKey: "commandValues") } }
    @Published var scriptPaths: [String: String] = UserDefaults.standard.dictionary(forKey: "scriptPaths") as? [String: String] ?? [:] {
        didSet { defaults.set(scriptPaths, forKey: "scriptPaths") }
    }
    @Published var selection: String? = Catalog.all.first?.id
    @Published var status: StatusLine?
    /// Command keys that could not be registered (another app holds them) or clash with the palette key.
    @Published var failedKeys: Set<String> = []

    static func storedHidden() -> Set<String> { Set(UserDefaults.standard.stringArray(forKey: "hiddenCommands") ?? []) }
    static var defaultKeys: [String: KeyCombo] {
        Dictionary(uniqueKeysWithValues: Catalog.all.compactMap { command in command.defaultKey.map { (command.id, $0.combo) } })
    }
    /// Commands of 1.0.0, saved before "commandKeysKnown" existed.
    static let firstCommands: Set<String> = ["roundCorners", "dropShadow", "warp", "outlineObject", "outlineStroke", "offsetPath", "pfAdd", "pfDivide", "pfOutline", "pfCrop",
        "rectangle", "zigzag", "zigzagFlat", "freeDistort", "freeDistortScript", "puckerBloat", "roughen", "transform", "flatten", "removeItem", "sketchy", "strokeScale",
        "clearAppearance", "clearKeepFill", "expandAppearance", "knockout", "makeCompoundShape", "releaseCompoundShape", "makeCompoundPath", "releaseCompoundPath",
        "buttCap", "roundCap", "projectingCap"]
    /// Saved keys, plus the default keys of commands added since (when the key is still free).
    static func storedKeys() -> [String: KeyCombo] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "commandKeys"), let stored = try? JSONDecoder().decode([String: KeyCombo].self, from: data) else { return defaultKeys }
        var keys = stored.filter { Catalog.command($0.key) != nil }
        let known = defaults.stringArray(forKey: "commandKeysKnown").map(Set.init) ?? firstCommands
        for command in Catalog.all where !known.contains(command.id) {
            if let combo = command.defaultKey?.combo, !keys.values.contains(combo) { keys[command.id] = combo }
        }
        return keys
    }
    static func storedValues() -> [String: [String: Double]] {
        (UserDefaults.standard.dictionary(forKey: "commandValues") as? [String: [String: Double]]) ?? [:]
    }
    /// Re-reads the shared settings after an import so the next save does not write the old values back.
    func reloadSharedSettings() {
        hidden = Model.storedHidden(); keys = Model.storedKeys(); values = Model.storedValues()
        paletteHotkeyEnabled = defaults.object(forKey: "paletteHotkeyEnabled") as? Bool ?? true
        paletteCombo = Model.storedCombo("paletteHotkey", default: Model.defaultPaletteCombo)
    }

    func value(_ command: Command, _ spec: ParamSpec) -> Double { values[command.id]?[spec.key] ?? spec.defaultValue }
    func setValue(_ command: Command, _ spec: ParamSpec, _ value: Double) {
        var current = values[command.id] ?? [:]
        current[spec.key] = min(max(value, spec.range.lowerBound), spec.range.upperBound)
        values[command.id] = current
    }
    func resetValues(_ command: Command) { values[command.id] = nil }
    func hasCustomValues(_ command: Command) -> Bool { !(values[command.id] ?? [:]).isEmpty }

    func scriptPath(_ command: Command) -> String? {
        guard let path = scriptPaths[command.id] ?? command.scriptPath else { return nil }
        return (path as NSString).expandingTildeInPath
    }
    func scriptExists(_ command: Command) -> Bool { scriptPath(command).map { FileManager.default.fileExists(atPath: $0) } ?? true }

    var visibleCommands: [Command] { Catalog.all.filter { !hidden.contains($0.id) } }

    /// Gives the key to `id`, taking it from another command. Returns the command it was taken from.
    @discardableResult
    func assign(_ combo: KeyCombo?, to id: String) -> Command? {
        var updated = keys
        var previous: Command?
        if let combo, let owner = updated.first(where: { $0.value == combo && $0.key != id })?.key {
            updated[owner] = nil; previous = Catalog.command(owner)
        }
        updated[id] = combo
        keys = updated
        return previous
    }
    func resetAll() {
        hidden = []; keys = Model.defaultKeys; values = [:]
    }

    // MARK: Hotkeys

    /// Shows or hides the palette while Illustrator is in front. Default ⌃A (the original palette's key).
    nonisolated static let defaultPaletteCombo = KeyCombo(code: UInt32(kVK_ANSI_A), modifiers: KeyCombo.control)
    static let paletteHotkeyFieldID = "paletteHotkey"
    static let appHotkeyFieldID = "appHotkey"
    static func storedCombo(_ key: String, default value: KeyCombo?) -> KeyCombo? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return value }
        return data.isEmpty ? nil : try? JSONDecoder().decode(KeyCombo.self, from: data)
    }
    @Published var paletteHotkeyEnabled = UserDefaults.standard.object(forKey: "paletteHotkeyEnabled") as? Bool ?? true {
        didSet { defaults.set(paletteHotkeyEnabled, forKey: "paletteHotkeyEnabled"); updateRegistrations() }
    }
    @Published var paletteCombo: KeyCombo? = Model.storedCombo("paletteHotkey", default: Model.defaultPaletteCombo) {
        didSet { defaults.set(paletteCombo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: "paletteHotkey"); updateRegistrations() }
    }
    @Published var paletteHotkeyRegistered = true
    /// Shows the main window from any app (per Mac). No default: every ⌃⌥ letter is taken on this Mac.
    @Published var appHotkeyEnabled = UserDefaults.standard.object(forKey: "appHotkeyEnabled") as? Bool ?? true {
        didSet { defaults.set(appHotkeyEnabled, forKey: "appHotkeyEnabled"); registerAppHotkey() }
    }
    @Published var appCombo: KeyCombo? = Model.storedCombo("appHotkey", default: nil) {
        didSet { defaults.set(appCombo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: "appHotkey"); registerAppHotkey() }
    }
    @Published var appHotkeyRegistered = true

    let appHotkeys = HotkeySet(signature: "VFxA")
    let paletteHotkeys = HotkeySet(signature: "VFxP")
    let commandHotkeys = HotkeySet(signature: "VFxC")
    /// Set by the palette controller; command keys work only while it is requested.
    var paletteRequested = false { didSet { updateRegistrations() } }

    func registerAppHotkey() {
        appHotkeys.unregisterAll()
        guard appHotkeyEnabled, let appCombo else { appHotkeyRegistered = true; return }
        appHotkeyRegistered = appHotkeys.register(1, appCombo) == noErr
    }
    /// The palette key exists only while Illustrator is in front; the command keys also need the palette shown,
    /// so bare keys like - do not take typing away from Illustrator otherwise.
    func updateRegistrations() {
        let illustratorFront = Illustrator.front != nil
        paletteHotkeys.unregisterAll()
        if illustratorFront, paletteHotkeyEnabled, let paletteCombo {
            paletteHotkeyRegistered = paletteHotkeys.register(1, paletteCombo) == noErr
        } else { paletteHotkeyRegistered = true }
        commandHotkeys.unregisterAll()
        var failed: Set<String> = []
        if illustratorFront && paletteRequested {
            for (index, command) in Catalog.all.enumerated() {
                guard let combo = keys[command.id], !hidden.contains(command.id) else { continue }
                if combo == paletteCombo && paletteHotkeyEnabled { failed.insert(command.id); continue }
                if commandHotkeys.register(UInt32(index + 1), combo) != noErr { failed.insert(command.id) }
            }
        }
        if failed != failedKeys { failedKeys = failed }
    }
    func command(forHotkey number: UInt32) -> Command? {
        let index = Int(number) - 1
        return Catalog.all.indices.contains(index) ? Catalog.all[index] : nil
    }

    // MARK: Running

    /// Actions recorded in Illustrator, bundled under Resources/Actions.
    nonisolated static func recordedAction(_ name: String) -> String? {
        Bundle.main.url(forResource: name, withExtension: "aia", subdirectory: "Actions").flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    private let runner = CommandRunner()
    @Published var running = 0

    /// fromWindow: started from the main window, so Illustrator is brought to the front first (dialog boxes open there).
    func run(_ command: Command, dialog: Bool = false, fromWindow: Bool = false) {
        guard Illustrator.running != nil else { report(L("status.noIllustrator"), error: true); return }
        if fromWindow { Illustrator.running?.activate() }
        let values = Dictionary(uniqueKeysWithValues: command.params.map { ($0.key, value(command, $0)) })
        let source = ScriptBuilder.source(for: command, values: values, dialog: dialog, recorded: Model.recordedAction)
        let file = source == nil ? scriptPath(command) : nil
        running += 1
        let accepted = runner.run(source: source, file: file) { [weak self] outcome in
            guard let self else { return }
            self.running -= 1
            self.show(outcome, command)
        }
        if !accepted { running -= 1; report(L("status.busy"), error: true) }
    }
    private func show(_ outcome: RunOutcome, _ command: Command) {
        switch outcome {
        case .success, .scriptFinished: report(String(format: L("status.done"), command.title), error: false)
        case .noIllustrator: report(L("status.noIllustrator"), error: true)
        case .automationDenied: report(L("status.automation"), error: true)
        case .fileMissing(let path): report(String(format: L("status.fileMissing"), path), error: true)
        case .refused(let failure):
            if failure == .action, case .namedAction(let set, let name) = command.action {
                report(String(format: L("status.err.action"), name, set), error: true)
            } else {
                report(L("status.err." + failure.rawValue), error: true)
            }
        case .failed(let message): report(String(format: L("status.failed"), command.title, message), error: true)
        }
    }
    func report(_ text: String, error: Bool) { status = StatusLine(text: text, isError: error) }
}
