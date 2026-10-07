import SwiftUI

/// Shared settings layout: login, presence, then the app-launch shortcut.
/// Callers provide localized copy and the system-backed login control.
/// `presenceExtra` (e.g. the menu bar toggle) sits after the resident toggle, before the shortcut.
struct LaunchPresenceSection<LoginControl: View, PresenceExtra: View>: View {
    let title: String
    let loginControl: LoginControl
    let residentTitle: String
    let residentDetail: String
    @Binding var resident: Bool
    var presenceExtra: PresenceExtra
    let shortcutTitle: String
    let shortcutButton: String
    let shortcutDetail: String
    let configureShortcut: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            loginControl.fixedSize(horizontal: false, vertical: true)
            Toggle(residentTitle, isOn: $resident)
            Text(residentDetail).font(.caption).foregroundColor(.secondary)
            presenceExtra
            HStack {
                Text(shortcutTitle)
                Spacer()
                Button(shortcutButton, action: configureShortcut)
            }
            Text(shortcutDetail).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension LaunchPresenceSection where PresenceExtra == EmptyView {
    /// Original signature, kept for existing callers.
    init(title: String, loginControl: LoginControl, residentTitle: String, residentDetail: String, resident: Binding<Bool>,
         shortcutTitle: String, shortcutButton: String, shortcutDetail: String, configureShortcut: @escaping () -> Void) {
        self.init(title: title, loginControl: loginControl, residentTitle: residentTitle, residentDetail: residentDetail, resident: resident,
                  presenceExtra: EmptyView(), shortcutTitle: shortcutTitle, shortcutButton: shortcutButton, shortcutDetail: shortcutDetail,
                  configureShortcut: configureShortcut)
    }
}
