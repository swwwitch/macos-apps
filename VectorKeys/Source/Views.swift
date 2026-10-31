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
    @AppStorage("itemShowVersion") private var showVersion = false
    @AppStorage("itemShowFilename") private var showFilename = false
    @ObservedObject var model: AppModel
    @Binding var script: ScriptEntry
    @AppStorage("itemShowUses") private var showUses = false
    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $script.enabled).labelsHidden().accessibilityLabel(script.name).help(L("enabledHint"))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(script.name).lineLimit(1).truncationMode(.middle)
                }
                if showFilename {
                    ForEach(script.actions.compactMap(\.scriptPath), id: \.self) { path in
                        Text((path as NSString).lastPathComponent).font(.caption).foregroundColor(.secondary)
                    }
                }
                if showVersion, let version = model.version(for: script) { Text(version).font(.caption2).foregroundColor(.secondary) }
            }
            if script.hasUnsupportedSteps { Badge(text: L("legacy.badge"), color: .orange).help(L("legacy.unsupported")) }
            else if !script.isAvailable && !script.actions.isEmpty { Badge(text: L("code.unavailable"), color: .orange).help(L("code.unavailableHint")) }
            Spacer(minLength: 4)
            if showUses && script.uses > 0 {
                Text(String(format: L("uses.count"), script.uses)).font(.caption.monospacedDigit()).foregroundColor(.secondary).help(L("uses.hint"))
            }
            if let hotkey = script.hotkey {
                Text(hotkey.fullLabel).font(.system(size: 12, design: .monospaced)).kerning(1).fixedSize()
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
    @AppStorage("showUses") private var showUses = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TextField(L("name"), text: Binding(get: { script.name }, set: { script.name = $0; script.automaticName = nil; script.userRenamed = true }))
                            .textFieldStyle(.plain).font(.system(size: 16, weight: .semibold))
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
                ItemTagsEditor(model: model, script: script)
                ItemColorPicker(color: Binding(get: { script.tagColor }, set: { model.setColor($0, for: [script.id]) }))
                StepsEditor(model: model, script: script)
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("hotkey")).font(.subheadline.weight(.semibold))
                    HStack(spacing: 8) {
                        HotkeyField(id: "script-" + script.id, combo: Binding(get: { script.hotkey.map { KeyCombo(code: $0.code, modifiers: $0.modifiers) } },
                            set: { combo in script.hotkey = combo.map { Hotkey(code: $0.code, modifiers: $0.modifiers, taps: script.hotkey?.taps) } }),
                            allowsClear: true, others: model.otherHotkeys(except: script.id, taps: .some(script.hotkey?.taps)),
                            registered: !model.failedHotkeys.contains(script.id), isEnabled: script.enabled && script.scriptsOnly, allowsOption: true)
                        Picker(L("taps.label"), selection: Binding(get: { script.hotkey?.taps ?? 1 }, set: { script.hotkey?.taps = $0 == 2 ? 2 : nil })) {
                            Text(L("taps.single")).tag(1)
                            Text(L("taps.double")).tag(2)
                        }
                        .pickerStyle(.segmented).labelsHidden().fixedSize().disabled(script.hotkey == nil || !script.enabled)
                    }.controlSize(.small)
                    if model.duplicateHotkeys.contains(script.id) { Text(L("hotkey.duplicate")).font(.caption).foregroundColor(.red) }
                }
                Divider()
                ScriptOverviewView(model: model, script: script)
                ScriptInfoView(model: model, script: $script)
                if showUses && script.uses > 0 {
                    Text(usesText).font(.caption).foregroundColor(.secondary).help(L("uses.hint"))
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Script files run in order. Legacy unsupported steps are retained until the user removes them.
struct StepsEditor: View {
    @ObservedObject var model: AppModel
    let script: ScriptEntry
    @State private var showComponents = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("components.shared")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            if script.actions.isEmpty { Text(L("steps.empty")).foregroundColor(.secondary) }
            ForEach(Array(script.actions.enumerated()), id: \.offset) { index, step in
                StepRow(model: model, script: script, index: index, step: step)
            }
            Menu {
                Button(L("components.choose")) { showComponents = true }
                Divider()
                Button(L("step.addScript")) { model.addScriptSteps(to: script.id) }
                Button(L("code.add")) { model.addStep(.code(source: ""), to: script.id) }
            } label: { Label(L("ui.addStep"), systemImage: "plus") }
            .fixedSize().menuStyle(.borderlessButton).font(.caption).foregroundColor(.secondary)
            .padding(.top, 2)
            if script.hasUnsupportedSteps {
                Text(L("legacy.unsupported")).font(.caption).foregroundColor(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }.sheet(isPresented: $showComponents) { ComponentLibraryView(model: model, actionID: script.id) }
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
                    Text(componentName).font(.caption).foregroundColor(.secondary)
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
                if let version = model.version(for: step) { Text(L("meta.version") + " " + version).font(.caption).foregroundColor(.secondary) }
                if missing { Text(L("code.empty")).font(.caption).foregroundColor(.secondary) }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: symbol).foregroundColor(.secondary).padding(.top, 2).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(title).lineLimit(2).truncationMode(.middle)
                            if let version = model.version(for: step) { Text(version).font(.caption).foregroundColor(.secondary) }
                        }
                        Text(detail).font(.caption).foregroundColor(missing ? .orange : .secondary)
                            .lineLimit(2).truncationMode(.middle).textSelection(.enabled).help(detail)
                        if case .script(let path) = step {
                            HStack(spacing: 8) {
                                Button(L("source.preview")) { model.showQuickLook?(URL(fileURLWithPath: path)) }
                                Button(L("source.reveal")) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
                                Button(L("source.open")) { model.openSource(path) }
                                    .help(L("source.hint")).disabled((path as NSString).pathExtension.lowercased() == "jsxbin")
                            }
                            .controlSize(.small).disabled(missing).padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 0)
                    stepMenu
                }
                .padding(8)
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
    private var componentName: String {
        guard let ids = script.componentIDs, ids.indices.contains(index) else { return L("components.title") }
        return model.library.components?.first { $0.id == ids[index] }?.name ?? L("components.title")
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
                row(L("group.recent"), AppModel.recentCategory, symbol: "clock", count: model.library.recentlyUsed.count)
                ForEach(model.library.categoryList, id: \.self) { name in
                    row(name, name, symbol: "folder", count: model.scripts(in: name).count)
                        .contextMenu {
                            Button(L("palette.show")) { model.showPalette?(name) }
                            Divider()
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
                Button { model.showPalette?(model.categoryFilter) } label: { Image(systemName: "macwindow").frame(width: 16, height: 16) }
                    .help(L("palette.show")).accessibilityLabel(L("palette.show"))
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
            if over { if tag != AppModel.allCategories && tag != AppModel.recentCategory { dropTarget = tag } } else if dropTarget == tag { dropTarget = nil }
        })) { providers in
            let target: String? = tag == AppModel.allCategories ? nil : (tag == AppModel.uncategorized ? nil : tag)
            guard tag != AppModel.allCategories, tag != AppModel.recentCategory else { return false }
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
    @AppStorage("statisticsHiddenColumns") private var hidden = ""
    private var rows: [StatisticsRow] {
        model.library.byUse.enumerated().map { rank, script in
            let names = script.actions.map { step in
                model.metadata(for: step)?.fields["Name"] ?? step.scriptPath.map { ($0 as NSString).lastPathComponent } ?? L("code.title")
            }
            return StatisticsRow(rank: rank + 1, id: script.id, name: script.name, category: script.category ?? L("category.none"),
                scriptName: names.joined(separator: " · "), path: script.actions.compactMap(\.scriptPath).joined(separator: " · "),
                uses: script.uses, last: script.lastRun, key: script.hotkey?.fullLabel ?? "")
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("stats.title")).font(.headline)
                Spacer()
                Menu(L("stats.columns")) {
                    ForEach(StatisticsColumn.allCases, id: \.self) { column in
                        Toggle(column.title, isOn: Binding(get: { !hidden.components(separatedBy: "|").contains(column.rawValue) }, set: { visible in
                            var keys = Set(hidden.components(separatedBy: "|").filter { !$0.isEmpty })
                            if visible { keys.remove(column.rawValue) } else { keys.insert(column.rawValue) }
                            hidden = keys.sorted().joined(separator: "|")
                        }))
                    }
                }
            }
            Text(String(format: L("stats.total"), rows.reduce(0) { $0 + $1.uses }, rows.filter { $0.uses > 0 }.count, rows.count)).font(.caption).foregroundColor(.secondary)
            StatisticsTable(rows: rows, hidden: Set(hidden.components(separatedBy: "|"))) { id in
                model.categoryFilter = AppModel.allCategories; model.selection = [id]
                NSApp.windows.first { $0.frameAutosaveName == "MainWindow" }?.makeKeyAndOrderFront(nil)
            }
            Text(L("stats.hint")).font(.caption).foregroundColor(.secondary)
        }.padding(16).frame(minWidth: 620, minHeight: 400).tint(appTint)
    }
}

