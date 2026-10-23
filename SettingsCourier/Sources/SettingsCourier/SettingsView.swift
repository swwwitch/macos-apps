import SwiftUI

struct SettingsView: View {
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(alignment: .leading, spacing: 16) {
                SettingsSection(SettingsUI.launchTitle) {
                    LoginAtLaunchView().fixedSize(horizontal: false, vertical: true)
                    MenuBarPresenceView()
                }
                FullDiskAccessSection()
            })),
            (L("受け渡しフォルダー"), AnyView(FolderSettings())),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView())),
        ]).padding(12)
    }
}

/// 受け渡しフォルダーの場所と、終了時の自動書き出し。パスはMacごとに異なるので設定の共有には含めない
private struct FolderSettings: View {
    @ObservedObject private var courier = Courier.shared
    @AppStorage(Courier.autoExportKey) private var autoExport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(L("受け渡しフォルダー")) {
                Text(courier.folder?.path ?? (courier.folderMissing ? L("受け渡しフォルダーが見つかりません") : L("未設定")))
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(L("選択…")) { courier.chooseFolder() }
                    Button(L("Finderで表示")) { courier.showFolder() }.disabled(courier.folder == nil)
                    Button(L("解除")) { courier.clearFolder() }
                        .disabled(UserDefaults.standard.string(forKey: Courier.folderKey) == nil)
                }
                Text(L("Dropbox・iCloud Drive などほかのMacと同期しているフォルダーを選びます。「フォルダーに書き出す」でアプリごとに「<アプリ名>.settingscourier」を置き、ほかのMacでは「フォルダーから取り込む…」で選んで取り込みます。自動では取り込みません。"))
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SettingsSection(L("自動書き出し")) {
                Toggle(L("登録したアプリを終了したときに書き出す"), isOn: $autoExport)
                    .disabled(courier.folder == nil)
                Text(L("SettingsCourierが起動している間だけ働きます。値が変わっていなければ書き出しません。サンドボックスのアプリは、フルディスクアクセスを許可しているか、メインウインドウで「設定を読む」を押したあとだけ書き出します。"))
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let last = courier.lastAutoExport {
                    Text(last).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
