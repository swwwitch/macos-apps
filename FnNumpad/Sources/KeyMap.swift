import Foundation

/// What a Fn+key becomes. Codes are macOS virtual key codes (kVK_*), which name the same physical
/// positions as Karabiner-Elements' key_code (Tests/check_karabiner.py compares the two).
struct KeyTarget: Equatable {
    var code: Int64
    var label: String
    /// Keypad keys carry the numeric-pad flag, as the real keys do.
    var keypad: Bool
}

/// The key held to convert, chosen separately for JIS and other keyboards.
enum TriggerKey: String, CaseIterable, Identifiable {
    case fn, capsLock, both
    var id: String { rawValue }
    var usesFn: Bool { self != .capsLock }
    var usesCapsLock: Bool { self != .fn }
    func pressed(fn: Bool, capsLock: Bool) -> Bool { (usesFn && fn) || (usesCapsLock && capsLock) }
}

/// The four groups the 「キー」 settings turn on and off.
enum KeyGroup: String, CaseIterable, Identifiable {
    case numpad, numberRow, operators, editing
    var id: String { rawValue }
    var defaultsKey: String { "group." + rawValue }
}

struct KeyMapping: Equatable, Identifiable {
    var from: Int64
    var fromLabel: String
    /// Karabiner's key_code for the physical key (checked against the rule file).
    var karabiner: String
    /// Two entries for Fn+N (00). On key repeat only the last one repeats, as in Karabiner.
    var to: [KeyTarget]
    var group: KeyGroup
    var id: Int64 { from }
    var toLabel: String { to.map(\.label).joined() }
}

enum KeyMap {
    static let keypad0 = KeyTarget(code: 0x52, label: "0", keypad: true)
    static let keypad1 = KeyTarget(code: 0x53, label: "1", keypad: true)
    static let keypad2 = KeyTarget(code: 0x54, label: "2", keypad: true)
    static let keypad3 = KeyTarget(code: 0x55, label: "3", keypad: true)
    static let keypad4 = KeyTarget(code: 0x56, label: "4", keypad: true)
    static let keypad5 = KeyTarget(code: 0x57, label: "5", keypad: true)
    static let keypad6 = KeyTarget(code: 0x58, label: "6", keypad: true)
    static let keypad7 = KeyTarget(code: 0x59, label: "7", keypad: true)
    static let keypad8 = KeyTarget(code: 0x5B, label: "8", keypad: true)
    static let keypad9 = KeyTarget(code: 0x5C, label: "9", keypad: true)
    static let keypadMinus = KeyTarget(code: 0x4E, label: "−", keypad: true)
    static let keypadEquals = KeyTarget(code: 0x51, label: "=", keypad: true)
    static let keypadMultiply = KeyTarget(code: 0x43, label: "*", keypad: true)
    static let keypadPlus = KeyTarget(code: 0x45, label: "+", keypad: true)
    static let keypadDecimal = KeyTarget(code: 0x41, label: ".", keypad: true)
    static let keypadDivide = KeyTarget(code: 0x4B, label: "/", keypad: true)
    /// A comma: typed by CommaTyper (pasted under Japanese input). The keypad comma (JIS) types nothing in US/ABC.
    static let comma = KeyTarget(code: 0x2B, label: ",", keypad: false)
    static let tab = KeyTarget(code: 0x30, label: "Tab", keypad: false)
    static let delete = KeyTarget(code: 0x33, label: "Delete", keypad: false)
    static let returnKey = KeyTarget(code: 0x24, label: "Return", keypad: false)
    static let keypadEnter = KeyTarget(code: 0x4C, label: "Enter", keypad: true)

