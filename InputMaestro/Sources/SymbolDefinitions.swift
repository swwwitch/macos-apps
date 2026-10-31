import Foundation

/// Only the eight generic symbol entries from InsertSnippets; no personal snippets or settings are imported.
struct SymbolDefinition: Identifiable {
    var id: String
    var text: String
    var code: UInt32
    var modifiers: UInt32
    var isArrow: Bool
}
enum SymbolDefinitions {
    static let all: [SymbolDefinition] = [
        .init(id: "control", text: "⌃", code: 38, modifiers: 2048 | 512, isArrow: false),
        .init(id: "option", text: "⌥", code: 40, modifiers: 2048 | 512, isArrow: false),
        .init(id: "command", text: "⌘", code: 37, modifiers: 2048 | 512, isArrow: false),
        .init(id: "shift", text: "⇧", code: 34, modifiers: 2048 | 512, isArrow: false),
        .init(id: "left", text: "←", code: 38, modifiers: 4096 | 2048 | 512, isArrow: true),
        .init(id: "down", text: "↓", code: 40, modifiers: 4096 | 2048 | 512, isArrow: true),
        .init(id: "right", text: "→", code: 37, modifiers: 4096 | 2048 | 512, isArrow: true),
        .init(id: "up", text: "↑", code: 34, modifiers: 4096 | 2048 | 512, isArrow: true),
    ]
}
