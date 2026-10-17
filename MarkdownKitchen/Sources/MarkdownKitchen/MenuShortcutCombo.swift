import AppKit
import Carbon

/// 保存形式（MenuShortcut：文字＋NSEvent の修飾キー）と、共通の記録欄の KeyCombo（キーコード＋Carbon の修飾キー）の相互変換。
/// 文字とキーコードの対応は今のキーボード配列で引く（記録時の characters(byApplyingModifiers: []) と同じ考え方）
extension MenuShortcut {
    private static let namedCodes: [String: UInt32] = [
        "\r": UInt32(kVK_Return), "\t": UInt32(kVK_Tab), " ": UInt32(kVK_Space),
        upArrow: UInt32(kVK_UpArrow), downArrow: UInt32(kVK_DownArrow), leftArrow: UInt32(kVK_LeftArrow), rightArrow: UInt32(kVK_RightArrow),
    ]
    private static let namedKeys: [UInt32: String] = {
        var keys = Dictionary(uniqueKeysWithValues: namedCodes.map { ($0.value, $0.key) })
        keys[UInt32(kVK_ANSI_KeypadEnter)] = "\r"
        return keys
    }()

    /// 共通の記録欄で押されたキーから。文字にならないキー（F1 など）は nil
    init?(combo: KeyCombo) {
        let key: String
        if let named = Self.namedKeys[combo.code] {
            key = named
        } else {
            let name = KeyCombo.keyName(combo.code)
            guard name.count == 1, !name.hasPrefix("#") else { return nil }
            key = name.lowercased()
        }
        var flags: NSEvent.ModifierFlags = []
        if combo.modifiers & KeyCombo.command != 0 { flags.insert(.command) }
        if combo.modifiers & KeyCombo.option != 0 { flags.insert(.option) }
        if combo.modifiers & KeyCombo.shift != 0 { flags.insert(.shift) }
        if combo.modifiers & KeyCombo.control != 0 { flags.insert(.control) }
        self.init(key, flags)
    }

    /// 記録欄に表示するための KeyCombo。今の配列で打てない文字なら nil
    var combo: KeyCombo? {
        guard let code = Self.namedCodes[key] ?? Self.code(for: key) else { return nil }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= KeyCombo.command }
        if flags.contains(.option) { modifiers |= KeyCombo.option }
        if flags.contains(.shift) { modifiers |= KeyCombo.shift }
        if flags.contains(.control) { modifiers |= KeyCombo.control }
        return KeyCombo(code: code, modifiers: modifiers)
    }

    /// 文字を打つキーのコード（数字はテンキーより上段を優先）
    private static func code(for key: String) -> UInt32? {
        (0..<UInt32(128)).first { KeyCombo.keyName($0).lowercased() == key.lowercased() && namedKeys[$0] == nil }
    }
}
