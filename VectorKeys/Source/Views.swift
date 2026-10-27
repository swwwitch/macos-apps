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
    @AppStorage("showUses") private var showUses = true
    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $script.enabled).labelsHidden().accessibilityLabel(script.name).help(L("enabledHint"))
            Text(script.name).lineLimit(1).truncationMode(.middle)
            if script.hasUnsupportedSteps { Badge(text: L("legacy.badge"), color: .orange).help(L("legacy.unsupported")) }
            else if !script.isAvailable && !script.actions.isEmpty { Badge(text: L("code.unavailable"), color: .orange).help(L("code.unavailableHint")) }
            if script.actions.count > 1 { Badge(text: String(format: L("steps.count"), script.actions.count)).help(L("steps")) }
            Spacer(minLength: 4)
            if showUses && script.uses > 0 {
                Text(String(format: L("uses.count"), script.uses)).font(.caption.monospacedDigit()).foregroundColor(.secondary).help(L("uses.hint"))
            }
            if let hotkey = script.hotkey {
                Text(hotkey.fullLabel).font(.system(size: 12, design: .monospaced)).kerning(1)
                    .foregroundColor(problem ? .red : (script.enabled ? .primary : .secondary))
                    .help(problem ? L(model.duplicateHotkeys.contains(script.id) ? "hotkey.duplicate" : "hotkey.failed") : (hotkey.isDouble ? L("taps.double") : ""))
            }
        }
        .opacity(script.enabled ? 1 : 0.6)
    }
    private var problem: Bool { model.failedHotkeys.contains(script.id) || model.duplicateHotkeys.contains(script.id) }
}

extension Hotkey {
    /// ⌥T, or ⌥T ×2 for a double press.
    var fullLabel: String { isDouble ? label + " ×2" : label }
}

