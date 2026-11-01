import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast (3:1 or more) on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

struct MainView: View {
    @ObservedObject var model: Model
    let dropFiles: ([URL]) -> Void
    let recognize: () -> Void

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(nsImage: currentAppIcon()).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                    AppVersionLabel()
                }
                VStack(alignment: .leading, spacing: 4) { Text(L("heading")).font(.system(size: 22, weight: .semibold)); Text(L("subtitle")).foregroundStyle(.secondary) }
                Spacer()
            }
            Group {
                VStack(alignment: .leading, spacing: 14) {
                    ocr
                    Divider()
                    OCRFormattingView(model: model)
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
        }
        .frame(minWidth: 580, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: AppSurface.color)).tint(appTint)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            for provider in providers {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async { dropFiles([url]) }
                }
            }
            return !providers.isEmpty
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
            HStack {
                Text(L("ocr.last")).font(.subheadline)
                Spacer()
                Button(L("copy")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.lastOCR, forType: .string)
                }.disabled(model.lastOCR.isEmpty)
            }
            Text(L("drop.ocr")).font(.caption).foregroundStyle(.secondary)
            ScrollView {
                Text(model.lastOCR.isEmpty ? L("ocr.lastEmpty") : model.lastOCR).font(.callout).foregroundColor(model.lastOCR.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(minHeight: 150)
            DisclosureGroup(L("explanation")) { Text(L("ocr.detail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
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

            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in allowed = AreaCapture.allowed }
    }
}

struct OCRFormattingView: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("ocr.settings")).font(.headline)
            Toggle(L("ocr.join"), isOn: $model.joinJapanese)
            Toggle(L("ocr.parens"), isOn: $model.fullwidthParens)
            DisclosureGroup(L("explanation")) {
                Text(L("ocr.keepLines")).font(.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: Model
    @AppStorage("resident") var resident = true
    var body: some View {
        SettingsTabs(sections: [
            (SettingsUI.launchTitle, AnyView(VStack(spacing: 16) {
                SettingsSection(SettingsUI.launchTitle) {
                    VStack(alignment: .leading, spacing: 12) {
                        LoginAtLaunchView()
                        Toggle(L("resident"), isOn: $resident)
                        DisclosureGroup(L("explanation")) {
                            Text(L("residentDetail")).font(.caption).foregroundColor(.secondary)
                        }
                        MenuBarPresenceView()
                        HStack {
                            Text(L("launchShortcut")); Spacer()
                            Button(L("openShortcuts")) { NSWorkspace.shared.open(URL(string: "shortcuts://")!) }
                        }
                        DisclosureGroup(L("explanation")) { Text(L("shortcutDetail")).font(.caption) }
                    }
                }
                ScreenRecordingSection()
            })),
            (L("processingTab"), AnyView(VStack(spacing: 16) {
                SettingsSection(L("ocr.settings")) { OCRFormattingView(model: model) }
                SettingsSection(L("hotkeyTab")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("hotkey.ocr"))
                        Toggle(HotkeyText.enable, isOn: $model.ocrHotkeyEnabled)
                        HotkeyField(id: Model.ocrHotkeyFieldID, combo: $model.ocrCombo, defaultCombo: Model.defaultOCRCombo, allowsClear: true,
                                    registered: model.ocrHotkeyRegistered, isEnabled: model.ocrHotkeyEnabled)
                        DisclosureGroup(L("explanation")) {
                            Text(L("hotkey.ocrDetail")).font(.caption).foregroundColor(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                SettingsSection(NotificationPreferences.title) {
                    NotificationPermissionView(enabled: $model.notify, toggleTitle: L("notifyToggle"))
                }
                SettingsSection(L("resultDisplay")) {
                    Toggle(L("ocr.panel"), isOn: $model.showOCRPanel)
                }
            })),
            (ExcludedApps.title, AnyView(SettingsSection(ExcludedApps.title) { ExcludedAppsView() })),
            (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())),
            (AboutSection.title, AnyView(AboutView()))
        ])
        .padding(.top, 16)
        .padding(.horizontal, 12)
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
    }
}
