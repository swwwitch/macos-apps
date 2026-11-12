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

@MainActor final class AppearanceModel: ObservableObject {
    private let defaults = UserDefaults.standard
    /// Keys shared by 設定の共有 (added to VectorMate's own). Script paths stay per Mac.
    nonisolated static let sharedKeys: Set<String> = ["appearance.skipWhileTyping", "appearance.hiddenCommands", "appearance.commandColors", "appearance.commandKeys", "appearance.commandKeysKnown", "appearance.commandValues", "appearance.paletteHotkey", "appearance.paletteHotkeyEnabled"]

    // MARK: Palette items

    @Published var hidden: Set<String> = AppearanceModel.storedHidden() { didSet { defaults.set(hidden.sorted(), forKey: "appearance.hiddenCommands"); updateRegistrations() } }
    /// Every command's key; a missing entry means none. Until the first change the original keys are used.
    @Published var keys: [String: KeyCombo] = AppearanceModel.storedKeys() {
        didSet {
            defaults.set((try? JSONEncoder().encode(keys)) ?? Data(), forKey: "appearance.commandKeys")
            defaults.set(Catalog.all.map(\.id), forKey: "appearance.commandKeysKnown")
            updateRegistrations()
        }
    }
    /// Finder tag colors by command id (rawValue of ItemTag); a missing entry means none.
    @Published var colors: [String: String] = UserDefaults.standard.dictionary(forKey: "appearance.commandColors") as? [String: String] ?? [:] {
        didSet { defaults.set(colors, forKey: "appearance.commandColors") }
    }
    func color(_ command: Command) -> ItemTag? { colors[command.id].flatMap(ItemTag.init(rawValue:)) }
    func setColor(_ tag: ItemTag?, for command: Command) { colors[command.id] = tag?.rawValue }
    @Published var values: [String: [String: Double]] = AppearanceModel.storedValues() { didSet { defaults.set(values, forKey: "appearance.commandValues") } }
    @Published var scriptPaths: [String: String] = UserDefaults.standard.dictionary(forKey: "appearance.scriptPaths") as? [String: String] ?? [:] {
        didSet { defaults.set(scriptPaths, forKey: "appearance.scriptPaths") }
    }
    @Published var selection: String? = Catalog.all.first?.id
    @Published var status: StatusLine?
    /// Command keys that could not be registered (another app holds them) or clash with the palette key.
    @Published var failedKeys: Set<String> = []

