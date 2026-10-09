import SwiftUI

struct SettingsView: View {
    @AppStorage(showGuideKey) private var showGuide = true

    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(Form { Section(SettingsUI.launchTitle) {
                LoginAtLaunchView().fixedSize(horizontal: false, vertical: true)
                MenuBarPresenceView()
            } }.formStyle(.grouped))),
            (SettingsUI.displayTitle, AnyView(SettingsSection(L("メインウインドウ")) {
                Toggle(L("操作手順を表示"), isOn: $showGuide)
                Text(L("一覧の上に、値の変え方と新しいMacへの移し方を表示します。"))
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            })),
            (L("マイプリセット"), AnyView(MyPresetSettings())),
        ]).padding(12)
    }
}
