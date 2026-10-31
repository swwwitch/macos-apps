import AppKit
import SwiftUI
import Carbon

func M(_ key: String) -> String { NSLocalizedString(key, tableName: "Maestro", comment: "") }

@MainActor enum MaestroRegistry {
    static var changed: (() -> Void)?
    static var combos: (() -> [(String, KeyCombo)])?
    static func others(except id: String) -> [(String, KeyCombo)] {
        (combos?() ?? []).filter { $0.0 != id }.map { (M($0.0), $0.1) }
    }
}

struct MaestroHeader: NSViewRepresentable {
    func makeNSView(context: Context) -> NSStackView { appHeader(M("title"), subtitle: M("subtitle")) }
    func updateNSView(_ view: NSStackView, context: Context) {}
}

struct FunctionHotkey: View {
    let id: String
    let title: String
    @Binding var enabled: Bool
    @Binding var combo: KeyCombo?
    let initial: KeyCombo
    let failed: Bool
    var allowsOption = false
    var body: some View {
        HStack(spacing: 12) {
            Toggle(title, isOn: $enabled).toggleStyle(.checkbox)
                .frame(maxWidth: .infinity, alignment: .leading)
            HotkeyField(id: id, combo: $combo, defaultCombo: initial,
                        others: MaestroRegistry.others(except: id), registered: !failed,
                        isEnabled: enabled, allowsOption: allowsOption)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

struct MaestroView: View {
    let delegate: AppDelegate
    @ObservedObject var row: Model
    @ObservedObject var increment: IncrementModel
    @ObservedObject var style: StyleModel
    @State private var selection = "row"
    @State private var legacy = LegacyApps.running
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MaestroHeader().fixedSize(horizontal: false, vertical: true)
            if legacy { Text(M("legacy")).foregroundColor(.orange).fixedSize(horizontal: false, vertical: true) }
            if !AccessibilitySection.isTrusted {
                HStack { Text(AccessibilityText.text("denied")).foregroundColor(.orange); Spacer(); Button(AccessibilityText.text("title")) { delegate.showPreferences() } }
            }
            if row.paused { Text(L("hotkeyPaused")).foregroundColor(.orange) }
            Picker(M("mode"), selection: $selection) {
                Text(M("row")).tag("row")
                Text(M("increment")).tag("increment")
                Text(M("style")).tag("style")
            }.pickerStyle(.segmented).labelsHidden()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch selection {
                    case "increment":
                        FunctionHotkey(id: "increment", title: M("pasteKey"), enabled: Binding(get: { increment.hotkeyEnabled }, set: { increment.hotkeyEnabled = $0; increment.save() }), combo: Binding(get: { increment.combo }, set: { increment.combo = $0 }), initial: Shortcut.increment.combo, failed: increment.hotkeyFailed, allowsOption: true)
                        HStack {
                            IncrementValueBox(title: IL("clipboardTitle"), value: increment.current, placeholder: IL("clipboardEmpty"))
                            Image(systemName: "arrow.right").foregroundColor(.secondary)
                            IncrementValueBox(title: M("next"), value: increment.next?.text, placeholder: "—", emphasized: true)
                        }
                        result(increment.status, error: increment.statusIsError)
                        HStack {
                            Spacer()
                            Button(IL("revert")) { increment.revert() }.disabled(!increment.canRevert)
                        }
                    case "style":
                        FunctionHotkey(id: "style", title: M("pasteKey"), enabled: Binding(get: { style.hotkeyEnabled }, set: { style.hotkeyEnabled = $0; style.save() }), combo: Binding(get: { style.combo }, set: { style.combo = $0 }), initial: Shortcut.style.combo, failed: style.hotkeyFailed)
                        Text(M("styleSummary")).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                        result(style.status, error: style.statusIsError)
                        HStack {
                            Spacer()
                            Button(SL("strip")) { style.stripClipboard() }.help(SL("stripHint"))
                        }
                    default:
                        FunctionHotkey(id: "row", title: M("pasteKey"), enabled: Binding(get: { row.hotkeyEnabled }, set: { row.hotkeyEnabled = $0; row.save() }), combo: Binding(get: { row.pasteCombo }, set: { row.pasteCombo = $0 }), initial: Shortcut.paste.combo, failed: row.hotkeyFailed)
                        FunctionHotkey(id: "add", title: L("addHotkey"), enabled: Binding(get: { row.addEnabled }, set: { row.addEnabled = $0; row.save() }), combo: Binding(get: { row.addCombo }, set: { row.addCombo = $0 }), initial: Shortcut.add.combo, failed: row.addFailed)
                        HStack {
                            Text(String(format: L("queueCount"), String(row.upcoming.count))).foregroundColor(.secondary)
                            Spacer()
                            Button(M("openPalette")) { delegate.showRowPalette() }.controlSize(.large)
                        }.padding(.vertical, 8)
                        result(row.status == L("ready") ? String(format: M("emptyPalette"), row.addShortcut.label) : row.status, error: row.statusIsError)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button(L("settingsButton")) { delegate.showPreferences() }
                Spacer()
                Button(L("appHelp")) { delegate.help() }
            }
        }
        .padding(20)
        .frame(minWidth: 600, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity)
        .background(Color(nsColor: AppSurface.color))
        .onAppear { delegate.selectedFeature = selection; increment.refreshPreview() }
        .onChange(of: selection) { value in delegate.selectedFeature = value; increment.watchClipboard(value == "increment") }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in refresh() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { note in
            if note.object as? NSWindow === delegate.mainWindow { increment.watchClipboard(false) }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            if note.object as? NSWindow === delegate.mainWindow { increment.watchClipboard(selection == "increment") }
        }
    }
    private func result(_ value: String, error: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: error ? "exclamationmark.circle" : "info.circle").accessibilityHidden(true)
            Text(value).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }.font(.callout).foregroundColor(error ? .red : .secondary)
    }
    private func refresh() {
        legacy = LegacyApps.running
        row.excludedAppsChanged(); increment.excludedAppsChanged(); style.excludedAppsChanged()
    }
}
