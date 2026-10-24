import AppKit
import CoreText
import SwiftUI

/// サイドバーで選ぶ一覧の絞り込み
enum SidebarItem: Hashable {
    case all, favorites, active, inactive, duplicates, missing
    case recentlyActivated, recentlyDeactivated, recentlyAdded, japanese
    case folder(SystemFolder)
    case kind(FontKind)
    case vendor(String)
    case collection(String)
    case set(UUID)
    case project(UUID)
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
    /// サイドバーのアイコンは各社のロゴ（VendorLogos.swift）。owner は商標の持ち主の名前に含まれる語
    static let vendors: [(id: String, title: String, owner: String)] = [
        ("MRSW", L("モリサワ"), "Morisawa"), ("FWKS", L("フォントワークス"), "Fontworks"), ("ADBE", L("アドビ"), "Adobe"),
    ]

    /// アドビに入れるファミリー（ユーザー指定、これだけをアドビとする）。英語のファミリー名の先頭で照合する。
    /// 貂明朝・貂明朝テキスト・貂明朝アンチック、小塚明朝・小塚ゴシック、源ノ角ゴシック・源ノ明朝、ヒグミン、百千鳥、Adobe Clean、
    /// Myriad、Minion、りょう（Ryo Gothic・Ryo Display・Ryo Text）、Source Code Pro、Noto
    static let adobeFamilies = ["Ten Mincho", "Kozuka", "Source Han", "Higumin", "Momochidori", "Adobe Clean",
                                "Myriad", "Minion", "Ryo ", "Source Code Pro", "Noto"]

    /// ベンダーに入るか：アドビは一覧のファミリーだけ。それ以外のベンダーは商標の持ち主が分かればその名前で、分からなければベンダーIDで決める
    static func belongs(_ file: FontFile, toVendor id: String) -> Bool {
        let adobe = adobeFamilies.contains { file.family.hasPrefix($0) }
        if adobe || id == "ADBE" { return adobe && id == "ADBE" }
        guard let vendor = vendors.first(where: { $0.id == id }) else { return file.vendor == id }
        if let owner = file.trademarkOwner, !owner.isEmpty {
            return owner.localizedCaseInsensitiveContains(vendor.owner)
        }
        return file.vendor == id
    }
    /// 「最近」は7日以内
    static let recentInterval: TimeInterval = 7 * 24 * 60 * 60
    static let defaultSampleText = "あいうえお 永遠の文字 Aa Bb Cc 0123456789"
    /// 設定の共有で書き出す・同期するキー。ライブラリ（ファイルの場所）はMacごと
    static let syncedKeys: Set<String> = Set([restoreAtLaunchKey, deactivateOnQuitKey, sampleTextKey, includeUserFontsKey, NameDisplay.key]
        + SidebarSection.allCases.map(\.showKey) + [SidebarSection.orderKey])

    @Published private(set) var data = LibraryData() { didSet { invalidate() } }
    @Published private(set) var states: [UUID: FontState] = [:] { didSet { invalidate() } }
    // 絞り込みの書体数と選択肢の数は、サイドバーで選んだ範囲で数えるので一緒に捨てる
    @Published var sidebar: SidebarItem = .all { didSet { shownCache = nil; faceCountCache = nil; filterCache = nil; listVersion += 1 } }
    @Published var selection = Set<String>()
    @Published var searchText = "" { didSet { shownCache = nil; listVersion += 1 } }
    /// 検索オプションの絞り込み：文字セット（"—" は文字セットの名前が無いもの）・形式・種類・ファミリーの書体数・収録文字数。nil は絞り込まない
    @Published var charsetFilter: String? { didSet { shownCache = nil; listVersion += 1 } }
    @Published var formatFilter: String? { didSet { shownCache = nil; listVersion += 1 } }
    @Published var kindFilter: FontKind? { didSet { shownCache = nil; listVersion += 1 } }
    @Published var faceCountFilter: FaceCountRange? { didSet { shownCache = nil; listVersion += 1 } }
    @Published var characterCountFilter: CharacterCountRange? { didSet { shownCache = nil; listVersion += 1 } }
    @Published var variantFilters: [VariantFilter: Bool] = [:] { didSet { shownCache = nil; listVersion += 1 } }
    var hasFilter: Bool {
        charsetFilter != nil || formatFilter != nil || kindFilter != nil || faceCountFilter != nil || characterCountFilter != nil || !variantFilters.isEmpty
    }

