import AppKit
import SwiftUI
import UniformTypeIdentifiers

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

enum RowFilter: String, CaseIterable, Identifiable {
    case diff, changed, added, removed, same, conflict, assigned, all
    var id: String { rawValue }
    var title: String { L("filter." + rawValue) }

    func includes(_ row: Row) -> Bool {
        switch self {
        case .diff: return [.changed, .added, .removed, .unlisted].contains(row.status)
        case .changed: return row.status == .changed
        case .added: return row.status == .added
        case .removed: return row.status == .removed
        case .same: return row.status == .same
        case .conflict: return row.hasConflict
        case .assigned: return row.status != .unassigned
        case .all: return true
        }
    }
}

enum ExportFormat {
    case csv, markdown
    var fileExtension: String { self == .csv ? "csv" : "md" }
}

@MainActor final class AppModel: ObservableObject {
    static let allGroups = "*"
    private let defaults = UserDefaults.standard
    private let table: (names: [CommandKey: CommandName], order: [CommandKey: Int])
    private let japanese = (Bundle.main.preferredLocalizations.first ?? "ja").hasPrefix("ja")

    @Published private(set) var sources: [KeySetSource] = []
    @Published var baselineID = KeySetSource.bundledID { didSet { if baselineID != oldValue { select() } } }
    @Published var targetID = KeySetSource.bundledID { didSet { if targetID != oldValue { select() } } }
    @Published var filter: RowFilter = .diff { didSet { refilter() } }
    @Published var group = AppModel.allGroups { didSet { refilter() } }
    @Published var query = "" { didSet { refilter() } }
    @Published var sortOrder = [KeyPathComparator(\Row.order)] { didSet { refilter() } }
    @Published var selection = Set<CommandKey>()
    @Published private(set) var rows: [Row] = []
    @Published private(set) var shown: [Row] = []
    @Published private(set) var counts: [RowFilter: Int] = [:]
    @Published private(set) var groups: [String] = []
    @Published private(set) var baselineCount = 0
    @Published private(set) var targetCount = 0
    /// Why a set could not be read, or the note about the active set. Stays until the next load.
    @Published private(set) var problem = ""
    /// Result of the last copy or export.
    @Published private(set) var note = ""

    // Keyboard view
    @Published var keyboardKind: KeyboardKind { didSet { defaults.set(keyboardKind.rawValue, forKey: "keyboardKind"); selectedKeyCode = nil; rebuildKeyMap() } }
    @Published var keyboardUsesBaseline = false { didSet { rebuildKeyMap() } }
    @Published var keyboardModifiers = 64
    @Published var selectedKeyCode: Int?
    @Published private(set) var keyMap = KeyMap(kind: .jis, assignments: [])
    private var systemSlots = Set<Slot>()

    private var active: ActiveSet?
    private var stamps: [String: Date] = [:]

    init() {
        Shortcut.yenKey = japanese ? "¥" : "\\"
        keyboardKind = UserDefaults.standard.string(forKey: "keyboardKind").flatMap(KeyboardKind.init) ?? SystemShortcuts.detectedKeyboard
        let text = Bundle.main.url(forResource: "Commands", withExtension: "tsv").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        table = CommandTable.parse(text)
        scan()
        let saved = defaults.string(forKey: "baselineID") ?? KeySetSource.bundledID
        baselineID = sources.contains { $0.id == saved } ? saved : KeySetSource.bundledID
        targetID = defaults.string(forKey: "targetID").flatMap { id in sources.contains { $0.id == id } ? id : nil } ?? automaticTarget
        load()
    }

    // MARK: Sets

    private var addedPaths: [String] {
        get { defaults.stringArray(forKey: "addedSets") ?? [] }
        set { defaults.set(newValue, forKey: "addedSets") }
    }

    /// The set in use, or the first one found. With no custom set, the defaults against themselves.
    private var automaticTarget: String {
        sources.first { $0.isActive }?.id ?? sources.first { $0.id != KeySetSource.bundledID }?.id ?? KeySetSource.bundledID
    }

    private func scan() {
        let preferences = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences")
        let found = SetScanner.scan(preferences: preferences)
        active = found.active
        var list = [KeySetSource(id: KeySetSource.bundledID, name: "", url: nil, origin: .bundled)] + found.sources
        for path in addedPaths where FileManager.default.fileExists(atPath: path) && !list.contains(where: { $0.id == path }) {
            let url = URL(fileURLWithPath: path)
            list.append(KeySetSource(id: path, name: url.deletingPathExtension().lastPathComponent, url: url, origin: .added))
        }
        sources = list
    }

    func title(_ source: KeySetSource) -> String {
        switch source.origin {
        case .bundled: return L("source.bundled")
        case .detected(let version): return String(format: L(source.isActive ? "source.active" : "source.detected"), source.name, version)
        case .added: return String(format: L("source.added"), source.name)
        }
    }

    private func select() {
        guard !isLoadingSelection else { return }
        defaults.set(baselineID, forKey: "baselineID")
        defaults.set(targetID, forKey: "targetID")
        selection = []
        load()
    }
    private var isLoadingSelection = false

    func swapSets() {
        isLoadingSelection = true
        (baselineID, targetID) = (targetID, baselineID)
        isLoadingSelection = false
        select()
    }

