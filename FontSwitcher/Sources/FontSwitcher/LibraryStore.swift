import AppKit
import CoreText
import SwiftUI

/// サイドバーで選ぶ一覧の絞り込み
enum SidebarItem: Hashable {
    case all, favorites, active, inactive, duplicates, missing
    case folder(SystemFolder)
    case kind(FontKind)
    case vendor(String)
    case collection(String)
    case set(UUID)
}

/// ライブラリの保存・取り込み・アクティブの切り替え。画面とメニューから共有する
@MainActor
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    static let restoreAtLaunchKey = "restoreActiveFontsAtLaunch"
    static let deactivateOnQuitKey = "deactivateFontsOnQuit"
    static let sampleTextKey = "previewSampleText"
    static let includeUserFontsKey = "includeUserFontsFolder"
    /// 共有ライブラリを置くフォルダー（Macごと）
    static let sharedFolderKey = "sharedLibraryFolder"
    static let sharedFileName = "FontSwitcher-Library.json"
    /// サイドバーの「ベンダー」。OS/2 のベンダーIDで見分ける
    static let vendors: [(id: String, title: String)] = [("MRSW", L("モリサワ")), ("FWKS", L("フォントワークス")), ("ADBE", L("アドビ"))]
    static let defaultSampleText = "あいうえお 永遠の文字 Aa Bb Cc 0123456789"
    /// 設定の共有で書き出す・同期するキー。ライブラリ（ファイルの場所）はMacごと
    static let syncedKeys: Set<String> = Set([restoreAtLaunchKey, deactivateOnQuitKey, sampleTextKey, includeUserFontsKey, NameDisplay.key]
        + SidebarSection.allCases.map(\.showKey))

    @Published private(set) var data = LibraryData() { didSet { invalidate() } }
    @Published private(set) var states: [UUID: FontState] = [:] { didSet { invalidate() } }
    @Published var sidebar: SidebarItem = .all { didSet { shownCache = nil; listVersion += 1 } }
    @Published var selection = Set<String>()
    @Published var searchText = "" { didSet { shownCache = nil; listVersion += 1 } }
    /// 絞り込み：文字セット（"—" は文字セットの名前が無いもの）と名前の先頭。nil は絞り込まない
    @Published var charsetFilter: String? { didSet { shownCache = nil; listVersion += 1 } }
    @Published var prefixFilter: String? { didSet { shownCache = nil; listVersion += 1 } }
    static let noCharset = "—"
    /// 一覧の中身（行・チェック・お気に入り）が変わるたびに進む。一覧はこれが変わったときだけ読み直す
    @Published private(set) var listVersion = 0
    @Published private(set) var isBusy = false
    /// 最後の操作の結果。ウインドウ下の状態欄に出す
    @Published var status = ""
    @Published var message: (title: String, body: String)?
    /// 共有ライブラリのフォルダー。nil ならこのMacだけのライブラリ
    @Published private(set) var sharedFolder: String?
    /// Font Book・フォントパネルのコレクション（~/Library/FontCollections）。前面に戻ったときに読み直す
    @Published private(set) var collectionNames: [String] = []
    /// コレクションの中身：PostScript名とファミリー名（Font Book はファミリーごとに入れることがある）
    private var collectionQueries: [String: (names: Set<String>, families: Set<String>)] = [:]

    private let localURL: URL
    private var refreshTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var folderWatcher: DispatchSourceFileSystemObject?
    /// 最後に読み書きしたときの共有ファイルの更新日時。自分の書き込みで読み直さないため
    private var knownModification: Date?
    private var userFontsScan: DispatchWorkItem?

    // 一覧・件数は数千件を数え直すので、元が変わるまで控えておく（画面の描き直しのたびに計算しない）
    private var shownCache: [FontFamily]?
    private var countCache: [SidebarItem: Int] = [:]
    private var duplicateCache: Set<UUID>?
    private var familyCountCache: Int?
    private var filterCache: (charsets: [(String, Int)], prefixes: [(String, Int)])?

    /// ライブラリ・状態・表示の設定が変わったときに控えを捨てる
    func invalidate() {
        listVersion += 1
        shownCache = nil
        countCache = [:]
        duplicateCache = nil
        familyCountCache = nil
        filterCache = nil
    }

    private var libraryURL: URL {
        guard let sharedFolder else { return localURL }
        return URL(fileURLWithPath: sharedFolder).appendingPathComponent(Self.sharedFileName)
    }

    private init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FontSwitcher", isDirectory: true)
        localURL = folder.appendingPathComponent("Library.json")
        UserDefaults.standard.register(defaults: [Self.restoreAtLaunchKey: true, Self.deactivateOnQuitKey: false,
                                                  Self.sampleTextKey: Self.defaultSampleText, Self.includeUserFontsKey: true])
        UserDefaults.standard.register(defaults: Self.sidebarDefaults)
        sharedFolder = UserDefaults.standard.string(forKey: Self.sharedFolderKey)
        if let sharedFolder, !FileManager.default.fileExists(atPath: sharedFolder) {
            // Dropbox が止まっているなどで見えないときは、このMacのライブラリで開く（設定は残す）
            self.sharedFolder = nil
            message = (L("共有フォルダーが見つかりません"), L("%@ が見つからないため、このMacのライブラリを開きました。", sharedFolder))
        }
        load()
        watchSharedFolder()
        // ほかのアプリ（Font Bookなど）がフォントを入れ替えたときも表示を合わせる。~/Library/Fonts に足されたものも拾う
        observers.append(NotificationCenter.default.addObserver(
            forName: kCTFontManagerRegisteredFontsChangedNotification as NSNotification.Name, object: nil, queue: .main
        ) { _ in Task { @MainActor in LibraryStore.shared.scheduleFontsChanged() } })
        // 前面に戻ったときも、ほかのMacの変更を確かめる（フォルダーの監視の取りこぼしに備える）
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in Task { @MainActor in
            LibraryStore.shared.reloadIfSharedChanged()
            LibraryStore.shared.reloadCollections()
        } })
        reloadCollections()
    }

    // MARK: 表示

    var includeUserFonts: Bool { UserDefaults.standard.bool(forKey: Self.includeUserFontsKey) }

    /// フォントフォルダー（username・All Users・System）のファイルかどうか
    static func isInstalled(_ file: FontFile) -> Bool { SystemFolder.of(file.path) != nil }

    /// System・Adobe Fonts のフォントは切り替えない・取り除かない
    static func isLocked(_ file: FontFile) -> Bool { SystemFolder.of(file.path).map { !$0.isEditable } ?? false }

    /// 切り替えられない理由（一覧のチェックボックスと失敗の一覧に出す）
    static func lockedReason(_ file: FontFile) -> String {
        SystemFolder.of(file.path) == .adobeFonts ? L("Adobe Fontsのフォントは、Creative Cloudで切り替えます")
            : L("System のフォントは切り替えられません")
    }

    /// 設定でフォントフォルダーを外したときは、そのフォントを一覧に出さない（ライブラリからは消さない）
    var visibleFiles: [FontFile] {
        includeUserFonts ? data.files : data.files.filter { !Self.isInstalled($0) }
    }

    func files(in item: SidebarItem) -> [FontFile] {
        let base = visibleFiles
        switch item {
        case .all: return base
        case .favorites: return base.filter { data.favorites.contains($0.family) }
        case .active: return base.filter { states[$0.id] == .active }
        case .inactive: return base.filter { states[$0.id] == .inactive }
        case .duplicates:
            let ids = duplicateIDs
            return base.filter { ids.contains($0.id) }
        case .missing: return base.filter { states[$0.id] == .missing }
        case .folder(let folder): return base.filter { SystemFolder.of($0.path) == folder }
        case .kind(.variable): return base.filter { $0.isVariable == true }
        case .kind(.color): return base.filter { $0.isColor == true }
        case .vendor(let id): return base.filter { $0.vendor == id }
        case .collection(let name):
            let query = collectionQuery(name)
            return base.filter { file in
                file.faces.contains { query.names.contains($0.postScriptName) || query.families.contains($0.family) }
            }
        case .set(let id):
            let ids = Set(data.sets.first { $0.id == id }?.files ?? [])
            return base.filter { ids.contains($0.id) }
        }
    }

    var shownFiles: [FontFile] {
        var files = files(in: sidebar)
        if let charsetFilter {
            files = files.filter { (FontNaming.charset($0.family) ?? Self.noCharset) == charsetFilter }
        }
        if let prefixFilter {
            files = files.filter { FontNaming.prefix($0.family) == prefixFilter }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return files }
        return files.filter { file in
            file.fileName.localizedCaseInsensitiveContains(query)
                || file.faces.contains { $0.family.localizedCaseInsensitiveContains(query)
                    || ($0.localizedFamily ?? "").localizedCaseInsensitiveContains(query)
                    || $0.postScriptName.localizedCaseInsensitiveContains(query)
                    || $0.fullName.localizedCaseInsensitiveContains(query) }
        }
    }

    var shownFamilies: [FontFamily] {
        if let shownCache { return shownCache }
        let families = data.families(of: shownFiles)
        shownCache = families
        return families
    }

    private var duplicateIDs: Set<UUID> {
        if let duplicateCache { return duplicateCache }
        let ids = data.duplicateFileIDs
        duplicateCache = ids
        return ids
    }

    /// 絞り込みの選択肢（ファミリー数つき）。文字セットは決まった順、名前の先頭は5ファミリー以上のものを多い順
    var filterOptions: (charsets: [(String, Int)], prefixes: [(String, Int)]) {
        if let filterCache { return filterCache }
        let families = Set(visibleFiles.map(\.family))
        var charsets: [String: Int] = [:]
        var prefixes: [String: Int] = [:]
        for family in families {
            charsets[FontNaming.charset(family) ?? Self.noCharset, default: 0] += 1
            prefixes[FontNaming.prefix(family), default: 0] += 1
        }
        let options = (
            charsets: (FontNaming.charsets + [Self.noCharset]).compactMap { name in charsets[name].map { (name, $0) } },
            prefixes: prefixes.filter { $0.value >= 5 }.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                .map { ($0.key, $0.value) })
        filterCache = options
        return options
    }

    /// 表示しているファイル全体のファミリー数（ウインドウ下の要約）
    var familyCount: Int {
        if let familyCountCache { return familyCountCache }
        let count = Set(visibleFiles.map(\.family)).count
        familyCountCache = count
        return count
    }

    /// 一覧で選んだファミリー・書体のファイル（表示中の絞り込みの範囲）
    var selectedFiles: [FontFile] { files(for: selection) }

    /// 一覧の行の id から実際のファイルへ。ファミリーの行は中のファイルすべて、書体の行はそのファイル
    func files(for ids: Set<String>) -> [FontFile] {
        var result: [FontFile] = []
        var seen = Set<UUID>()
        for family in shownFamilies {
            let whole = ids.contains(family.id)
            for file in family.files where (whole || ids.contains(FamilyNode.fileID(file))) && seen.insert(file.id).inserted {
                result.append(file)
            }
        }
        return result
    }

    /// 選んだ行が属するファミリー。プレビューは1つに絞れたときだけ出す
    var selectedFamilies: [FontFamily] {
        shownFamilies.filter { family in
            selection.contains(family.id) || family.files.contains { selection.contains(FamilyNode.fileID($0)) }
        }
    }

    /// 書体（ファイル）1つがアクティブかどうか
    func isActive(_ file: FontFile) -> Bool { states[file.id] == .active }

    func count(_ item: SidebarItem) -> Int {
        if let cached = countCache[item] { return cached }
        let count = files(in: item).count
        countCache[item] = count
        return count
    }

    /// ファミリーの状態：すべてアクティブ／一部／なし
    func familyState(_ family: FontFamily) -> Bool? {
        let active = family.files.filter { states[$0.id] == .active }.count
        if active == 0 { return false }
        return active == family.files.count ? true : nil
    }

    // MARK: 取り込み

    func showAddPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = L("フォントファイルか、フォントの入ったフォルダーを選びます")
        panel.prompt = L("追加")
        guard panel.runModal() == .OK else { return }
        add(panel.urls)
    }

    func add(_ urls: [URL]) {
        guard !isBusy, !urls.isEmpty else { return }
        isBusy = true
        status = L("フォントを読み込み中…")
        Task.detached(priority: .userInitiated) {
            let found = FontScanner.fontURLs(in: urls)
            var read: [FontFile] = []
            var unreadable = 0
            for url in found {
                if let file = FontScanner.read(url) { read.append(file) } else { unreadable += 1 }
            }
            let files = read
            let skipped = unreadable
            await MainActor.run {
                let store = LibraryStore.shared
                let added = store.data.add(files)
                store.save()
                store.isBusy = false
                var parts = [L("%d個のファイルを追加しました", added)]
                if files.count > added { parts.append(L("登録済み %d", files.count - added)) }
                if skipped > 0 { parts.append(L("読めないファイル %d", skipped)) }
                store.status = parts.joined(separator: L("、"))
                if found.isEmpty {
                    store.message = (L("フォントが見つかりません"), L("選んだ場所にフォントファイル（.otf・.ttf・.ttc など）がありません。"))
                }
                store.refreshStates()
            }
        }
    }

    /// ライブラリから外す。アクティブにしていたものは先に解除する。ファイルは消さない
    func remove(_ files: [FontFile]) {
        // フォントフォルダーのフォントは次の読み込みでまた入るので、ライブラリから取り除かない
        let installed = files.filter(Self.isInstalled)
        let files = files.filter { !Self.isInstalled($0) }
        if !installed.isEmpty {
            status = L("フォントフォルダー（%@）のフォントは取り除けません", SystemFolder.allCases.map(\.title).joined(separator: L("、")))
        }
        guard !files.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = L("%d個のファイルをライブラリから取り除きますか？", files.count)
        alert.informativeText = L("アクティブなものは解除します。フォントファイルは削除しません。")
        alert.addButton(withTitle: L("取り除く"))
        alert.addButton(withTitle: L("キャンセル")).keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        for file in files where data.active.contains(file.id) { _ = FontActivation.deactivate(file) }
        data.remove(Set(files.map(\.id)))
        selection.removeAll()
        save()
        status = L("%d個のファイルを取り除きました", files.count)
        refreshStates()
    }

    // MARK: アクティブ

    func setActive(_ files: [FontFile], _ on: Bool) {
        guard !files.isEmpty else { return }
        var failures: [String] = []
        var changed = 0
        for file in files {
            if Self.isLocked(file) {
                failures.append("\(file.fileName) — \(Self.lockedReason(file))")
                continue
            }
            // フォントフォルダーのフォントは、macOS に覚えさせる（.persistent）。ライブラリのアクティブには数えない
            let installed = Self.isInstalled(file)
            let scope: CTFontManagerScope = installed ? .persistent : .session
            let error = on ? FontActivation.activate(file, scope: scope) : FontActivation.deactivate(file, scope: scope)
            if let error {
                failures.append("\(file.fileName) — \(error)")
                continue
            }
            // 同じPostScript名がほかで使われていると、登録は通っても先のほうが使われる。紛らわしいので戻して失敗にする
            if on, case .conflict = FontActivation.state(of: file) {
                _ = FontActivation.deactivate(file, scope: scope)
                failures.append("\(file.fileName) — \(L("同じ名前のフォントがすでに使われています"))")
                continue
            }
            changed += 1
            if installed { continue }
            if on { data.active.insert(file.id) } else { data.active.remove(file.id) }
        }
        save()
        refreshStates()
        status = on ? L("%d個のファイルをアクティブにしました", changed) : L("%d個のファイルを解除しました", changed)
        if !failures.isEmpty {
            status += L("、失敗 %d", failures.count)
            message = (on ? L("アクティブにできなかったファイルがあります") : L("解除できなかったファイルがあります"),
                       failures.prefix(20).joined(separator: "\n") + (failures.count > 20 ? "\n…" : ""))
        }
    }

    func isFavorite(_ family: FontFamily) -> Bool { data.favorites.contains(family.name) }

    /// 選んだものが1つでもお気に入りでなければ全部をお気に入りに、全部お気に入りなら外す
    func toggleFavorite(_ families: [FontFamily]) {
        guard !families.isEmpty else { return }
        let names = Set(families.map(\.name))
        if names.isSubset(of: data.favorites) { data.favorites.subtract(names) } else { data.favorites.formUnion(names) }
        save()
    }

    func toggle(_ family: FontFamily) {
        setActive(family.files, familyState(family) != true)
    }

    /// 起動時に、前回アクティブにしていたフォントを戻す（ログアウトすると解除されるため）
    func restoreActiveFonts() {
        guard UserDefaults.standard.bool(forKey: Self.restoreAtLaunchKey) else { return }
        let files = data.files.filter { data.active.contains($0.id) && !Self.isInstalled($0) }
        var missing = 0
        for file in files {
            if !FileManager.default.fileExists(atPath: file.path) { missing += 1; continue }
            _ = FontActivation.activate(file)
        }
        if !files.isEmpty {
            status = L("前回アクティブだった%d個のファイルを戻しました", files.count - missing)
            if missing > 0 { status += L("、見つからない %d", missing) }
        }
        refreshStates()
    }

    func deactivateAllOnQuit() {
        guard UserDefaults.standard.bool(forKey: Self.deactivateOnQuitKey) else { return }
        for file in data.files where data.active.contains(file.id) && !Self.isInstalled(file) { _ = FontActivation.deactivate(file) }
    }

    // MARK: セット

    func newSet(with files: [FontFile] = []) {
        guard let name = askName(title: L("新規セット"), initial: L("名称未設定セット")) else { return }
        let set = FontSet(name: name, files: files.map(\.id))
        data.sets.append(set)
        save()
        sidebar = .set(set.id)
    }

    func renameSet(_ id: UUID) {
        guard let index = data.sets.firstIndex(where: { $0.id == id }),
              let name = askName(title: L("セットの名前を変更"), initial: data.sets[index].name) else { return }
        data.sets[index].name = name
        save()
    }

    func deleteSet(_ id: UUID) {
        guard let set = data.sets.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = L("セット「%@」を削除しますか？", set.name)
        alert.informativeText = L("ライブラリのフォントとアクティブの状態はそのままです。")
        alert.addButton(withTitle: L("削除"))
        alert.addButton(withTitle: L("キャンセル")).keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        data.sets.removeAll { $0.id == id }
        if sidebar == .set(id) { sidebar = .all }
        save()
    }

    func addToSet(_ id: UUID, _ files: [FontFile]) {
        guard let index = data.sets.firstIndex(where: { $0.id == id }) else { return }
        let known = Set(data.sets[index].files)
        data.sets[index].files += files.map(\.id).filter { !known.contains($0) }
        save()
    }

    func removeFromSet(_ id: UUID, _ files: [FontFile]) {
        guard let index = data.sets.firstIndex(where: { $0.id == id }) else { return }
        let ids = Set(files.map(\.id))
        data.sets[index].files.removeAll { ids.contains($0) }
        selection.removeAll()
        save()
    }

    func setFiles(_ id: UUID) -> [FontFile] {
        let ids = Set(data.sets.first { $0.id == id }?.files ?? [])
        return data.files.filter { ids.contains($0.id) }
    }

    private func askName(title: String, initial: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        let field = NSTextField(string: initial)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: L("OK"))
        alert.addButton(withTitle: L("キャンセル")).keyEquivalent = "\u{1b}"
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    // MARK: サイドバーの表示

    /// サイドバーに出す区分（設定の「表示」）。ライブラリは常に出す
    enum SidebarSection: String, CaseIterable {
        case system, kinds, vendors, collections, sets
        var showKey: String { "sidebarShow." + rawValue }
        var expandedKey: String { "sidebarExpanded." + rawValue }
        /// コレクションは多くなりがちなので、初めは閉じておく
        var expandedByDefault: Bool { self != .collections }
    }

    static var sidebarDefaults: [String: Any] {
        var values: [String: Any] = ["sidebarExpanded.library": true]
        for section in SidebarSection.allCases {
            values[section.showKey] = true
            values[section.expandedKey] = section.expandedByDefault
        }
        return values
    }

    /// 隠した区分の項目を選んでいたら「すべてのフォント」に戻す
    func ensureSidebarVisible() {
        let defaults = UserDefaults.standard
        let section: SidebarSection?
        switch sidebar {
        case .folder: section = .system
        case .kind: section = .kinds
        case .vendor: section = .vendors
        case .collection: section = .collections
        case .set: section = .sets
        default: section = nil
        }
        if let section, !defaults.bool(forKey: section.showKey) { sidebar = .all }
    }

    // MARK: コレクション（~/Library/FontCollections）

    /// Font Book やフォントパネルのコレクション。com.apple で始まる内部のもの（最近使ったフォントなど）は除く
    func reloadCollections() {
        let names = NSFontCollection.allFontCollectionNames.map(\.rawValue)
            .filter { !$0.hasPrefix("com.apple") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        collectionQueries = [:]
        if names != collectionNames { collectionNames = names }
        // 中身が変わっていることもあるので、件数と一覧は数え直す
        if case .collection = sidebar { shownCache = nil }
        invalidate()
        if case .collection(let name) = sidebar, !names.contains(name) { sidebar = .all }
    }

    private func collectionQuery(_ name: String) -> (names: Set<String>, families: Set<String>) {
        if let cached = collectionQueries[name] { return cached }
        let descriptors = NSFontCollection(name: NSFontCollection.Name(rawValue: name), visibility: .user)?.queryDescriptors
            ?? NSFontCollection(name: NSFontCollection.Name(rawValue: name), visibility: .computer)?.queryDescriptors ?? []
        var query: (names: Set<String>, families: Set<String>) = ([], [])
        for descriptor in descriptors {
            if let name = descriptor.fontAttributes[.name] as? String { query.names.insert(name) }
            else if let family = descriptor.fontAttributes[.family] as? String { query.families.insert(family) }
        }
        collectionQueries[name] = query
        return query
    }

    /// コレクションにPostScript名で加える。アクティブでないフォントも名前で入り、アクティブにすると現れる
    func addToCollection(_ name: String?, _ files: [FontFile]) {
        guard !files.isEmpty else { return }
        guard let name = name ?? askName(title: L("新規コレクション"), initial: L("名称未設定コレクション")) else { return }
        let collectionName = NSFontCollection.Name(rawValue: name)
        let collection = (NSFontCollection(name: collectionName, visibility: .user)?.mutableCopy() as? NSMutableFontCollection)
            ?? NSMutableFontCollection(descriptors: [])
        let existing = Set((collection.queryDescriptors ?? []).compactMap { $0.fontAttributes[.name] as? String })
        let names = files.flatMap { $0.faces.map(\.postScriptName) }
        var seen = existing
        let descriptors = names.filter { seen.insert($0).inserted }.map { NSFontDescriptor(fontAttributes: [.name: $0]) }
        if !descriptors.isEmpty { collection.addQuery(for: descriptors) }
        do {
            try NSFontCollection.show(collection, withName: collectionName, visibility: .user)
            status = L("コレクション「%@」に%d書体を追加しました", name, descriptors.count)
            reloadCollections()
        } catch {
            message = (L("コレクションに追加できませんでした"), error.localizedDescription)
        }
    }

    // MARK: 状態と保存

    /// ファイルごとの状態を読み直す。数千件でも画面を止めないよう裏で調べる
    func refreshStates() {
        refreshTask?.cancel()
        let files = data.files
        refreshTask = Task.detached(priority: .userInitiated) {
            var result: [UUID: FontState] = [:]
            for file in files {
                if Task.isCancelled { return }
                // System のフォントは常に使える。内部用の名前などで引き当てが外れることがあるので、調べずにアクティブとする
                result[file.id] = SystemFolder.of(file.path) == .system ? .active : FontActivation.state(of: file)
            }
            let states = result
            await MainActor.run { LibraryStore.shared.states = states }
        }
    }

    func revealInFinder(_ files: [FontFile]) {
        NSWorkspace.shared.activateFileViewerSelecting(files.map(\.url))
    }

    private func load() {
        guard let loaded = read(libraryURL) else { return }
        data = loaded
        knownModification = modification(of: libraryURL)
    }

    /// ファイルを読み、場所の目印をこのMacの場所に戻す。読めないファイルは上書きされないよう控える
    private func read(_ url: URL) -> LibraryData? {
        guard let bytes = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(LibraryData.self, from: bytes).mapPaths { PortablePath.decode($0) }
        } catch {
            let backup = url.deletingPathExtension().appendingPathExtension("unreadable.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: url, to: backup)
            message = (L("ライブラリを読み込めませんでした"), L("元のファイルを %@ に残しました。", backup.path))
            return nil
        }
    }

    private func save() {
        write(data, to: libraryURL)
        knownModification = modification(of: libraryURL)
    }

    private func write(_ library: LibraryData, to url: URL) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(library.mapPaths { PortablePath.encode($0) }).write(to: url, options: .atomic)
        } catch {
            message = (L("ライブラリを保存できませんでした"), error.localizedDescription)
        }
    }

    private func modification(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    // MARK: ベンダー

    /// 古い版で登録したファイルには、ベンダーID・日本語の表示名・種類（バリアブル・カラー）が無い。裏で読み直して足す（7,953件で数秒、1回だけ）
    func fillMetadata() {
        let missing = data.files.filter {
            ($0.vendor == nil || $0.isVariable == nil || $0.faces.contains { $0.localizedFamily == nil }) && FileManager.default.fileExists(atPath: $0.path)
        }
        guard !missing.isEmpty else { return }
        Task.detached(priority: .utility) {
            var found: [UUID: FontFile] = [:]
            for file in missing {
                if let fresh = FontScanner.read(file.url) { found[file.id] = fresh }
            }
            let result = found
            await MainActor.run {
                let store = LibraryStore.shared
                var data = store.data
                for index in data.files.indices {
                    guard let fresh = result[data.files[index].id] else { continue }
                    data.files[index].vendor = fresh.vendor
                    data.files[index].isVariable = fresh.isVariable
                    data.files[index].isColor = fresh.isColor
                    for face in data.files[index].faces.indices {
                        let name = data.files[index].faces[face].postScriptName
                        let match = fresh.faces.first { $0.postScriptName == name }
                        data.files[index].faces[face].localizedFamily = match?.localizedFamily ?? ""
                        data.files[index].faces[face].localizedStyle = match?.localizedStyle ?? ""
                    }
                }
                store.data = data
                store.save()
            }
        }
    }

    // MARK: フォントフォルダー

    /// フォントの変更の通知は続けて届く（登録1つで数回）。落ち着いてから状態とフォルダーを1回だけ読み直す。
    /// 読み直しのたびに前の読み直しを取り消していたため、起動直後は状態がそろうまで約10秒かかっていた
    func scheduleFontsChanged() {
        userFontsScan?.cancel()
        let work = DispatchWorkItem { Task { @MainActor in
            LibraryStore.shared.refreshStates()
            LibraryStore.shared.scanUserFonts()
        } }
        userFontsScan = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// フォントフォルダー（username・All Users・System）の中身に一覧を合わせる。
    /// 新しいファイルだけを読んで足し、フォルダーから消えたファイルと、macOS の内部用のフォントは一覧から外す
    func scanUserFonts() {
        guard includeUserFonts else { return }
        let known = Set(data.files.map(\.path))
        let folders = SystemFolder.allCases.filter { !$0.includesHiddenFiles }.map { URL(fileURLWithPath: $0.path) }
        let hiddenFolders = SystemFolder.allCases.filter(\.includesHiddenFiles).map { URL(fileURLWithPath: $0.path) }
        Task.detached(priority: .utility) {
            let urls = (FontScanner.fontURLs(in: folders) + FontScanner.fontURLs(in: hiddenFolders, includeHidden: true))
                .filter { !known.contains($0.standardizedFileURL.path) }
            let files = urls.compactMap(FontScanner.read).filter { !Self.isHiddenSystemFont($0) }
            await MainActor.run {
                let store = LibraryStore.shared
                let gone = Set(store.data.files.filter {
                    Self.isInstalled($0) && (Self.isHiddenSystemFont($0) || !FileManager.default.fileExists(atPath: $0.path))
                }.map(\.id))
                if !gone.isEmpty { store.data.remove(gone) }
                let added = files.isEmpty ? 0 : store.data.add(files)
                guard added > 0 || !gone.isEmpty else { return }
                store.save()
                if added > 0 { store.status = L("フォントフォルダーから%d個のファイルを追加しました", added) }
                store.refreshStates()
            }
        }
    }

    /// 「.SF NS」のように名前が . で始まるのは macOS の内部用（Font Book でも出ない）
    nonisolated static func isHiddenSystemFont(_ file: FontFile) -> Bool {
        file.faces.allSatisfy { $0.family.hasPrefix(".") }
    }

    // MARK: 共有ライブラリ

    /// 共有フォルダーを選ぶ。そこにライブラリがあれば、このMacのライブラリと合わせる
    func chooseSharedFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.message = L("ほかのMacと共有するフォルダー（Dropboxの中など）を選びます")
        panel.prompt = L("選択")
        if let root = PortablePath.dropboxRoots.values.sorted().first { panel.directoryURL = URL(fileURLWithPath: root) }
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let target = folder.appendingPathComponent(Self.sharedFileName)
        var merged = data
        var added = 0
        if FileManager.default.fileExists(atPath: target.path) {
            guard let other = read(target) else { return }
            // 共有側を元に、このMacのライブラリを足す（ほかのMacで付けた id を保つ）
            merged = other
            added = merged.merge(data)
        }
        let before = data.active
        sharedFolder = folder.path
        UserDefaults.standard.set(folder.path, forKey: Self.sharedFolderKey)
        data = merged
        write(data, to: target)
        knownModification = modification(of: target)
        applyActiveChanges(from: before, oldFiles: data.files)
        watchSharedFolder()
        selection.removeAll()
        status = L("共有ライブラリを使っています（このMacから%d個のファイルを足しました）", added)
        refreshStates()
    }

    /// 共有をやめ、いまの内容をこのMacのライブラリとして残す
    func stopSharing() {
        guard sharedFolder != nil else { return }
        sharedFolder = nil
        UserDefaults.standard.removeObject(forKey: Self.sharedFolderKey)
        folderWatcher?.cancel()
        folderWatcher = nil
        write(data, to: localURL)
        knownModification = nil
        status = L("共有をやめ、このMacのライブラリに切り替えました")
    }

    /// Dropbox は上書きのとき別名で置き換えるので、ファイルではなくフォルダーを見張る
    private func watchSharedFolder() {
        folderWatcher?.cancel()
        folderWatcher = nil
        guard let sharedFolder else { return }
        let descriptor = open(sharedFolder, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename], queue: .main)
        source.setEventHandler { Task { @MainActor in LibraryStore.shared.reloadIfSharedChanged() } }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        folderWatcher = source
    }

    /// ほかのMacが共有ライブラリを書き換えていたら読み直し、アクティブの違いをこのMacにも反映する
    func reloadIfSharedChanged() {
        guard sharedFolder != nil else { return }
        let url = libraryURL
        guard let date = modification(of: url), date != knownModification, let loaded = read(url) else { return }
        knownModification = date
        let before = data.active
        let oldFiles = data.files
        data = loaded
        applyActiveChanges(from: before, oldFiles: oldFiles)
        status = L("ほかのMacの変更を読み込みました")
        refreshStates()
    }

    /// 前のアクティブとの違いだけを登録・解除する。このMacに無いファイルと ~/Library/Fonts は飛ばす
    private func applyActiveChanges(from before: Set<UUID>, oldFiles: [FontFile]) {
        for file in data.files where data.active.contains(file.id) && !before.contains(file.id) && !Self.isInstalled(file)
            && FileManager.default.fileExists(atPath: file.path) {
            _ = FontActivation.activate(file)
        }
        for file in oldFiles where before.contains(file.id) && !data.active.contains(file.id) && !Self.isInstalled(file) {
            _ = FontActivation.deactivate(file)
        }
    }
}