extension StatisticsColumn {
    var title: String {
        switch self {
        case .rank: return "#"
        case .name: return L("name")
        case .category: return L("category")
        case .scriptName: return L("meta.scriptName")
        case .path: return L("stats.path")
        case .uses: return L("stats.uses")
        case .last: return L("stats.last")
        case .key: return L("hotkey")
        }
    }
}
struct StatisticsTable: NSViewRepresentable {
    let rows: [StatisticsRow]
    let hidden: Set<String>
    let openItem: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
        let table = NSTableView(); table.delegate = context.coordinator; table.dataSource = context.coordinator
        table.usesAlternatingRowBackgroundColors = true; table.allowsColumnReordering = true; table.columnAutoresizingStyle = .noColumnAutoresizing
        table.target = context.coordinator; table.doubleAction = #selector(Coordinator.openSelected)
        for column in StatisticsColumn.allCases {
            let native = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.rawValue))
            native.title = column.title
            native.width = column == .path ? 340 : column == .name || column == .scriptName ? 180 : column == .rank || column == .uses ? 55 : 130
            native.minWidth = 36; native.sortDescriptorPrototype = NSSortDescriptor(key: column.rawValue, ascending: true)
            table.addTableColumn(native)
        }
        table.sortDescriptors = [NSSortDescriptor(key: "uses", ascending: false)]
        scroll.documentView = table
        context.coordinator.table = table
        updateNSView(scroll, context: context)
        return scroll
    }
    func updateNSView(_ view: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.rows = rows; coordinator.openItem = openItem
        for column in coordinator.table?.tableColumns ?? [] { column.isHidden = hidden.contains(column.identifier.rawValue) }
        coordinator.sort()
    }
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        weak var table: NSTableView?
        var rows: [StatisticsRow] = [], shown: [StatisticsRow] = []
        var openItem: (String) -> Void = { _ in }
        func numberOfRows(in tableView: NSTableView) -> Int { shown.count }
        func sort() {
            let descriptor = table?.sortDescriptors.first
            shown = StatisticsRow.sorted(rows, by: StatisticsColumn(rawValue: descriptor?.key ?? "uses") ?? .uses, ascending: descriptor?.ascending ?? false)
            table?.reloadData()
        }
        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) { sort() }
        func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
            guard shown.indices.contains(row), let key = column.flatMap({ StatisticsColumn(rawValue: $0.identifier.rawValue) }) else { return nil }
            let text = shown[row].text(for: key)
            let field = NSTextField(labelWithString: text.isEmpty ? "—" : text)
            field.lineBreakMode = .byTruncatingMiddle; field.toolTip = text
            field.setAccessibilityLabel((column?.title ?? "") + " " + text)
            return field
        }
        @objc func openSelected() { guard let table, shown.indices.contains(table.clickedRow) else { return }; openItem(shown[table.clickedRow].id) }
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
    @State private var showComponentLibrary = false
    @AppStorage("sortOrder") private var sortOrder = SortOrder.manual.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(spacing: 3) {
                    Image(nsImage: currentAppIcon()).resizable().frame(width: 40, height: 40).accessibilityHidden(true)
                    AppVersionLabel()
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("heading")).font(.system(size: 18, weight: .semibold))
                    Text(L("ui.subtitle")).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(L("components.title")) { showComponentLibrary = true }
                        Button(L("action.new")) { model.newAction() }
                    }.controlSize(.small)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 4) {
                    Toggle(L("useHotkeys"), isOn: $model.hotkeysEnabled).toggleStyle(.switch).controlSize(.small).help(L("useHotkeysHint"))
                    Label(L(model.illustratorFront ? "state.front" : "state.back"), systemImage: model.illustratorFront ? "circle.fill" : "circle")
                        .font(.caption2).foregroundColor(.secondary).help(L("state.hint"))
                }
            }
            if model.updatingInformation {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(L("meta.refreshing"))
                        Spacer()
                        Text("\(model.informationCompleted) / \(model.informationTotal)").monospacedDigit()
                    }.font(.caption).foregroundColor(.secondary)
                    ProgressView(value: Double(model.informationCompleted), total: Double(max(model.informationTotal, 1)))
                        .progressViewStyle(.linear).accessibilityLabel(L("meta.refreshing"))
                }
            }
            Group {
                if model.library.scripts.isEmpty && model.library.categoryList.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.badge.plus").font(.system(size: 32)).foregroundColor(.secondary).accessibilityHidden(true)
                        Text(L("empty")).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button(L("addMenu")) { model.chooseFiles() }.keyboardShortcut(.defaultAction)
                        Button(L("code.add")) { model.addCode() }
                    Button(L("divider.add")) { model.addDivider() }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                } else {
                    ResizableColumns(
                        categories: AnyView(CategorySidebar(model: model).padding(.trailing, 6)),
                        scripts: AnyView(list.padding(.horizontal, 6)),
                        detail: AnyView(Group {
                            if let id = model.selectedID, let binding = model.binding(for: id) {
                                if binding.wrappedValue.isDivider {
                                    VStack(alignment: .leading) {
                                        Text(L("divider.title")).font(.headline)
                                        TextField(L("name"), text: binding.name).textFieldStyle(.roundedBorder)
                                    }.padding(20)
                                } else { ScriptDetail(model: model, script: binding) }
                            } else if model.selection.count > 1 {
                                MultipleSelection(model: model)
                            } else {
                                CategoryDetail(model: model, category: model.categoryFilter).id(model.categoryFilter)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                        .padding(.leading, 6))
                    )
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
        .sheet(isPresented: $showComponentLibrary) { ComponentLibraryView(model: model, actionID: nil) }
        .sheet(isPresented: $model.showReplace) { ReplaceNamesSheet(model: model) }
        .confirmationDialog(L("deleteConfirm"), isPresented: $confirmDelete) {
            Button(L("delete"), role: .destructive) { model.delete(model.selection) }
            Button(L("cancel"), role: .cancel) {}
        } message: { Text(L("deleteConfirmDetail")) }
    }

    private var order: SortOrder { SortOrder(rawValue: sortOrder) ?? .manual }
    /// The scripts of the chosen category, searched and sorted for display.
    private func shown(_ scripts: [ScriptEntry]) -> [ScriptEntry] {
        let tagged = model.tagFilter.isEmpty ? scripts : scripts.filter { $0.allTags.contains(model.tagFilter) }
        let found = search.isEmpty ? tagged : tagged.filter { $0.name.localizedCaseInsensitiveContains(search) || ($0.hotkey?.fullLabel ?? "").localizedCaseInsensitiveContains(search) }
        return model.categoryFilter == AppModel.recentCategory ? found : order.sorted(found) { KeyCombo.keyName($0.code) }
    }
    /// Dragging rows reorders only the plain manual list (not while searching or sorted).
    private var canReorder: Bool { search.isEmpty && order == .manual && model.categoryFilter != AppModel.recentCategory }

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
                Menu {
                    Button(L("tags.all")) { model.tagFilter = "" }
                    ForEach(model.allTags, id: \.self) { tag in Button(tag) { model.tagFilter = tag } }
                } label: { Label(model.tagFilter.isEmpty ? L("tags.title") : model.tagFilter, systemImage: "tag") }
                .fixedSize()
                ItemDisplayOptions()
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
                    Button(L("divider.add")) { model.selection = ids; model.addDivider() }
                    Menu(L("item.color")) {
                        Button(L("color.none")) { model.setColor(nil, for: ids) }
                        ForEach(ItemTag.allCases, id: \.self) { color in
                            Button { model.setColor(color, for: ids) } label: { Label(L("color." + color.rawValue), systemImage: "circle.fill").foregroundColor(color.displayColor) }
                        }
                    }
                    if ids.count > 1 {
                        Menu(L("sort.label")) {
                            Button(L("sort.name")) { model.sortSelected(ids, by: .name); sortOrder = SortOrder.manual.rawValue }
                            Button(L("sort.uses")) { model.sortSelected(ids, by: .uses); sortOrder = SortOrder.manual.rawValue }
                            Button(L("sort.hotkey")) { model.sortSelected(ids, by: .hotkey); sortOrder = SortOrder.manual.rawValue }
                        }
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
            .background(ItemDeleteShortcut { if !model.selection.isEmpty { confirmDelete = true } })
            HStack {
                // The same frame for both symbols: "minus" is shorter than "plus" and would make a lower button.
                Menu {
                    Button(L("addMenu")) { model.chooseFiles() }
                    Button(L("code.add")) { model.addCode() }
                    Button(L("divider.add")) { model.addDivider() }
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
            Group {
                if script.isDivider {
                    HStack { Divider(); Text(script.name).font(.caption).foregroundColor(.secondary); Divider() }.frame(height: 22)
                } else { ScriptRow(model: model, script: binding) }
            }.tag(script.id)
                .listRowSeparator(.visible)
                .listRowBackground(script.tagColor.map { $0.displayColor.opacity(0.22) })
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
        })), (L("watch.title"), AnyView(WatchFolderSettings(model: model))), (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView())), (AboutSection.title, AnyView(AboutView()))])
            .frame(minWidth: 560, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
    }
}

