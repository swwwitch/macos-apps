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

struct MaestroView: View {
    let delegate: AppDelegate
    @ObservedObject var row: Model
    @ObservedObject var increment: IncrementModel
    @ObservedObject var style: StyleModel
    @State private var selection = "row"
    @State private var legacy = LegacyApps.running
    var body: some View {
        VStack(spacing: 0) {
            if legacy { Text(M("legacy")).foregroundColor(.orange).padding(12).fixedSize(horizontal: false, vertical: true) }
            Text(M("enableHint")).font(.caption).foregroundColor(.secondary).padding(.horizontal, 16).padding(.top, 10)
            Picker(M("mode"), selection: $selection) {
                Text(M("row")).tag("row")
                Text(M("increment")).tag("increment")
                Text(M("style")).tag("style")
            }.pickerStyle(.segmented).padding([.horizontal, .top], 16)
            Group {
                switch selection {
                case "increment": IncrementMainView(model: increment)
                case "style": StyleMainView(model: style)
                default: RowView(model: row)
                }
            }
        }
        .background(Color(nsColor: AppSurface.color))
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
    private func refresh() {
        legacy = LegacyApps.running
        row.excludedAppsChanged(); increment.excludedAppsChanged(); style.excludedAppsChanged()
    }
}
