import Carbon
import SwiftUI

/// メニューのホットキー（設定で変えられる）。共通仕様のキー（⌘0・⌘,・⌘W・⌘?）は変えない
@MainActor
final class MenuShortcuts: ObservableObject {
    static let shared = MenuShortcuts()

    enum Command: String, CaseIterable {
        case addFonts, newSet, activate, deactivate, reveal, remove, togglePreview

        var title: String {
            switch self {
            case .addFonts: return L("フォントを追加…")
            case .newSet: return L("新規セット…")
            case .activate: return L("アクティブにする")
            case .deactivate: return L("解除")
            case .reveal: return L("Finderで表示")
            case .remove: return L("ライブラリから取り除く…")
            case .togglePreview: return L("プレビューを隠す・表示")
            }
        }

        /// 1.19 まではアクティブ ⌘E・解除 ⇧⌘E。ユーザー指定で ⇧⌘A・⇧⌘D に変えた。
        var defaultCombo: KeyCombo? {
            switch self {
            case .addFonts: return KeyCombo(code: UInt32(kVK_ANSI_O), modifiers: KeyCombo.command)
            case .newSet: return KeyCombo(code: UInt32(kVK_ANSI_N), modifiers: KeyCombo.command | KeyCombo.shift)
            case .activate: return KeyCombo(code: UInt32(kVK_ANSI_A), modifiers: KeyCombo.command | KeyCombo.shift)
            case .deactivate: return KeyCombo(code: UInt32(kVK_ANSI_D), modifiers: KeyCombo.command | KeyCombo.shift)
            case .reveal: return KeyCombo(code: UInt32(kVK_ANSI_R), modifiers: KeyCombo.command)
            case .remove: return KeyCombo(code: UInt32(kVK_Delete), modifiers: KeyCombo.command)
            case .togglePreview: return KeyCombo(code: UInt32(kVK_ANSI_P), modifiers: KeyCombo.command | KeyCombo.option)
            }
        }

        var key: String { "menuShortcut." + rawValue }
    }

    @Published private var combos: [Command: KeyCombo?] = [:]

    private init() {
        for command in Command.allCases {
            // 保存なし＝初期値、空のデータ＝割り当てを解除した
            if let data = UserDefaults.standard.data(forKey: command.key) {
                combos[command] = data.isEmpty ? .some(nil) : try? JSONDecoder().decode(KeyCombo.self, from: data)
            }
        }
    }

    func combo(_ command: Command) -> KeyCombo? {
        if let stored = combos[command] { return stored }
        return command.defaultCombo
    }

    func set(_ command: Command, _ combo: KeyCombo?) {
        combos[command] = .some(combo)
        UserDefaults.standard.set(combo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: command.key)
    }

    func resetAll() {
        for command in Command.allCases { UserDefaults.standard.removeObject(forKey: command.key) }
        combos = [:]
    }

    /// SwiftUI のメニューに付ける形。打てる文字の無いキーは付けない
    func shortcut(_ command: Command) -> KeyboardShortcut? {
        guard let combo = combo(command), let key = Self.keyEquivalent(combo.code) else { return nil }
        var modifiers: SwiftUI.EventModifiers = []
        if combo.modifiers & KeyCombo.command != 0 { modifiers.insert(.command) }
        if combo.modifiers & KeyCombo.shift != 0 { modifiers.insert(.shift) }
        if combo.modifiers & KeyCombo.option != 0 { modifiers.insert(.option) }
        if combo.modifiers & KeyCombo.control != 0 { modifiers.insert(.control) }
        return KeyboardShortcut(key, modifiers: modifiers)
    }

    private static func keyEquivalent(_ code: UInt32) -> KeyEquivalent? {
        switch Int(code) {
        case kVK_Return: return .return
        case kVK_Tab: return .tab
        case kVK_Space: return .space
        case kVK_Delete: return .delete
        case kVK_ForwardDelete: return .deleteForward
        case kVK_Escape: return .escape
        case kVK_LeftArrow: return .leftArrow
        case kVK_RightArrow: return .rightArrow
        case kVK_UpArrow: return .upArrow
        case kVK_DownArrow: return .downArrow
        case kVK_Home: return .home
        case kVK_End: return .end
        case kVK_PageUp: return .pageUp
        case kVK_PageDown: return .pageDown
        default:
            // 今のキー配列で打つ文字（A → a）。英字は小文字で渡し、⇧ は修飾キーで表す
            let name = KeyCombo.keyName(code)
            guard name.count == 1, let character = name.lowercased().first else { return nil }
            return KeyEquivalent(character)
        }
    }
}

/// 設定の「ホットキー」タブ
struct MenuShortcutsSettingsView: View {
    @ObservedObject private var shortcuts = MenuShortcuts.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(L("メニューのホットキー")) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    ForEach(MenuShortcuts.Command.allCases, id: \.self) { command in
                        GridRow {
                            Text(command.title + L(" :")).gridColumnAlignment(.trailing)
                            HotkeyField(id: "fontswitcher.menu." + command.rawValue,
                                        combo: Binding(get: { shortcuts.combo(command) }, set: { shortcuts.set(command, $0) }),
                                        defaultCombo: command.defaultCombo, allowsClear: true,
                                        others: MenuShortcuts.Command.allCases.filter { $0 != command }
                                            .compactMap { other in shortcuts.combo(other).map { (other.title, $0) } })
                        }
                    }
                }
                Text(L("メニューの項目のキーを変えます。欄をクリックして新しいキーを押します。「メインウインドウを開く」（⌘0）・「設定…」（⌘,）・「ウインドウを閉じる」（⌘W）・ヘルプ（⌘?）は変えられません。"))
                    .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Button(L("初期値に戻す")) { shortcuts.resetAll() }
        }
    }
}
