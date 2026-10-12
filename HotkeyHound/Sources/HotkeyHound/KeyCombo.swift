import AppKit
import Carbon

/// 修飾キーの組み合わせ（照合用にアプリごとの表現から正規化する）
struct KeyModifiers: OptionSet, Hashable {
    let rawValue: Int
    static let control = KeyModifiers(rawValue: 1 << 0)
    static let option = KeyModifiers(rawValue: 1 << 1)
    static let shift = KeyModifiers(rawValue: 1 << 2)
    static let command = KeyModifiers(rawValue: 1 << 3)
    static let function = KeyModifiers(rawValue: 1 << 4)

    /// NSEvent.ModifierFlags / CGEventFlags の値（BetterTouchTool・システムのホットキーも同じ）
    init(cocoaFlags flags: Int) {
        var value: KeyModifiers = []
        if flags & 0x40000 != 0 { value.insert(.control) }
        if flags & 0x80000 != 0 { value.insert(.option) }
        if flags & 0x20000 != 0 { value.insert(.shift) }
        if flags & 0x100000 != 0 { value.insert(.command) }
        if flags & 0x800000 != 0 { value.insert(.function) }
        self = value
    }
    /// Carbon の修飾キー（Keyboard Maestro が使う）
    init(carbonFlags flags: Int) {
        var value: KeyModifiers = []
        if flags & controlKey != 0 { value.insert(.control) }
        if flags & optionKey != 0 { value.insert(.option) }
        if flags & shiftKey != 0 { value.insert(.shift) }
        if flags & cmdKey != 0 { value.insert(.command) }
        self = value
    }
    init(rawValue: Int) { self.rawValue = rawValue }

    var carbonFlags: UInt32 {
        var flags = 0
        if contains(.control) { flags |= controlKey }
        if contains(.option) { flags |= optionKey }
        if contains(.shift) { flags |= shiftKey }
        if contains(.command) { flags |= cmdKey }
        return UInt32(flags)
    }
    /// macOS の表記順（fn ⌃ ⌥ ⇧ ⌘）
    var symbols: String {
        var text = ""
        if contains(.function) { text += "fn " }
        if contains(.control) { text += "⌃" }
        if contains(.option) { text += "⌥" }
        if contains(.shift) { text += "⇧" }
        if contains(.command) { text += "⌘" }
        return text
    }
}

/// 物理キー（仮想キーコード）と修飾キーの組
struct KeyCombo: Hashable {
    let keyCode: Int
    let modifiers: KeyModifiers

    /// 矢印・ファンクションキーの fn は OS が自動で付けるので表示しない
    var display: String {
        let shown = KeyNames.functionImplied.contains(keyCode) ? modifiers.subtracting(.function) : modifiers
        return shown.symbols + KeyNames.name(for: keyCode)
    }

    /// fn は矢印・ファンクションキーなどで OS が自動で付けるので、そうしたキーでは区別しない
    func matches(_ other: KeyCombo) -> Bool {
        guard keyCode == other.keyCode else { return false }
        if KeyNames.functionImplied.contains(keyCode) {
            return modifiers.subtracting(.function) == other.modifiers.subtracting(.function)
        }
        return modifiers == other.modifiers
    }
}

/// キーコードと表示名・文字の対応
enum KeyNames {
    /// 文字を持たないキー
    static let special: [Int: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 76: "⌤", 71: "⌧", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟", 114: "Help",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9",
        109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17",
        79: "F18", 80: "F19", 90: "F20", 102: L("英数"), 104: L("かな"), 57: "⇪", 10: "§",
        65: "Keypad .", 67: "Keypad *", 69: "Keypad +", 75: "Keypad /", 78: "Keypad -", 81: "Keypad =",
        82: "Keypad 0", 83: "Keypad 1", 84: "Keypad 2", 85: "Keypad 3", 86: "Keypad 4", 87: "Keypad 5",
        88: "Keypad 6", 89: "Keypad 7", 91: "Keypad 8", 92: "Keypad 9"
    ]
    /// OS が fn を付けて送るキー（矢印・ファンクション・ナビゲーション）
    static let functionImplied: Set<Int> = [123, 124, 125, 126, 115, 119, 116, 121, 114, 117,
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]

    static func name(for keyCode: Int) -> String {
        if let name = special[keyCode] { return name }
        if let text = character(for: keyCode, shift: false), !text.isEmpty { return text.uppercased() }
        return "#\(keyCode)"
    }

    /// 現在のキーボード配列で、そのキーが入力する文字。表は prepare() でメインスレッドから作る
    static func character(for keyCode: Int, shift: Bool) -> String? {
        lock.lock(); defer { lock.unlock() }
        return (shift ? shiftedTable : plainTable)[keyCode]
    }
    nonisolated(unsafe) private static var plainTable: [Int: String] = [:]
    nonisolated(unsafe) private static var shiftedTable: [Int: String] = [:]
    private static let lock = NSLock()

