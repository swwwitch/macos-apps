import AppKit
import ApplicationServices
import Carbon

struct NativeKeyStroke: Codable, Equatable {
    let code: UInt32
    let modifiers: UInt32
    let fn: Bool
    let character: String?
    let sourceModifiers: UInt32?
    var combo: KeyCombo {
        if let character, let resolved = NativeKeyboardLayout.resolve(character) {
            return KeyCombo(code: resolved.code, modifiers: (sourceModifiers ?? modifiers) | resolved.modifiers)
        }
        return KeyCombo(code: code, modifiers: modifiers)
    }
    var flags: CGEventFlags {
        var flags = combo.cgFlags
        if fn || (123...126).contains(code) { flags.insert(.maskSecondaryFn) }
        if (123...126).contains(code) { flags.insert(.maskNumericPad) }
        return flags
    }
}

struct NativeKeyboardAction: Codable, Identifiable {
    let id: String
    let sourceID: String
    let label: String
    let strokes: [NativeKeyStroke]
    var source: NativeShortcut? { ShortcutCatalog.bundled.native.first { $0.id == sourceID } }
    var title: String { (source?.title ?? sourceID) + (label.isEmpty ? "" : "（" + label + "）") }
    var originalCombo: KeyCombo? { strokes.count == 1 ? strokes.first?.combo : nil }
    func needsRegistration(_ assigned: KeyCombo?) -> Bool { assigned != nil && assigned != originalCombo }
}

struct NativeActionLibrary: Codable {
    struct Unsupported: Codable { let sourceID: String; let reason: String }
    let actions: [NativeKeyboardAction]
    let unsupported: [Unsupported]
    static let bundled: NativeActionLibrary = {
        guard let url = Bundle.main.url(forResource: "NativeActions", withExtension: "json"),
              let library = try? JSONDecoder().decode(Self.self, from: Data(contentsOf: url)) else {
            return Self(actions: [], unsupported: [])
        }
        return library
    }()
    func actions(for sourceID: String) -> [NativeKeyboardAction] { actions.filter { $0.sourceID == sourceID } }
}

/// Resolve punctuation against the current keyboard layout (e.g. colon/brackets on JIS vs US).
private enum NativeKeyboardLayout {
    private static var cache: [String: KeyCombo] = [:]
    static func resolve(_ character: String) -> KeyCombo? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let idPointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
        let sourceID = idPointer.map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String } ?? ""
        let cacheKey = sourceID + ":" + character
        if let saved = cache[cacheKey] { return saved }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        return data.withUnsafeBytes { bytes -> KeyCombo? in
            guard let layout = bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            for shift in [false, true] {
                for code in UInt16(0)...UInt16(50) {
                    var dead: UInt32 = 0, length = 0
                    var chars = [UniChar](repeating: 0, count: 8)
                    let result = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDisplay), shift ? UInt32(shiftKey >> 8) : 0,
                                                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &length, &chars)
                    if result == noErr && String(utf16CodeUnits: chars, count: length) == character {
                        let key = KeyCombo(code: UInt32(code), modifiers: shift ? UInt32(shiftKey) : 0)
                        cache[cacheKey] = key; return key
                    }
                }
            }
            return nil
        }
    }
}