struct ScriptDetail: View {
    @ObservedObject var model: AppModel
    @Binding var script: ScriptEntry
    @AppStorage("showUses") private var showUses = true
    @State private var showHotkeyHelp = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        TextField(L("name"), text: $script.name)
                            .textFieldStyle(.plain).font(.system(size: 18, weight: .semibold))
                            .accessibilityLabel(L("name"))
                        Button { model.runFromWindow(script) } label: { Label(L("run"), systemImage: "play.fill") }
                            .buttonStyle(.borderedProminent).disabled(!script.isAvailable).help(L("runHint"))
                    }
                    HStack(spacing: 8) {
                        Text(L("category")).font(.caption).foregroundColor(.secondary)
                        Picker("", selection: Binding(get: { script.category ?? "" }, set: { model.setCategory($0.isEmpty ? nil : $0, for: [script.id]) })) {
                            Text(L("category.none")).tag("")
                            ForEach(model.library.categoryList, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden().fixedSize().accessibilityLabel(L("category"))
                        Spacer(minLength: 0)
                    }
                }
                StepsEditor(model: model, script: script)
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("hotkey")).font(.subheadline.weight(.semibold))
                    HotkeyField(id: "script-" + script.id, combo: Binding(get: { script.hotkey.map { KeyCombo(code: $0.code, modifiers: $0.modifiers) } },
                        set: { combo in script.hotkey = combo.map { Hotkey(code: $0.code, modifiers: $0.modifiers, taps: script.hotkey?.taps) } }),
                        allowsClear: true, others: model.otherHotkeys(except: script.id, taps: .some(script.hotkey?.taps)),
                        registered: !model.failedHotkeys.contains(script.id), isEnabled: script.enabled && script.scriptsOnly, allowsOption: true)
                    Picker(L("taps.label"), selection: Binding(get: { script.hotkey?.taps ?? 1 }, set: { script.hotkey?.taps = $0 == 2 ? 2 : nil })) {
                        Text(L("taps.single")).tag(1)
                        Text(L("taps.double")).tag(2)
                    }
                    .pickerStyle(.segmented).frame(maxWidth: 260).disabled(script.hotkey == nil || !script.enabled)
                    if model.duplicateHotkeys.contains(script.id) { Text(L("hotkey.duplicate")).font(.caption).foregroundColor(.red) }
                    DisclosureGroup(L("ui.hotkeyHelp"), isExpanded: $showHotkeyHelp) {
                        Text(L("hotkeyHint") + "\n" + L("taps.hint"))
                            .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
                    }.font(.caption).foregroundColor(.secondary)
                }
                if showUses && script.uses > 0 {
                    Text(usesText).font(.caption).foregroundColor(.secondary).help(L("uses.hint"))
                }
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Script files run in order. Legacy unsupported steps are retained until the user removes them.
struct StepsEditor: View {
    @ObservedObject var model: AppModel
    let script: ScriptEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if script.actions.isEmpty { Text(L("steps.empty")).foregroundColor(.secondary) }
            ForEach(Array(script.actions.enumerated()), id: \.offset) { index, step in
                StepRow(model: model, script: script, index: index, step: step)
            }
            Menu {
                Button(L("step.addScript")) { model.addScriptSteps(to: script.id) }
                Button(L("code.add")) { model.addStep(.code(source: ""), to: script.id) }
            } label: { Label(L("ui.addStep"), systemImage: "plus") }
            .fixedSize().menuStyle(.borderlessButton).font(.caption).foregroundColor(.secondary)
            .padding(.top, 2)
            if script.hasUnsupportedSteps {
                Text(L("legacy.unsupported")).font(.caption).foregroundColor(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct StepRow: View {
    @ObservedObject var model: AppModel
    let script: ScriptEntry
    let index: Int
    let step: Step
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if case .code(let source) = step {
                HStack {
                    if script.actions.count > 1 {
                        Text(String(format: L("ui.stepNumber"), index + 1)).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    stepMenu
                }
                TextEditor(text: Binding(get: { source }, set: { model.updateCode(script.id, at: index, source: $0) }))
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 240)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.18)))
                    .accessibilityLabel(L("code.title"))
                if missing { Text(L("code.empty")).font(.caption).foregroundColor(.secondary) }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: symbol).foregroundColor(.secondary).padding(.top, 2).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).lineLimit(2).truncationMode(.middle)
                        Text(detail).font(.caption).foregroundColor(missing ? .orange : .secondary)
                            .lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                    }
                    Spacer(minLength: 0)
                    stepMenu
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.15)))
            }
        }
    }
    private var stepMenu: some View {
        Menu {
                Button(L("moveUp")) { model.moveStep(script.id, from: index, by: -1) }.disabled(index == 0)
                Button(L("moveDown")) { model.moveStep(script.id, from: index, by: 1) }.disabled(index == script.actions.count - 1)
                switch step {
                case .script(let path):
                    Divider()
                    Button(L("reveal")) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }.disabled(missing)
                    Button(L("relink")) { model.relink(script.id, step: index) }
                case .code, .menuCommand, .menuItem:
                    EmptyView()
                }
                Divider()
                Button(L("delete")) { model.removeStep(script.id, at: index) }
            } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help(L("stepMenu")).accessibilityLabel(L("stepMenu"))
    }
    private var missing: Bool { !step.exists }
    private var symbol: String {
        switch step { case .code: return "chevron.left.forwardslash.chevron.right"; case .script: return "doc.text"; case .menuCommand: return "command"; case .menuItem: return "menubar.rectangle" }
    }
    private var title: String {
        switch step {
        case .code: return L("code.title")
        case .script(let path): return (path as NSString).lastPathComponent
        case .menuCommand(let id, let menuTitle): return menuTitle ?? id
        case .menuItem(let path): return path.joined(separator: " › ")
        }
    }
    private var detail: String {
        switch step {
        case .code: return L(missing ? "code.empty" : "code.hint")
        case .script(let path): return missing ? L("badge.missingHint") : (path as NSString).deletingLastPathComponent
        case .menuCommand(let id, _): return L("legacy.badge") + "：" + id
        case .menuItem: return L("legacy.badge")
        }
    }
}

extension ScriptDetail {
    var usesText: String {
        guard let last = script.lastRun, script.uses > 0 else { return L("uses.never") }
        return String(format: L("uses.detail"), script.uses, last.formatted(date: .numeric, time: .shortened))
    }
}

