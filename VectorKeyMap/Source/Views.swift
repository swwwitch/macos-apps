import AppKit
import SwiftUI

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast (3:1 or more) on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

struct Explanation: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
}

struct ShortcutCell: View {
    let shortcut: Shortcut?
    var body: some View {
        if let shortcut {
            HStack(spacing: 4) {
                Text(shortcut.label).font(.system(.body, design: .monospaced)).lineLimit(1).fixedSize()
                if shortcut.context == 1 {
                    Text(L("context.mark")).font(.caption2).foregroundColor(.secondary).lineLimit(1).fixedSize().help(L("tip.context"))
                }
            }
        } else {
            Text("—").foregroundColor(.secondary).accessibilityLabel(L("a11y.noKey"))
        }
    }
}

struct StatusCell: View {
    let status: DiffStatus
    let text: String
    private var color: Color {
        switch status {
        case .changed: return .orange
        case .added: return .green
        case .removed, .unlisted: return .red
        case .same, .unassigned: return .secondary
        }
    }
    var body: some View { Text(text).foregroundColor(color).lineLimit(1) }
}

struct NameCell: View {
    let row: Row
    var body: some View {
        HStack(spacing: 4) {
            if row.hasConflict {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    .help(String(format: L("detail.conflict"), row.conflicts.joined(separator: " / ")))
                    .accessibilityLabel(L("a11y.conflict"))
            }
            Text(row.displayName).lineLimit(1).truncationMode(.middle)
        }
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel
    let close: () -> Void
    @FocusState private var searchFocused: Bool
    @AppStorage("showsKeyboard") private var showsKeyboard = false

    private var header: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Image(nsImage: currentAppIcon()).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                AppVersionLabel()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(L("heading")).font(.system(size: 22, weight: .semibold))
                Text(L("subtitle")).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            searchControls
        }
    }

    private func setPicker(_ label: String, selection: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Text(label).lineLimit(1).fixedSize()
            Picker(label, selection: selection) {
                ForEach(model.sources) { Text(model.title($0)).tag($0.id) }
            }
            .labelsHidden()
            .frame(minWidth: 240, maxWidth: .infinity, alignment: .leading)
        }
    }

    private var setRow: some View {
        HStack(spacing: 10) {
            setPicker(L("field.baseline"), selection: $model.baselineID)
            Button { model.swapSets() } label: { Image(systemName: "arrow.left.arrow.right") }
                .help(L("tip.swap")).accessibilityLabel(L("tip.swap"))
            setPicker(L("field.target"), selection: $model.targetID)
            Button(L("button.addSet")) { model.openAddPanel() }.help(L("tip.addSet"))
        }
    }

    /// Category and search sit in the header: the filter row is already as wide as the window in English.
    private var searchControls: some View {
        HStack(spacing: 10) {
            Picker(L("a11y.view"), selection: $showsKeyboard) {
                Text(L("view.table")).tag(false)
                Text(L("view.keyboard")).tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            if !showsKeyboard { listControls }
        }
    }

    private var listControls: some View {
        HStack(spacing: 10) {
            Picker(L("column.group"), selection: $model.group) {
                Text(L("group.all")).tag(AppModel.allGroups)
                Divider()
                ForEach(model.groups, id: \.self) { Text(model.groupText($0)).tag($0) }
            }
            .labelsHidden().frame(width: 170)
            TextField(L("search.placeholder"), text: $model.query)
                .textFieldStyle(.roundedBorder).focused($searchFocused).frame(width: 200).help(L("tip.search")).accessibilityLabel(L("search.placeholder"))
            Button("") { searchFocused = true }.keyboardShortcut("f", modifiers: .command)
                .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
        }
    }

    private var filterRow: some View {
        Picker(L("a11y.filter"), selection: $model.filter) {
            ForEach(RowFilter.allCases) { Text("\($0.title) \(model.counts[$0] ?? 0)").tag($0) }
        }
        .pickerStyle(.segmented).labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
    }

    private var list: some View {
        Table(model.shown, selection: $model.selection, sortOrder: $model.sortOrder) {
            TableColumn(L("column.status"), value: \Row.statusRank) { row in
                StatusCell(status: row.status, text: model.statusText(row.status))
            }.width(min: 56, ideal: 64, max: 90)
            TableColumn(L("column.group"), value: \Row.groupRank) { row in
                Text(model.groupText(row.group)).lineLimit(1)
            }.width(min: 70, ideal: 120, max: 180)
            TableColumn(L("column.command"), value: \Row.order) { row in
                NameCell(row: row)
            }.width(min: 180, ideal: 340)
            TableColumn(L("column.baseline"), value: \Row.baselineSort) { row in
                ShortcutCell(shortcut: row.baseline)
            }.width(min: 90, ideal: 130, max: 200)
            TableColumn(L("column.target"), value: \Row.targetSort) { row in
                ShortcutCell(shortcut: row.target)
            }.width(min: 90, ideal: 130, max: 200)
            TableColumn(L("column.id"), value: \Row.commandID) { row in
                Text(row.commandID).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle).help(row.commandID)
            }.width(min: 120, ideal: 240)
        }
        .contextMenu(forSelectionType: CommandKey.self) { keys in
            let rows = model.shown.filter { keys.contains($0.key) }
            if !rows.isEmpty {
                Button(L("menu.copyID")) { model.copy(rows.map(\.commandID).joined(separator: "\n"), count: rows.count) }
                Button(L("menu.copyRows")) { model.copy(model.tsv(for: rows), count: rows.count) }
            }
        }
        .onCopyCommand {
            let rows = model.selectedRows
            return rows.isEmpty ? [] : [NSItemProvider(object: model.tsv(for: rows) as NSString)]
        }
        .overlay {
            if model.shown.isEmpty { Text(L("empty.rows")).foregroundColor(.secondary) }
        }
    }

    private var detail: some View {
        let rows = model.selectedRows
        return Group {
            if rows.count == 1, let row = rows.first, row.hasConflict {
                Text(String(format: L("detail.conflict"), row.conflicts.joined(separator: " / "))).foregroundColor(.orange)
            } else if rows.count > 1 {
                Text(String(format: L("detail.selected"), rows.count)).foregroundColor(.secondary)
            } else {
                Text(String(format: L("summary"), model.baselineCount, model.targetCount, model.shown.count)).foregroundColor(.secondary)
            }
        }
        .font(.callout).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            setRow
            if !model.problem.isEmpty {
                Label(model.problem, systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange).font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showsKeyboard {
                KeyboardPane(model: model)
            } else {
                filterRow
                list
            }
            if !model.note.isEmpty {
                Text(model.note).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                if showsKeyboard {
                    Text(String(format: L("key.summary"), model.keyMap.freeKeys(model.keyboardModifiers).count, model.keyMap.keys.filter(\.assignable).count))
                        .font(.callout).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    Button(L("button.copyFree")) { model.copyFreeKeys() }.help(L("tip.copyFree"))
                } else {
                    detail
                    Button(L("button.copyTable")) { model.copyTable() }.disabled(model.shown.isEmpty).help(L("tip.copyTable"))
                    Menu(L("button.export")) {
                        Button(L("export.csv")) { model.export(.csv) }
                        Button(L("export.markdown")) { model.export(.markdown) }
                    }
                    .fixedSize().disabled(model.shown.isEmpty).help(L("tip.export"))
                }
                Button(L("button.close")) { close() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 1020, minHeight: 560)
        .background(Color(nsColor: AppSurface.color))
        .tint(appTint)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { model.add(url) }
            }
            return true
        }
    }
}

// MARK: Settings

struct SettingsView: View {
    @ObservedObject var launcher: AppLauncherHotkey
    @AppStorage("resident") var resident = false
    var body: some View {
        SettingsTabs(sections: [(SettingsUI.launchTitle, AnyView(VStack(spacing: 16) {
            SettingsSection(SettingsUI.launchTitle) {
                LaunchPresenceSection(title: SettingsUI.launchTitle, loginControl: LoginAtLaunchView(), residentTitle: L("resident"), residentDetail: L("residentDetail"), resident: $resident,
                                      presenceExtra: MenuBarPresenceView(), shortcutTitle: L("launchShortcut"), shortcutButton: L("openShortcuts"), shortcutDetail: L("shortcutDetail")) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(SettingsUI.shortcutTitle).padding(.top, 4)
                    Toggle(HotkeyText.enable, isOn: $launcher.enabled)
                    HotkeyField(id: AppLauncherHotkey.fieldID, combo: $launcher.combo, allowsClear: true, registered: launcher.registered, isEnabled: launcher.enabled)
                    Explanation(L("appHotkeyHint"))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (AboutSection.title, AnyView(AboutView()))])
            .frame(minWidth: 560, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity)
    }
}