struct ItemDisplayOptions: View {
    @AppStorage("itemShowUses") private var uses = false
    @AppStorage("itemShowVersion") private var version = false
    @AppStorage("itemShowFilename") private var filename = false
    var body: some View {
        Menu {
            Toggle(L("meta.version"), isOn: $version)
            Toggle(L("sort.uses"), isOn: $uses)
            Toggle(L("item.filename"), isOn: $filename)
        } label: { Image(systemName: "slider.horizontal.3") }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .accessibilityLabel(L("item.display")).help(L("item.display"))
    }
}

struct CategoryDetail: View {
    @ObservedObject var model: AppModel
    let category: String
    @State private var name = ""
    @State private var invalidName = false
    @FocusState private var editingName: Bool
    private var editable: Bool { category != AppModel.allCategories && category != AppModel.uncategorized && category != AppModel.recentCategory }
    private func commitName() {
        guard editable, model.categoryFilter == category else { return }
        invalidName = !model.renameCategory(category, to: name)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if editable {
                    TextField(L("palette.name"), text: $name).textFieldStyle(.plain).font(.title2.weight(.semibold))
                        .focused($editingName).onSubmit { commitName() }.accessibilityLabel(L("palette.name"))
                        .onChange(of: editingName) { focused in if !focused { commitName() } }
                    if invalidName { Text(L("palette.nameInvalid")).font(.caption).foregroundColor(.red) }
                } else { Text(model.categoryTitle(category)).font(.title2.weight(.semibold)) }
                Toggle(L("palette.show"), isOn: Binding(get: { model.library.allowsPalette(category) }, set: { model.setPaletteEnabled($0, for: category) }))
                Text(L("hotkey")).font(.headline)
                HotkeyField(id: "palette-" + category, combo: Binding(get: {
                    model.library.paletteHotkeys?[category].map { KeyCombo(code: $0.code, modifiers: $0.modifiers) }
                }, set: { model.setPaletteHotkey($0, for: category) }), allowsClear: true,
                others: model.paletteConflicts(except: category), registered: !model.failedPaletteHotkeys.contains(category),
                isEnabled: model.hotkeysEnabled && model.library.allowsPalette(category))
                Picker(L("palette.behavior"), selection: Binding(get: { model.library.paletteMode(category) }, set: { model.setPaletteMode($0, for: category) })) {
                    Text(L("palette.mode0")).tag(0)
                    Text(L("palette.mode1")).tag(1)
                    Text(L("palette.mode2")).tag(2)
                }.pickerStyle(.radioGroup)
                Text(L("palette.visibility")).font(.caption).foregroundColor(.secondary)
                Text(L("palette.behaviorHint")).font(.caption).foregroundColor(.secondary)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { name = model.categoryTitle(category) }
        .onChange(of: category) { _ in name = model.categoryTitle(category); invalidName = false }
    }
}

