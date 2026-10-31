import Foundation
@main struct PreferencesTests {
    static func main() throws {
        let suite = "InputMaestro.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        precondition(OCRPreferences.shortcut(in: defaults) == OCRPreferences.defaultShortcut, "untouched 0.1.0 migrates to command shift 1")
        let custom = OCRShortcut(code: 20, modifiers: 256 | 2048)
        defaults.set(try JSONEncoder().encode(custom), forKey: "ocr.hotkey")
        precondition(OCRPreferences.shortcut(in: defaults) == custom, "custom shortcut is preserved")
        defaults.set(Data(), forKey: "ocr.hotkey")
        precondition(OCRPreferences.shortcut(in: defaults) == nil, "explicit clear stays clear")
        defaults.set(Data([1, 2, 3]), forKey: "ocr.hotkey")
        precondition(OCRPreferences.shortcut(in: defaults) == nil, "invalid saved data does not activate a shortcut")
        print("PASS: OCR default migration, custom shortcut, explicit clear and invalid storage")
    }
}