    func clearFilters() {
        charsetFilter = nil; formatFilter = nil; kindFilter = nil; faceCountFilter = nil; characterCountFilter = nil; variantFilters = [:]
    }
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
    private var filterCache: FilterOptions?
    /// ファミリーごとの書体数（表示しているファイル全体で数える。ほかの絞り込みでは変わらない）
    private var faceCountCache: [String: Int]?

    /// ライブラリ・状態・表示の設定が変わったときに控えを捨てる
    func invalidate() {
        listVersion += 1
        shownCache = nil
        countCache = [:]
        duplicateCache = nil
        familyCountCache = nil
        filterCache = nil
        faceCountCache = nil
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
        case .recentlyActivated:
            let since = Date().addingTimeInterval(-Self.recentInterval)
            return base.filter { states[$0.id] == .active && ($0.activatedAt ?? .distantPast) > since }
        case .recentlyDeactivated:
            let since = Date().addingTimeInterval(-Self.recentInterval)
            return base.filter { states[$0.id] != .active && ($0.deactivatedAt ?? .distantPast) > since }
        case .recentlyAdded:
            let since = Date().addingTimeInterval(-Self.recentInterval)
            return base.filter { $0.added > since }
        case .japanese: return base.filter { $0.supportsJapanese == true }
        case .folder(let folder): return base.filter { SystemFolder.of($0.path) == folder }
        case .kind(let kind): return base.filter(kind.matches)
        case .vendor(let id): return base.filter { Self.belongs($0, toVendor: id) }
        case .collection(let name):
            let query = collectionQuery(name)
            return base.filter { file in
                file.faces.contains { query.names.contains($0.postScriptName) || query.families.contains($0.family) }
            }
        case .project(let id):
            let ids = Set(data.projects.first { $0.id == id }?.files ?? [])
            return base.filter { ids.contains($0.id) }
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
        if let formatFilter {
            files = files.filter { $0.format == formatFilter }
        }
        if let kindFilter {
            files = files.filter(kindFilter.matches)
        }
        for (variant, value) in variantFilters {
            files = files.filter { variant.value($0) == value }
        }
        if let characterCountFilter {
            files = files.filter { $0.characterCount.map(characterCountFilter.contains) ?? false }
        }
        if let faceCountFilter {
            let counts = familyFaceCounts
            files = files.filter { faceCountFilter.contains(counts[$0.family] ?? 0) }
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

    /// ファミリーごとの書体数。一覧の「n書体」と同じく、サイドバーで選んだ範囲で数える
    /// （ライブラリ全体で数えると、モリサワ版とアドビ版があるファミリーが「アドビ」で1書体なのに2以上に入っていた）
    private var familyFaceCounts: [String: Int] {
        if let faceCountCache { return faceCountCache }
        var counts: [String: Int] = [:]
        for file in files(in: sidebar) { counts[file.family, default: 0] += file.faces.count }
        faceCountCache = counts
        return counts
    }

    struct FilterOptions {
        var charsets: [(String, Int)]
        var formats: [(String, Int)]
        var kinds: [(FontKind, Int)]
        var faceCounts: [(FaceCountRange, Int)]
        var characterCounts: [(CharacterCountRange, Int)]
        var variants: [VariantFilter: [(Bool, Int)]]
    }

    /// 絞り込みの選択肢（ファミリー数つき、サイドバーで選んだ範囲で数える）。文字セットは決まった順、形式は多い順
    var filterOptions: FilterOptions {
        if let filterCache { return filterCache }
        let base = files(in: sidebar)
        var charsets: [String: Int] = [:]
        for family in Set(base.map(\.family)) {
            charsets[FontNaming.charset(family) ?? Self.noCharset, default: 0] += 1
        }
        // 形式と種類はファイル単位なので、当てはまるファイルを含むファミリーを数える
        var formats: [String: Set<String>] = [:]
        var kinds: [FontKind: Set<String>] = [:]
        var characterCounts: [CharacterCountRange: Set<String>] = [:]
        var variants: [VariantFilter: [Bool: Set<String>]] = [:]
        for file in base {
            for variant in VariantFilter.allCases {
                if let value = variant.value(file) { variants[variant, default: [:]][value, default: []].insert(file.family) }
            }
            formats[file.format, default: []].insert(file.family)
            for kind in FontKind.allCases where kind.matches(file) { kinds[kind, default: []].insert(file.family) }
            if let count = file.characterCount, let range = CharacterCountRange.allCases.first(where: { $0.contains(count) }) {
                characterCounts[range, default: []].insert(file.family)
            }
        }
        var faceCounts: [FaceCountRange: Int] = [:]
        for count in familyFaceCounts.values {
            if let range = FaceCountRange.allCases.first(where: { $0.contains(count) }) { faceCounts[range, default: 0] += 1 }
        }
        let options = FilterOptions(
            charsets: (FontNaming.charsets + [Self.noCharset]).compactMap { name in charsets[name].map { (name, $0) } },
            formats: formats.map { ($0.key, $0.value.count) }.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 },
            kinds: FontKind.allCases.compactMap { kind in kinds[kind].map { (kind, $0.count) } },
            faceCounts: FaceCountRange.allCases.compactMap { range in faceCounts[range].map { (range, $0) } },
            characterCounts: CharacterCountRange.allCases.compactMap { range in characterCounts[range].map { (range, $0.count) } },
            variants: variants.mapValues { counts in [true, false].compactMap { value in counts[value].map { (value, $0.count) } } })
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

    /// ウォッチフォルダーで見つけたファイルを足す（アクティブにはしない）
    func importWatched(_ files: [FontFile]) {
        let added = data.add(files)
        guard added > 0 else { return }
        save()
        status = L("ウォッチフォルダーから%d個のファイルを追加しました", added)
        refreshStates()
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
        var stamped: [UUID: Date] = [:]
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
            stamped[file.id] = Date()
            if installed { continue }
            if on { data.active.insert(file.id) } else { data.active.remove(file.id) }
        }
        // 日時は一度にまとめて書く（data を書き換えるたびに一覧の控えが捨てられるため）
        if !stamped.isEmpty {
            var updated = data
            for index in updated.files.indices {
                guard let date = stamped[updated.files[index].id] else { continue }
                if on { updated.files[index].activatedAt = date } else { updated.files[index].deactivatedAt = date }
            }
            data = updated
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

    /// セットのアクティブの状態：すべて／一部（nil）／なし。System・Adobe Fonts と見つからないファイルは数えない
    func setState(_ id: UUID) -> Bool? {
        let files = setFiles(id).filter { !Self.isLocked($0) && states[$0.id] != .missing }
        let active = files.filter { states[$0.id] == .active }.count
        if active == 0 { return false }
        return active == files.count ? true : nil
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

    // MARK: プロジェクト

    func projectFiles(_ id: UUID) -> [FontFile] {
        let ids = Set(data.projects.first { $0.id == id }?.files ?? [])
        return data.files.filter { ids.contains($0.id) }
    }

    /// プロジェクトのアクティブの状態：すべて／一部（nil）／なし。System・Adobe Fonts と見つからないファイルは数えない
    func projectState(_ id: UUID) -> Bool? {
        let files = projectFiles(id).filter { !Self.isLocked($0) && states[$0.id] != .missing }
        let active = files.filter { states[$0.id] == .active }.count
        if active == 0 { return files.isEmpty ? true : false }
        return active == files.count ? true : nil
    }

    func newProjectFromFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []
        panel.message = L("フォントを調べる制作ファイル（IDML・INDD・PDF・AI）を選びます")
        panel.prompt = L("選択")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        newProject(from: url)
    }

    /// 制作ファイルから使っているフォント名を取り出し、ライブラリと照合して確認の画面を出す
    func newProject(from url: URL) {
        status = L("%@ のフォントを調べています…", url.lastPathComponent)
        Task.detached(priority: .userInitiated) {
            let result = Result { try FontNameExtractor.names(in: url) }
            await MainActor.run {
                let store = LibraryStore.shared
                switch result {
                case .success(let names):
                    store.status = L("%d個のフォント名が見つかりました", names.count)
                    ProjectDraftWindow.shared.show(ProjectDraft(name: url.deletingPathExtension().lastPathComponent,
                                                                source: url.path, names: names, files: store.data.files))
                case .failure:
                    store.status = ""
                    store.message = (L("フォントを調べられませんでした"),
                                     L("IDML・INDD・PDF・PDF互換で保存したAIのファイルを選んでください。（%@）", url.lastPathComponent))
                }
            }
        }
    }

    func createProject(name: String, source: String?, files: [FontFile], missing: [String], activate: Bool) {
        var seen = Set<UUID>()
        let project = FontProject(name: name.trimmingCharacters(in: .whitespaces),
                                  files: files.map(\.id).filter { seen.insert($0).inserted }, missing: missing, source: source)
        data.projects.append(project)
        save()
        sidebar = .project(project.id)
        selection.removeAll()
        if activate { activateProject(project.id) } else { status = L("プロジェクト「%@」を作成しました", project.name) }
    }

    /// プロジェクトのフォントをアクティブにする。ほかのフォントは解除しない（ユーザー指定）。
    /// 1つでも失敗したら、この操作でアクティブにしたものを解除して元に戻す。同じ名前のフォントが別の場所で使われているものは、使える状態とみなして飛ばす
    func activateProject(_ id: UUID) {
        guard let project = data.projects.first(where: { $0.id == id }) else { return }
        let targets = projectFiles(id).filter {
            !Self.isLocked($0) && FileManager.default.fileExists(atPath: $0.path) && states[$0.id] != .active
        }
        var done: [(FontFile, CTFontManagerScope)] = []
        var failure: String?
        for file in targets {
            if case .conflict = FontActivation.state(of: file) { continue }
            let scope: CTFontManagerScope = Self.isInstalled(file) ? .persistent : .session
            if let error = FontActivation.activate(file, scope: scope) {
                failure = "\(file.fileName) — \(error)"
                break
            }
            done.append((file, scope))
        }
        if let failure {
            for (file, scope) in done { _ = FontActivation.deactivate(file, scope: scope) }
            message = (L("プロジェクト「%@」をアクティブにできませんでした", project.name),
                       L("途中で失敗したため、この操作でアクティブにしたフォントを元に戻しました。") + "\n" + failure)
            refreshStates()
            return
        }
        var updated = data
        let now = Date()
        let ids = Set(done.map(\.0.id))
        for index in updated.files.indices where ids.contains(updated.files[index].id) {
            updated.files[index].activatedAt = now
            if !Self.isInstalled(updated.files[index]) { updated.active.insert(updated.files[index].id) }
        }
        data = updated
        save()
        refreshStates()
        status = L("プロジェクト「%@」をアクティブにしました（%d個）", project.name, done.count)
        if !project.missing.isEmpty { status += L("、ライブラリに無いフォント %d", project.missing.count) }
    }

    func deactivateProject(_ id: UUID) {
        setActive(projectFiles(id).filter { !Self.isLocked($0) }, false)
    }

    func renameProject(_ id: UUID) {
        guard let index = data.projects.firstIndex(where: { $0.id == id }),
              let name = askName(title: L("プロジェクトの名前を変更"), initial: data.projects[index].name) else { return }
        data.projects[index].name = name
        save()
    }

    func deleteProject(_ id: UUID) {
        guard let project = data.projects.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = L("プロジェクト「%@」を削除しますか？", project.name)
        alert.informativeText = L("ライブラリのフォントとアクティブの状態はそのままです。")
        alert.addButton(withTitle: L("削除"))
        alert.addButton(withTitle: L("キャンセル")).keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        data.projects.removeAll { $0.id == id }
        if sidebar == .project(id) { sidebar = .all }
        save()
    }

    /// ライブラリに見つからなかったフォント名を見せる。いまライブラリにあれば入れ直す
    func showProjectMissing(_ id: UUID) {
        guard let index = data.projects.firstIndex(where: { $0.id == id }) else { return }
        let draft = ProjectDraft(name: "", source: nil, names: data.projects[index].missing, files: data.files)
        if !draft.exact.isEmpty {
            let known = Set(data.projects[index].files)
            data.projects[index].files += draft.exact.map(\.file.id).filter { !known.contains($0) }
            data.projects[index].missing = draft.candidates.map(\.name) + draft.missing
            save()
        }
        let missing = data.projects[index].missing
        message = missing.isEmpty
            ? (L("ライブラリに無いフォントはありません"), draft.exact.isEmpty ? "" : L("%d個のフォントをプロジェクトに入れ直しました", draft.exact.count))
            : (L("ライブラリに無いフォント（%d）", missing.count), missing.prefix(40).joined(separator: "\n") + (missing.count > 40 ? "\n…" : ""))
    }

    func revealProjectSource(_ id: UUID) {
        guard let source = data.projects.first(where: { $0.id == id })?.source else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: source)])
    }