extension ItemTag {
    var displayColor: Color {
        switch self {
        case .red: return Color(nsColor: .systemRed)
        case .orange: return Color(nsColor: .systemOrange)
        case .yellow: return Color(nsColor: .systemYellow)
        case .green: return Color(nsColor: .systemGreen)
        case .blue: return Color(nsColor: .systemBlue)
        case .purple: return Color(nsColor: .systemPurple)
        case .gray: return Color(nsColor: .systemGray)
        }
    }
}

struct ItemColorPicker: View {
    @Binding var color: ItemTag?
    var body: some View {
        HStack(spacing: 8) {
            Text(L("item.color")).font(.caption).foregroundColor(.secondary).frame(width: 52, alignment: .leading)
            HStack(spacing: 6) {
                Button { color = nil } label: {
                    Image(systemName: "nosign").font(.system(size: 16)).frame(width: 23, height: 23)
                        .overlay(Circle().strokeBorder(color == nil ? Color.primary : .clear, lineWidth: 2))
                }.help(L("color.none")).accessibilityLabel(L("color.none"))
                ForEach(ItemTag.allCases, id: \.self) { tag in
                    Button { color = tag } label: {
                        Circle().fill(tag.displayColor.opacity(0.65))
                            .overlay(Circle().strokeBorder(tag.displayColor, lineWidth: 1.5))
                            .frame(width: 17, height: 17).padding(3)
                            .overlay(Circle().strokeBorder(color == tag ? Color.primary : .clear, lineWidth: 2))
                    }.help(L("color." + tag.rawValue)).accessibilityLabel(L("color." + tag.rawValue))
                        .accessibilityValue(color == tag ? L("color.selected") : "")
                }
            }.buttonStyle(.plain)
        }
    }
}

