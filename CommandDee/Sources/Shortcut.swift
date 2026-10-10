import AppKit

struct Shortcut: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt
    let label: String
    static let mask: NSEvent.ModifierFlags = [.command, .control, .option, .shift, .function]
    private static func key(_ code: UInt16, _ flags: NSEvent.ModifierFlags, _ label: String) -> Shortcut {
        Shortcut(keyCode: code, modifiers: flags.rawValue, label: label)
    }
    /// ⌃ renames in place, ⌘ / ⌃⌘ duplicate (1.8.13); D = date, E = edited, F = folder, S = switch. Order matches `modes` and the settings rows.
    static let defaults: [Shortcut] = [
        key(2, .command, "⌘D"),                 // 連番で複製
        key(2, .control, "⌃D"),                 // 日付付き（名前変更）
        key(2, [.control, .command], "⌃⌘D"),    // 日付付きで複製
        key(14, [.control, .command], "⌃⌘E"),   // edited付きで複製
        key(3, .control, "⌃F"),                 // 親フォルダ名を付け外し
        key(1, .control, "⌃S")                  // 2項目の名前を入れ替え
    ]
    static let modes: [Duplicator.Mode] = [.version, .renameDate, .date, .edited, .parent, .swapNames]
    static var titles: [String] {
        [L("shortcut.version"), L("shortcut.renameDate"), L("shortcut.date"), L("shortcut.edited"), L("shortcut.parent"), L("shortcut.swapNames")]
    }
    static let storageKey = "keyboardShortcutsV2"
    /// Until 1.8.12: array in the order version, date, edited, parent, renameVersion (removed in 1.8.14), swapNames.
    static let legacyKey = "keyboardShortcuts"
    static let legacyDefaults: [Shortcut] = [
        key(2, .command, "⌘D"), key(2, .control, "⌃D"), key(14, [.control, .command], "⌃⌘E"),
        key(14, .control, "⌃E"), key(2, [.control, .shift, .command], "⌃⇧⌘D"), key(1, [.control, .shift, .command], "⌃⇧⌘S")
    ]
    /// Stored placeholder for a shortcut that could not be migrated (kept as persisted data).
    static let unsetLabel = "未設定"
    static let unset = Shortcut(keyCode: UInt16.max, modifiers: 0, label: unsetLabel)
    /// Button text: the unset placeholder follows the UI language; real key labels are shown as-is.
    var displayLabel: String { keyCode == UInt16.max || label == Self.unsetLabel ? L("shortcut.unset") : label }
    static func load(defaults: UserDefaults = .standard) -> [Shortcut] {
        if let data = defaults.data(forKey: storageKey),
           var values = try? JSONDecoder().decode([Shortcut].self, from: data) {
            // 1.8.13 stored 7 keys including 連番だけ更新 at index 5; drop it.
            if values.count == Self.defaults.count + 1 { values.remove(at: 5); save(values, defaults: defaults) }
            // Until 1.8.15 the parent default was ⌃P, which Keyboard Maestro / Emacs-style remaps often take; move it to ⌃F if free.
            let parentIndex = 4, oldParent = key(35, .control, "⌃P"), newParent = Self.defaults[parentIndex]
            if values.count == Self.defaults.count, values[parentIndex] == oldParent,
               !values.contains(where: { $0.keyCode == newParent.keyCode && $0.modifiers == newParent.modifiers }) {
                values[parentIndex] = newParent; save(values, defaults: defaults)
            }
            if values.count == Self.defaults.count { return values }
        }
        guard let data = defaults.data(forKey: legacyKey),
              let legacy = try? JSONDecoder().decode([Shortcut].self, from: data), (4...6).contains(legacy.count) else { return Self.defaults }
        // Keys the user changed carry over; keys still on the old default take the new layout,
        // unless a carried custom key already uses them (then that action starts unset).
        let legacyIndex: [Int?] = [0, nil, 1, 2, 3, 5]   // new slot → old slot (old 4 = 連番だけ更新, removed)
        let custom: [Shortcut?] = legacyIndex.map { old in
            guard let old, old < legacy.count, legacy[old] != legacyDefaults[old] else { return nil }
            return legacy[old]
        }
        func same(_ a: Shortcut, _ b: Shortcut) -> Bool { a.keyCode == b.keyCode && a.modifiers == b.modifiers }
        var migrated = custom.map { $0 ?? unset }
        for index in migrated.indices where custom[index] == nil {
            let candidate = Self.defaults[index]
            if !migrated.contains(where: { same($0, candidate) }) { migrated[index] = candidate }
        }
        save(migrated, defaults: defaults)
        return migrated
    }

    static func save(_ values: [Shortcut], defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(values) { defaults.set(data, forKey: storageKey) }
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
