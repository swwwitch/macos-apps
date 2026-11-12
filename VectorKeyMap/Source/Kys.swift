import Foundation

/// One key assignment. A .kys entry: /<ID> { /Context /Modifiers /Represent /Key }
struct Shortcut: Hashable {
    /// ⌘64・⇧32・⌥128. Illustrator has no ⌃ shortcut.
    let modifiers: Int
    /// Character code, or 14–25 for F1–F12 and 9 for Tab. 0 means not assigned.
    let key: Int
    /// 1 works only while editing text.
    let context: Int

    init?(modifiers: Int, key: Int, context: Int) {
        guard key != 0 else { return nil }
        self.modifiers = modifiers
        self.key = Self.canonicalKey(key)
        self.context = context
    }

    /// Sets differ in letter case (u / U) and in the yen key (\ and ¥ are one key on a Japanese keyboard).
    static func canonicalKey(_ key: Int) -> Int {
        if (97...122).contains(key) { return key - 32 }
        return key == 92 ? 165 : key
    }

    var keyLabel: String {
        switch key {
        case 14...25: return "F\(key - 13)"
        case 9: return "Tab"
        case 32: return "Space"
        case 165: return Self.yenKey
        case 33...126, 128...: return Unicode.Scalar(key).map { String(Character($0)) } ?? "#\(key)"
        default: return "#\(key)"
        }
    }
    static var yenKey = "¥"

    /// ⌥⇧⌘K order, as in macOS menus.
    var label: String {
        (modifiers & 128 != 0 ? "⌥" : "") + (modifiers & 32 != 0 ? "⇧" : "") + (modifiers & 64 != 0 ? "⌘" : "") + keyLabel
    }

    /// Groups by key first, so the same key with different modifiers sits together when sorted.
    var sortKey: String { String(format: "%06d-%03d-%d", key, modifiers, context) }
}

enum CommandKind: String {
    case menu, tool
}

struct CommandKey: Hashable {
    let kind: CommandKind
    let id: String
}

/// A parsed .kys file. A listed command without a key has a nil value.
struct KeySet {
    var entries: [CommandKey: Shortcut?] = [:]
    /// Commands in the file's order, for a stable listing of IDs the name table does not know.
    var order: [CommandKey] = []
    var assignedCount: Int { entries.values.filter { $0 != nil }.count }
}

enum KysError: Error { case notKeySet }

enum Kys {
    private static let entry = try! NSRegularExpression(
        pattern: #"/((?:\\.|[^\s{\\])*)\s*\{\s*/Context\s+(\d+)\s*/Modifiers\s+(\d+)\s*/Represent\s+(\d+)\s*/Key\s+(\d+)\s*\}"#)

    /// /Menus { … } /Tools { … } /type { … }. Line ends are CR or LF.
    static func parse(_ data: Data) throws -> KeySet {
        let text = String(decoding: data, as: UTF8.self)
        let source = text as NSString
        let toolsStart = source.range(of: "/Tools {").location
        var set = KeySet()
        for match in entry.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            func number(_ index: Int) -> Int { Int(source.substring(with: match.range(at: index))) ?? 0 }
            let kind: CommandKind = toolsStart != NSNotFound && match.range.location > toolsStart ? .tool : .menu
            let key = CommandKey(kind: kind, id: unescape(source.substring(with: match.range(at: 1))))
            if set.entries[key] == nil { set.order.append(key) }
            // Key, not Represent: Represent is the label character (zoomin is Key = with Represent +).
            set.entries[key] = .some(Shortcut(modifiers: number(3), key: number(5), context: number(2)))
        }
        guard !set.entries.isEmpty else { throw KysError.notKeySet }
        return set
    }

    /// "\ " is a space and "\ooo" a byte. Adobe writes bytes above 0x7F with the sign bit set
    /// (\743\603\651 is E3 83 A9), so only the low 8 bits count.
    static func unescape(_ raw: String) -> String {
        var bytes: [UInt8] = []
        let source = Array(raw.utf8)
        var index = 0
        while index < source.count {
            let byte = source[index]
            guard byte == UInt8(ascii: "\\"), index + 1 < source.count else {
                bytes.append(byte); index += 1; continue
            }
            let digits = source[(index + 1)..<min(index + 4, source.count)]
            if digits.count == 3, digits.allSatisfy({ (48...55).contains($0) }) {
                let value = digits.reduce(0) { $0 * 8 + Int($1) - 48 }
                bytes.append(UInt8(value & 255))
                index += 4
            } else {
                bytes.append(source[index + 1])
                index += 2
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