    // MARK: サイドバーの表示

    /// サイドバーに出す区分（設定の「表示」）。ライブラリは常に出す
    enum SidebarSection: String, CaseIterable {
        case system, kinds, vendors, collections, smartSets, projects, sets
        /// 並び順（rawValue をカンマでつなぐ）。ライブラリは常に先頭
        static let orderKey = "sidebarOrder"
        var showKey: String { "sidebarShow." + rawValue }
        var title: String {
            switch self {
            case .system: return L("システム")
            case .kinds: return L("種類")
            case .vendors: return L("ベンダー")
            case .collections: return L("コレクション")
            case .smartSets: return L("スマートセット")
            case .projects: return L("プロジェクト")
            case .sets: return L("セット")
            }
        }
        /// 保存した並び順。知らない名前は捨て、無い区分（版を上げて増えたもの）は初期の並びで次に来る区分の前に入れる
        static func ordered(_ saved: String) -> [SidebarSection] {
            var order = saved.split(separator: ",").compactMap { SidebarSection(rawValue: String($0)) }
            for (index, section) in allCases.enumerated() where !order.contains(section) {
                let next = allCases[(index + 1)...].first { order.contains($0) }
                order.insert(section, at: next.flatMap { order.firstIndex(of: $0) } ?? order.count)
            }
            return order
        }
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
        case .project: section = .projects
        case .favorites, .active, .inactive, .recentlyActivated, .recentlyDeactivated, .recentlyAdded, .japanese: section = .smartSets
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