/// Only the item column owns this local shortcut; text editing retains Command-Delete.
struct ItemDeleteShortcut: NSViewRepresentable {
    let action: () -> Void
    final class ShortcutView: NSView {
        var action: () -> Void = {}
        var monitor: Any?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.window?.isKeyWindow == true, event.keyCode == 51,
                      event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function]) == .command,
                      let responder = self.window?.firstResponder as? NSView,
                      !(responder is NSTextView), !(responder is NSTextField) else { return event }
                var host: NSView? = self.superview
                while let view = host, !(view is NSHostingView<AnyView>) { host = view.superview }
                guard let host, responder === host || responder.isDescendant(of: host) else { return event }
                self.action(); return nil
            }
        }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
    func makeNSView(context: Context) -> ShortcutView { let view = ShortcutView(); view.action = action; return view }
    func updateNSView(_ view: ShortcutView, context: Context) { view.action = action }
}

struct ScriptOverviewView: View {
    @ObservedObject var model: AppModel
    let script: ScriptEntry
    @State private var expanded = false
    var body: some View {
        DisclosureGroup(L("meta.summary"), isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(script.actions.enumerated()), id: \.offset) { index, step in
                    if step.isSupported {
                        if script.actions.count > 1 {
                            Text(step.scriptPath.map { ($0 as NSString).lastPathComponent } ?? String(format: L("ui.stepNumber"), index + 1)).font(.caption.weight(.semibold))
                        }
                        let summary = model.metadata(for: step)?.summary ?? ""
                        Text(summary.isEmpty ? L("meta.absent") : summary)
                            .font(.callout).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }.padding(.top, 4)
        }.font(.subheadline)
    }
}

