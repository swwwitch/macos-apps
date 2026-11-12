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

/// A longer note that stays folded until 「説明」 is opened (house rule, 2026-10-28).
struct Explanation: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        DisclosureGroup(L("explain")) {
            Text(text).font(.caption).foregroundColor(.secondary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption)
    }
}

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
            if !script.overrides().isEmpty {
                Text(script.overrides().map(\.value).joined(separator: " · ")).font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.tail)
                    .help(script.overrides().map { "\($0.name) = \($0.value)" }.joined(separator: "\n"))
            }
            if !script.fileExists { Badge(text: L("badge.missing"), color: .orange).help(L("badge.missingHint")) }
            Spacer(minLength: 4)
            if script.uses > 0 {
                Text(String(format: L("uses.count"), script.uses)).font(.caption.monospacedDigit()).foregroundColor(.secondary).help(L("uses.hint"))
            }
            let variableKeys = script.keys.filter { $0.hotkey != nil }
            if !variableKeys.isEmpty {
                Badge(text: String(format: L("varKeys.count"), variableKeys.count), color: keyProblem ? .red : .secondary)
                    .help(variableKeys.map { "\($0.label)  \($0.hotkey!.label)" }.joined(separator: "\n"))
            }
            if let hotkey = script.hotkey {
                Text(hotkey.label).font(.system(size: 12, design: .monospaced)).kerning(1)
                    .foregroundColor(problem ? .red : (script.enabled ? .primary : .secondary))
                    .help(problem ? L(model.duplicateHotkeys.contains(Trigger(script: script.id)) ? "hotkey.duplicate" : "hotkey.failed") : "")
            }
        }
        .opacity(script.enabled ? 1 : 0.6)
    }
    private var problem: Bool { model.failedHotkeys.contains(Trigger(script: script.id)) || model.duplicateHotkeys.contains(Trigger(script: script.id)) }
    private var keyProblem: Bool {
        script.keys.contains { key in [model.failedHotkeys, model.duplicateHotkeys].contains { $0.contains(Trigger(script: script.id, key: key.id)) } }
    }
}

/// A value for one SW_ variable: a menu when the choices are known (true/false, or 「[a|b]」 in the comment), a field otherwise.
/// The empty value means 「not changed here」, shown as `empty`.
struct VariableValueControl: View {
    let candidate: VariableOverrides.Candidate
    @Binding var value: String
    let empty: String
    var body: some View {
        if candidate.choices.isEmpty {
            TextField(empty, text: $value).textFieldStyle(.roundedBorder).frame(minWidth: 90).accessibilityLabel(candidate.name)
        } else {
            Picker("", selection: $value) {
                Text(empty).tag("")
                Divider()
                ForEach(candidate.choices, id: \.self) { Text($0).tag($0) }
                // A saved value that is not among the choices (the file changed) stays visible.
                if !value.isEmpty && !candidate.choices.contains(value) { Text(value).tag(value) }
            }
            .labelsHidden().fixedSize().accessibilityLabel(candidate.name)
        }
    }
}