    static func storedHidden() -> Set<String> { Set(UserDefaults.standard.stringArray(forKey: "appearance.hiddenCommands") ?? []) }
    static var defaultKeys: [String: KeyCombo] {
        Dictionary(uniqueKeysWithValues: Catalog.all.compactMap { command in command.defaultKey.map { (command.id, $0.combo) } })
    }
    /// Commands of 1.0.0, saved before "appearance.commandKeysKnown" existed.
    static let firstCommands: Set<String> = ["roundCorners", "dropShadow", "warp", "outlineObject", "outlineStroke", "offsetPath", "pfAdd", "pfDivide", "pfOutline", "pfCrop",
        "rectangle", "zigzag", "zigzagFlat", "freeDistort", "freeDistortScript", "puckerBloat", "roughen", "transform", "flatten", "removeItem", "sketchy", "strokeScale",
        "clearAppearance", "clearKeepFill", "expandAppearance", "knockout", "makeCompoundShape", "releaseCompoundShape", "makeCompoundPath", "releaseCompoundPath",
        "buttCap", "roundCap", "projectingCap"]
    /// Saved keys, plus the default keys of commands added since (when the key is still free).
    static func storedKeys() -> [String: KeyCombo] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "appearance.commandKeys"), let stored = try? JSONDecoder().decode([String: KeyCombo].self, from: data) else { return defaultKeys }
        var keys = stored.filter { Catalog.command($0.key) != nil }
        let known = defaults.stringArray(forKey: "appearance.commandKeysKnown").map(Set.init) ?? firstCommands
        for command in Catalog.all where !known.contains(command.id) {
            if let combo = command.defaultKey?.combo, !keys.values.contains(combo) { keys[command.id] = combo }
        }
        return keys
    }
    static func storedValues() -> [String: [String: Double]] {
        (UserDefaults.standard.dictionary(forKey: "appearance.commandValues") as? [String: [String: Double]]) ?? [:]
    }
    /// Re-reads the shared settings after an import so the next save does not write the old values back.
    func reloadSharedSettings() {
        hidden = AppearanceModel.storedHidden(); keys = AppearanceModel.storedKeys(); values = AppearanceModel.storedValues()
        colors = defaults.dictionary(forKey: "appearance.commandColors") as? [String: String] ?? [:]
        paletteHotkeyEnabled = defaults.object(forKey: "appearance.paletteHotkeyEnabled") as? Bool ?? true
        skipWhileTyping = defaults.object(forKey: "appearance.skipWhileTyping") as? Bool ?? true
        paletteCombo = AppearanceModel.storedCombo("appearance.paletteHotkey", default: AppearanceModel.defaultPaletteCombo)
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
        hidden = []; keys = AppearanceModel.defaultKeys; values = [:]; colors = [:]
    }

    // MARK: Hotkeys

    /// Shows or hides the palette while Illustrator is in front. Default ⌃A (the original palette's key).
    nonisolated static let defaultPaletteCombo = KeyCombo(code: UInt32(kVK_ANSI_A), modifiers: KeyCombo.control)
    static let paletteHotkeyFieldID = "appearance.paletteHotkey"
    static func storedCombo(_ key: String, default value: KeyCombo?) -> KeyCombo? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return value }
        return data.isEmpty ? nil : try? JSONDecoder().decode(KeyCombo.self, from: data)
    }
    @Published var paletteHotkeyEnabled = UserDefaults.standard.object(forKey: "appearance.paletteHotkeyEnabled") as? Bool ?? true {
        didSet { defaults.set(paletteHotkeyEnabled, forKey: "appearance.paletteHotkeyEnabled"); updateRegistrations() }
    }
    @Published var paletteCombo: KeyCombo? = AppearanceModel.storedCombo("appearance.paletteHotkey", default: AppearanceModel.defaultPaletteCombo) {
        didSet { defaults.set(paletteCombo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: "appearance.paletteHotkey"); updateRegistrations() }
    }
    @Published var paletteHotkeyRegistered = true

    let paletteHotkeys = HotkeySet(signature: "VMfP")
    let commandHotkeys = HotkeySet(signature: "VMfC")
    /// Set by the palette controller; command keys work only while it is requested.
    var paletteRequested = false { didSet { updateRegistrations() } }

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
        var tapKeys: [KeyCombo: String] = [:]
        let active = illustratorFront && paletteRequested
        // With Accessibility the event tap takes the keys and leaves them to Illustrator while text is typed.
        let tapping = active && skipWhileTyping && keyTap.setEnabled(true)
        if !tapping { keyTap.setEnabled(false) }
        if active {
            for (index, command) in Catalog.all.enumerated() {
                guard let combo = keys[command.id], !hidden.contains(command.id) else { continue }
                if combo == paletteCombo && paletteHotkeyEnabled { failed.insert(command.id); continue }
                if tapping { tapKeys[combo] = command.id }
                else if commandHotkeys.register(UInt32(index + 1), combo) != noErr { failed.insert(command.id) }
            }
        }
        keyTap.keys = tapKeys
        if failed != failedKeys { failedKeys = failed }
        if tapping != typingGuardActive { typingGuardActive = tapping }
    }
    let keyTap = KeyTap()
    /// Leave keys that type characters to Illustrator while a type tool is active (needs Accessibility). Default on.
    @Published var skipWhileTyping = UserDefaults.standard.object(forKey: "appearance.skipWhileTyping") as? Bool ?? true {
        didSet { defaults.set(skipWhileTyping, forKey: "appearance.skipWhileTyping"); updateRegistrations() }
    }
    /// The event tap is in use (the guard works); false while the permission is missing or the palette is hidden.
    @Published var typingGuardActive = false
    func command(forHotkey number: UInt32) -> Command? {
        let index = Int(number) - 1
        return Catalog.all.indices.contains(index) ? Catalog.all[index] : nil
    }

    // MARK: Running

    /// A bundled file copied to the temporary folder, so Illustrator never opens (or writes next to) the one inside the app.
    nonisolated static func temporaryCopy(_ name: String) -> String? {
        guard let url = Bundle.main.url(forResource: (name as NSString).deletingPathExtension, withExtension: (name as NSString).pathExtension) else { return nil }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("VectorMate-Appearance", isDirectory: true)
        let copy = folder.appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: copy)
        return (try? FileManager.default.copyItem(at: url, to: copy)).map { copy.path }
    }
    /// Actions recorded in Illustrator, bundled under Resources/Actions.
    nonisolated static func recordedAction(_ name: String) -> String? {
        Bundle.main.url(forResource: name, withExtension: "aia", subdirectory: "Actions").flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    private let runner = CommandRunner()
    @Published var running = 0

    /// fromWindow: started from the main window, so Illustrator is brought to the front first (dialog boxes open there).
    func run(_ command: Command, dialog: Bool = false, fromWindow: Bool = false) {
        guard Illustrator.running != nil else { report(FX("status.noIllustrator"), error: true); return }
        if fromWindow { Illustrator.running?.activate() }
        let values = Dictionary(uniqueKeysWithValues: command.params.map { ($0.key, value(command, $0)) })
        let source = ScriptBuilder.source(for: command, values: values, dialog: dialog, recorded: AppearanceModel.recordedAction,
                                          resourceFile: AppearanceModel.temporaryCopy)
        let file = source == nil ? scriptPath(command) : nil
        running += 1
        let accepted = runner.run(source: source, file: file) { [weak self] outcome in
            guard let self else { return }
            self.running -= 1
            self.show(outcome, command)
        }
        if !accepted { running -= 1; report(FX("status.busy"), error: true) }
    }
    private func show(_ outcome: RunOutcome, _ command: Command) {
        switch outcome {
        case .success, .scriptFinished: report(String(format: FX("status.done"), command.title), error: false)
        case .noIllustrator: report(FX("status.noIllustrator"), error: true)
        case .automationDenied: report(FX("status.automation"), error: true)
        case .fileMissing(let path): report(String(format: FX("status.fileMissing"), path), error: true)
        case .refused(let failure):
            if failure == .action, case .namedAction(let set, let name) = command.action {
                report(String(format: FX("status.err.action"), name, set), error: true)
            } else {
                report(FX("status.err." + failure.rawValue), error: true)
            }
        case .failed(let message): report(String(format: FX("status.failed"), command.title, message), error: true)
        }
    }
    func report(_ text: String, error: Bool) { status = StatusLine(text: text, isError: error) }
}