struct ScriptInfoView: View {
    @ObservedObject var model: AppModel
    @Binding var script: ScriptEntry
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        DisclosureGroup(L("meta.info"), isExpanded: $expanded) {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(script.actions.enumerated()), id: \.offset) { index, step in
                if step.isSupported {
                    VStack(alignment: .leading, spacing: 10) {
                        if script.actions.count > 1 {
                            Text(step.scriptPath.map { ($0 as NSString).lastPathComponent } ?? String(format: L("ui.stepNumber"), index + 1))
                                .font(.caption.weight(.semibold)).lineLimit(2)
                        }
                        MetadataFields(info: model.metadata(for: step), readme: step.scriptPath.flatMap { model.scriptReadmes[$0] }, codeURL: step.scriptPath.flatMap { model.scriptCodeURLs[$0] })
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(L("meta.notes")).font(.caption).foregroundColor(.secondary)
                TextEditor(text: Binding(get: { script.notes ?? "" }, set: { script.notes = $0.isEmpty ? nil : $0 }))
                    .font(.body).frame(minHeight: 72).padding(6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.secondary.opacity(0.18)))
                    .accessibilityLabel(L("meta.notes"))
            }
        }.padding(.top, 6)
        }.font(.subheadline)
        .transaction { transaction in
            transaction.animation = reduceMotion ? nil : .easeInOut(duration: 0.12)
        }
    }
}

