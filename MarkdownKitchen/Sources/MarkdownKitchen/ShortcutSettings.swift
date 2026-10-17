import AppKit
import SwiftUI

/// メニューのキー（文字と修飾キー）
struct MenuShortcut: Codable, Equatable {
    var key: String
    var modifiers: UInt

    init(_ key: String, _ flags: NSEvent.ModifierFlags) {
        self.key = key
        modifiers = flags.intersection([.command, .option, .shift, .control]).rawValue
    }

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    /// 矢印キー（NSMenuItem のキー表記）
    static let upArrow = String(Character(UnicodeScalar(NSUpArrowFunctionKey)!))
    static let downArrow = String(Character(UnicodeScalar(NSDownArrowFunctionKey)!))
    static let leftArrow = String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!))
    static let rightArrow = String(Character(UnicodeScalar(NSRightArrowFunctionKey)!))

    /// 「⌥⌘1」のような表記
    var display: String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        switch key {
        case "\r": return text + "↩"
        case "\t": return text + "⇥"
        case " ": return text + "Space"
        case Self.upArrow: return text + "↑"
        case Self.downArrow: return text + "↓"
        case Self.leftArrow: return text + "←"
        case Self.rightArrow: return text + "→"
        default: return text + key.uppercased()
        }
    }

    var swiftUI: KeyboardShortcut {
        var modifiers: EventModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.control) { modifiers.insert(.control) }
        let equivalent: KeyEquivalent
        switch key {
        case "\r": equivalent = .return
        case "\t": equivalent = .tab
        case Self.upArrow: equivalent = .upArrow
        case Self.downArrow: equivalent = .downArrow
        case Self.leftArrow: equivalent = .leftArrow
        case Self.rightArrow: equivalent = .rightArrow
        default: equivalent = KeyEquivalent(Character(key))
        }
        return KeyboardShortcut(equivalent, modifiers: modifiers)
    }

    /// アプリの標準のキー（変えられない）。メニューの共通構成・ファイル・編集・文字サイズなど
    static let reserved: [MenuShortcut] = [
        .init("0", .command), .init("1", .command), .init(",", .command), .init("q", .command), .init("w", .command),
        .init("h", .command), .init("h", [.command, .option]), .init("o", .command), .init("s", .command), .init("s", [.command, .shift]),
        .init("z", .command), .init("z", [.command, .shift]), .init("x", .command), .init("c", .command), .init("v", .command),
        .init("a", .command), .init("?", .command),
        // Hidden list keys (FormatAction.hiddenKeys).
        .init("5", [.command, .option]), .init("6", [.command, .option]), .init("m", [.command, .option]),
        .init("+", .command), .init("-", .command),
    ]
}

/// 書式などのキーの割り当て。初期値と違うものだけを保存する（nil＝キーなし）
@MainActor
final class ShortcutStore: ObservableObject {
    static let shared = ShortcutStore()
    static let key = "markdownKitchen.shortcuts"

    /// 項目のID → 割り当て。値が nil の項目はキーなし
    @Published private var overrides: [String: MenuShortcut?] {
        didSet { save() }
    }

    init() {
        overrides = Self.stored
    }

    private static var stored: [String: MenuShortcut?] {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([String: MenuShortcut?].self, from: $0) } ?? [:]
    }

    /// 設定の読み込み・同期の後に UserDefaults から読み直す（古い割り当てで書き戻さない）
    func reload() {
        let saved = Self.stored
        if saved != overrides { overrides = saved }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(overrides) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    func shortcut(for action: FormatAction) -> MenuShortcut? {
        if let override = overrides[action.id] { return override }
        return action.defaultShortcut
    }


    /// 割り当てる（nil＝キーなし）。重なりは設定の記録欄（HotkeyField の others）で断っている
    func set(_ shortcut: MenuShortcut?, for action: FormatAction) {
        if shortcut == action.defaultShortcut {
            overrides.removeValue(forKey: action.id)
        } else {
            overrides[action.id] = .some(shortcut)
        }
    }

    func resetAll() { overrides = [:] }
    var hasCustomizations: Bool { !overrides.isEmpty }
}

/// 割り当てたキーを付けたメニュー項目（割り当てが変わるとメニューも変わる）
struct ShortcutButton: View {
    let action: FormatAction
    /// サブメニューの中で短く出す名前（なければ action.title）
    var title: String?
    @ObservedObject private var store = ShortcutStore.shared
    var body: some View {
        Button(title ?? action.title) { action.perform() }
            .keyboardShortcut(store.shortcut(for: action)?.swiftUI)
    }
}

/// 設定の「ホットキー」タブ。記録欄は全アプリ共通の HotkeyField（保存は MenuShortcut のまま）
struct ShortcutSettingsView: View {
    @ObservedObject private var store = ShortcutStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("書式・変換などのメニュー項目のキーです。MarkdownKitchenが前面のときだけ効きます。"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(FormatAction.settingsGroups.enumerated()), id: \.offset) { _, group in
                SettingsSection(group.title) {
                    ForEach(group.actions, id: \.self) { action in row(action) }
                }
            }
            Button(L("すべて初期値に戻す")) { HotkeyRecorder.shared.stop(); store.resetAll() }
                .disabled(!store.hasCustomizations)
        }
        .onDisappear { HotkeyRecorder.shared.stop() }
    }

    private func row(_ action: FormatAction) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(action.title)
                .frame(width: 150, alignment: .trailing)
            HotkeyField(id: "markdownKitchen.shortcut." + action.id,
                        combo: Binding(get: { store.shortcut(for: action)?.combo },
                                       set: { store.set($0.flatMap(MenuShortcut.init(combo:)), for: action) }),
                        defaultCombo: action.defaultShortcut?.combo,
                        allowsClear: true,
                        others: others(action))
        }
    }

    /// 重ねられないキー：ほかの項目のキーと、アプリの標準のキー（メニューの共通構成・ファイル・編集・文字サイズなど）
    private func others(_ action: FormatAction) -> [(String, KeyCombo)] {
        let items = FormatAction.allCases.filter { $0 != action }.compactMap { other in
            store.shortcut(for: other)?.combo.map { (other.title, $0) }
        }
        return items + MenuShortcut.reserved.compactMap { reserved in reserved.combo.map { (L("アプリの標準のキー"), $0) } }
    }
}