/// The left column: all scripts, each category, and the uncategorized ones. Rows of the list can be dropped on a category.
struct CategorySidebar: View {
    @ObservedObject var model: AppModel
    @State private var confirmDelete: String?
    /// The category a drag is over, shown inverted (mustard fill, white text).
    @State private var dropTarget: String?
    var body: some View {
        VStack(spacing: 6) {
            List(selection: Binding(get: { model.categoryFilter }, set: { if let value = $0 { model.categoryFilter = value } })) {
                row(L("category.all"), AppModel.allCategories, symbol: "tray.full", count: model.library.scripts.count)
                ForEach(model.library.categoryList, id: \.self) { name in
                    row(name, name, symbol: "folder", count: model.scripts(in: name).count)
                        .contextMenu {
                            Button(L("category.rename")) { model.renameCategory(name) }
                            Button(L("category.delete")) { confirmDelete = name }
                        }
                }
                let loose = model.scripts(in: AppModel.uncategorized).count
                if loose > 0 && !model.library.categoryList.isEmpty {
                    row(L("category.none"), AppModel.uncategorized, symbol: "tray", count: loose)
                }
            }
            HStack {
                Button { model.newCategory() } label: { Image(systemName: "plus").frame(width: 16, height: 16) }
                    .help(L("category.new")).accessibilityLabel(L("category.new"))
                Button { if let name = model.currentCategory { confirmDelete = name } } label: { Image(systemName: "minus").frame(width: 16, height: 16) }
                    .disabled(model.currentCategory == nil).help(L("category.delete")).accessibilityLabel(L("category.delete"))
                Spacer()
            }
        }
        .confirmationDialog(String(format: L("category.deleteConfirm"), confirmDelete ?? ""), isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })) {
            Button(L("category.delete"), role: .destructive) { if let name = confirmDelete { model.deleteCategory(name) }; confirmDelete = nil }
            Button(L("cancel"), role: .cancel) { confirmDelete = nil }
        } message: { Text(L("category.deleteDetail")) }
    }
    private func row(_ title: String, _ tag: String, symbol: String, count: Int) -> some View {
        let highlighted = dropTarget == tag
        return HStack {
            Label(title, systemImage: symbol).lineLimit(1)
            Spacer(minLength: 4)
            Text("\(count)").font(.caption.monospacedDigit()).foregroundColor(highlighted ? .white : .secondary)
        }
        .foregroundColor(highlighted ? .white : nil)
        .tag(tag)
        .listRowBackground(highlighted ? RoundedRectangle(cornerRadius: 5).fill(appTint).padding(.horizontal, 10) : nil)
        // Script rows dragged from the list carry their id as text.
        .onDrop(of: [.utf8PlainText], isTargeted: Binding(get: { highlighted }, set: { over in
            if over { if tag != AppModel.allCategories { dropTarget = tag } } else if dropTarget == tag { dropTarget = nil }
        })) { providers in
            let target: String? = tag == AppModel.allCategories ? nil : (tag == AppModel.uncategorized ? nil : tag)
            guard tag != AppModel.allCategories else { return false }
            for provider in providers {
                _ = provider.loadObject(ofClass: NSString.self) { text, _ in
                    guard let id = text as? String else { return }
                    DispatchQueue.main.async { MainActor.assumeIsolated { model.dropped(id, on: target) } }
                }
            }
            return true
        }
    }
}

