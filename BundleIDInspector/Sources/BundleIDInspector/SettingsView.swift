import SwiftUI

struct SettingsView: View {
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(Form { Section(SettingsUI.launchTitle) {
                LoginAtLaunchView().fixedSize(horizontal: false, vertical: true)
                MenuBarPresenceView()
            } }.formStyle(.grouped))),
            (AboutSection.title, AnyView(AboutView()))
        ]).padding(12)
    }
}
