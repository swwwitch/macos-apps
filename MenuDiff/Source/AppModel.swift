import AppKit
import SwiftUI

/// 比較の相手として選べるもの（インストール済みのバージョン、または保存済みのスナップショットだけのもの）
struct MenuSource: Identifiable, Hashable {
    let name: String
    var install: AppInstall?
    var id: String { name }

    var title: String {
        guard let install else { return name }
        return LF("source.title", install.displayName, install.version)
    }
}

enum ResultCategory: String, CaseIterable, Identifiable {
    case added, removed, renamed, moved, shortcuts
    var id: String { rawValue }
    var title: String { L("category." + rawValue) }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var sources: [MenuSource] = []
    @Published var product = AdobeApp(rawValue: UserDefaults.standard.string(forKey: "product") ?? "") ?? .illustrator {
        didSet {
            UserDefaults.standard.set(product.rawValue, forKey: "product")
            oldName = UserDefaults.standard.string(forKey: Self.key("oldName", product)) ?? ""
            newName = UserDefaults.standard.string(forKey: Self.key("newName", product)) ?? ""
            diff = nil
            compared = nil
            errorText = ""
            status = ""
            refresh()
        }
    }
    @Published var oldName = "" {
        didSet { UserDefaults.standard.set(oldName, forKey: Self.key("oldName", product)) }
    }
    @Published var newName = "" {
        didSet { UserDefaults.standard.set(newName, forKey: Self.key("newName", product)) }
    }
    @Published var status = ""
    @Published var errorText = ""
    @Published var isWorking = false
    @Published var trusted = AXIsProcessTrusted()
    @Published var diff: MenuDiff?
    @Published var comparedTitle = ""
    @Published var category: ResultCategory = .added
    @Published var query = ""
    /// 表示を更新するための目印（起動・終了・保存のたび）
    @Published var stateStamp = 0
    /// 比較の選択（読み直さずに結果だけ作り直す）
    @Published var ignoresShortcuts = UserDefaults.standard.bool(forKey: "ignoresShortcuts") {
        didSet { UserDefaults.standard.set(ignoresShortcuts, forKey: "ignoresShortcuts"); rebuildDiff() }
    }
    @Published var excludesPlugins = UserDefaults.standard.bool(forKey: "excludesPlugins") {
        didSet { UserDefaults.standard.set(excludesPlugins, forKey: "excludesPlugins"); rebuildDiff() }
    }
    @Published var pluginNote = ""
    private var compared: (old: MenuSnapshot, new: MenuSnapshot)?

    var visibleCategories: [ResultCategory] {
        ignoresShortcuts ? ResultCategory.allCases.filter { $0 != .shortcuts } : ResultCategory.allCases
    }

    private var observers: [NSObjectProtocol] = []

    /// 選択はアプリごとに覚える（Illustrator は 1.0.0 からのキーをそのまま使う）
    static func key(_ base: String, _ app: AdobeApp) -> String {
        app == .illustrator ? base : "\(base).\(app.rawValue)"
    }