    /// The rule 「Fn+Number to KeyPad, Fn+[ / Y / H to Tab / Delete / Return」 (numpad-v4.json), in its order.
    static let all: [KeyMapping] = [
        KeyMapping(from: 0x2E, fromLabel: "M", karabiner: "m", to: [keypad0], group: .numpad),
        KeyMapping(from: 0x26, fromLabel: "J", karabiner: "j", to: [keypad1], group: .numpad),
        KeyMapping(from: 0x28, fromLabel: "K", karabiner: "k", to: [keypad2], group: .numpad),
        KeyMapping(from: 0x25, fromLabel: "L", karabiner: "l", to: [keypad3], group: .numpad),
        KeyMapping(from: 0x20, fromLabel: "U", karabiner: "u", to: [keypad4], group: .numpad),
        KeyMapping(from: 0x22, fromLabel: "I", karabiner: "i", to: [keypad5], group: .numpad),
        KeyMapping(from: 0x1F, fromLabel: "O", karabiner: "o", to: [keypad6], group: .numpad),
        KeyMapping(from: 0x1A, fromLabel: "7", karabiner: "7", to: [keypad7], group: .numpad),
        KeyMapping(from: 0x1C, fromLabel: "8", karabiner: "8", to: [keypad8], group: .numpad),
        KeyMapping(from: 0x19, fromLabel: "9", karabiner: "9", to: [keypad9], group: .numpad),
        KeyMapping(from: 0x1D, fromLabel: "0", karabiner: "0", to: [keypad0], group: .numberRow),
        KeyMapping(from: 0x12, fromLabel: "1", karabiner: "1", to: [keypad1], group: .numberRow),
        KeyMapping(from: 0x13, fromLabel: "2", karabiner: "2", to: [keypad2], group: .numberRow),
        KeyMapping(from: 0x14, fromLabel: "3", karabiner: "3", to: [keypad3], group: .numberRow),
        KeyMapping(from: 0x15, fromLabel: "4", karabiner: "4", to: [keypad4], group: .numberRow),
        KeyMapping(from: 0x17, fromLabel: "5", karabiner: "5", to: [keypad5], group: .numberRow),
        KeyMapping(from: 0x16, fromLabel: "6", karabiner: "6", to: [keypad6], group: .numberRow),
        KeyMapping(from: 0x32, fromLabel: "`", karabiner: "grave_accent_and_tilde", to: [keypad0], group: .numberRow),
        KeyMapping(from: 0x1B, fromLabel: "-", karabiner: "hyphen", to: [keypadMinus], group: .operators),
        KeyMapping(from: 0x18, fromLabel: "=", karabiner: "equal_sign", to: [keypadEquals], group: .operators),
        KeyMapping(from: 0x23, fromLabel: "P", karabiner: "p", to: [keypadMultiply], group: .operators),
        KeyMapping(from: 0x29, fromLabel: ";", karabiner: "semicolon", to: [keypadPlus], group: .operators),
        KeyMapping(from: 0x27, fromLabel: "'", karabiner: "quote", to: [keypadMinus], group: .operators),
        KeyMapping(from: 0x2F, fromLabel: ".", karabiner: "period", to: [keypadDecimal], group: .operators),
        KeyMapping(from: 0x2C, fromLabel: "/", karabiner: "slash", to: [keypadDivide], group: .operators),
        // Added in FnNumpad (not in the Karabiner rule): Fn+, types a comma.
        KeyMapping(from: 0x2B, fromLabel: ",", karabiner: "comma", to: [comma], group: .operators),
        KeyMapping(from: 0x2D, fromLabel: "N", karabiner: "n", to: [keypad0, keypad0], group: .numpad),
        KeyMapping(from: 0x21, fromLabel: "[", karabiner: "open_bracket", to: [tab], group: .editing),
        KeyMapping(from: 0x10, fromLabel: "Y", karabiner: "y", to: [delete], group: .editing),
        KeyMapping(from: 0x04, fromLabel: "H", karabiner: "h", to: [returnKey], group: .editing),
        // Added in FnNumpad: Fn+Return types the keypad Enter.
        KeyMapping(from: 0x24, fromLabel: "Return", karabiner: "return_or_enter", to: [keypadEnter], group: .editing),
    ]

    private static let byCode = Dictionary(uniqueKeysWithValues: all.map { ($0.from, $0) })

    static func mapping(for code: Int64, groups: Set<KeyGroup>) -> KeyMapping? {
        guard let found = byCode[code], groups.contains(found.group) else { return nil }
        return found
    }

    /// Tables show the keypad group as it sits on the keyboard (7 8 9 / U I O / J K L / M N); the others keep the rule's order.
    static func mappings(in group: KeyGroup) -> [KeyMapping] {
        let found = all.filter { $0.group == group }
        guard group == .numpad else { return found }
        let order = Array("789UIOJKLMN").map(String.init)
        return found.sorted { (order.firstIndex(of: $0.fromLabel) ?? 99) < (order.firstIndex(of: $1.fromLabel) ?? 99) }
    }
}
