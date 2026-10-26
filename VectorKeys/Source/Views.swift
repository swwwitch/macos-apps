import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Mustard accent. Dark Mode uses a lighter mustard so tinted controls keep contrast (3:1 or more) on the dark surface.
let appTint = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.78, green: 0.56, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.55, green: 0.38, blue: 0.04, alpha: 1)
})

extension Hotkey {
    var label: String { KeyCombo(code: code, modifiers: modifiers).label }
}

// MARK: Main window

struct Badge: View {
    let text: String
    var color: Color = .secondary
    var body: some View {
        Text(text).font(.caption2).padding(.horizontal, 5).padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.18))).foregroundColor(color == .secondary ? .secondary : color)
    }
}

struct ScriptRow: View {
    @ObservedObject var model: AppModel
    @Binding var script: ScriptEntry
    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $script.enabled).labelsHidden().accessibilityLabel(script.name).help(L("enabledHint"))
            Text(script.name).lineLimit(1).truncationMode(.middle)
            if !script.fileExists { Badge(text: L("badge.missing"), color: .orange).help(L("badge.missingHint")) }
            Spacer(minLength: 4)
            if script.uses > 0 {
                Text(String(format: L("uses.count"), script.uses)).font(.caption.monospacedDigit()).foregroundColor(.secondary).help(L("uses.hint"))
            }
            if let hotkey = script.hotkey {
                Text(hotkey.label).font(.system(size: 12, design: .monospaced)).kerning(1)
                    .foregroundColor(problem ? .red : (script.enabled ? .primary : .secondary))
                    .help(problem ? L(model.duplicateHotkeys.contains(script.id) ? "hotkey.duplicate" : "hotkey.failed") : "")
            }
        }
        .opacity(script.enabled ? 1 : 0.6)
    }
    private var problem: Bool { model.failedHotkeys.contains(script.id) || model.duplicateHotkeys.contains(script.id) }
}