struct ScriptDetail: View {
    @ObservedObject var model: AppModel
    @Binding var script: ScriptEntry
    @State private var candidates: [VariableOverrides.Candidate] = []
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
                if !candidates.isEmpty || script.variables != nil { variablesSection }
                HStack(spacing: 12) {
                    Button { model.runFromWindow(script) } label: { Label(L("run"), systemImage: "play.fill") }
                        .disabled(!script.fileExists).help(L("runHint"))
                    Text(usesText).font(.callout).foregroundColor(.secondary).help(L("uses.hint"))
                    Spacer()
                }
                hotkeysSection
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear(perform: reload)
        .onChange(of: script.id) { _ in reload() }
        .onChange(of: script.path) { _ in reload() }
    }

    // MARK: Variables

    /// The script's `var SW_… = …;` declarations: a new initial value for this entry, or empty to keep the file's.
    private var variablesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L("variables")).font(.headline)
                Spacer()
                Button(L("variables.reload")) { reload() }.controlSize(.small).help(L("variables.reloadHint"))
            }
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 8) {
                ForEach(candidates) { candidate in
                    GridRow {
                        Text(candidate.name).font(.system(.callout, design: .monospaced)).gridColumnAlignment(.trailing)
                        VStack(alignment: .leading, spacing: 2) {
                            VariableValueControl(candidate: candidate, value: baseValue(candidate.name),
                                                 empty: candidate.value.isEmpty ? L("variables.empty") : String(format: L("variables.default"), candidate.value))
                            if !candidate.explanation.isEmpty {
                                Text(candidate.explanation).font(.caption).foregroundColor(.secondary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            if !stale.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: L("variables.stale"), stale.joined(separator: ", "))).font(.caption).foregroundColor(.orange).fixedSize(horizontal: false, vertical: true)
                    Button(L("variables.clearStale")) { clearStale() }.controlSize(.small)
                }
            }
            Explanation(L("variables.hint"))
        }
    }
    /// Saved values (the entry's or a variable key's) whose declaration is no longer in the file; runs stop with an error until they are removed.
    private var stale: [String] {
        let known = Set(candidates.map(\.name))
        let saved = Set((script.variables ?? [:]).keys).union(script.keys.flatMap { $0.values.keys })
        return saved.subtracting(known).sorted()
    }
    private func clearStale() {
        let gone = Set(stale)
        if var values = script.variables { for name in gone { values[name] = nil }; script.variables = values.isEmpty ? nil : values }
        if var keys = script.variableKeys {
            for index in keys.indices { for name in gone { keys[index].values[name] = nil } }
            script.variableKeys = keys
        }
    }
    private func reload() { candidates = VariableOverrides.candidates(forFile: script.path) }
    private func baseValue(_ name: String) -> Binding<String> {
        Binding(get: { script.variables?[name] ?? "" }, set: { text in
            var values = script.variables ?? [:]
            values[name] = text.isEmpty ? nil : text
            script.variables = values.isEmpty ? nil : values
        })
    }

    // MARK: Hotkeys

    /// One table: the script as set above, then one row per variable key, each with its values and its hotkey.
    private var hotkeysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("hotkey")).font(.headline)
            Toggle(L("enabled"), isOn: $script.enabled)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 8) {
                if !candidates.isEmpty {
                    GridRow {
                        ForEach(candidates) { Text($0.name).font(.system(.caption, design: .monospaced)).foregroundColor(.secondary) }
                        Text(L("hotkey")).font(.caption).foregroundColor(.secondary)
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                }
                GridRow {
                    if !candidates.isEmpty {
                        Text(L("varKeys.asSet")).foregroundColor(.secondary).gridCellColumns(candidates.count)
                    }
                    hotkeyField(Trigger(script: script.id), get: { script.hotkey }, set: { script.hotkey = $0 })
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                }
                ForEach(script.keys) { key in
                    GridRow {
                        ForEach(candidates) { candidate in
                            VariableValueControl(candidate: candidate, value: keyValue(key.id, candidate.name), empty: "—")
                        }
                        hotkeyField(Trigger(script: script.id, key: key.id), get: { key.hotkey },
                                    set: { hotkey in updateKey(key.id) { $0.hotkey = hotkey } })
                        HStack(spacing: 2) {
                            Button { model.runFromWindow(script, key: key) } label: { Image(systemName: "play.fill") }
                                .buttonStyle(.borderless).disabled(!script.fileExists).help(L("runHint")).accessibilityLabel(L("run"))
                            Button { script.variableKeys?.removeAll { $0.id == key.id } } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless).help(L("varKeys.remove")).accessibilityLabel(L("varKeys.remove"))
                        }
                    }
                }
            }
            if !candidates.isEmpty {
                HStack(spacing: 8) {
                    Button { script.variableKeys = script.keys + [VariableKey()] } label: { Label(L("varKeys.add"), systemImage: "plus") }
                    ForEach(candidates.filter { !$0.isBoolean && !$0.choices.isEmpty }) { candidate in
                        Button(String(format: L("varKeys.fill"), candidate.name)) { fill(candidate) }.help(L("varKeys.fillHint"))
                    }
                    if candidates.filter({ !$0.choices.isEmpty }).count > 1 {
                        Button(String(format: L("varKeys.fillAll"), combinationCount)) { fillAll() }.help(L("varKeys.fillAllHint"))
                    }
                }.controlSize(.small)
            }
            Explanation(candidates.isEmpty ? L("hotkeyHint") : L("varKeys.hint") + "\n" + L("hotkeyHint"))
        }
    }
    private func hotkeyField(_ trigger: Trigger, get: @escaping () -> Hotkey?, set: @escaping (Hotkey?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HotkeyField(id: "script-" + script.id + (trigger.key.map { "-" + $0 } ?? ""),
                        combo: Binding(get: { get().map { KeyCombo(code: $0.code, modifiers: $0.modifiers) } }, set: { set($0.map { Hotkey(code: $0.code, modifiers: $0.modifiers) }) }),
                        allowsClear: true, others: model.otherHotkeys(except: trigger),
                        registered: !model.failedHotkeys.contains(trigger), isEnabled: script.enabled, allowsOption: true)
            if model.duplicateHotkeys.contains(trigger) { Text(L("hotkey.duplicate")).font(.caption).foregroundColor(.red).fixedSize(horizontal: false, vertical: true) }
        }
        .fixedSize(horizontal: true, vertical: false)   // Keeps 「割り当てを解除」 at its width inside the table.
    }
    private func updateKey(_ id: String, _ change: (inout VariableKey) -> Void) {
        guard var keys = script.variableKeys, let index = keys.firstIndex(where: { $0.id == id }) else { return }
        change(&keys[index])
        script.variableKeys = keys
    }
    private func keyValue(_ id: String, _ name: String) -> Binding<String> {
        Binding(get: { script.keys.first { $0.id == id }?.values[name] ?? "" },
                set: { text in updateKey(id) { $0.values[name] = text.isEmpty ? nil : text } })
    }
    /// The variables with choices and every combination of their values (「left × true」…), in the order of the file.
    private var combinations: [[String: String]] {
        candidates.filter { !$0.choices.isEmpty }.reduce([[:]]) { partial, candidate in
            partial.flatMap { values in candidate.choices.map { values.merging([candidate.name: $0]) { $1 } } }
        }
    }
    private var combinationCount: Int { combinations.count }
    /// The value a row runs with: its own, else the one set above, else the file's.
    private func effectiveValue(_ key: VariableKey, _ candidate: VariableOverrides.Candidate) -> String {
        key.values[candidate.name] ?? script.variables?[candidate.name] ?? candidate.value
    }
    /// One row for each combination that no row runs yet (keys to be assigned).
    private func fillAll() {
        let named = candidates.filter { !$0.choices.isEmpty }
        let existing = Set(script.keys.map { key in named.map { effectiveValue(key, $0) } })
        let added = combinations.filter { values in !existing.contains(named.map { values[$0.name]! }) }.map { VariableKey(values: $0) }
        script.variableKeys = script.keys + added
    }
    /// One row for each choice of the variable that no row uses yet (keys to be assigned).
    private func fill(_ candidate: VariableOverrides.Candidate) {
        let used = Set(script.keys.compactMap { $0.values[candidate.name] })
        let added = candidate.choices.filter { !used.contains($0) }.map { VariableKey(values: [candidate.name: $0]) }
        script.variableKeys = script.keys + added
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
                Label(L(model.inDesignFront ? "state.front" : "state.back"), systemImage: model.inDesignFront ? "circle.fill" : "circle")
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
                                others: model.otherHotkeys(except: nil), registered: launcher.registered, isEnabled: launcher.enabled)
                    Explanation(L("appHotkeyHint"))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (L("hotkeysTab"), AnyView(VStack(spacing: 16) {
            SettingsSection(L("hotkeysSection")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("useHotkeys"), isOn: $model.hotkeysEnabled)
                    Explanation(L("useHotkeysDetail"))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        })), (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())), (AboutSection.title, AnyView(AboutView()))])
            .frame(minWidth: 560, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
    }
}
