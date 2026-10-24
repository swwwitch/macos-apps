import SwiftUI

struct SettingsView: View {
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(SettingsSection(SettingsUI.launchTitle) {
                LoginAtLaunchView().fixedSize(horizontal: false, vertical: true)
                MenuBarPresenceView()
            })),
            (L("取り込み"), AnyView(MirrorSettingsView())),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView())),
        ]).padding(12)
    }
}

/// 「取り込み」タブ：たどる範囲と上限。変更は次の取り込みから使う
private struct MirrorSettingsView: View {
    @AppStorage(Mirror.externalAssetsKey) private var externalAssets = true
    @AppStorage(Mirror.subdomainsKey) private var subdomains = false
    @AppStorage(Mirror.startFolderOnlyKey) private var startFolderOnly = false
    @AppStorage(Mirror.obeyRobotsKey) private var obeyRobots = true
    @AppStorage(Mirror.maxDepthKey) private var maxDepth = 0
    @AppStorage(Mirror.maxFilesKey) private var maxFiles = 10_000
    @AppStorage(Mirror.connectionsKey) private var connections = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(L("取り込む範囲")) {
                Toggle(L("ほかのドメインのCSS・JavaScript・画像・フォントも保存"), isOn: $externalAssets)
                note(L("CDNなどに置かれた、ページの表示に必要なファイルを保存します。ほかのドメインのページはたどりません。"))
                Toggle(L("サブドメインのページもたどる"), isOn: $subdomains)
                Toggle(L("開始URLのフォルダーより上はたどらない"), isOn: $startFolderOnly)
                Toggle(L("robots.txtに従う"), isOn: $obeyRobots)
            }
            SettingsSection(L("上限")) {
                Stepper(value: $maxDepth, in: 0...50) {
                    Text(maxDepth == 0 ? L("たどる深さ : 無制限") : L("たどる深さ : %d", maxDepth))
                }
                Stepper(value: $maxFiles, in: 0...200_000, step: 1_000) {
                    Text(maxFiles == 0 ? L("ファイル数 : 無制限") : L("ファイル数 : %d", maxFiles))
                }
                Stepper(value: $connections, in: 1...8) {
                    Text(L("同時接続数 : %d", connections))
                }
                note(L("同時接続数を増やすと速くなりますが、相手のサーバーの負担が増えます。"))
                Button(L("初期値に戻す")) {
                    externalAssets = true; subdomains = false; startFolderOnly = false; obeyRobots = true
                    maxDepth = 0; maxFiles = 10_000; connections = 4
                }
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
