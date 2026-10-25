import AppKit
import SwiftUI

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast (3:1 or more) on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

func displayPath(_ path: String) -> String { (path as NSString).abbreviatingWithTildeInPath }

struct MainView: View {
    @ObservedObject var model: Model
    @State private var showVariables = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(nsImage: currentAppIcon()).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                    AppVersionLabel()
                }
                VStack(alignment: .leading, spacing: 4) { Text(L("heading")).font(.system(size: 22, weight: .semibold)); Text(L("subtitle")).foregroundStyle(.secondary) }
                Spacer()
            }
            HStack {
                Text(L("sheet")).font(.headline)
                Spacer()
                Button(L("loadClipboardButton")) { model.loadClipboard() }
                Button(L("clear")) { model.sheet = ""; model.result = nil; model.setStatus("") }.disabled(model.sheet.isEmpty)
            }
            TextEditor(text: $model.sheet)
                .font(.system(size: 11, design: .monospaced))
                .frame(minHeight: 130)
                .overlay(alignment: .topLeading) {
                    if model.sheet.isEmpty { Text(L("sheetPlaceholder")).font(.callout).foregroundColor(.secondary).padding(8).allowsHitTesting(false) }
                }
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.gray.opacity(0.25)))
                .accessibilityLabel(L("sheet"))
            summary
            HStack(spacing: 16) {
                Toggle(L("makeQR"), isOn: $model.makeQR)
                Toggle(L("openAfter"), isOn: $model.openAfter)
                Spacer()
                if model.working { ProgressView().controlSize(.small) }
                Button(L("generate")) { model.generate() }.keyboardShortcut(.return, modifiers: .command).disabled(!model.canGenerate)
            }
            if let result = model.result { resultView(result) }
            DisclosureGroup(isExpanded: $showVariables) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(model.event.vars.keys.sorted(), id: \.self) { name in
                            HStack(alignment: .firstTextBaseline) {
                                Text(name).font(.system(size: 11, design: .monospaced)).frame(width: 260, alignment: .leading).textSelection(.enabled)
                                Text(model.event[name].replacingOccurrences(of: "\n", with: "⏎")).font(.caption).foregroundColor(.secondary).lineLimit(1).textSelection(.enabled)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(height: 160)
            } label: { Text(String(format: L("variables"), model.event.vars.count)) }
            Text(model.status.isEmpty ? " " : model.status).font(.callout).foregroundColor(model.statusIsError ? .red : .secondary).lineLimit(2)
        }
        .padding(20)
        .frame(minWidth: 600, maxWidth: .infinity, minHeight: 640, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: AppSurface.color)).tint(appTint)
    }

    private var summary: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 4) {
            row("summary.category", model.event["EventCategory"])
            row("summary.name", model.event["EventName"])
            row("summary.date", model.event["EventDate"])
            GridRow {
                Text(L("summary.folder")).foregroundColor(.secondary).gridColumnAlignment(.trailing)
                if model.event.missingRequired.isEmpty {
                    Text(displayPath(model.root) + "/" + model.event["EventPath"]).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                } else {
                    Text(String(format: L("summary.missing"), model.event.missingRequired.joined(separator: L("listSeparator")))).foregroundColor(model.sheet.isEmpty ? .secondary : .orange)
                }
            }
            row("summary.templates", String(format: L("summary.templateCount"), model.templateCount))
        }.font(.callout)
    }
    private func row(_ key: String, _ value: String) -> some View {
        GridRow { Text(L(key)).foregroundColor(.secondary); Text(value.isEmpty ? "—" : value).lineLimit(1) }
    }

    private func resultView(_ result: GenerationResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(String(format: L("result.written"), result.written.count), systemImage: "checkmark.circle.fill").foregroundColor(.green)
                Spacer()
                Button(L("result.open")) { model.open(result.folder.appendingPathComponent("docs")) }
            }
            if !result.qrCodes.isEmpty { Text(String(format: L("result.qr"), result.qrCodes.count)).font(.caption) }
            if let copy = result.storesCopy { Text(String(format: L("result.stores"), copy)).font(.caption) }
            if !result.emptyVariables.isEmpty {
                Text(String(format: L("result.empty"), result.emptyVariables.count, result.emptyVariables.prefix(12).joined(separator: " ")))
                    .font(.caption).foregroundColor(.secondary).lineLimit(3).textSelection(.enabled)
            }
            ForEach(result.warnings, id: \.self) { Text($0).font(.caption).foregroundColor(.orange) }
        }
        .padding(10).background(Color(nsColor: .textBackgroundColor)).cornerRadius(8)
    }
}

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
