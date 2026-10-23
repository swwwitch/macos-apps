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
            (SettingsSync.shared.tabTitle, AnyView(CourierSharingView())),
            (AboutSection.title, AnyView(AboutView())),
        ]).padding(12)
    }
}

/// 「設定の共有」タブ：共通の「書き出し・読み込み」「設定の同期」に、アプリの設定の受け渡しの節を足す（PrefsPreset のマイプリセットと同じ形）
/// 受け渡しフォルダーは同期フォルダーの中の SettingsCourier フォルダー。同期フォルダーを選び直すと受け渡し先も変わる
private struct CourierSharingView: View {
    @ObservedObject private var courier = Courier.shared
    @ObservedObject private var sync = SettingsSync.shared
    @AppStorage(Courier.autoExportKey) private var autoExport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSharingView()
            SettingsSection(L("アプリの設定の受け渡し")) {
                Text(courier.folder?.path ?? (courier.folderMissing ? L("同期フォルダーが見つかりません") : L("上の「設定の同期」で同期フォルダーを選ぶと使えます")))
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L("Finderで表示")) { courier.showFolder() }.disabled(courier.folder == nil)
                Text(L("「フォルダーに書き出す」で、同期フォルダーの中の SettingsCourier フォルダーにアプリごとの「<アプリ名>.settingscourier」を置きます。ほかのMacでは「フォルダーから取り込む…」で選んで取り込みます。アプリの設定を書き換えるので、自動では取り込みません。"))
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
        .onChange(of: sync.pathText) { courier.scanFolder() }
    }
}
