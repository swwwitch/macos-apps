import Foundation

/// The stored Shortcut and the shared KeyCombo hold the same Carbon code and modifiers; the label is derived again.
extension Shortcut {
    init(_ combo: KeyCombo) { self.init(code: combo.code, modifiers: combo.modifiers, label: combo.label) }
    var combo: KeyCombo { KeyCombo(code: code, modifiers: modifiers) }
}


/// Supported Keynote editions are the sole scope; no exclusions setting is needed.
enum KeynoteHotkeyScope {
    static let bundleIDs = ["com.apple.Keynote", "com.apple.iWork.Keynote"]
    static func permits(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return bundleIDs.contains(bundleID)
    }
}

/// Independent of shortcut profiles and palette item visibility. Missing = unset.
struct PaletteDisplayHotkey: Equatable {
    static let storageKey = "paletteDisplayHotkeyV1"
    static let fieldID = "palette.display"
    static let registrationID: UInt32 = 9_000
    var combo: KeyCombo?
    init(combo: KeyCombo? = nil) { self.combo = combo }
    static func load(from defaults: UserDefaults = .standard) -> Self {
        Self(combo: defaults.data(forKey: storageKey).flatMap { try? JSONDecoder().decode(KeyCombo.self, from: $0) })
    }
    func save(to defaults: UserDefaults = .standard) {
        if let combo, let data = try? JSONEncoder().encode(combo) { defaults.set(data, forKey: Self.storageKey) }
        else { defaults.removeObject(forKey: Self.storageKey) }
    }
    static func conflict(for combo: KeyCombo, among others: [(String, KeyCombo)]) -> String? {
        others.first { $0.1 == combo }?.0
    }
}
