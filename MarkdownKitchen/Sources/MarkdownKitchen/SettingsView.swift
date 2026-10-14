import SwiftUI

struct SettingsView: View {
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(Form { Section(SettingsUI.launchTitle) {
                LoginAtLaunchView().fixedSize(horizontal: false, vertical: true)
                MenuBarPresenceView()
            } }.formStyle(.grouped))),
            (L("見出し"), AnyView(HeadingSettingsView())),
            (L("ホットキー"), AnyView(ShortcutSettingsView())),
            (L("HTML→Markdown"), AnyView(HTMLToMarkdownSettingsView())),
            (L("テーマ"), AnyView(DoorkeeperPresetsView())),
            (AboutSection.title, AnyView(VStack(spacing: 24) { AboutView(); AcknowledgmentsView() }))
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08)))
        }
    }
}