/// Tools › 統計: every script by use, with its category. Double-click a row to show it in the main window.
struct StatsView: View {
    @ObservedObject var model: AppModel
    private struct Row: Identifiable {
        let rank: Int, id: String, name: String, category: String, uses: Int, last: Date?, key: String
    }
    private var rows: [Row] {
        model.library.byUse.enumerated().map { index, script in
            Row(rank: index + 1, id: script.id, name: script.name, category: script.category ?? L("category.none"),
                uses: script.uses, last: script.lastRun, key: script.hotkey?.fullLabel ?? "")
        }
    }
    var body: some View {
        let rows = rows
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(L("stats.title")).font(.headline)
                Spacer()
                Text(String(format: L("stats.total"), rows.reduce(0) { $0 + $1.uses }, rows.filter { $0.uses > 0 }.count, rows.count))
                    .font(.callout).foregroundColor(.secondary)
            }
            Table(rows) {
                TableColumn("#") { Text("\($0.rank)").monospacedDigit().foregroundColor(.secondary) }.width(32)
                TableColumn(L("name")) { Text($0.name).lineLimit(1) }
                TableColumn(L("category")) { Text($0.category).foregroundColor(.secondary).lineLimit(1) }.width(min: 90, ideal: 140)
                TableColumn(L("stats.uses")) { row in Text(row.uses > 0 ? "\(row.uses)" : "—").monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing) }.width(60)
                TableColumn(L("stats.last")) { row in Text(row.last?.formatted(date: .numeric, time: .shortened) ?? "—").monospacedDigit().foregroundColor(.secondary) }.width(min: 110, ideal: 130)
                TableColumn(L("hotkey")) { Text($0.key).font(.system(size: 12, design: .monospaced)) }.width(min: 60, ideal: 80)
            }
            .contextMenu(forSelectionType: String.self) { _ in } primaryAction: { ids in
                guard let id = ids.first else { return }
                model.categoryFilter = AppModel.allCategories; model.selection = [id]
                NSApp.windows.first { $0.frameAutosaveName == "MainWindow" }?.makeKeyAndOrderFront(nil)
            }
            Text(L("stats.hint")).font(.caption).foregroundColor(.secondary)
        }
        .padding(16).frame(minWidth: 620, minHeight: 400).tint(appTint)
    }
}

/// Tools › アイテム名の検索と置換…: find and replace in the selected scripts' names, with a before → after preview.
struct ReplaceNamesSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("replace.find") private var find = ""
    @AppStorage("replace.with") private var replacement = ""
    @AppStorage("replace.regex") private var regex = false
    @AppStorage("replace.caseSensitive") private var caseSensitive = false
    private var targets: [ScriptEntry] { model.library.scripts.filter { model.selection.contains($0.id) } }
    private var preview: [(ScriptEntry, String)]? {
        var rows: [(ScriptEntry, String)] = []
        for script in targets {
            guard let new = Library.replacing(in: script.name, find: find, with: replacement, regex: regex, caseSensitive: caseSensitive) else { return nil }
            rows.append((script, new))
        }
        return rows
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("replace.title")).font(.headline)
            Text(String(format: L("replace.detail"), targets.count)).font(.callout).foregroundColor(.secondary)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text(L("replace.find")).gridColumnAlignment(.trailing)
                    TextField("", text: $find).textFieldStyle(.roundedBorder).accessibilityLabel(L("replace.find"))
                }
                GridRow {
                    Text(L("replace.with"))
                    TextField("", text: $replacement).textFieldStyle(.roundedBorder).accessibilityLabel(L("replace.with"))
                }
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    HStack(spacing: 16) {
                        Toggle(L("replace.regex"), isOn: $regex)
                        Toggle(L("replace.caseSensitive"), isOn: $caseSensitive)
                    }
                }
            }
            if let rows = preview {
                let changed = rows.filter { $0.0.name != $0.1 }
                List(rows, id: \.0.id) { script, new in
                    HStack(spacing: 6) {
                        Text(script.name).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                        Image(systemName: "arrow.right").foregroundColor(.secondary).accessibilityLabel(L("replace.to"))
                        Text(new).fontWeight(new != script.name ? .semibold : .regular).foregroundColor(new != script.name ? .primary : .secondary).lineLimit(1).truncationMode(.middle)
                    }
                }
                .frame(minHeight: 160)
                HStack {
                    Text(String(format: L("replace.changes"), changed.count)).font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Button(L("cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                    Button(L("replace.button")) { model.replaceNames(find: find, with: replacement, regex: regex, caseSensitive: caseSensitive); dismiss() }
                        .keyboardShortcut(.defaultAction).disabled(changed.isEmpty)
                }
            } else {
                Text(L("replace.badPattern")).foregroundColor(.orange).frame(maxWidth: .infinity, minHeight: 160)
                HStack { Spacer(); Button(L("cancel")) { dismiss() }.keyboardShortcut(.cancelAction); Button(L("replace.button")) {}.disabled(true) }
            }
        }
        .padding(20).frame(width: 520).tint(appTint)
    }
}