struct MetadataFields: View {
    let info: ScriptMetadata.Info?
    let readme: URL?
    let codeURL: URL?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let name = info?.fields["Name"], !name.isEmpty { field(L("meta.scriptName"), value: name) }
            field(L("meta.version"), value: info?.version)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(L("meta.articleURL")).font(.caption).foregroundColor(.secondary).frame(width: 110, alignment: .leading)
                if let url = info?.url {
                    Link(url.absoluteString, destination: url).font(.callout).lineLimit(2).truncationMode(.middle)
                        .help(url.absoluteString)
                } else { Text(L("meta.absent")).font(.caption).foregroundColor(.secondary) }
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(L("meta.codeURL")).font(.caption).foregroundColor(.secondary).frame(width: 110, alignment: .leading)
                if let url = info?.codeURL ?? codeURL {
                    Link(url.absoluteString, destination: url).font(.callout).lineLimit(2).truncationMode(.middle).help(url.absoluteString)
                } else { Text(L("meta.absent")).font(.caption).foregroundColor(.secondary) }
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("README").font(.caption).foregroundColor(.secondary).frame(width: 78, alignment: .leading)
                if let url = info?.readmeURL(language: Locale.preferredLanguages.first ?? "en") {
                    Link(L("meta.openReadme"), destination: url).font(.callout).help(url.absoluteString)
                } else if let readme {
                    Button(readme.lastPathComponent) { NSWorkspace.shared.open(readme) }
                        .buttonStyle(.link).font(.callout).help(readme.path)
                } else { Text(L("meta.absent")).font(.caption).foregroundColor(.secondary) }
            }
            field(L("meta.author"), value: info?.fields["Author"])
            if let target = info?.fields["Target-App"], !target.isEmpty { field(L("meta.target"), value: target) }
            if let date = info?.fields["First-Release-Date"], !date.isEmpty { field(L("meta.released"), value: date) }
            if let date = info?.fields["Updated-Date"], !date.isEmpty { field(L("meta.date"), value: date) }
            else if let date = info?.fields["Release-Date"], !date.isEmpty { field(L("meta.releaseDate"), value: date) }
        }
    }
    private func field(_ label: String, value: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label).font(.caption).foregroundColor(.secondary).frame(width: 78, alignment: .leading)
            Text(value.flatMap { $0.isEmpty ? nil : $0 } ?? L("meta.absent"))
                .font(.callout).foregroundColor(value == nil ? .secondary : .primary)
                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
        }
    }
}