    func openAddPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "kys") ?? .data]
        panel.prompt = L("button.add")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        add(url)
    }

    func add(_ url: URL) {
        guard url.pathExtension.lowercased() == "kys" else { problem = L("error.notKys"); return }
        let resolved = url.resolvingSymlinksInPath()
        if !sources.contains(where: { $0.id == resolved.path }) {
            addedPaths.append(resolved.path)
            scan()
        }
        targetID = resolved.path
        load()
    }

    var canRemoveTarget: Bool { sources.first { $0.id == targetID }?.origin == .added }

    func removeTarget() {
        guard canRemoveTarget else { return }
        addedPaths.removeAll { $0 == targetID }
        scan()
        targetID = automaticTarget
        load()
    }

    /// Back from Illustrator: a set saved there shows up without restarting.
    func reloadIfChanged() {
        let before = sources.map(\.id)
        scan()
        let slots = SystemShortcuts.enabledSlots()
        if slots != systemSlots { systemSlots = slots; rebuildKeyMap() }
        let current = [baselineID, targetID].compactMap { id in sources.first { $0.id == id } }
        let changed = current.contains { source in source.url.map { modified($0) != stamps[$0.path] } ?? false }
        if !sources.contains(where: { $0.id == baselineID }) { baselineID = KeySetSource.bundledID }
        if !sources.contains(where: { $0.id == targetID }) { targetID = automaticTarget }
        if changed || before != sources.map(\.id) { load() }
    }

    private func modified(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    private func read(_ id: String) -> KeySet? {
        guard let source = sources.first(where: { $0.id == id }) else { return nil }
        let url = source.url ?? Bundle.main.url(forResource: "IllustratorDefault", withExtension: "kys")
        do {
            guard let url else { throw KysError.notKeySet }
            if source.url != nil { stamps[url.path] = modified(url) }
            return try Kys.parse(Data(contentsOf: url))
        } catch {
            problem = String(format: L("error.cannotRead"), title(source))
            return nil
        }
    }

    private func load() {
        problem = ""
        note = ""
        guard let baseline = read(baselineID), let target = read(targetID) else {
            rows = []; baselineCount = 0; targetCount = 0
            refresh()
            return
        }
        baselineCount = baseline.assignedCount
        targetCount = target.assignedCount
        rows = Compare.rows(baseline: baseline, target: target, names: table.names, order: table.order, japanese: japanese)
        if sources.count == 1 { problem = L("note.noCustom") }
        else if active?.isPreset == true, targetID == KeySetSource.bundledID { problem = L("note.activeDefault") }
        refresh()
    }

    // MARK: List

    private func refresh() {
        counts = Dictionary(uniqueKeysWithValues: RowFilter.allCases.map { filter in (filter, rows.filter(filter.includes).count) })
        let present = Set(rows.map(\.group))
        groups = (Compare.groups + [Compare.unknownGroup]).filter(present.contains)
        if group != Self.allGroups && !present.contains(group) { group = Self.allGroups }
        refilter()
        rebuildKeyMap()
    }

    private func rebuildKeyMap() {
        if systemSlots.isEmpty { systemSlots = SystemShortcuts.enabledSlots() }
        let assignments = rows.compactMap { row -> (name: String, shortcut: Shortcut)? in
            (keyboardUsesBaseline ? row.baseline : row.target).map { (row.displayName, $0) }
        }
        keyMap = KeyMap(kind: keyboardKind, assignments: assignments, system: systemSlots)
    }

    var selectedKey: KeySpec? { keyMap.keys.first { $0.id == selectedKeyCode } }

    /// Free keys of the modifier set on screen, as text: ⌘A ⌘B …
    var freeKeysText: String {
        keyMap.freeKeys(keyboardModifiers).map { KeyboardLayout.modifierLabel(keyboardModifiers) + $0.label }.joined(separator: " ")
    }

    func copyFreeKeys() {
        let keys = keyMap.freeKeys(keyboardModifiers)
        copy(freeKeysText, count: keys.count)
    }

    private func refilter() {
        shown = rows
            .filter { filter.includes($0) && (group == Self.allGroups || $0.group == group) && Compare.matches($0, query: query) }
            .sorted(using: sortOrder + [KeyPathComparator(\Row.order)])
    }

    var selectedRows: [Row] { shown.filter { selection.contains($0.key) } }

    func statusText(_ status: DiffStatus) -> String {
        switch status {
        case .changed: return L("status.changed")
        case .added: return L("status.added")
        case .removed: return L("status.removed")
        case .unlisted: return L("status.unlisted")
        case .same: return L("status.same")
        case .unassigned: return L("status.unassigned")
        }
    }

    func groupText(_ group: String) -> String { L("group." + group) }

    // MARK: Output

    private func table(for rows: [Row]) -> [[String]] {
        Report.table(rows, labels: .init(status: L("column.status"), group: L("column.group"), command: L("column.command"),
                                         baseline: L("column.baseline"), target: L("column.target"), id: L("column.id"), conflict: L("column.conflict")),
                     contextMark: L("context.mark"), statusText: statusText, groupText: groupText)
    }

    func tsv(for rows: [Row]) -> String { Report.tsv(table(for: rows)) }

    func copy(_ text: String, count: Int) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        note = String(format: L("note.copied"), count)
    }

    func copyTable() { copy(tsv(for: shown), count: shown.count) }

    func export(_ format: ExportFormat) {
        let panel = NSSavePanel()
        let name = sources.first { $0.id == targetID }?.name ?? ""
        panel.nameFieldStringValue = "Illustrator-shortcuts" + (name.isEmpty ? "" : "-" + name) + "." + format.fileExtension
        panel.allowedContentTypes = [UTType(filenameExtension: format.fileExtension) ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let rows = table(for: shown)
        // The BOM lets Excel read the file as UTF-8.
        let text = format == .csv ? "\u{FEFF}" + Report.csv(rows) : Report.markdown(rows)
        do {
            try Data(text.utf8).write(to: url, options: .atomic)
            note = String(format: L("note.exported"), url.lastPathComponent, shown.count)
        } catch {
            note = String(format: L("note.exportFailed"), error.localizedDescription)
        }
    }
}
