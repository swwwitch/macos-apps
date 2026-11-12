import Foundation

enum KeyboardKind: String, CaseIterable, Identifiable {
    case jis, ansi
    var id: String { rawValue }
}

/// One key on the drawn keyboard. `id` is the macOS virtual key code; keys that are only drawn have negative ids.
struct KeySpec: Identifiable, Hashable {
    let id: Int
    let label: String
    var shiftLabel = ""
    /// Character code in a .kys, canonical (capital letters, 165 for the yen / backslash key).
    var baseKey = 0
    /// Code of the character Shift types on this key.
    var shiftKey = 0
    var width = 1.0
    /// Modifier keys, Return and the like cannot take a shortcut in Illustrator, so they do not count as free.
    var assignable = true
}

/// A physical key with modifiers: what is actually pressed.
struct Slot: Hashable {
    let keyCode: Int
    let modifiers: Int
}

struct KeyUse: Hashable {
    let name: String
    let context: Int
}

enum SlotState {
    case free, used, textOnly, system, unavailable
}

enum KeyboardLayout {
    /// None, ⇧, ⌘, ⇧⌘, ⌥, ⌥⇧, ⌥⌘, ⌥⇧⌘. Illustrator has no ⌃ shortcut.
    static let modifierSets = [0, 32, 64, 96, 128, 160, 192, 224]
    static let unitsPerRow = 15.0

    static func modifierLabel(_ modifiers: Int) -> String {
        (modifiers & 128 != 0 ? "⌥" : "") + (modifiers & 32 != 0 ? "⇧" : "") + (modifiers & 64 != 0 ? "⌘" : "")
    }

    private static func code(_ text: String) -> Int { text.unicodeScalars.first.map { Int($0.value) } ?? 0 }

    /// "1!" is a key with its Shift character. The yen key is code 165 in either layout, as Shortcut.canonicalKey has it.
    private static func key(_ id: Int, _ text: String, width: Double = 1) -> KeySpec {
        let characters = Array(text).map(String.init)
        let base = characters[0]
        let shifted = characters.count > 1 ? characters[1] : ""
        return KeySpec(id: id, label: base, shiftLabel: shifted, baseKey: Shortcut.canonicalKey(code(base)),
                       shiftKey: shifted.isEmpty ? 0 : code(shifted), width: width)
    }

    private static func letters(_ pairs: [(Int, String)]) -> [KeySpec] { pairs.map { key($0.0, $0.1) } }

    private static func drawn(_ id: Int, _ label: String, _ width: Double) -> KeySpec {
        KeySpec(id: id, label: label, width: width, assignable: false)
    }

    private static let functionRow: [KeySpec] = {
        let codes = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
        return [drawn(-1, "esc", 1)] + codes.enumerated().map { index, id in
            KeySpec(id: id, label: "F\(index + 1)", baseKey: 14 + index, width: 14.0 / 12.0)
        }
    }()

    private static let tab = KeySpec(id: 48, label: "Tab", baseKey: 9, width: 1.5)
    private static let space = KeySpec(id: 49, label: "Space", baseKey: 32, width: 6, assignable: false)

    private static let qwerty = letters([(12, "Q"), (13, "W"), (14, "E"), (15, "R"), (17, "T"), (16, "Y"), (32, "U"), (34, "I"), (31, "O"), (35, "P")])
    private static let asdf = letters([(0, "A"), (1, "S"), (2, "D"), (3, "F"), (5, "G"), (4, "H"), (38, "J"), (40, "K"), (37, "L")])
    private static let zxcv = letters([(6, "Z"), (7, "X"), (8, "C"), (9, "V"), (11, "B"), (45, "N"), (46, "M")])

