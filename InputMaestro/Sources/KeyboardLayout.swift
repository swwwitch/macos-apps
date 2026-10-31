import Foundation

// Physical key positions of Apple keyboards, for the keyboard view. Copied from FnNumpad (DocklessLauncher origin, pure data).
// Widths are in key units (a letter key = 1). `code` is the virtual key code; nil is a gap or a key that cannot be used.

struct KeySpec: Equatable {
    var code: UInt32?
    var width: Double = 1
    /// Fixed caption for keys whose name does not come from the input source (tab, shift, …).
    var caption: String?
    /// Modifier and system keys are drawn but cannot take an app.
    var assignable: Bool { code != nil && caption == nil || KeyboardLayout.namedAssignable.contains(code ?? 0) }
}

enum KeyboardLayout: String, CaseIterable {
    case ansi, jis

    /// Named keys that can still be shortcuts (Return, Delete, Space, F-keys, arrows, Esc, 英数/かな).
    static let namedAssignable: Set<UInt32> = [36, 51, 49, 53, 48, 122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
                                                123, 124, 125, 126, 102, 104]

    var rows: [[KeySpec]] {
        let fn: [KeySpec] = [KeySpec(code: 53, width: 1.5, caption: "esc")] + [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
            .enumerated().map { KeySpec(code: UInt32($0.element), width: 1.08, caption: "F\($0.offset + 1)") }
        func keys(_ codes: [UInt32]) -> [KeySpec] { codes.map { KeySpec(code: $0) } }
        switch self {
        case .ansi:
            return [
                fn,
                [KeySpec(code: 50)] + keys([18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24]) + [KeySpec(code: 51, width: 1.5, caption: "delete")],
                [KeySpec(code: 48, width: 1.5, caption: "tab")] + keys([12, 13, 14, 17, 16, 15, 32, 34, 31, 35, 33, 30]).reorderedQWERTY() + [KeySpec(code: 42)],
                [KeySpec(code: nil, width: 1.75, caption: "⇪")] + keys([0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39]) + [KeySpec(code: 36, width: 1.75, caption: "return")],
                [KeySpec(code: nil, width: 2.25, caption: "⇧")] + keys([6, 7, 8, 9, 11, 45, 46, 43, 47, 44]) + [KeySpec(code: nil, width: 2.25, caption: "⇧")],
                [KeySpec(code: nil, caption: "fn"), KeySpec(code: nil, caption: "⌃"), KeySpec(code: nil, caption: "⌥"),
                 KeySpec(code: nil, width: 1.25, caption: "⌘"), KeySpec(code: 49, width: 5, caption: "space"),
                 KeySpec(code: nil, width: 1.25, caption: "⌘"), KeySpec(code: nil, caption: "⌥"),
                 KeySpec(code: 123, caption: "←"), KeySpec(code: 125, caption: "↓"), KeySpec(code: 126, caption: "↑"), KeySpec(code: 124, caption: "→")]
            ]
        case .jis:
            return [
                fn,
                keys([18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24, 93]) + [KeySpec(code: 51, width: 1.5, caption: "delete")],
                [KeySpec(code: 48, width: 1.5, caption: "tab")] + keys([12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30]) + [KeySpec(code: 36, width: 1.5, caption: "return")],
                [KeySpec(code: nil, width: 1.75, caption: "⌃")] + keys([0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39, 42]) + [KeySpec(code: nil, width: 1.25)],
                [KeySpec(code: nil, width: 2.25, caption: "⇧")] + keys([6, 7, 8, 9, 11, 45, 46, 43, 47, 44, 94]) + [KeySpec(code: nil, width: 1.75, caption: "⇧")],
                [KeySpec(code: nil, caption: "⇪"), KeySpec(code: nil, caption: "⌥"), KeySpec(code: nil, width: 1.25, caption: "⌘"),
                 KeySpec(code: 102, width: 1.25, caption: "英数"), KeySpec(code: 49, width: 4, caption: "space"), KeySpec(code: 104, width: 1.25, caption: "かな"),
                 KeySpec(code: nil, width: 1.25, caption: "⌘"), KeySpec(code: nil, caption: "fn"),
                 KeySpec(code: 123, caption: "←"), KeySpec(code: 125, caption: "↓"), KeySpec(code: 126, caption: "↑"), KeySpec(code: 124, caption: "→")]
            ]
        }
    }
    /// Widest row in key units, for scaling.
    var width: Double { rows.map { $0.reduce(0) { $0 + $1.width } }.max() ?? 15 }
}

private extension Array where Element == KeySpec {
    /// The ANSI row is listed by code above for brevity; put it in physical Q W E R T Y order.
    func reorderedQWERTY() -> [KeySpec] {
        let order: [UInt32] = [12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30]
        return order.compactMap { code in first { $0.code == code } }
    }
}