    init() {
        oldName = UserDefaults.standard.string(forKey: Self.key("oldName", product)) ?? ""
        newName = UserDefaults.standard.string(forKey: Self.key("newName", product)) ?? ""
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.stateStamp += 1 }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.trusted = AXIsProcessTrusted() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: SnapshotStore.folderChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.excludesPlugins else { return }
                let names = PluginFilter.keywords
                if names != self.lastKeywords { self.rebuildDiff() }
            }
        })
    }

    func refresh() {
        let installs = AppInstall.discover(product)
        var list = installs.map { MenuSource(name: $0.snapshotName, install: $0) }
        let installedNames = Set(list.map(\.name))
        for name in SnapshotStore.names(for: product) where !installedNames.contains(name) {
            list.append(MenuSource(name: name, install: nil))
        }
        list.sort { $0.name.compare($1.name, options: .numeric) == .orderedDescending }
        sources = list
        // 既定：新＝Beta・Prerelease 以外で最も新しいもの、旧＝それより古いリリース版で最も新しいもの
        let names = list.map(\.name)
        if !names.contains(newName) {
            newName = list.first { $0.install != nil && $0.install?.channel == "" }?.name ?? names.first ?? ""
        }
        if !names.contains(oldName) {
            let newVersion = source(named: newName)?.install?.version ?? ""
            let releases = list.filter { $0.install?.channel == "" }
            oldName = releases.first { ($0.install?.version ?? "").compare(newVersion, options: .numeric) == .orderedAscending }?.name
                ?? names.first { $0 != newName } ?? ""
        }
        stateStamp += 1
    }

    func source(named name: String) -> MenuSource? { sources.first { $0.name == name } }

    func stateText(for source: MenuSource) -> String {
        _ = stateStamp
        var parts: [String] = []
        let running = source.install?.runningApplication != nil
        if running { parts.append(L("state.running")) }
        if let snapshot = SnapshotStore.load(source.name) {
            parts.append(LF("state.saved", snapshot.date))
        } else if !running {
            parts.append(L("state.notRead"))
        }
        if source.install == nil { parts.append(L("state.noApp")) }
        return parts.joined(separator: L("state.separator"))
    }

    func openAccessibilitySettings() {
        _ = AccessibilitySettingsLocator.shared.open()
    }

    /// 起動中なら読み直す。起動していなければ保存済みを使い、無ければ起動して読む（forceRead で常に読む）
    func snapshot(for source: MenuSource, forceRead: Bool) async throws -> MenuSnapshot {
        if let install = source.install, forceRead || install.runningApplication != nil || SnapshotStore.load(source.name) == nil {
            let snapshot = try await MenuReader.capture(install) { message in
                Task { @MainActor in self.status = message }
            }
            try SnapshotStore.save(snapshot)
            stateStamp += 1
            return snapshot
        }
        if let saved = SnapshotStore.load(source.name) { return saved }
        throw MenuReaderError.nothingToRead(source.name)
    }

    var canCompare: Bool { !isWorking && !oldName.isEmpty && !newName.isEmpty && oldName != newName }

    func compare() {
        guard canCompare, let oldSource = source(named: oldName), let newSource = source(named: newName) else { return }
        run {
            let oldSnapshot = try await self.snapshot(for: oldSource, forceRead: false)
            let newSnapshot = try await self.snapshot(for: newSource, forceRead: false)
            self.compared = (oldSnapshot, newSnapshot)
            self.rebuildDiff()
            if oldSnapshot.locale != newSnapshot.locale {
                self.errorText = LF("warning.localeMismatch", oldSnapshot.locale, newSnapshot.locale)
            }
            if let diff = self.diff, self.count(of: self.category, in: diff) == 0,
               let first = self.visibleCategories.first(where: { self.count(of: $0, in: diff) > 0 }) {
                self.category = first
            }
            self.status = ""
        }
    }

    private var lastKeywords: [String] = []

    /// 選択（ショートカット・プラグイン）に合わせて結果を作り直す。読み直しはしない
    func rebuildDiff() {
        if ignoresShortcuts && category == .shortcuts { category = .added }
        guard let compared else { return }
        var old = compared.old, new = compared.new
        pluginNote = ""
        if excludesPlugins {
            lastKeywords = PluginFilter.keywords
            let names = PluginFilter.names(for: [old, new], keywords: lastKeywords)
            let before = old.entries.count + new.entries.count
            old = PluginFilter.removingPlugins(from: old, names: names)
            new = PluginFilter.removingPlugins(from: new, names: names)
            let removed = before - old.entries.count - new.entries.count
            if removed > 0 { pluginNote = LF("note.pluginsExcluded", removed) }
        }
        diff = MenuDiff(old: old, new: new)
        comparedTitle = LF("compared.title", old.name, old.entries.count, new.name, new.entries.count)
    }

    func reread(_ name: String) {
        guard let source = source(named: name) else { return }
        run {
            let snapshot = try await self.snapshot(for: source, forceRead: true)
            self.status = LF("status.reread", snapshot.name, snapshot.entries.count)
        }
    }

    func swapSelection() { swap(&oldName, &newName) }

    private func run(_ work: @escaping @MainActor () async throws -> Void) {
        isWorking = true
        errorText = ""
        Task { @MainActor in
            defer { isWorking = false }
            do {
                try await work()
            } catch {
                status = ""
                errorText = error.localizedDescription
                trusted = AXIsProcessTrusted()
            }
        }
    }

    func count(of category: ResultCategory, in diff: MenuDiff) -> Int {
        switch category {
        case .added: return diff.added.count
        case .removed: return diff.removed.count
        case .renamed: return diff.renamed.count
        case .moved: return diff.moved.count
        case .shortcuts: return diff.shortcutChanges.count
        }
    }

    /// いま表示している一覧（絞り込み後）
    func rows(for category: ResultCategory, in diff: MenuDiff) -> [ResultRow] {
        let all: [ResultRow]
        switch category {
        case .added: all = diff.added.map { ResultRow(path: $0) }
        case .removed: all = diff.removed.map { ResultRow(path: $0) }
        case .renamed: all = diff.renamed.map { ResultRow(path: $0.new, oldPath: $0.old) }
        case .moved: all = diff.moved.map { ResultRow(path: $0.new, oldPath: $0.old) }
        case .shortcuts: all = diff.shortcutChanges.map { ResultRow(path: $0.path, oldShortcut: $0.old, newShortcut: $0.new) }
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.path.localizedCaseInsensitiveContains(trimmed) || ($0.oldPath ?? "").localizedCaseInsensitiveContains(trimmed) }
    }

    var shownRows: [ResultRow] {
        guard let diff else { return [] }
        return rows(for: category, in: diff)
    }

    func copyShownRows() {
        let rows = shownRows
        guard !rows.isEmpty else { NSSound.beep(); return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(rows.map(\.plainText).joined(separator: "\n"), forType: .string)
        status = LF("status.copied", rows.count)
    }

    func openSnapshotFolder() {
        try? FileManager.default.createDirectory(at: SnapshotStore.folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(SnapshotStore.folder)
    }
}

struct ResultRow: Identifiable, Hashable {
    let path: String
    var oldPath: String?
    var oldShortcut: String?
    var newShortcut: String?
    var id: String { (oldPath ?? "") + "\u{1}" + path }

    var plainText: String {
        if let oldPath { return "\(oldPath)\t\(path)" }
        if let oldShortcut, let newShortcut { return "\(path)\t\(oldShortcut)\t\(newShortcut)" }
        return path
    }
}