    static func rows(_ kind: KeyboardKind) -> [[KeySpec]] {
        let bottom = [drawn(-2, "⌃ ⌥ ⌘", 4.5), space, drawn(-3, "⌘ ⌥", 4.5)]
        switch kind {
        case .jis:
            return [
                functionRow,
                letters([(18, "1!"), (19, "2\""), (20, "3#"), (21, "4$"), (23, "5%"), (22, "6&"), (26, "7'"), (28, "8("), (25, "9)"), (29, "0"),
                         (27, "-="), (24, "^~"), (93, "¥|")]) + [drawn(-4, "delete", 2)],
                [tab] + qwerty + letters([(33, "@`"), (30, "[{")]) + [drawn(-5, "return", 1.5)],
                [drawn(-6, "control", 1.75)] + asdf + letters([(41, ";+"), (39, ":*"), (42, "]}")]) + [drawn(-7, "", 1.25)],
                [drawn(-8, "shift", 2.25)] + zxcv + letters([(43, ",<"), (47, ".>"), (44, "/?"), (94, "_")]) + [drawn(-9, "shift", 1.75)],
                bottom,
            ]
        case .ansi:
            return [
                functionRow,
                letters([(50, "`~"), (18, "1!"), (19, "2@"), (20, "3#"), (21, "4$"), (23, "5%"), (22, "6^"), (26, "7&"), (28, "8*"), (25, "9("), (29, "0)"),
                         (27, "-_"), (24, "=+")]) + [drawn(-4, "delete", 2)],
                [tab] + qwerty + letters([(33, "[{"), (30, "]}")]) + [key(42, "\\|", width: 1.5)],
                [drawn(-6, "caps lock", 1.75)] + asdf + letters([(41, ";:"), (39, "'\"")]) + [drawn(-5, "return", 2.25)],
                [drawn(-8, "shift", 2.25)] + zxcv + letters([(43, ",<"), (47, ".>"), (44, "/?")]) + [drawn(-9, "shift", 2.75)],
                bottom,
            ]
        }
    }

    /// A macOS shortcut as an Illustrator slot. Carbon flags: ⌘0x100 ⇧0x200 ⌥0x800. Anything else, such as ⌃0x1000 or
    /// Globe 0x20000 (Globe+A is 0x20000 with key A), can never collide with an Illustrator shortcut.
    static func systemSlot(code: Int, carbonFlags flags: Int) -> Slot? {
        guard flags & ~0xB00 == 0 else { return nil }
        return Slot(keyCode: code, modifiers: (flags & 0x100 != 0 ? 64 : 0) | (flags & 0x200 != 0 ? 32 : 0) | (flags & 0x800 != 0 ? 128 : 0))
    }

    /// The key and modifiers a shortcut takes. A character typed with Shift (+ on a Japanese keyboard) needs Shift
    /// even when the .kys does not say so, as with ⌘+ and ⌘=.
    static func slot(_ shortcut: Shortcut, keys: [KeySpec]) -> Slot? {
        if let key = keys.first(where: { $0.baseKey == shortcut.key }) { return Slot(keyCode: key.id, modifiers: shortcut.modifiers) }
        if let key = keys.first(where: { $0.shiftKey == shortcut.key }) { return Slot(keyCode: key.id, modifiers: shortcut.modifiers | 32) }
        return nil
    }
}

/// Which commands sit on which keys of one set.
struct KeyMap {
    let keys: [KeySpec]
    private(set) var uses: [Slot: [KeyUse]] = [:]
    /// Shortcuts of the set with no key on this keyboard.
    private(set) var unplaced: [String] = []
    var system = Set<Slot>()

    init(kind: KeyboardKind, assignments: [(name: String, shortcut: Shortcut)], system: Set<Slot> = []) {
        keys = KeyboardLayout.rows(kind).flatMap { $0 }.filter { $0.id >= 0 }
        self.system = system
        for item in assignments {
            if let slot = KeyboardLayout.slot(item.shortcut, keys: keys) {
                uses[slot, default: []].append(KeyUse(name: item.name, context: item.shortcut.context))
            } else {
                unplaced.append(item.shortcut.label + " " + item.name)
            }
        }
    }

    func uses(_ key: KeySpec, _ modifiers: Int) -> [KeyUse] { uses[Slot(keyCode: key.id, modifiers: modifiers)] ?? [] }

    func state(_ key: KeySpec, _ modifiers: Int) -> SlotState {
        let found = uses(key, modifiers)
        if found.contains(where: { $0.context == 0 }) { return .used }
        if system.contains(Slot(keyCode: key.id, modifiers: modifiers)) { return .system }
        if !found.isEmpty { return .textOnly }
        return key.assignable ? .free : .unavailable
    }

    func freeKeys(_ modifiers: Int) -> [KeySpec] { keys.filter { state($0, modifiers) == .free } }
}