    // MARK: Adobe Fonts

    /// Adobe Fonts のオン・オフは Creative Cloud が持つ（解除しても1秒以内に登録し直される、2026-10-24 実測）ので、切り替える場所を開く
    func openCreativeCloud() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.adobe.acc.AdobeCreativeCloud") else {
            message = (L("Creative Cloudが見つかりません"), L("Creative Cloudアプリが入っていません。fonts.adobe.comで切り替えてください。"))
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    func openAdobeFontsWeb() {
        if let url = URL(string: "https://fonts.adobe.com/my_fonts") { NSWorkspace.shared.open(url) }
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

    /// 古い版で登録したファイルには、ベンダーID・日本語の表示名・種類（バリアブル・カラー・かな）・収録文字数が無い。裏で読み直して足す（7,953件で数秒、1回だけ）
    /// 判定の仕方を変えたら上げる。保存した値より古ければ全件を読み直す（2〜6：アイコンフォントの判定を直した）
    nonisolated static let metadataVersion = 6
    nonisolated static let metadataVersionKey = "metadataVersion"

    func fillMetadata() {
        let outdated = UserDefaults.standard.integer(forKey: Self.metadataVersionKey) < Self.metadataVersion
        let missing = data.files.filter {
            (outdated || $0.vendor == nil || $0.trademarkOwner == nil || $0.isVariable == nil || $0.characterCount == nil || $0.supportsJapanese == nil || $0.isIcon == nil || $0.faces.contains { $0.localizedFamily == nil }) && FileManager.default.fileExists(atPath: $0.path)
        }
        guard !missing.isEmpty else { return }
        Task.detached(priority: .utility) {
            defer { UserDefaults.standard.set(LibraryStore.metadataVersion, forKey: LibraryStore.metadataVersionKey) }
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
                    data.files[index].trademarkOwner = fresh.trademarkOwner
                    data.files[index].isVariable = fresh.isVariable
                    data.files[index].isColor = fresh.isColor
                    data.files[index].characterCount = fresh.characterCount
                    data.files[index].glyphCount = fresh.glyphCount
                    data.files[index].isKana = fresh.isKana
                    data.files[index].supportsJapanese = fresh.supportsJapanese
                    data.files[index].isIcon = fresh.isIcon
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
