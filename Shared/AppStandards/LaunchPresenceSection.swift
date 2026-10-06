import SwiftUI

/// Shared settings layout: login, presence, then the app-launch shortcut.
/// Callers provide localized copy and the system-backed login control.
struct LaunchPresenceSection<LoginControl: View>: View {
    let title: String
    let loginControl: LoginControl
    let residentTitle: String
    let residentDetail: String
    @Binding var resident: Bool
    let shortcutTitle: String
    let shortcutButton: String
    let shortcutDetail: String
    let configureShortcut: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            loginControl.frame(minHeight: 58)
            Toggle(residentTitle, isOn: $resident)
            Text(residentDetail).font(.caption).foregroundColor(.secondary)
            HStack {
                Text(shortcutTitle)
                Spacer()
                Button(shortcutButton, action: configureShortcut)
            }
            Text(shortcutDetail).font(.caption).foregroundColor(.secondary)
        }
    }
}
