import AppKit

struct Shortcut: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt
    let label: String
    static let mask: NSEvent.ModifierFlags = [.command, .control, .option, .shift, .function]
    static let defaults: [Shortcut] = [
        Shortcut(keyCode: 2, modifiers: NSEvent.ModifierFlags.command.rawValue, label: "⌘D"),
        Shortcut(keyCode: 2, modifiers: NSEvent.ModifierFlags([.control, .command]).rawValue, label: "⌃⌘D"),
        Shortcut(keyCode: 14, modifiers: NSEvent.ModifierFlags([.control, .command]).rawValue, label: "⌃⌘E"),
        Shortcut(keyCode: 14, modifiers: NSEvent.ModifierFlags.control.rawValue, label: "⌃E"),
        Shortcut(keyCode: 2, modifiers: NSEvent.ModifierFlags([.control, .shift, .command]).rawValue, label: "⌃⇧⌘D"),
        Shortcut(keyCode: 1, modifiers: NSEvent.ModifierFlags([.control, .option, .command]).rawValue, label: "⌃⌥⌘S")
    ]
    static var titles: [String] {
        [L("shortcut.version"), L("shortcut.date"), L("shortcut.edited"), L("shortcut.parent"), L("shortcut.renameVersion"), L("shortcut.swapNames")]
    }
    /// Stored placeholder for a shortcut that could not be migrated (kept as persisted data).
    static let unsetLabel = "未設定"
    /// Button text: the unset placeholder follows the UI language; real key labels are shown as-is.
    var displayLabel: String { keyCode == UInt16.max || label == Self.unsetLabel ? L("shortcut.unset") : label }
    static let modes: [Duplicator.Mode] = [.version, .date, .edited, .parent, .renameVersion, .swapNames]
    static func load(defaults: UserDefaults = .standard) -> [Shortcut] {
        guard let data = defaults.data(forKey: "keyboardShortcuts"),
              let values = try? JSONDecoder().decode([Shortcut].self, from: data), (4...Self.defaults.count).contains(values.count) else { return Self.defaults }
        var migrated = values
        for added in Self.defaults.dropFirst(values.count) {
            let conflicts = migrated.contains { $0.keyCode == added.keyCode && $0.modifiers == added.modifiers }
            migrated.append(conflicts ? Shortcut(keyCode: UInt16.max, modifiers: 0, label: Self.unsetLabel) : added)
        }
        return migrated
    }

    static func save(_ values: [Shortcut], defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(values) { defaults.set(data, forKey: "keyboardShortcuts") }
    }
    static func capture(_ event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection(mask)
        guard !flags.intersection([.command, .control, .option]).isEmpty,
              let key = event.charactersIgnoringModifiers, !key.isEmpty else { return nil }
        let prefix = (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "")
            + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "")
            + (flags.contains(.function) ? "fn " : "")
        return Shortcut(keyCode: event.keyCode, modifiers: flags.rawValue, label: prefix + key.uppercased())
    }
}
