import SwiftUI

struct SettingsView: View {
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(Form { Section(SettingsUI.launchTitle) {
                LoginAtLaunchView().fixedSize(horizontal: false, vertical: true)
                MenuBarPresenceView()
            } }.formStyle(.grouped))),
            (L("見出し"), AnyView(HeadingSettingsView())),
            (L("HTML→Markdown"), AnyView(HTMLToMarkdownSettingsView())),
            (L("テーマ"), AnyView(DoorkeeperPresetsView())),
            (AboutSection.title, AnyView(AboutView()))
        ]).padding(12)
    }
}

/// 原稿での見出しの表示（コピーの形式はメインウインドウの「コピー」で選ぶ）
private struct HeadingSettingsView: View {
    @AppStorage(MarkdownStore.boldHeadingsKey) private var boldHeadings = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(L("表示")) {
                Toggle(L("見出しを太字で表示"), isOn: $boldHeadings)
            }

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
