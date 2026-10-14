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
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([String: MenuShortcut?].self, from: data) {
            overrides = saved
        } else {
            overrides = [:]
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(overrides) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    func shortcut(for action: FormatAction) -> MenuShortcut? {
        if let override = overrides[action.id] { return override }
        return action.defaultShortcut
    }

    func isCustomized(_ action: FormatAction) -> Bool { overrides[action.id] != nil }

    /// 割り当てる。アプリの標準のキーやほかの項目と重なるときは、その理由を返して割り当てない
    func assign(_ shortcut: MenuShortcut?, to action: FormatAction) -> String? {
        if let shortcut {
            if MenuShortcut.reserved.contains(shortcut) {
                return L("%@はアプリの標準のキーで使われています", shortcut.display)
            }
            if let other = FormatAction.allCases.first(where: { $0 != action && self.shortcut(for: $0) == shortcut }) {
                return L("%@は「%@」で使われています", shortcut.display, other.title)
            }
        }
        if shortcut == action.defaultShortcut {
            overrides.removeValue(forKey: action.id)
        } else {
            overrides[action.id] = .some(shortcut)
        }
        return nil
    }

    func reset(_ action: FormatAction) { overrides.removeValue(forKey: action.id) }
    func resetAll() { overrides = [:] }
    var hasCustomizations: Bool { !overrides.isEmpty }
}

/// 割り当てたキーを付けたメニュー項目（割り当てが変わるとメニューも変わる）
struct ShortcutButton: View {
    let action: FormatAction
    @ObservedObject private var store = ShortcutStore.shared
    var body: some View {
        Button(action.title) { action.perform() }
            .keyboardShortcut(store.shortcut(for: action)?.swiftUI)
    }
}

/// 設定の「ホットキー」タブ
struct ShortcutSettingsView: View {
    @ObservedObject private var store = ShortcutStore.shared
    @State private var recording: FormatAction?
    @State private var problem: (FormatAction, String)?
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("項目のキーをクリックして、新しいキーを押します（⌘か⌃を含む組み合わせ）。Escで取り消し。"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(FormatAction.settingsGroups.enumerated()), id: \.offset) { _, group in
                SettingsSection(group.title) {
                    ForEach(group.actions, id: \.self) { action in row(action) }
                }
            }
            Button(L("すべて初期値に戻す")) { stopRecording(); store.resetAll(); problem = nil }
                .disabled(!store.hasCustomizations)
        }
        .onDisappear { stopRecording() }
    }

    private func row(_ action: FormatAction) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(action.title)
                    .frame(width: 150, alignment: .trailing)
                Button {
                    recording == action ? stopRecording() : startRecording(action)
                } label: {
                    Text(recording == action ? L("キーを押してください…") : (store.shortcut(for: action)?.display ?? L("なし")))
                        .font(.system(.body, design: .rounded))
                        .frame(minWidth: 130)
                }
                .accessibilityLabel(L("%@のキー", action.title))
                Button(L("なし")) { stopRecording(); problem = nil; _ = store.assign(nil, to: action) }
                    .disabled(store.shortcut(for: action) == nil)
                Button(L("初期値")) { stopRecording(); problem = nil; store.reset(action) }
                    .disabled(!store.isCustomized(action))
                    .help(action.defaultShortcut.map { L("初期値：%@", $0.display) } ?? L("初期値：なし"))
            }
            if let problem, problem.0 == action {
                Label(problem.1, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.leading, 158)
            }
        }
    }

    private func startRecording(_ action: FormatAction) {
        stopRecording()
        problem = nil
        recording = action
        // Key equivalents are matched later, so a local monitor sees the keys first and keeps them from the menus.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let action = recording else { return event }
            let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
            if event.keyCode == 53, flags.isEmpty { stopRecording(); return nil }
            guard flags.contains(.command) || flags.contains(.control) else { NSSound.beep(); return nil }
            // The key without Shift: ⇧⌘7 is recorded as "7", not "&" or "'".
            var key = event.characters(byApplyingModifiers: [])?.lowercased() ?? ""
            if event.keyCode == 36 || event.keyCode == 76 { key = "\r" }
            guard key.count == 1 else { NSSound.beep(); return nil }
            let shortcut = MenuShortcut(key, flags)
            stopRecording()
            if let message = store.assign(shortcut, to: action) {
                problem = (action, message)
                NSSound.beep()
            }
            return nil
        }
    }

    private func stopRecording() {
        recording = nil
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    }
}