    /// 起動時と入力ソースの変更時に呼ぶ。TIS はメインスレッド専用なので、照合で使う文字をここで表にしておく
    @MainActor static func prepare() {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var plain: [Int: String] = [:], shifted: [Int: String] = [:]
        for code in 0..<128 {
            for shift in [false, true] {
                var deadKeys: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = data.withUnsafeBytes { buffer -> OSStatus in
                    guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
                    return UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay),
                                          shift ? UInt32(shiftKey >> 8) : 0, UInt32(LMGetKbdType()),
                                          OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, 4, &length, &chars)
                }
                guard status == noErr, length > 0 else { continue }
                let text = String(utf16CodeUnits: chars, count: length)
                // 制御文字は文字として扱わない
                guard text.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7f }) else { continue }
                if shift { shifted[code] = text } else { plain[code] = text }
            }
        }
        lock.lock(); plainTable = plain; shiftedTable = shifted; lock.unlock()
    }

    /// メニュー・NSUserKeyEquivalents の文字から、その文字を入力するキーを探す。
    /// 記号はシフトで入力するものならシフト込み。英字の大文字は caseImpliesShift のときだけシフト扱い
    /// （AX のメニューは英字を常に大文字で返し、Cocoa のキー設定は大文字がシフトを意味する）
    static func keyCode(forCharacter text: String, caseImpliesShift: Bool) -> (keyCode: Int, shift: Bool)? {
        if let code = functionCharacters[text] { return (code, false) }
        let lower = text.lowercased()
        let isLetter = lower != text.uppercased()
        for code in 0..<128 where special[code] == nil {
            guard let plain = character(for: code, shift: false) else { continue }
            if plain == text { return (code, false) }
            if isLetter && plain.lowercased() == lower { return (code, caseImpliesShift && text != lower) }
        }
        for code in 0..<128 where special[code] == nil {
            if character(for: code, shift: true) == text { return (code, true) }
        }
        return nil
    }

    /// Cocoa のメニューで使われる特殊キーの文字（NSUpArrowFunctionKey など）
    static let functionCharacters: [String: Int] = [
        "\u{F700}": 126, "\u{F701}": 125, "\u{F702}": 123, "\u{F703}": 124,
        "\u{F704}": 122, "\u{F705}": 120, "\u{F706}": 99, "\u{F707}": 118, "\u{F708}": 96, "\u{F709}": 97,
        "\u{F70A}": 98, "\u{F70B}": 100, "\u{F70C}": 101, "\u{F70D}": 109, "\u{F70E}": 103, "\u{F70F}": 111,
        "\u{F710}": 105, "\u{F711}": 107, "\u{F712}": 113, "\u{F713}": 106, "\u{F714}": 64, "\u{F715}": 79, "\u{F716}": 80,
        "\u{F728}": 117, "\u{F729}": 115, "\u{F72B}": 119, "\u{F72C}": 116, "\u{F72D}": 121,
        "\r": 36, "\n": 36, "\t": 48, " ": 49, "\u{8}": 51, "\u{7F}": 51, "\u{1B}": 53, "\u{3}": 76
    ]

    /// メニュー項目の特殊キー記号（AXMenuItemCmdGlyph の値）
    static let menuGlyphs: [Int: Int] = [
        0x02: 48, 0x04: 76, 0x09: 49, 0x0A: 117, 0x0B: 36, 0x0D: 36, 0x17: 51, 0x1B: 53, 0x1C: 71,
        0x62: 116, 0x64: 123, 0x65: 124, 0x66: 115, 0x67: 114, 0x68: 126, 0x69: 119, 0x6A: 125, 0x6B: 121,
        0x6F: 122, 0x70: 120, 0x71: 99, 0x72: 118, 0x73: 96, 0x74: 97, 0x75: 98, 0x76: 100, 0x77: 101,
        0x78: 109, 0x79: 103, 0x7A: 111, 0x87: 105, 0x88: 107, 0x89: 113, 0x8D: 102, 0x8E: 104,
        0x8F: 106, 0x90: 64, 0x91: 79, 0x92: 80
    ]

    /// "@~^$s" 形式（NSUserKeyEquivalents・サービス）を解釈する。# はテンキー
    static func comboFromKeyEquivalent(_ value: String) -> KeyCombo? {
        var modifiers: KeyModifiers = []
        var rest = Substring(value)
        while let first = rest.first, "@~^$#".contains(first), rest.count > 1 {
            switch first {
            case "@": modifiers.insert(.command)
            case "~": modifiers.insert(.option)
            case "^": modifiers.insert(.control)
            case "$": modifiers.insert(.shift)
            default: break
            }
            rest = rest.dropFirst()
        }
        guard !rest.isEmpty, let key = keyCode(forCharacter: String(rest), caseImpliesShift: true) else { return nil }
        if key.shift { modifiers.insert(.shift) }
        return KeyCombo(keyCode: key.keyCode, modifiers: modifiers)
    }
}