struct ScriptDetail: View {
    @ObservedObject var model: AppModel
    @Binding var script: ScriptEntry
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow {
                        Text(L("name")).gridColumnAlignment(.trailing)
                        TextField("", text: $script.name).textFieldStyle(.roundedBorder).font(.body.weight(.semibold)).accessibilityLabel(L("name"))
                    }
                    GridRow {
                        Text(L("file"))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(script.path).font(.callout).foregroundColor(.secondary).textSelection(.enabled)
                                .lineLimit(3).truncationMode(.middle).fixedSize(horizontal: false, vertical: true)
                            if !script.fileExists {
                                Text(L("badge.missingHint")).font(.caption).foregroundColor(.orange).fixedSize(horizontal: false, vertical: true)
                            }
                            HStack(spacing: 8) {
                                Button(L("reveal")) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: script.path)]) }
                                    .disabled(!script.fileExists)
                                Button(L("relink")) { model.relink(script.id) }.help(L("relinkHint"))
                            }
                        }
                    }
                }
                HStack(spacing: 12) {
                    Button { model.runFromWindow(script) } label: { Label(L("run"), systemImage: "play.fill") }
                        .disabled(!script.fileExists).help(L("runHint"))
                    Text(usesText).font(.callout).foregroundColor(.secondary).help(L("uses.hint"))
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("hotkey")).font(.headline)
                    Toggle(L("enabled"), isOn: $script.enabled)
                    HotkeyField(id: "script-" + script.id, combo: Binding(get: { script.hotkey.map { KeyCombo(code: $0.code, modifiers: $0.modifiers) } },
                                                                         set: { script.hotkey = $0.map { Hotkey(code: $0.code, modifiers: $0.modifiers) } }),
                                allowsClear: true, others: model.otherHotkeys(except: script.id),
                                registered: !model.failedHotkeys.contains(script.id), isEnabled: script.enabled, allowsOption: true)
                    if model.duplicateHotkeys.contains(script.id) { Text(L("hotkey.duplicate")).font(.caption).foregroundColor(.red) }
                    Text(L("hotkeyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension ScriptDetail {
    var usesText: String {
        guard let last = script.lastRun, script.uses > 0 else { return L("uses.never") }
        return String(format: L("uses.detail"), script.uses, last.formatted(date: .numeric, time: .shortened))
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel
    @State private var search = ""
    @State private var confirmDelete = false
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(nsImage: currentAppIcon()).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                    AppVersionLabel()
                }
                VStack(alignment: .leading, spacing: 4) { Text(L("heading")).font(.system(size: 22, weight: .semibold)); Text(L("subtitle")).foregroundStyle(.secondary) }
                Spacer()
                Toggle(L("useHotkeys"), isOn: $model.hotkeysEnabled).toggleStyle(.switch).help(L("useHotkeysHint"))
            }
            HStack(spacing: 8) {
                Button(L("addMenu")) { model.chooseFiles() }
                Spacer()
                Label(L(model.illustratorFront ? "state.front" : "state.back"), systemImage: model.illustratorFront ? "circle.fill" : "circle")
                    .font(.caption).foregroundColor(.secondary).labelStyle(.titleAndIcon)
                    .help(L("state.hint"))
            }
            Group {
                if model.library.scripts.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.badge.plus").font(.system(size: 32)).foregroundColor(.secondary).accessibilityHidden(true)
                        Text(L("empty")).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button(L("addMenu")) { model.chooseFiles() }.keyboardShortcut(.defaultAction)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                } else {
                    // A plain stack, not HSplitView: no divider line between the columns (the list keeps a fixed width).
                    HStack(spacing: 12) {
                        list.frame(width: 340)
                        Group {
                            if let id = model.selection, let binding = model.binding(for: id) {
                                ScriptDetail(model: model, script: binding)
                            } else {
                                Text(L("selectScript")).foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(appTint, lineWidth: 2).opacity(dropTargeted ? 1 : 0))
            .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
                let group = DispatchGroup()
                var urls: [URL] = []
                for provider in providers {
                    group.enter()
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        DispatchQueue.main.async { if let url { urls.append(url) }; group.leave() }
                    }
                }
                group.notify(queue: .main) { model.add(urls: urls) }
                return true
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(L("recent")).font(.headline)
                if model.records.isEmpty {
                    Text(L("recentEmpty")).font(.caption).foregroundColor(.secondary)
                } else {
                    ForEach(model.records.prefix(4)) { record in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: record.isError ? "exclamationmark.triangle.fill" : "checkmark.circle").foregroundColor(record.isError ? .orange : .green)
                                .accessibilityLabel(L(record.isError ? "a11y.error" : "a11y.success"))
                            Text(record.date.formatted(date: .omitted, time: .standard)).font(.caption.monospacedDigit()).foregroundColor(.secondary)
                            Text(record.name).font(.caption.weight(.medium)).lineLimit(1)
                            Text(record.text).font(.caption).foregroundColor(record.isError ? .orange : .secondary).lineLimit(2).textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 500)
        .background(Color(nsColor: AppSurface.color))
        .tint(appTint)
        .confirmationDialog(L("deleteConfirm"), isPresented: $confirmDelete) {
            Button(L("delete"), role: .destructive) { if let id = model.selection { model.delete([id]) } }
            Button(L("cancel"), role: .cancel) {}
        } message: { Text(L("deleteConfirmDetail")) }
    }

    private var list: some View {
        VStack(spacing: 6) {
            TextField(L("search"), text: $search).textFieldStyle(.roundedBorder)
            List(selection: $model.selection) {
                // Reordering only in the full list: moving within a filtered list would land in the wrong place.
                if search.isEmpty {
                    ForEach(model.library.scripts) { script in row(script) }.onMove { model.move(from: $0, to: $1) }
                } else {
                    ForEach(model.library.scripts.filter { $0.name.localizedCaseInsensitiveContains(search) || ($0.hotkey?.label ?? "").localizedCaseInsensitiveContains(search) }) { script in row(script) }
                }
            }
            .contextMenu(forSelectionType: String.self) { ids in
                if let id = ids.first, let script = model.library.scripts.first(where: { $0.id == id }) {
                    Button(L("run")) { model.runFromWindow(script) }.disabled(!script.fileExists)
                    Button(L("reveal")) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: script.path)]) }.disabled(!script.fileExists)
                    Divider()
                    Button(L("delete")) { model.selection = id; confirmDelete = true }
                }
            }
            .onDeleteCommand { if model.selection != nil { confirmDelete = true } }
            HStack {
                // The same frame for both symbols: "minus" is shorter than "plus" and would make a lower button.
                Button { model.chooseFiles() } label: { Image(systemName: "plus").frame(width: 16, height: 16) }.help(L("addMenu")).accessibilityLabel(L("addMenu"))
                Button { confirmDelete = true } label: { Image(systemName: "minus").frame(width: 16, height: 16) }.disabled(model.selection == nil)
                    .help(L("delete")).accessibilityLabel(L("delete"))
                Spacer()
                Text(String(format: L("count"), model.library.scripts.count)).font(.caption).foregroundColor(.secondary)
            }
        }
    }
    @ViewBuilder private func row(_ script: ScriptEntry) -> some View {
        if let binding = model.binding(for: script.id) { ScriptRow(model: model, script: binding).tag(script.id) }
    }
}

// MARK: Settings

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var launcher: AppLauncherHotkey
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
                    Toggle(HotkeyText.enable, isOn: $launcher.enabled)
                    HotkeyField(id: AppLauncherHotkey.fieldID, combo: $launcher.combo, allowsClear: true,
                                others: model.otherHotkeys(except: ""), registered: launcher.registered, isEnabled: launcher.enabled)
                    Text(L("appHotkeyHint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (L("hotkeysTab"), AnyView(VStack(spacing: 16) {
            SettingsSection(L("hotkeysSection")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("useHotkeys"), isOn: $model.hotkeysEnabled)
                    Text(L("useHotkeysDetail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (AboutSection.title, AnyView(AboutView()))])
            .frame(minWidth: 560, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
    }
}
