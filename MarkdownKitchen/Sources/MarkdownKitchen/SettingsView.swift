import SwiftUI

struct SettingsView: View {
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(SettingsSection(SettingsUI.launchTitle) {
                LoginAtLaunchView().fixedSize(horizontal: false, vertical: true)
                MenuBarPresenceView()
            })),
            (L("ホットキー"), AnyView(ShortcutSettingsView())),
            (L("HTML→Markdown"), AnyView(HTMLToMarkdownSettingsView())),
            (L("テーマ"), AnyView(VStack(alignment: .leading, spacing: 16) { DoorkeeperPresetsView(); DivBoxSettingsView() })),
            (L("右クリック"), AnyView(ContextMenuSettingsView())),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(VStack(spacing: 24) { AboutView(); AcknowledgmentsView() }))
        ]).padding(12)
    }
}

/// 表示メニューの原稿欄の項目：配色・表示・見出しの太字（以前は設定の「見出し」タブ）
struct EditorViewMenuItems: View {
    @AppStorage(MarkdownStore.boldHeadingsKey) private var boldHeadings = true
    @AppStorage(MarkdownStore.editorStyleKey) private var editorStyle = SourceEditor.currentStyle
    @AppStorage(MarkdownStore.editorAppearanceKey) private var editorAppearance = "auto"
    @AppStorage(MarkdownStore.marginKey) private var margin = "standard"
    @AppStorage(MarkdownStore.editorFontKey) private var editorFont = ""
    @AppStorage(MarkdownStore.lineSpacingKey) private var lineSpacing = MarkdownStore.defaultLineSpacing

    var body: some View {
        // Checked buttons rather than an inline Picker, which adds separators around the items.
        Menu(L("原稿の配色")) {
            choice(L("自動"), "auto", $editorAppearance)
            choice(L("ライト"), "light", $editorAppearance)
            choice(L("ダーク"), "dark", $editorAppearance)
        }
        Menu(L("原稿の表示")) {
            choice(L("MacDown風"), "rich", $editorStyle)
            choice(L("色分け"), "color", $editorStyle)
            choice(L("プレーン"), "plain", $editorStyle)
        }
        Button(L("原稿のフォント…")) { EditorFontPicker.shared.show() }
        Button(L("標準のフォントに戻す")) { editorFont = "" }
            .disabled(editorFont.isEmpty)
        Menu(L("行送り")) {
            ForEach(MarkdownStore.lineSpacings, id: \.self) { value in
                Button { lineSpacing = value } label: {
                    let title = String(format: "%.1f", value)
                    if lineSpacing == value { Label(title, systemImage: "checkmark") } else { Text(title) }
                }
            }
        }
        Menu(L("余白")) {
            choice(L("狭い"), "narrow", $margin)
            choice(L("標準"), "standard", $margin)
            choice(L("広い"), "wide", $margin)
        }
        // Used with 色分け only (MacDown style is always bold; Plain never is).
        Toggle(L("見出しを太字で表示"), isOn: $boldHeadings)
            .disabled(editorStyle != "color")
    }

    private func choice(_ title: String, _ value: String, _ selection: Binding<String>) -> some View {
        Button { selection.wrappedValue = value } label: {
            if selection.wrappedValue == value { Label(title, systemImage: "checkmark") } else { Text(title) }
        }
    }
}

/// HTML→Markdownで変換しない要素
private struct HTMLToMarkdownSettingsView: View {
    @AppStorage(MarkdownStore.skipDivsKey) private var skipDivs = true
    @AppStorage(MarkdownStore.skipTablesKey) private var skipTables = true