/// Several rows selected: their count and one category for all of them.
struct MultipleSelection: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: 12) {
            Text(String(format: L("selectedCount"), model.selection.count)).font(.headline)
            Picker(L("category"), selection: Binding(get: { commonCategory }, set: { model.setCategory($0.isEmpty ? nil : $0, for: model.selection) })) {
                if commonCategory == mixed { Text(L("category.mixed")).tag(mixed) }
                Text(L("category.none")).tag("")
                ForEach(model.library.categoryList, id: \.self) { Text($0).tag($0) }
            }
            .fixedSize()
            Text(L("selectedHint")).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private let mixed = "\u{0}mixed"
    private var commonCategory: String {
        let names = Set(model.library.scripts.filter { model.selection.contains($0.id) }.map { $0.category ?? "" })
        return names.count == 1 ? names.first! : mixed
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel
    @State private var search = ""
    @State private var confirmDelete = false
    @State private var dropTargeted = false
    @State private var showRecent = false
    @AppStorage("sortOrder") private var sortOrder = SortOrder.manual.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: currentAppIcon()).resizable().frame(width: 40, height: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("heading")).font(.system(size: 18, weight: .semibold))
                    Text(L("ui.subtitle")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 4) {
                    Toggle(L("useHotkeys"), isOn: $model.hotkeysEnabled).toggleStyle(.switch).controlSize(.small).help(L("useHotkeysHint"))
                    Label(L(model.illustratorFront ? "state.front" : "state.back"), systemImage: model.illustratorFront ? "circle.fill" : "circle")
                        .font(.caption2).foregroundColor(.secondary).help(L("state.hint"))
                }
            }
            Group {
                if model.library.scripts.isEmpty && model.library.categoryList.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.badge.plus").font(.system(size: 32)).foregroundColor(.secondary).accessibilityHidden(true)
                        Text(L("empty")).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button(L("addMenu")) { model.chooseFiles() }.keyboardShortcut(.defaultAction)
                        Button(L("code.add")) { model.addCode() }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                } else {
                    // Plain stacks, not split views: no divider lines between the columns (fixed widths on the left).
                    HStack(spacing: 12) {
                        CategorySidebar(model: model).frame(width: 154)
                        list.frame(width: 286)
                        Group {
                            if let id = model.selectedID, let binding = model.binding(for: id) {
                                ScriptDetail(model: model, script: binding)
                            } else if model.selection.count > 1 {
                                MultipleSelection(model: model)
                            } else {
                                Text(L("selectScript")).foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
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
                group.notify(queue: .main) { model.open(urls: urls) }
                return true
            }
            DisclosureGroup(isExpanded: $showRecent) {
                VStack(alignment: .leading, spacing: 6) {
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
                .padding(.top, 6)
            } label: {
                HStack(spacing: 8) {
                    Text(L("recent")).font(.caption)
                    if let record = model.records.first {
                        Image(systemName: record.isError ? "exclamationmark.triangle.fill" : "checkmark.circle")
                            .foregroundColor(record.isError ? .orange : .secondary)
                        Text(record.name + " · " + record.text).font(.caption).foregroundColor(record.isError ? .orange : .secondary)
                            .lineLimit(1).help(record.text)
                    }
                    Spacer()
                    AppVersionLabel()
                }
            }
            .onChange(of: model.records.first?.date) { _ in
                if model.records.first?.isError == true { showRecent = true }
            }
        }
        .padding(20)
        .frame(minWidth: 940, minHeight: 540)
        .background(Color(nsColor: AppSurface.color))
        .tint(appTint)
        .sheet(isPresented: $model.showReplace) { ReplaceNamesSheet(model: model) }
        .confirmationDialog(L("deleteConfirm"), isPresented: $confirmDelete) {
            Button(L("delete"), role: .destructive) { model.delete(model.selection) }
            Button(L("cancel"), role: .cancel) {}
        } message: { Text(L("deleteConfirmDetail")) }
    }

    private var order: SortOrder { SortOrder(rawValue: sortOrder) ?? .manual }
    /// The scripts of the chosen category, searched and sorted for display.
    private func shown(_ scripts: [ScriptEntry]) -> [ScriptEntry] {
        let found = search.isEmpty ? scripts : scripts.filter { $0.name.localizedCaseInsensitiveContains(search) || ($0.hotkey?.fullLabel ?? "").localizedCaseInsensitiveContains(search) }
        return order.sorted(found) { KeyCombo.keyName($0.code) }
    }
    /// Dragging rows reorders only the plain manual list (not while searching or sorted).
    private var canReorder: Bool { search.isEmpty && order == .manual }

    private var list: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                TextField(L("search"), text: $search).textFieldStyle(.roundedBorder)
                Picker("", selection: $sortOrder) {
                    Text(L("sort.manual")).tag(SortOrder.manual.rawValue)
                    Text(L("sort.name")).tag(SortOrder.name.rawValue)
                    Text(L("sort.hotkey")).tag(SortOrder.hotkey.rawValue)
                }
                .labelsHidden().fixedSize().help(L("sort.hint")).accessibilityLabel(L("sort.label"))
            }
            List(selection: $model.selection) {
                if model.categoryFilter == AppModel.allCategories && !model.library.categoryList.isEmpty {
                    // All scripts, one section per category, uncategorized last.
                    ForEach(model.library.categoryList + [AppModel.uncategorized], id: \.self) { name in
                        let members = shown(model.scripts(in: name))
                        if !members.isEmpty {
                            Section(name == AppModel.uncategorized ? L("category.none") : name) { rows(members) }
                        }
                    }
                } else {
                    rows(shown(model.scripts(in: model.categoryFilter)))
                }
            }
            .contextMenu(forSelectionType: String.self) { ids in
                if let id = ids.first, let script = model.library.scripts.first(where: { $0.id == id }) {
                    Button(L("run")) { model.runFromWindow(script) }.disabled(!script.isAvailable)
                    if let path = script.actions.compactMap(\.scriptPath).first {
                        Button(L("reveal")) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }.disabled(!FileManager.default.fileExists(atPath: path))
                    }
                    Menu(L("category")) {
                        Button(L("category.none")) { model.setCategory(nil, for: ids) }
                        ForEach(model.library.categoryList, id: \.self) { name in Button(name) { model.setCategory(name, for: ids) } }
                    }
                    Divider()
                    Button(L("delete")) { if !model.selection.isSuperset(of: ids) { model.selection = ids }; confirmDelete = true }
                }
            }
            .onDeleteCommand { if !model.selection.isEmpty { confirmDelete = true } }
            HStack {
                // The same frame for both symbols: "minus" is shorter than "plus" and would make a lower button.
                Menu {
                    Button(L("addMenu")) { model.chooseFiles() }
                    Button(L("code.add")) { model.addCode() }
                } label: { Image(systemName: "plus").frame(width: 16, height: 16) }
                    .help(L("addMenu")).accessibilityLabel(L("addMenu"))
                Button { confirmDelete = true } label: { Image(systemName: "minus").frame(width: 16, height: 16) }.disabled(model.selection.isEmpty)
                    .help(L("delete")).accessibilityLabel(L("delete"))
                Spacer()
                Text(String(format: L("count"), model.scripts(in: model.categoryFilter).count)).font(.caption).foregroundColor(.secondary)
            }
        }
    }
    @ViewBuilder private func rows(_ scripts: [ScriptEntry]) -> some View {
        let ids = scripts.map(\.id)
        if canReorder {
            ForEach(scripts) { script in row(script) }.onMove { model.move(ids: ids, from: $0, to: $1) }
        } else {
            ForEach(scripts) { script in row(script) }
        }
    }
    @ViewBuilder private func row(_ script: ScriptEntry) -> some View {
        if let binding = model.binding(for: script.id) {
            ScriptRow(model: model, script: binding).tag(script.id)
                // Dragging a row onto a category in the sidebar moves it there.
                .itemProvider { NSItemProvider(object: script.id as NSString) }
        }
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
        })), (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())), (AboutSection.title, AnyView(AboutView()))])
            .frame(minWidth: 560, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
    }
}
