import AppKit
import SwiftUI

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast (3:1 or more) on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

func chooseFolder(_ start: String) -> String? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
    panel.directoryURL = URL(fileURLWithPath: start)
    panel.prompt = L("choose")
    return panel.runModal() == .OK ? panel.url?.path : nil
}
func displayPath(_ path: String) -> String { (path as NSString).abbreviatingWithTildeInPath }

struct FolderRow: View {
    let title: String
    @Binding var path: String
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Image(systemName: "folder").foregroundColor(appTint).accessibilityHidden(true)
            Text(displayPath(path)).lineLimit(1).truncationMode(.middle).help(path)
            Spacer(minLength: 4)
            Button(L("change")) { if let chosen = chooseFolder(path) { path = chosen } }
            Button { NSWorkspace.shared.open(URL(fileURLWithPath: path)) } label: { Image(systemName: "arrow.up.forward.app") }
                .help(L("openFolder")).accessibilityLabel(L("openFolder"))
        }
    }
}

enum Pane: String, CaseIterable { case screenshots, ocr }

struct MainView: View {
    @ObservedObject var model: Model
    let recognize: () -> Void
    @AppStorage("pane") private var pane = Pane.screenshots.rawValue

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
            Picker("", selection: $pane) {
                ForEach(Pane.allCases, id: \.rawValue) { Text(L("pane." + $0.rawValue)).tag($0.rawValue) }
            }.pickerStyle(.segmented).labelsHidden()
            Group {
                switch Pane(rawValue: pane) ?? .screenshots {
                case .screenshots: screenshots
                case .ocr: ocr
                }
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .textBackgroundColor)).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.25)))
            VStack(alignment: .leading, spacing: 4) {
                Text(L("activity")).font(.headline)
                if model.activity.isEmpty {
                    Text(L("activityEmpty")).font(.callout).foregroundColor(.secondary)
                } else {
                    ForEach(model.activity.prefix(5)) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(entry.date, style: .time).font(.caption).monospacedDigit().foregroundColor(.secondary)
                            Image(systemName: entry.symbol).font(.caption).foregroundColor(entry.isError ? .red : appTint).accessibilityHidden(true)
                            Text(entry.text).font(.caption).foregroundColor(entry.isError ? .red : .primary).lineLimit(2)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 580, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: AppSurface.color)).tint(appTint)
    }

    private var screenshots: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(L("shot.enabled"), isOn: $model.shotEnabled)
            FolderRow(title: L("shot.folder"), path: $model.shotFolder)
            if model.shotFolder != Model.screenshotLocation {
                Text(String(format: L("shot.locationDiffers"), displayPath(Model.screenshotLocation))).font(.caption).foregroundColor(.orange)
            }
            HStack {
                Text(L("shot.template"))
                TextField("", text: $model.nameTemplate).font(.system(.body, design: .monospaced)).accessibilityLabel(L("shot.template"))
                Button(L("resetDefault")) { model.nameTemplate = ShotNaming.defaultTemplate }.disabled(model.nameTemplate == ShotNaming.defaultTemplate)
            }
            Text(L("shot.templateHint") + "  " + ShotNaming.name(template: model.nameTemplate, info: ImageInfo(width: 1920, height: 1080, dpi: 144), date: Date()))
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Toggle(L("shot.ocrComment"), isOn: $model.ocrComment)
            Toggle(L("shot.qrRename"), isOn: $model.qrRename)
            Text(L("shot.detail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ocr: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(action: recognize) { Label(L("recognizeButton"), systemImage: "text.viewfinder") }
                    .disabled(model.recognizing)
                if let combo = model.ocrCombo, model.ocrHotkeyEnabled { Text(combo.label).font(.callout).foregroundColor(.secondary) }
                if model.recognizing { ProgressView().controlSize(.small) }
            }
            Toggle(L("ocr.join"), isOn: $model.joinJapanese)
            Toggle(L("ocr.parens"), isOn: $model.fullwidthParens)
            Toggle(L("ocr.panel"), isOn: $model.showOCRPanel)
            Text(L("ocr.last")).font(.subheadline)
            ScrollView {
                Text(model.lastOCR.isEmpty ? L("ocr.lastEmpty") : model.lastOCR).font(.callout).foregroundColor(model.lastOCR.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(height: 90)
            Text(L("ocr.detail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

}

struct ScreenRecordingSection: View {
    @State private var allowed = AreaCapture.allowed
    var body: some View {
        SettingsSection(L("perm.screen")) {
            VStack(alignment: .leading, spacing: 6) {
                Label(L(allowed ? "perm.allowed" : "perm.notAllowed"), systemImage: allowed ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(allowed ? Color.green : Color.orange)
                Text(L("perm.screenDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    if !allowed { Button(L("perm.request")) { CGRequestScreenCaptureAccess(); allowed = AreaCapture.allowed } }
                    Button(L("perm.openSettings")) { SystemSettings.openScreenRecording() }
                }
                Text(L("perm.finderDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true).padding(.top, 6)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in allowed = AreaCapture.allowed }
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
                                others: model.ocrCombo.map { [(L("hotkey.ocr"), $0)] } ?? [], registered: model.appHotkeyRegistered, isEnabled: model.appHotkeyEnabled)
                    Text(L("appHotkeyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            ScreenRecordingSection()
        })), (L("hotkeyTab"), AnyView(VStack(spacing: 16) {
            SettingsSection(L("hotkey.ocr")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(HotkeyText.enable, isOn: $model.ocrHotkeyEnabled)
                    HotkeyField(id: Model.ocrHotkeyFieldID, combo: $model.ocrCombo, defaultCombo: Model.defaultOCRCombo, allowsClear: true,
                                others: model.appCombo.map { [(SettingsUI.shortcutTitle, $0)] } ?? [], registered: model.ocrHotkeyRegistered, isEnabled: model.ocrHotkeyEnabled)
                    Text(L("hotkey.ocrDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (NotificationPreferences.title, AnyView(SettingsSection(NotificationPreferences.title) {
            NotificationPermissionView(enabled: $model.notify, toggleTitle: L("notifyToggle"))
        })), (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())), (AboutSection.title, AnyView(AboutView()))])
            .frame(minWidth: 560, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
    }
}
