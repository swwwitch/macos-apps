import Foundation

/// The shared hotkey field's persisted JSON shape, kept independent of UI for migration tests.
struct OCRShortcut: Codable, Equatable {
    var code: UInt32
    var modifiers: UInt32
}
enum OCRPreferences {
    static let defaultShortcut = OCRShortcut(code: 18, modifiers: 256 | 512) // ⌘⇧1
    static func shortcut(in defaults: UserDefaults) -> OCRShortcut? {
        // 0.1.0's untouched, unassigned default wrote no key. Empty Data means an explicit clear.
        guard defaults.object(forKey: "ocr.hotkey") != nil else { return defaultShortcut }
        guard let data = defaults.data(forKey: "ocr.hotkey"), !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(OCRShortcut.self, from: data)
    }
}
