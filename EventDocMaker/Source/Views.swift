import AppKit
import SwiftUI

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast (3:1 or more) on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

func displayPath(_ path: String) -> String { (path as NSString).abbreviatingWithTildeInPath }

struct FolderSetting: View {
    let title: String
    let detail: String
    @Binding var path: String
    var allowsNone = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            HStack {
                Image(systemName: "folder").foregroundColor(appTint).accessibilityHidden(true)
                Text(path.isEmpty ? L("none") : displayPath(path)).lineLimit(1).truncationMode(.middle).help(path)
                Spacer(minLength: 4)
                Button(L("change")) {
                    let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
                    if !path.isEmpty { panel.directoryURL = URL(fileURLWithPath: path) }
                    if panel.runModal() == .OK, let url = panel.url { path = url.path }
                }
                if allowsNone { Button(L("noneButton")) { path = "" }.disabled(path.isEmpty) }
            }
            Text(detail).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsView: View {
    @ObservedObject var model: Model
    @AppStorage("resident") var resident = true
    var body: some View {
        SettingsTabs(sections: [(SettingsUI.launchTitle, AnyView(VStack(spacing: 16) {
            SettingsSection(SettingsUI.launchTitle) {
                LaunchPresenceSection(title: SettingsUI.launchTitle, loginControl: LoginAtLaunchView(), residentTitle: L("resident"), residentDetail: L("residentDetail"), resident: $resident,
                                      presenceExtra: MenuBarPresenceView(), shortcutTitle: L("launchShortcut"), shortcutButton: L("openShortcuts"), shortcutDetail: L("shortcutDetail")) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(SettingsUI.shortcutTitle).padding(.top, 4)
                    Toggle(HotkeyText.enable, isOn: $model.appHotkeyEnabled)
                    HotkeyField(id: Model.appHotkeyFieldID, combo: $model.appCombo, defaultCombo: Model.defaultAppCombo, allowsClear: true,
                                registered: model.appHotkeyRegistered, isEnabled: model.appHotkeyEnabled)
                    Text(L("appHotkeyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (L("foldersTab"), AnyView(VStack(spacing: 16) {
            SettingsSection(L("foldersTab")) {
                VStack(alignment: .leading, spacing: 14) {
                    FolderSetting(title: L("folder.root"), detail: L("folder.rootDetail"), path: $model.root)
                    FolderSetting(title: L("folder.eventDoc"), detail: L("folder.eventDocDetail"), path: $model.eventDoc)
                    FolderSetting(title: L("folder.recent"), detail: L("folder.recentDetail"), path: $model.recent, allowsNone: true)
                    Button(L("resetFolders")) { let d = Locations.defaults; model.root = d.root; model.eventDoc = d.eventDoc; model.recent = d.recent }
                }
            }
            SettingsSection(L("openSection")) {
                Picker(L("openWith"), selection: $model.opener) {
                    Text("Path Finder").tag("pathfinder")
                    Text("Finder").tag("finder")
                }.pickerStyle(.radioGroup)
                Text(L("openDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        })), (AboutSection.title, AnyView(AboutView()))])
            .frame(minWidth: 560, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
    }
}
