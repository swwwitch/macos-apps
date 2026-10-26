import AppKit
import Carbon

/// Key codes of the main block in rows, for drawing the keyboard. JIS adds ¥ and _ (and the layout labels come from
/// the current input source, so the same codes show the right characters on either keyboard).
enum KeyboardRows {
    static var isJIS: Bool { KBGetLayoutType(Int16(LMGetKbdType())) == kKeyboardJIS }
    static var rows: [[Int]] {
        [
            [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12],
            (isJIS ? [] : [kVK_ANSI_Grave]) + [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7,
                                                kVK_ANSI_8, kVK_ANSI_9, kVK_ANSI_0, kVK_ANSI_Minus, kVK_ANSI_Equal] + (isJIS ? [kVK_JIS_Yen] : []),
            [kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_E, kVK_ANSI_R, kVK_ANSI_T, kVK_ANSI_Y, kVK_ANSI_U, kVK_ANSI_I, kVK_ANSI_O, kVK_ANSI_P,
             kVK_ANSI_LeftBracket, kVK_ANSI_RightBracket] + (isJIS ? [] : [kVK_ANSI_Backslash]),
            [kVK_ANSI_A, kVK_ANSI_S, kVK_ANSI_D, kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L,
             kVK_ANSI_Semicolon, kVK_ANSI_Quote] + (isJIS ? [kVK_ANSI_Backslash] : []),
            [kVK_ANSI_Z, kVK_ANSI_X, kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_B, kVK_ANSI_N, kVK_ANSI_M, kVK_ANSI_Comma, kVK_ANSI_Period,
             kVK_ANSI_Slash] + (isJIS ? [kVK_JIS_Underscore] : []),
        ]
    }
    /// Symbols for a modifier set, in Apple's order.
    static func symbols(_ flags: NSEvent.ModifierFlags) -> String {
        (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "") + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "")
    }
}

/// Which favorite uses each key, for one modifier set. Pure, so it can be tested.
enum KeyUsage {
    /// Modifier sets in use, most used first.
    static func modifierSets(_ items: [FavoriteItem]) -> [NSEvent.ModifierFlags] {
        var counts: [UInt: Int] = [:]
        for item in items { if let hotkey = item.hotkey { counts[hotkey.flags.rawValue, default: 0] += 1 } }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map { NSEvent.ModifierFlags(rawValue: $0.key) }
    }
    /// keyCode → favorites using it with exactly these modifiers (more than one means a clash).
    static func map(_ items: [FavoriteItem], flags: NSEvent.ModifierFlags) -> [Int: [FavoriteItem]] {
        var result: [Int: [FavoriteItem]] = [:]
        for item in items { if let hotkey = item.hotkey, hotkey.flags == flags { result[hotkey.code, default: []].append(item) } }
        return result
    }
}