struct ItemTagsEditor: View {
    @ObservedObject var model: AppModel
    let script: ScriptEntry
    @State private var text = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(L("tags.title")).font(.caption).foregroundColor(.secondary).frame(width: 52, alignment: .leading)
                TextField(L("tags.input"), text: $text).textFieldStyle(.roundedBorder)
                    .onSubmit { model.setTags(text, for: script.id) }
                Button { model.setTags(text, for: script.id) } label: { Image(systemName: "checkmark") }
                    .help(L("tags.save")).accessibilityLabel(L("tags.save"))
            }.controlSize(.small)
            if let tags = script.folderTags, !tags.isEmpty {
                Text(L("tags.fromFolder") + tags.joined(separator: " · ")).font(.caption).foregroundColor(.secondary)
            }
        }
        .onAppear { text = (script.tags ?? []).joined(separator: ", ") }
        .onChange(of: script.id) { _ in text = (script.tags ?? []).joined(separator: ", ") }
    }
}
struct WatchFolderSettings: View {
    @ObservedObject var model: AppModel
    @State private var exclusions = ""
    var body: some View {
        ScrollView {
            SettingsSection(L("watch.title")) {
                Toggle(L("watch.autoGroup"), isOn: $model.watchAutoGroup)
                Text(L("watch.groupHint")).font(.caption).foregroundColor(.secondary)
                Text(L("watch.exclusions")).font(.subheadline.weight(.semibold))
                TextEditor(text: $exclusions).font(.body).frame(height: 66).padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.3)))
                    .accessibilityLabel(L("watch.exclusions"))
                Button(L("watch.saveExclusions")) { model.setWatchExclusions(exclusions) }
                Text(L("watch.exclusionHint")).font(.caption).foregroundColor(.secondary)
                Divider()
                ForEach(model.watchFolders, id: \.self) { path in
                    HStack {
                        Text(path).lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                        Spacer()
                        Button(L("watch.remove")) { model.removeWatchFolder(path) }
                    }
                }
                HStack {
                    Button(L("watch.add")) { model.chooseWatchFolder() }
                    Button(L("watch.scan")) { model.scanWatchedFolders() }.disabled(model.watchScanning || model.watchFolders.isEmpty)
                    if model.watchScanning { ProgressView().controlSize(.small) }
                }
                if !model.watchStatus.isEmpty { Text(model.watchStatus).font(.caption) }
                DisclosureGroup(L("watch.help")) {
                    Text(L("watch.detail")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }.padding(16)
        }.onAppear { exclusions = model.watchExcludedNames.joined(separator: "\n") }
    }
}


struct ComponentLibraryView: View {
    @ObservedObject var model: AppModel
    let actionID: String?
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String?
    @State private var search = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("components.title")).font(.headline)
                Spacer()
                Button(L("close")) { dismiss() }
            }
            Text(L("components.shared")).font(.caption).foregroundColor(.secondary)
            TextField(L("search"), text: $search).textFieldStyle(.roundedBorder)
            HSplitView {
                List(selection: $selected) {
                    ForEach((model.library.components ?? []).filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { component in
                        Text(component.name).tag(component.id)
                    }
                }.frame(minWidth: 190)
                if let id = selected, let component = model.library.components?.first(where: { $0.id == id }) {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField(L("name"), text: Binding(get: { component.name }, set: { value in
                            if let i = model.library.components?.firstIndex(where: { $0.id == id }), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { model.library.components![i].name = value }
                        })).textFieldStyle(.roundedBorder)
                        let count = model.library.scripts.filter { $0.componentIDs?.contains(id) == true }.count
                        Text(String(format: L("components.references"), count)).font(.caption).foregroundColor(.secondary)
                        switch component.step {
                        case .code(let source):
                            TextEditor(text: Binding(get: { source }, set: { model.updateComponent(id, step: .code(source: $0)) }))
                                .font(.system(size: 12, design: .monospaced))
                        case .script(let path):
                            Text(path).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            Button(L("source.open")) { model.openSource(path) }.disabled(!component.step.exists || (path as NSString).pathExtension.lowercased() == "jsxbin")
                        default: Text(L("legacy.unsupported"))
                        }
                        Spacer()
                        HStack {
                            Button(L("delete")) { model.deleteComponent(id); selected = nil }.disabled(count > 0)
                            Spacer()
                            if let actionID {
                                Button(L("components.attach")) { model.attachComponent(component, to: actionID); dismiss() }
                            }
                        }
                    }.padding(10).frame(minWidth: 340)
                } else { Text(L("components.select")).foregroundColor(.secondary).frame(minWidth: 340, maxHeight: .infinity) }
            }
            HStack {
                Button(L("step.addScript")) { model.registerComponent(code: false) }
                Button(L("code.add")) { model.registerComponent(code: true); selected = model.library.components?.last?.id }
            }
        }.padding(20).frame(width: 760, height: 520)
    }
}
