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

/// 「設定の共有」タブ：共通の「書き出し・読み込み」「設定の同期」と、終了時の自動書き出し
/// アプリの設定の置き場は同期フォルダーの中の SettingsCourier フォルダーで決まるので、場所の設定は置かない
private struct CourierSharingView: View {
    @ObservedObject private var courier = Courier.shared
    @ObservedObject private var sync = SettingsSync.shared
    @AppStorage(Courier.autoExportKey) private var autoExport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSharingView()
            VStack(alignment: .leading, spacing: 6) {
                Toggle(L("登録したアプリを終了したときに書き出す"), isOn: $autoExport)
                    .disabled(courier.folder == nil)
                Text(L("同期フォルダーの SettingsCourier フォルダーに書き出します。SettingsCourierが起動している間だけ働き、値が変わっていなければ書きません。"))
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let last = courier.lastAutoExport {
                    Text(last).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 12)
        }
        .onChange(of: sync.pathText) { courier.scanFolder() }
    }
}