    var body: some View {
        SettingsSection(L("変換しない要素")) {
            Toggle(L("div要素内は無視"), isOn: $skipDivs)
            Toggle(L("table要素内は無視"), isOn: $skipTables)
            Text(L("オンにした要素は、開始タグから終了タグまで（入れ子も含む）をHTMLのまま残します。"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 「情報」タブの下の謝辞（同梱しているオープンソースの著作権表示）。AboutSection は共通部品なので、ここで足す
private struct AcknowledgmentsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("謝辞")).font(.system(size: 13, weight: .semibold)).padding(.leading, 4)
            VStack(alignment: .leading, spacing: 6) {
                Text("highlight.js 11.9.0").font(.callout.weight(.semibold))
                Text("Copyright (c) 2006, Ivan Sagalaev. BSD 3-Clause License.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(L("プレビューのコードブロックの色分けに使っています。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(L("ライセンスを表示")) {
                    if let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil, subdirectory: "highlight") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
                Divider().padding(.vertical, 4)
                Text("MacDown").font(.callout.weight(.semibold))
                Text(L("メニューの構成・キーの割り当て・入力の補助・原稿の表示（MacDown風）を参考にしました。MacDown（MIT License）のコードは含んでいません。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08)))
        }
    }
}

/// 「原稿のフォント…」：標準のフォントパネルで選んだフォントと大きさを原稿欄に使う
@MainActor
final class EditorFontPicker: NSObject {
    static let shared = EditorFontPicker()

    func show() {
        let defaults = UserDefaults.standard
        let size = defaults.object(forKey: MarkdownStore.fontSizeKey) as? Double ?? MarkdownStore.defaultFontSize
        let manager = NSFontManager.shared
        // The panel reports to this object, not to the source text view (which would restyle its text).
        manager.target = self
        manager.setSelectedFont(SourceEditor.baseFont(size, rich: SourceEditor.currentStyle == "rich"), isMultiple: false)
        manager.orderFrontFontPanel(self)
    }

    /// The font panel sends this to the font manager's target (changeFont: by selector).
    @objc func changeFont(_ sender: Any?) {
        do {
            guard let manager = sender as? NSFontManager else { return }
            let defaults = UserDefaults.standard
            let size = defaults.object(forKey: MarkdownStore.fontSizeKey) as? Double ?? MarkdownStore.defaultFontSize
            let font = manager.convert(SourceEditor.baseFont(size, rich: SourceEditor.currentStyle == "rich"))
            defaults.set(font.fontName, forKey: MarkdownStore.editorFontKey)
            let newSize = min(max(Double(font.pointSize), MarkdownStore.fontSizes.lowerBound), MarkdownStore.fontSizes.upperBound)
            defaults.set(newSize, forKey: MarkdownStore.fontSizeKey)
        }
    }

    @objc func validModesForFontPanel(_ fontPanel: NSFontPanel) -> NSFontPanel.ModeMask {
        [.face, .size, .collection]
    }
}

/// 設定の「右クリック」：原稿の右クリックメニューに出す書式の項目
private struct ContextMenuSettingsView: View {
    @State private var hidden: Set<String> = FormatAction.hiddenInContextMenu

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(L("右クリックメニューに表示する項目")) {
                Text(L("チェックを外した項目は、原稿の右クリックメニューに出しません（メニューバーの「書式」はそのまま）。"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(FormatAction.contextGroups.enumerated()), id: \.offset) { index, group in
                    if index > 0 { Divider() }
                    ForEach(group, id: \.self) { action in
                        Toggle(action.title, isOn: Binding(
                            get: { !hidden.contains(action.id) },
                            set: { shown in
                                if shown { hidden.remove(action.id) } else { hidden.insert(action.id) }
                                UserDefaults.standard.set(Array(hidden).sorted(), forKey: FormatAction.contextHiddenKey)
                            }))
                    }
                }
            }
            Button(L("すべて表示に戻す")) {
                hidden = []
                UserDefaults.standard.removeObject(forKey: FormatAction.contextHiddenKey)
            }
            .disabled(hidden.isEmpty)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppDelegate.settingsImported)) { _ in
            hidden = FormatAction.hiddenInContextMenu
        }
    }
}
