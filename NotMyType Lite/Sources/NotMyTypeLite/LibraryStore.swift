import AppKit
import CoreText
import SwiftUI

/// サイドバーで選ぶ一覧の絞り込み
enum SidebarItem: Hashable {
    case all, active, inactive, duplicates, missing
    case japanese, watchFolders
    case folder(SystemFolder)
    case set(UUID)
    case smartSet(UUID)
}

/// ライブラリの保存・取り込み・アクティブの切り替え。画面とメニューから共有する
@MainActor
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    static let restoreAtLaunchKey = "restoreActiveFontsAtLaunch"
    static let deactivateOnQuitKey = "deactivateFontsOnQuit"
    static let sampleTextKey = "previewSampleText"
    static let includeUserFontsKey = "includeUserFontsFolder"
    /// 重複の優先：同じフォントで形式が異なるときは、形式の順（formatOrderKey）で優先する（ユーザー指定で既定はオン。1.31 の OpenType の優先と同じキー）
    nonisolated static let preferOpenTypeKey = "preferOpenTypeDuplicates"
    /// 形式の優先の順。拡張子をカンマでつないで持つ（設定の同期に載せやすいよう文字列）
    static let formatOrderKey = "duplicateFormatOrder"
    static let defaultFormatOrder = ["otf", "otc", "ttf", "ttc", "dfont", "woff2", "woff"]
    /// 重複の優先の「バージョンが新しい」「字形数が多い」（ユーザー指定で追加、既定はオン）と、形式を含めた3つの条件の順
    nonisolated static let preferNewerVersionKey = "preferNewerVersionDuplicates"
    nonisolated static let preferMoreGlyphsKey = "preferMoreGlyphsDuplicates"
    static let autoCriteriaOrderKey = "duplicateAutoCriteriaOrder"
    /// 中身が同じファイル（ハッシュが一致）しか残らないときは、自動で1つに決める（ユーザー指定、既定はオン）
    nonisolated static let pickIdenticalKey = "autoPickIdenticalDuplicates"

    /// 形式・バージョン・字形数のどれで決めるか。ファイルの中身から自動で決める条件
    enum AutoCriterion: String, CaseIterable, Sendable {
        case format, version, glyphs
        var enabledKey: String {
            switch self {
            case .format: return LibraryStore.preferOpenTypeKey
            case .version: return LibraryStore.preferNewerVersionKey
            case .glyphs: return LibraryStore.preferMoreGlyphsKey
            }
        }
        var title: String {
            switch self {
            case .format: return L("形式（下の順）")
            case .version: return L("バージョンが新しい")
            case .glyphs: return L("字形数が多い")
            }
        }
    }

    /// 保存した条件の順。知らないものは捨て、足りないものは末尾に足す
    static func autoCriteriaOrder(_ saved: String? = UserDefaults.standard.string(forKey: autoCriteriaOrderKey)) -> [AutoCriterion] {
        var seen = Set<AutoCriterion>()
        let list = (saved ?? "").split(separator: ",").compactMap { AutoCriterion(rawValue: String($0)) }.filter { seen.insert($0).inserted }
        return list + AutoCriterion.allCases.filter { !seen.contains($0) }
    }

    /// 保存した形式の順。知らない拡張子は捨て、足りない形式は末尾に足す
    static func formatOrder(_ saved: String? = UserDefaults.standard.string(forKey: formatOrderKey)) -> [String] {
        let list = (saved ?? "").split(separator: ",").map(String.init).filter { defaultFormatOrder.contains($0) }
        var seen = Set<String>()
        let unique = list.filter { seen.insert($0).inserted }
        return unique + defaultFormatOrder.filter { !seen.contains($0) }
    }
    /// 共有ライブラリを置くフォルダー（Macごと）
    static let sharedFolderKey = "sharedLibraryFolder"
    /// 旧名（FontSwitcher）のまま。変えるとほかのMacの共有ライブラリと別のファイルになる
    static let sharedFileName = "NotMyTypeLite-Library.json"
    static let defaultSampleText = "あいうえお 永遠の文字 Aa Bb Cc 0123456789"
    /// 設定の共有で書き出す・同期するキー。ライブラリ（ファイルの場所）はMacごと
    static let syncedKeys: Set<String> = Set([restoreAtLaunchKey, deactivateOnQuitKey, sampleTextKey, preferOpenTypeKey, formatOrderKey,
                                                       preferNewerVersionKey, preferMoreGlyphsKey, autoCriteriaOrderKey, pickIdenticalKey, FontServices.key, NameDisplay.key]
        // プレビューのオプションとメニューのホットキーも、どのMacでも同じにする
        + [PreviewStyle.schemeKey, PreviewStyle.foregroundKey, PreviewStyle.backgroundKey,
           PreviewStyle.kerningKey, PreviewStyle.trackingOnKey, PreviewStyle.trackingKey, PreviewStyle.modeKey, FontInfoItem.hiddenKey]
        + MenuShortcuts.Command.allCases.map(\.key))

    @Published private(set) var data = LibraryData() { didSet { invalidate() } }
    /// 状態は重複の優先に関わらないので、重複の控えは残す（8,000件の組み分けを切り替えのたびにやり直さない）
    @Published private(set) var states: [UUID: FontState] = [:] { didSet { invalidate(keepDuplicates: true) } }
    // 絞り込みの書体数と選択肢の数は、サイドバーで選んだ範囲で数えるので一緒に捨てる
    @Published var sidebar: SidebarItem = .all { didSet { guard sidebar != oldValue else { return }; shownCache = nil; faceCountCache = nil; filterCache = nil; listVersion += 1 } }
    @Published var selection = Set<String>()
    /// Explicit sidebar navigation; keep search only for Option-click.
    func selectSidebar(_ item: SidebarItem, keepingSearch: Bool? = nil) {
        guard sidebar != item else { return }
        let preserve = keepingSearch ?? (NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags).contains(.option)
        if !preserve && !searchText.isEmpty { searchText = "" }
        sidebar = item
        if !selection.isEmpty { selection.removeAll() }
    }

    @Published var searchText = "" { didSet { guard searchText != oldValue else { return }; shownCache = nil; listVersion += 1 } }
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
    /// 一覧の中身（行・チェック）が変わるたびに進む。一覧はこれが変わったときだけ読み直す
    @Published private(set) var listVersion = 0
    @Published private(set) var isBusy = false
    /// 最後の操作の結果。ウインドウ下の状態欄に出す
    @Published var status = ""
    @Published var message: (title: String, body: String)?
    /// 共有ライブラリのフォルダー。nil ならこのMacだけのライブラリ
    @Published private(set) var sharedFolder: String?

    private let localURL: URL
    private var refreshTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var folderWatcher: DispatchSourceFileSystemObject?
    /// 最後に読み書きしたときの共有ファイルの更新日時。自分の書き込みで読み直さないため
    private var knownModification: Date?
    private var userFontsScan: DispatchWorkItem?

    // 一覧・件数は数千件を数え直すので、元が変わるまで控えておく（画面の描き直しのたびに計算しない）
    private var shownCache: [FontFamily]?
    /// 表示するファイル（フォントフォルダーを入れない設定なら除いたもの）。サイドバーの項目ごとに数え直さない
    private var visibleCache: [FontFile]?
    /// ファイルの id → ライブラリでの位置。セット・プロジェクトのファイルを数万件の走査なしに引く
    private var positionCache: [UUID: Int]?
    /// セット・プロジェクトのアクティブの状態（サイドバーの行を描くたびに数え直さない）
    private var groupStateCache: [UUID: Bool?] = [:]
    private var countCache: [SidebarItem: Int] = [:]
    private var duplicateCache: Set<UUID>?
    private var familyCountCache: Int?
    private var filterCache: FilterOptions?
    /// ファミリーごとの書体数（表示しているファイル全体で数える。ほかの絞り込みでは変わらない）
    private var faceCountCache: [String: Int]?
    private var preferenceCache: [UUID: Bool]?
    /// 名前の衝突（ファイルの id → PostScript名が同じ別の書体のパス）
    private var nameClashCache: [UUID: String]?
    private var undecidedCache: [[FontFile]]?

    /// ライブラリ・状態・表示の設定が変わったときに控えを捨てる。keepDuplicates は状態だけが変わったとき（重複の判定は残す）
    func invalidate(keepDuplicates: Bool = false) {
        listVersion += 1
        shownCache = nil
        visibleCache = nil
        countCache = [:]
        groupStateCache = [:]
        familyCountCache = nil
        filterCache = nil
        faceCountCache = nil
        guard !keepDuplicates else { return }
        positionCache = nil
        duplicateCache = nil
        nameClashCache = nil
        preferenceCache = nil
        undecidedCache = nil
    }

    private var libraryURL: URL {
        guard let sharedFolder else { return localURL }
        return URL(fileURLWithPath: sharedFolder).appendingPathComponent(Self.sharedFileName)
    }

    private init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            // 1.24.0 から NotMyType。旧 FontSwitcher のフォルダーは初回の起動で LegacyMigration が写す
            .appendingPathComponent("NotMyTypeLite", isDirectory: true)
        localURL = folder.appendingPathComponent("Library.json")
        UserDefaults.standard.register(defaults: [Self.restoreAtLaunchKey: true, Self.deactivateOnQuitKey: false,
                                                  Self.sampleTextKey: Self.defaultSampleText, Self.includeUserFontsKey: true,
                                                  Self.preferOpenTypeKey: true, Self.preferNewerVersionKey: true,
                                                  Self.preferMoreGlyphsKey: true, Self.pickIdenticalKey: true])
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
            // 外付けディスクをつないだなどで見えるようになったフォルダーを見張り直す
            WatchFolders.shared.refresh()
            // Creative Cloud で Adobe Fonts をオン・オフしたあと戻ってきたときも、登録の状態を読み直す
            LibraryStore.shared.scheduleFontsChanged()
        } })
        // 設定の同期でほかのMacから値が届いたときも、一覧の出し方を合わせる（設定画面の onChange は通らない）
        lastListSettings = listSettings
        observers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { _ in Task { @MainActor in LibraryStore.shared.listSettingsMayHaveChanged() } })
    }

    /// 一覧の出し方に効く設定（フォントフォルダーを入れるか・フォント名の出し方）
    private var listSettings: [String] {
        [String(includeUserFonts), UserDefaults.standard.string(forKey: NameDisplay.key) ?? ""]
    }
    private var lastListSettings: [String] = []

    private func listSettingsMayHaveChanged() {
        let current = listSettings
        guard current != lastListSettings else { return }
        let includedBefore = lastListSettings.first == "true"
        lastListSettings = current
        invalidate()
        if includeUserFonts && !includedBefore { scanUserFonts() }
    }

    // MARK: 表示

    /// フォントフォルダー（ユーザー名・All Users・System）は常に一覧に入れる（設定は持たない、ユーザー指定）
    var includeUserFonts: Bool { true }

    /// フォントフォルダー（username・All Users・System）のファイルかどうか
    static func isInstalled(_ file: FontFile) -> Bool { SystemFolder.of(file.path) != nil }

    /// System・Adobe Fonts のフォントは切り替えない・取り除かない
    static func isLocked(_ file: FontFile) -> Bool { SystemFolder.of(file.path).map { !$0.isEditable } ?? false }

    /// 切り替えられない理由（一覧のチェックボックスと失敗の一覧に出す）
    static func lockedReason(_ file: FontFile) -> String {
        SystemFolder.of(file.path) == .adobeFonts ? L("Adobe Fontsのフォントは、Creative Cloudで切り替えます")
            : L("System のフォントは切り替えられません")
    }

    /// 設定でフォントフォルダーを外したときは、そのフォントを一覧に出さない（ライブラリからは消さない）。
    /// Adobe Fonts はこの設定と切り離して、いつも出す（ユーザー指定）
    var visibleFiles: [FontFile] {
        if let visibleCache { return visibleCache }
        let files = includeUserFonts ? data.files
            : data.files.filter { !Self.isInstalled($0) || SystemFolder.of($0.path) == .adobeFonts }
        visibleCache = files
        return files
    }

    func files(in item: SidebarItem) -> [FontFile] {
        let base = visibleFiles
        switch item {
        case .all: return base
        case .active: return base.filter { states[$0.id] == .active }
        case .inactive: return base.filter { states[$0.id] == .inactive }
        case .duplicates:
            let ids = duplicateIDs
            return base.filter { ids.contains($0.id) }
        case .missing: return base.filter { states[$0.id] == .missing }
        case .japanese: return base.filter { $0.supportsJapanese == true }
        case .watchFolders:
            // どれかのウォッチフォルダーの下にあるファイル（まとめて1つ、ユーザー指定）
            let prefixes = WatchFolders.shared.folders.map { $0.hasSuffix("/") ? $0 : $0 + "/" }
            return base.filter { file in prefixes.contains { file.path.hasPrefix($0) } }
        case .folder(let folder): return base.filter { SystemFolder.of($0.path) == folder }
        case .smartSet(let id):
            guard let smartSet = data.smartSets.first(where: { $0.id == id }) else { return [] }
            return files(matching: smartSet)
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

    private var familyNodeCache = FamilyNodeCache()
    /// Reuse row identities and children until the existing list revision changes.
    var shownNodes: [FamilyNode] {
        familyNodeCache.nodes(for: shownFamilies, version: listVersion)
    }

    var shownFamilies: [FontFamily] {
        if let shownCache { return shownCache }
        let families = data.families(of: shownFiles)
        shownCache = families
        return families
    }

    /// サイドバーの「重複」：同じ PostScript名のファイルのうち、優先が決まらないもの（ウォッチフォルダーの順・規則・選択で1つに絞れない）だけ。
    /// 優先が決まった重複は数えない（ユーザー指定）。決まったものは一覧の「優先／優先外」と「優先外の重複」の操作で扱う
    private var duplicateIDs: Set<UUID> {
        if duplicateCache == nil { computeDuplicates() }
        return duplicateCache ?? []
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
        let shown = shownFamilies
        guard !selection.isEmpty else { return [] }
        // 行の id（ファミリー・ファイル）→ ファミリーの位置。選択を変えるたびに数万件の id を作り直さない
        if nodeIndexCache?.version != listVersion || nodeIndexCache?.count != shown.count {
            var index: [String: Int] = [:]
            for (position, family) in shown.enumerated() {
                index[family.id] = position
                for file in family.files { index[FamilyNode.fileID(file)] = position }
            }
            nodeIndexCache = (listVersion, shown.count, index)
        }
        let index = nodeIndexCache?.index ?? [:]
        return Set(selection.compactMap { index[$0] }).sorted().map { shown[$0] }
    }
    private var nodeIndexCache: (version: Int, count: Int, index: [String: Int])?

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

    /// reveal：追加したファミリーを選んでプレビューを出す（Finder でフォントファイルを開いたとき）
    /// toSet：セットを選んでいるときにドロップしたら、そのセットにも入れる（登録済みのファイルは読み直さずにセットへ）
    func add(_ urls: [URL], reveal: Bool = false, toSet: UUID? = nil) {
        guard !isBusy, !urls.isEmpty else { return }
        isBusy = true
        status = L("フォントを読み込み中…")
        TaskProgress.shared.begin(L("フォントを読み込み中…"), detail: L("フォルダーを調べています…"))
        // 登録済みのファイルは読み直さない（フォントの情報はライブラリのものを使う）
        let known = Set(data.files.map(\.path))
        Task.detached(priority: .userInitiated) {
            let found = FontScanner.fontURLs(in: urls)
            let fresh = found.filter { !known.contains($0.standardizedFileURL.path) }
            var read: [FontFile] = []
            var unreadable = 0
            for (index, url) in fresh.enumerated() {
                if index % 100 == 0 {
                    let done = index
                    await MainActor.run { TaskProgress.shared.update(done, of: fresh.count) }
                }
                if let file = FontScanner.read(url) { read.append(file) } else { unreadable += 1 }
            }
            let files = read
            let skipped = unreadable
            let registered = found.count - fresh.count
            await MainActor.run {
                let store = LibraryStore.shared
                // 自分で追加し直したものは、ウォッチフォルダーの除外から外す
                WatchFolders.shared.include(found.map(\.standardizedFileURL.path))
                let added = store.data.add(files)
                var setCount = 0
                if let toSet, let index = store.data.sets.firstIndex(where: { $0.id == toSet }) {
                    let paths = Set(found.map(\.standardizedFileURL.path))
                    let ids = store.data.files.filter { paths.contains($0.path) }.map(\.id)
                    let inSet = Set(store.data.sets[index].files)
                    let newIDs = ids.filter { !inSet.contains($0) }
                    store.data.sets[index].files += newIDs
                    setCount = newIDs.count
                }
                store.save()
                store.isBusy = false
                TaskProgress.shared.end()
                var parts = [L("%d個のファイルを追加しました", added)]
                if registered + files.count > added { parts.append(L("登録済み %d", registered + files.count - added)) }
                if let toSet, let set = store.data.sets.first(where: { $0.id == toSet }) {
                    parts.append(L("セット「%@」に%d個を入れました", set.name, setCount))
                }
                if skipped > 0 { parts.append(L("読めないファイル %d", skipped)) }
                store.status = parts.joined(separator: L("、"))
                if found.isEmpty {
                    store.message = (L("フォントが見つかりません"), L("選んだ場所にフォントファイル（.otf・.ttf・.ttc など）がありません。"))
                }
                if reveal {
                    let paths = Set(found.map { $0.standardizedFileURL.path })
                    let families = Set(store.data.files.filter { paths.contains($0.path) }.map(\.family))
                    if !families.isEmpty {
                        store.sidebar = .all
                        store.searchText = ""
                        store.clearFilters()
                        store.selection = families
                    }
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
        // ウォッチフォルダーの中のファイルは、次の読み込みでまた入らないよう除外する
        WatchFolders.shared.exclude(files.map(\.path))
        selection.removeAll()
        save()
        status = L("%d個のファイルを取り除きました", files.count)
        refreshStates()
    }

    // MARK: アクティブ

    func setActive(_ files: [FontFile], _ on: Bool) {
        // アクティブにするときは、同じ PostScript 名の重複を優先のファイルだけにする（2つ目は「同じ名前のフォントがすでに使われています」で失敗していた）
        let files = on ? preferredAmongDuplicates(files) : files
        guard !files.isEmpty else { return }
        var failures: [String] = []
        var conflicts: [(file: FontFile, path: String)] = []
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
            if on, case .conflict(let path) = FontActivation.state(of: file) {
                _ = FontActivation.deactivate(file, scope: scope)
                failures.append("\(file.fileName) — \(L("同じ名前のフォントがすでに使われています"))")
                if !installed { conflicts.append((file, path)) }
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
            let title = on ? L("アクティブにできなかったファイルがあります") : L("解除できなかったファイルがあります")
            let body = failures.prefix(20).joined(separator: "\n") + (failures.count > 20 ? "\n…" : "")
            if conflicts.isEmpty { message = (title, body) } else { offerForce(conflicts, title: title, body: body) }
        }
    }

    /// 同じ名前のフォントがすでに使われていて失敗したとき、相手の登録を外してアクティブにするか聞く。
    /// Adobe Fonts は外しても Creative Cloud がすぐ入れ直すので、Creative Cloud で切るよう案内する（macOS のフォントも外せない）
    private func offerForce(_ conflicts: [(file: FontFile, path: String)], title: String, body: String) {
        let adobe = conflicts.filter { $0.path.hasPrefix(SystemFolder.adobeFonts.path + "/") }
        let system = conflicts.filter { $0.path.hasPrefix(SystemFolder.system.path + "/") }
        let forceable = conflicts.filter { conflict in !adobe.contains { $0.file.id == conflict.file.id } && !system.contains { $0.file.id == conflict.file.id } }
        var notes: [String] = []
        if !forceable.isEmpty {
            notes.append(L("「強制的にアクティブにする」は、ぶつかっているフォント（%@ など）の登録を外してから、このファイルをアクティブにします。ぶつかっているファイルは動かしません。",
                           (forceable[0].path as NSString).lastPathComponent))
        }
        if !adobe.isEmpty {
            notes.append(L("%d個はAdobe Fontsとぶつかっています。Adobe Fontsの登録はCreative Cloudがすぐに戻すため、ここからは外せません。Creative Cloudでそのフォントをオフにしてから、もう一度アクティブにしてください。", adobe.count))
        }
        if !system.isEmpty {
            notes.append(L("%d個はmacOSのフォントとぶつかっているため、アクティブにできません。", system.count))
        }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body + "\n\n" + notes.joined(separator: "\n\n")
        var actions: [() -> Void] = []
        if !forceable.isEmpty {
            alert.addButton(withTitle: L("強制的にアクティブにする"))
            actions.append { [weak self] in self?.forceActivate(forceable) }
        }
        alert.addButton(withTitle: actions.isEmpty ? L("OK") : L("キャンセル")).keyEquivalent = actions.isEmpty ? "\r" : "\u{1b}"
        let index = alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        if actions.indices.contains(index) { actions[index]() }
    }

    /// ぶつかっているフォントの登録を外してから、ライブラリのファイルをアクティブにする
    private func forceActivate(_ conflicts: [(file: FontFile, path: String)]) {
        var released = Set<String>()
        var failures: [String] = []
        for path in Set(conflicts.map(\.path)) {
            if let reason = FontActivation.unregister(path: path) {
                failures.append((path as NSString).lastPathComponent + " — " + reason)
            } else {
                released.insert(path)
            }
        }
        // ライブラリのファイルどうしでぶつかっていたなら、相手はアクティブの記録からも外す
        let releasedIDs = Set(data.files.filter { file in released.contains { FontActivation.samePath($0, file.path) } }.map(\.id))
        var changed = 0
        var updated = data
        updated.active.subtract(releasedIDs)
        for (file, path) in conflicts where released.contains(path) {
            if let error = FontActivation.activate(file) {
                failures.append("\(file.fileName) — \(error)")
                continue
            }
            if case .conflict = FontActivation.state(of: file) {
                _ = FontActivation.deactivate(file)
                failures.append("\(file.fileName) — \(L("登録を外しても、同じ名前のフォントが使われたままです"))")
                continue
            }
            updated.active.insert(file.id)
            if let index = updated.files.firstIndex(where: { $0.id == file.id }) { updated.files[index].activatedAt = Date() }
            changed += 1
        }
        data = updated
        save()
        refreshStates()
        status = L("%d個のファイルを強制的にアクティブにしました", changed) + (failures.isEmpty ? "" : L("、失敗 %d", failures.count))
        if !failures.isEmpty {
            message = (L("強制的にアクティブにできなかったファイルがあります"), failures.prefix(20).joined(separator: "\n"))
        }
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
    func setState(_ id: UUID) -> Bool? { groupState(id) { setFiles(id) } }

    func setFiles(_ id: UUID) -> [FontFile] { files(withIDs: data.sets.first { $0.id == id }?.files ?? []) }

    /// id のファイルをライブラリの順で返す
    private func files(withIDs ids: [UUID]) -> [FontFile] {
        if positionCache == nil {
            var positions: [UUID: Int] = [:]
            for (index, file) in data.files.enumerated() { positions[file.id] = index }
            positionCache = positions
        }
        let positions = positionCache ?? [:]
        return Set(ids).compactMap { positions[$0] }.sorted().map { data.files[$0] }
    }

    /// セット・プロジェクトのアクティブの状態：すべて／一部（nil）／なし。System・Adobe Fonts と見つからないファイルは数えない
    private func groupState(_ id: UUID, _ files: () -> [FontFile]) -> Bool? {
        if let cached = groupStateCache[id] { return cached }
        let targets = files().filter { !Self.isLocked($0) && states[$0.id] != .missing }
        let active = targets.filter { states[$0.id] == .active }.count
        let state: Bool? = active == 0 ? false : active == targets.count ? true : nil
        groupStateCache[id] = state
        return state
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

    // MARK: ライブラリの再構築

    /// 全ファイルの情報を読み直し、無いファイルはウォッチフォルダー・フォントフォルダーから同じファイル名・PostScript名で探してつなぎ直し（id を保つ）、
    /// フォルダーの新しいファイルを足し、それでも見つからないものは取り除くか選ぶ。最後に無い id への参照を掃除して保存し直す
    func rebuildLibrary() {
        guard !isBusy else { return }
        let alert = NSAlert()
        alert.messageText = L("ライブラリを再構築しますか？")
        alert.informativeText = L("%d個のファイルの情報を読み直し、場所が変わったファイルをつなぎ直し、フォルダーの新しいファイルを足します。件数が多いと数十秒から数分かかります。フォントのアクティブの状態は変わりません。", data.files.count)
        alert.addButton(withTitle: L("再構築"))
        alert.addButton(withTitle: L("キャンセル")).keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        isBusy = true
        status = L("ライブラリを再構築中…")
        TaskProgress.shared.begin(L("ライブラリを再構築中…"))
        let files = data.files
        let folders = (WatchFolders.shared.folders + (includeUserFonts ? SystemFolder.scanned.map(\.path) : []))
            .map { URL(fileURLWithPath: $0) }
        Task.detached(priority: .userInitiated) {
            var refreshed: [UUID: FontFile] = [:]
            var missing: [FontFile] = []
            for (index, file) in files.enumerated() {
                if index % 200 == 0 {
                    let done = index
                    await MainActor.run {
                        LibraryStore.shared.status = L("ライブラリを再構築中…（%d／%d）", done, files.count)
                        TaskProgress.shared.update(done, of: files.count, detail: L("ファイルを読み直しています（%d／%d）", done, files.count))
                    }
                }
                guard FileManager.default.fileExists(atPath: file.path) else { missing.append(file); continue }
                guard var fresh = FontScanner.read(file.url) else { continue }
                fresh.id = file.id
                fresh.added = file.added
                fresh.activatedAt = file.activatedAt
                fresh.deactivatedAt = file.deactivatedAt
                refreshed[file.id] = fresh
            }
            // フォルダーにあってライブラリに無いファイル。見つからないファイルのつなぎ直し先の候補にもする
            await MainActor.run { TaskProgress.shared.step(L("フォルダーの新しいファイルを探しています…")) }
            let known = Set(files.map(\.path))
            let adobe = Self.registeredAdobeFontPaths()
            let candidates = FontScanner.fontURLs(in: folders).filter {
                let path = $0.standardizedFileURL.path
                return !known.contains(path) && (SystemFolder.of(path) != .adobeFonts || adobe.contains(path))
            }
            var byName: [String: [URL]] = [:]
            for url in candidates { byName[url.lastPathComponent, default: []].append(url) }
            var relinked: [UUID: FontFile] = [:]
            var used = Set<String>()
            for file in missing {
                for url in byName[file.fileName] ?? [] where !used.contains(url.path) {
                    guard var fresh = FontScanner.read(url), fresh.faces.first?.postScriptName == file.faces.first?.postScriptName else { continue }
                    fresh.id = file.id
                    fresh.added = file.added
                    fresh.activatedAt = file.activatedAt
                    fresh.deactivatedAt = file.deactivatedAt
                    relinked[file.id] = fresh
                    used.insert(url.path)
                    break
                }
            }
            let newURLs = candidates.filter { !used.contains($0.path) }
            var added: [FontFile] = []
            for (index, url) in newURLs.enumerated() {
                if index % 100 == 0 {
                    let done = index
                    await MainActor.run {
                        TaskProgress.shared.update(done, of: newURLs.count, detail: L("新しいファイルを読んでいます（%d／%d）", done, newURLs.count))
                    }
                }
                if let file = FontScanner.read(url), !LibraryStore.isHiddenSystemFont(file) { added.append(file) }
            }
            let stillMissing = missing.filter { relinked[$0.id] == nil }
            let result = (refreshed, relinked, added, stillMissing)
            await MainActor.run { TaskProgress.shared.step(L("保存しています…")) }
            await MainActor.run { LibraryStore.shared.finishRebuild(result.0, result.1, result.2, result.3) }
        }
    }

    private func finishRebuild(_ refreshed: [UUID: FontFile], _ relinked: [UUID: FontFile], _ added: [FontFile], _ missing: [FontFile]) {
        var updated = data
        for index in updated.files.indices {
            let id = updated.files[index].id
            if let fresh = refreshed[id] ?? relinked[id] { updated.files[index] = fresh }
        }
        let addedCount = added.isEmpty ? 0 : updated.add(added)
        data = updated
        isBusy = false
        TaskProgress.shared.end()
        var removed = 0
        if !missing.isEmpty {
            let alert = NSAlert()
            alert.messageText = L("見つからないファイルが%d個あります", missing.count)
            alert.informativeText = L("ファイルを移動・削除したか、外付けディスクやDropboxのファイルがこのMacに無い可能性があります。ライブラリから取り除きますか？（セット・プロジェクトからも外れます。フォントファイルは削除しません）")
                + "\n\n" + missing.prefix(10).map(\.path).joined(separator: "\n") + (missing.count > 10 ? "\n…" : "")
            alert.addButton(withTitle: L("残す"))
            alert.addButton(withTitle: L("取り除く"))
            if alert.runModal() == .alertSecondButtonReturn {
                data.remove(Set(missing.map(\.id)))
                removed = missing.count
            }
        }
        // ウォッチフォルダーを外したあとに残ったファイルも、ここで取り除けるようにする
        let outside = filesOutsideWatchFolders()
        removed += offerRemoving(outside, message: L("ウォッチフォルダーの外にあるファイルが%d個あります", outside.count),
                                detail: L("ウォッチフォルダーから外したフォルダーや、ウォッチフォルダーの外から追加したファイルです。ライブラリから取り除きますか？"))
        removeDanglingReferences()
        save()
        refreshStates()
        validateSidebar()
        status = L("ライブラリを再構築しました：読み直し %d、つなぎ直し %d、追加 %d、見つからない %d", refreshed.count, relinked.count, addedCount, missing.count)
            + (removed > 0 ? L("（取り除き %d）", removed) : "")
    }

    /// 無い id への参照（セット・プロジェクト・アクティブ）を掃除する
    private func removeDanglingReferences() {
        let ids = Set(data.files.map(\.id))
        var cleaned = data
        cleaned.active = cleaned.active.filter(ids.contains)
        for index in cleaned.sets.indices { cleaned.sets[index].files.removeAll { !ids.contains($0) } }
        for index in cleaned.projects.indices {
            cleaned.projects[index].matched.removeAll { !ids.contains($0) }
            cleaned.projects[index].candidates.removeAll { !ids.contains($0.file) }
            cleaned.projects[index].refreshFiles()
        }
        data = cleaned
    }

    // MARK: ウォッチフォルダーの外のファイル

    /// ウォッチフォルダーにもフォントフォルダーにも入っていないファイル。within があればそのフォルダーの中のものだけ
    func filesOutsideWatchFolders(within roots: [String]? = nil) -> [FontFile] {
        let slash = { (path: String) in path.hasSuffix("/") ? path : path + "/" }
        let watched = WatchFolders.shared.folders.map(slash)
        let scope = roots?.map(slash)
        return data.files.filter { file in
            !Self.isInstalled(file) && !watched.contains { file.path.hasPrefix($0) }
                && (scope.map { roots in roots.contains { file.path.hasPrefix($0) } } ?? true)
        }
    }

    /// 取り除いてよいか尋ね、よければアクティブを解除してライブラリから取り除く（フォントファイルは消さない）。取り除いた数を返す
    @discardableResult
    private func offerRemoving(_ files: [FontFile], message: String, detail: String) -> Int {
        guard !files.isEmpty else { return 0 }
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail + "\n" + L("アクティブなものは解除し、セット・プロジェクトからも外れます。フォントファイルは削除しません。")
            + "\n\n" + files.prefix(10).map(\.path).joined(separator: "\n") + (files.count > 10 ? "\n…" : "")
        alert.addButton(withTitle: L("残す"))
        alert.addButton(withTitle: L("取り除く"))
        guard alert.runModal() == .alertSecondButtonReturn else { return 0 }
        for file in files where data.active.contains(file.id) { _ = FontActivation.deactivate(file) }
        data.remove(Set(files.map(\.id)))
        return files.count
    }

    /// ウォッチフォルダーを外したとき：その中にあったファイルをライブラリからも取り除くか尋ねる
    func unwatched(_ paths: [String]) {
        guard !isBusy else { return }
        let files = filesOutsideWatchFolders(within: paths)
        let removed = offerRemoving(files, message: L("外したフォルダーのフォント%d個を、ライブラリからも取り除きますか？", files.count),
                                    detail: L("残すと、フォルダーを見張らなくなるだけで、一覧には出たままです。"))
        guard removed > 0 else { return }
        removeDanglingReferences()
        selection.removeAll()
        save()
        refreshStates()
        validateSidebar()
        status = L("%d個のファイルを取り除きました", removed)
    }

    // MARK: 重複の優先（ウォッチフォルダーの順）

    /// 優先の順位：設定のウォッチフォルダーの一覧で上にあるフォルダーほど小さい。どのウォッチフォルダーにも入っていなければその後ろ（ユーザー指定）
    func priority(of file: FontFile) -> Int {
        let folders = WatchFolders.shared.folders
        for (index, folder) in folders.enumerated() where file.path.hasPrefix(folder.hasSuffix("/") ? folder : folder + "/") {
            return index
        }
        return folders.count
    }

    /// PostScript名が同じ別の書体があれば、そのパス（名前の衝突）
    func nameClash(_ file: FontFile) -> String? {
        if nameClashCache == nil { computeDuplicates() }
        return nameClashCache?[file.id]
    }

    /// 重複しているファイルが優先か（true）優先でないか（false）。重複していない、または優先が決まらない候補なら nil
    func duplicatePreference(_ file: FontFile) -> Bool? {
        if preferenceCache == nil { computeDuplicates() }
        return preferenceCache?[file.id]
    }

    /// 優先が決まらない重複の組（組の全ファイル）。「重複フォントを解決」で使う
    var undecidedDuplicateGroups: [[FontFile]] {
        if undecidedCache == nil { computeDuplicates() }
        return undecidedCache ?? []
    }

    /// 重複の組ごとに優先を決め、「重複」の一覧・優先の印・決まらない組を一度に作る
    private func computeDuplicates() {
        var groups: [String: [FontFile]] = [:]
        var byName: [String: [FontFile]] = [:]
        for file in data.files {
            guard let name = file.faces.first?.postScriptName else { continue }
            // バリアブルフォントと個別のウエイトのファイルは、名前付きインスタンスの PostScript名が同じでも別物として扱う（ユーザー指定）
            groups[Self.duplicateKey(file, name), default: []].append(file)
            byName[name, default: []].append(file)
        }
        // 名前の衝突：PostScript名は同じだが別の書体（重複の組が異なる）。同時にアクティブにするとアプリからは一方しか見えない
        var clashes: [UUID: String] = [:]
        for (name, files) in byName where files.count > 1 {
            let keys = files.map { Self.duplicateKey($0, name) }
            guard Set(keys).count > 1 else { continue }
            for (file, key) in zip(files, keys) {
                if let other = zip(files, keys).first(where: { $0.1 != key })?.0 { clashes[file.id] = other.path }
            }
        }
        nameClashCache = clashes
        var preference: [UUID: Bool] = [:]
        var undecided = Set<UUID>()
        var undecidedGroups: [[FontFile]] = []
        // 設定は組ごとに読み直さず、1回だけ読む
        let settings = PreferenceSettings.current
        for group in groups.values where group.count > 1 {
            let candidates = Set(preferenceCandidates(group, settings).map(\.id))
            if candidates.count == 1 {
                for member in group { preference[member.id] = candidates.contains(member.id) }
            } else {
                // 候補より下の順位のものは、どれが優先でも優先外
                for member in group where !candidates.contains(member.id) { preference[member.id] = false }
                undecided.formUnion(group.map(\.id))
                undecidedGroups.append(group)
            }
        }
        preferenceCache = preference
        duplicateCache = undecided
        undecidedCache = undecidedGroups
        if !hashWanted.isEmpty {
            // 描画の途中で data を書き換えないよう、次の回に回す
            DispatchQueue.main.async { LibraryStore.shared.hashPendingFiles() }
        }
    }

    /// 重複の組で優先の候補として残るファイル（1つなら決まり）。ウォッチフォルダーの順位 → 規則 → ファイルごとの選択 →
    /// ファイルの中身で決める条件（形式・バージョン・字形数を設定の順に）で絞る。
    /// 自分で選んだ規則・選択を、自動の形式より先に使う
    func preferenceCandidates(_ group: [FontFile]) -> [FontFile] {
        preferenceCandidates(group, .current)
    }

    /// 重複の優先を決める設定（ウォッチフォルダーの順・自動の条件・形式の順）。重複の組を数千組まとめて判定するときに1回だけ読む
    struct PreferenceSettings {
        /// 末尾に「/」を付けたウォッチフォルダー（上から順位）
        var folderPrefixes: [String]
        /// 規則の優先するフォルダー・負けるフォルダー（末尾に「/」を付けたもの。FolderRule.prefers と同じ比べ方）
        var rules: [(preferred: String, other: String)]
        /// 「フォルダー/」→ その側に当たる規則の番号（パスの区切りごとに引く）
        var preferredIndex: [String: [Int]] = [:]
        var otherIndex: [String: [Int]] = [:]
        var criteria: [AutoCriterion]
        var formatOrder: [String]
        var pickIdentical: Bool

        @MainActor static var current: PreferenceSettings {
            var settings = PreferenceSettings(
                folderPrefixes: WatchFolders.shared.folders.map { $0.hasSuffix("/") ? $0 : $0 + "/" },
                // 簡易版はフォルダーの規則を使わない（共有ファイルの folderRules は読み書きだけ残す、ユーザー指定）
                rules: [],
                criteria: LibraryStore.autoCriteriaOrder().filter { UserDefaults.standard.bool(forKey: $0.enabledKey) },
                formatOrder: LibraryStore.formatOrder(),
                pickIdentical: UserDefaults.standard.bool(forKey: LibraryStore.pickIdenticalKey))
            for (index, rule) in settings.rules.enumerated() {
                settings.preferredIndex[rule.preferred, default: []].append(index)
                settings.otherIndex[rule.other, default: []].append(index)
            }
            return settings
        }

        func priority(of file: FontFile) -> Int {
            folderPrefixes.firstIndex { file.path.hasPrefix($0) } ?? folderPrefixes.count
        }

        /// 規則でほかのどれかに負けるファイルの番号。各ファイルが規則のどちら側に当たるかを先に1回だけ調べ、
        /// 規則ごとのビットで比べる（組の中の全組み合わせ × 規則の数だけ文字列を比べると、200件の組で数百万回になる）
        func beatenIndices(_ files: [FontFile]) -> Set<Int> {
            let words = (rules.count + 63) / 64
            // パスを「/」の位置ごとに切った親フォルダーで引く（規則の数だけ前方一致を試さない）
            func masks(_ index: [String: [Int]]) -> [[UInt64]] {
                files.map { file in
                    var mask = [UInt64](repeating: 0, count: words)
                    let path = file.path
                    var cursor = path.startIndex
                    while let slash = path[cursor...].firstIndex(of: "/") {
                        let next = path.index(after: slash)
                        for rule in index[String(path[..<next])] ?? [] { mask[rule / 64] |= 1 << UInt64(rule % 64) }
                        cursor = next
                    }
                    return mask
                }
            }
            let wins = masks(preferredIndex)
            let loses = masks(otherIndex)
            var beaten = Set<Int>()
            for loser in files.indices where loses[loser].contains(where: { $0 != 0 }) {
                for winner in files.indices where winner != loser && files[winner].id != files[loser].id {
                    if zip(wins[winner], loses[loser]).contains(where: { $0 & $1 != 0 }) { beaten.insert(loser); break }
                }
            }
            return beaten
        }
    }

    private func preferenceCandidates(_ group: [FontFile], _ settings: PreferenceSettings) -> [FontFile] {
        // 自分で選んだ優先（一覧の「選んだフォントを優先にする」など）は、フォルダーの順・規則より先に使う
        let chosen = group.filter { data.preferredFiles.contains($0.id) }
        if chosen.count == 1 { return chosen }
        let ranks = group.map { settings.priority(of: $0) }
        let top = ranks.min() ?? 0
        var tied = zip(group, ranks).filter { $0.1 == top }.map(\.0)
        guard tied.count > 1 else { return tied }
        if !settings.rules.isEmpty {
            let beaten = settings.beatenIndices(tied)
            // 規則どうしが食い違ってすべて負けるときは、絞らない
            if beaten.count < tied.count { tied = tied.indices.filter { !beaten.contains($0) }.map { tied[$0] } }
        }
        for criterion in settings.criteria where tied.count > 1 {
            tied = Self.narrow(tied, by: criterion, formatOrder: settings.formatOrder)
        }
        if tied.count > 1 && settings.pickIdentical {
            let hashes = tied.map(\.contentHash)
            if hashes.contains(where: { $0 == nil }) {
                // まだ計っていない。裏で計り、終わったら決め直す
                hashWanted.formUnion(tied.filter { $0.contentHash == nil }.map(\.id))
            } else if let first = hashes.first ?? nil, !first.isEmpty, hashes.allSatisfy({ $0 == first }) {
                // 中身が同じならどれでも同じ。先に登録したもの（同じなら場所の名前順）にする
                if let pick = tied.min(by: { ($0.added, $0.path) < ($1.added, $1.path) }) { return [pick] }
            }
        }
        return tied
    }

    /// 中身のハッシュを計りたいファイル（決まらない重複の候補）
    private var hashWanted = Set<UUID>()
    private var isHashing = false

    /// 候補のファイルの中身を裏で計り、保存して決め直す
    private func hashPendingFiles() {
        guard !isHashing, !hashWanted.isEmpty else { return }
        let ids = hashWanted
        hashWanted.removeAll()
        let files = data.files.filter { ids.contains($0.id) }.map { (id: $0.id, path: $0.path) }
        guard !files.isEmpty else { return }
        isHashing = true
        Task.detached(priority: .utility) {
            var hashes: [UUID: String] = [:]
            for file in files { hashes[file.id] = FontScanner.contentHash(URL(fileURLWithPath: file.path)) ?? "" }
            let result = hashes
            await MainActor.run {
                let store = LibraryStore.shared
                var data = store.data
                for index in data.files.indices {
                    if let hash = result[data.files[index].id] { data.files[index].contentHash = hash }
                }
                store.isHashing = false
                store.data = data
                store.save()
            }
        }
    }

    /// 条件でいちばん良いものだけ残す。値が分からないファイルがあるときは比べない（バージョン・字形数）
    private static func narrow(_ files: [FontFile], by criterion: AutoCriterion, formatOrder order: [String]) -> [FontFile] {
        let scores: [Double]
        switch criterion {
        case .format:
            // 順で上の形式ほど良い（順に無い形式は最後）
            scores = files.map { -Double(order.firstIndex(of: ($0.path as NSString).pathExtension.lowercased()) ?? order.count) }
        case .version:
            guard files.allSatisfy({ ($0.fontRevision ?? 0) > 0 }) else { return files }
            scores = files.map { $0.fontRevision ?? 0 }
        case .glyphs:
            guard files.allSatisfy({ $0.glyphCount != nil }) else { return files }
            scores = files.map { Double($0.glyphCount ?? 0) }
        }
        let best = scores.max() ?? 0
        // fontRevision は 16.16 の固定小数点なので、ごく小さい差は同じとみなす
        return zip(files, scores).filter { best - $0.1 < 0.0001 }.map(\.0)
    }

    /// 優先の順に並べる（同じ順位なら優先と決まったもの、次にライブラリの順）
    func byPriority(_ files: [FontFile]) -> [FontFile] {
        // 順位は先に1回だけ計る（並べ替えの比較のたびに計ると3万件で遅い）
        let ranked = files.enumerated().map { (rank: priority(of: $0.element), preferred: duplicatePreference($0.element) == true,
                                               offset: $0.offset, file: $0.element) }
        return ranked.sorted {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            if $0.preferred != $1.preferred { return $0.preferred }
            return $0.offset < $1.offset
        }.map(\.file)
    }

    /// 衝突しているファイル（同じ PostScript名のフォントが別の場所で使われている）
    func conflictingFiles(_ files: [FontFile]) -> [FontFile] {
        files.filter { if case .conflict = states[$0.id] { return true } else { return false } }
    }

    /// 選んだフォントと衝突しているほかのファイルの登録を外す（ファイルは動かさない）。外したあと、選んだフォントをアクティブにできる
    func releaseConflicts(_ files: [FontFile]) {
        var paths: [String] = []
        for file in files {
            if case .conflict(let path)? = states[file.id], !paths.contains(path) { paths.append(path) }
        }
        guard !paths.isEmpty else { status = L("衝突しているフォントはありません"); return }
        var released = 0
        var failures: [String] = []
        for path in paths {
            if let reason = FontActivation.unregister(path: path) {
                failures.append((path as NSString).lastPathComponent + "：" + reason)
            } else {
                released += 1
            }
        }
        refreshStates()
        status = L("衝突しているフォント%d個の登録を外しました", released) + (failures.isEmpty ? "" : L("、外せなかったもの %d", failures.count))
        if !failures.isEmpty {
            message = (L("外せなかった登録があります"), failures.joined(separator: "\n"))
        }
    }

    /// 重複の組の見出し。バリアブルフォントと個別のウエイトは別の組にする。
    /// 正体とイタリックで PostScript名が同じに作られたフォント（Eighties Comeback の UltraCon ExtBd）もあるので、
    /// スタイル名がイタリックかどうかでも分ける（スタイル名そのものは版で「Narrow Italic」「Italic」などと揺れるので使わない）
    static func duplicateKey(_ file: FontFile, _ postScriptName: String) -> String {
        let style = file.faces.first?.style ?? ""
        let italic = ["italic", "oblique", "slanted", "kursiv"].contains { style.localizedCaseInsensitiveContains($0) }
        return (file.isVariable == true ? "variable:" : "static:") + postScriptName + (italic ? "|italic" : "")
    }

    /// 一覧で選んだフォントを、それぞれの重複の組の優先にする（ウォッチフォルダーの順より先に使う）。
    /// 同じ組から2つ以上選んだときは、どちらを優先にするか分からないので、その組は変えない
    func preferSelected(_ files: [FontFile]) {
        var groups: [String: [FontFile]] = [:]
        for file in data.files {
            guard let name = file.faces.first?.postScriptName else { continue }
            groups[Self.duplicateKey(file, name), default: []].append(file)
        }
        var picks: [String: [FontFile]] = [:]
        for file in files {
            guard let name = file.faces.first?.postScriptName else { continue }
            let key = Self.duplicateKey(file, name)
            guard (groups[key]?.count ?? 0) > 1 else { continue }
            picks[key, default: []].append(file)
        }
        var updated = data
        var done = 0, ambiguous = 0
        for (key, picked) in picks {
            guard picked.count == 1, let pick = picked.first else { ambiguous += 1; continue }
            for member in groups[key] ?? [] { updated.preferredFiles.remove(member.id) }
            updated.preferredFiles.insert(pick.id)
            done += 1
        }
        guard done > 0 else {
            status = ambiguous > 0 ? L("同じ重複の組から2つ以上選んでいるため、優先を決められませんでした") : L("選んだフォントに重複はありません")
            return
        }
        data = updated
        save()
        status = L("%d組の重複を、選んだフォントを優先にして解決しました", done) + (ambiguous > 0 ? L("（2つ以上選んだ%d組はそのまま）", ambiguous) : "")
    }

    /// 選んだフォントに、ほかのファイルと重複しているものがあるか（メニューを出すかどうか）
    func hasDuplicates(_ files: [FontFile]) -> Bool {
        files.contains { duplicatePreference($0) != nil || duplicateIDs.contains($0.id) }
    }

    /// 規則にできない組で、このファイルを優先にする（同じ組のほかのファイルの選択は外す）
    func pickPreferred(_ file: FontFile, in group: [FontFile]) {
        for member in group { data.preferredFiles.remove(member.id) }
        data.preferredFiles.insert(file.id)
        save()
    }

    func clearPreferredFiles() {
        data.preferredFiles.removeAll()
        save()
    }

    /// 優先でない重複（一覧で「優先外」のファイル）。範囲は一覧で選んだもの、選んでいなければライブラリ全体
    func nonPreferredDuplicates() -> [FontFile] {
        let scope = selectedFiles.isEmpty ? visibleFiles : selectedFiles
        return scope.filter { duplicatePreference($0) == false }
    }

    func deactivateNonPreferredDuplicates() {
        let files = nonPreferredDuplicates().filter { states[$0.id] == .active && !Self.isLocked($0) }
        guard !files.isEmpty else { status = L("アクティブな優先外の重複はありません"); return }
        setActive(files, false)
    }

    /// ライブラリから取り除く（確認は remove が出す。フォントフォルダー・Adobe Fonts のファイルは取り除かない）
    func removeNonPreferredDuplicates() {
        let files = nonPreferredDuplicates()
        guard !files.isEmpty else { status = L("優先外の重複はありません"); return }
        remove(files)
    }

    /// まとめてアクティブにするファイルから、同じ PostScript 名の重複を優先のものだけにする（1つだけ選んだときはそのまま）
    func preferredAmongDuplicates(_ files: [FontFile]) -> [FontFile] {
        var seen = Set<String>()
        var kept = Set<UUID>()
        for file in byPriority(files) {
            guard let name = file.faces.first?.postScriptName else { kept.insert(file.id); continue }
            // 重複の組と同じく、バリアブルフォントと個別のウエイトは別物とする
            if seen.insert(Self.duplicateKey(file, name)).inserted { kept.insert(file.id) }
        }
        return files.filter { kept.contains($0.id) }
    }

    // MARK: 条件を自分で作るスマートセット

    func newSmartSet() {
        SmartSetEditorWindow.shared.show(SmartSet(name: L("名称未設定スマートセット")), isNew: true)
    }

    func saveSmartSet(_ smartSet: SmartSet) {
        var copy = smartSet
        copy.name = copy.name.trimmingCharacters(in: .whitespaces)
        if let index = data.smartSets.firstIndex(where: { $0.id == copy.id }) { data.smartSets[index] = copy } else { data.smartSets.append(copy) }
        save()
        sidebar = .smartSet(copy.id)
        selection.removeAll()
    }

    func deleteSmartSet(_ id: UUID) {
        guard let smartSet = data.smartSets.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = L("スマートセット「%@」を削除しますか？", smartSet.name)
        alert.informativeText = L("ライブラリのフォントとアクティブの状態はそのままです。")
        alert.addButton(withTitle: L("削除"))
        alert.addButton(withTitle: L("キャンセル")).keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        data.smartSets.removeAll { $0.id == id }
        if sidebar == .smartSet(id) { sidebar = .all }
        save()
    }

    // MARK: サイドバーの表示

    /// サイドバーの区分（簡易版は表示と並び順の設定を持たない。開閉だけ覚える）
    enum SidebarSection: String, CaseIterable {
        case system, smartSets, sets
        var title: String {
            switch self {
            case .system: return L("システム")
            case .smartSets: return L("スマートセット")
            case .sets: return L("セット")
            }
        }
        var expandedKey: String { "sidebarExpanded." + rawValue }
    }

    static var sidebarDefaults: [String: Any] {
        var values: [String: Any] = ["sidebarExpanded.library": true]
        for section in SidebarSection.allCases { values[section.expandedKey] = true }
        return values
    }

    /// ほかのMacで消されたセット・スマートセットを選んでいたら「すべてのフォント」に戻す
    func validateSidebar() {
        switch sidebar {
        case .set(let id) where !data.sets.contains(where: { $0.id == id }): sidebar = .all
        case .smartSet(let id) where !data.smartSets.contains(where: { $0.id == id }): sidebar = .all
        default: break
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

    func openAdobeFontsWeb() {
        if let url = URL(string: "https://fonts.adobe.com/my_fonts") { NSWorkspace.shared.open(url) }
    }

    func revealInFinder(_ files: [FontFile]) {
        NSWorkspace.shared.activateFileViewerSelecting(files.map(\.url))
    }

    /// ライブラリのファイルがあるのに読めなかった（Dropbox のオンラインのみ・同期の途中など）。
    /// この間は保存しない。空に近いライブラリで共有ファイルを上書きし、ほかのMacのアクティブまで外してしまうため
    private var loadFailed = false

    private func load() {
        guard FileManager.default.fileExists(atPath: libraryURL.path) else { return }
        guard let loaded = read(libraryURL) else {
            loadFailed = true
            if message == nil {
                message = (L("ライブラリを読み込めませんでした"),
                           L("%@ を読めませんでした。同期の途中か、ファイルがこのMacに無い可能性があります。読めるようになるまで変更は保存しません。", libraryURL.path))
            }
            return
        }
        data = loaded
        loadFailed = false
        knownModification = modification(of: libraryURL)
    }

    /// ファイルを読み、場所の目印をこのMacの場所に戻す。読めないファイルは上書きされないよう控える
    private func read(_ url: URL) -> LibraryData? {
        guard let bytes = try? Data(contentsOf: url) else { return nil }
        do {
            var library = try JSONDecoder().decode(LibraryData.self, from: bytes).mapPaths { PortablePath.decode($0) }
            library.migrateProjects()
            library.decodeEscapedNames()
            return library
        } catch {
            let backup = url.deletingPathExtension().appendingPathExtension("unreadable.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: url, to: backup)
            message = (L("ライブラリを読み込めませんでした"), L("元のファイルを %@ に残しました。", backup.path))
            return nil
        }
    }

    private func save() {
        if loadFailed {
            // 読めるようになったか確かめる。読めたらそちらを元にし、この変更は捨てる（上書きしないため）
            load()
            if loadFailed { status = L("ライブラリを読めないため、変更を保存していません"); return }
        }
        // 共有ライブラリが、読んだあとにほかのMacで書き換わっていたら、上書きせずにこちらの内容を合わせてから書く
        if sharedFolder != nil, let date = modification(of: libraryURL), date != knownModification, let remote = read(libraryURL) {
            var merged = remote
            _ = merged.merge(data)
            let before = data.active
            let oldFiles = data.files
            data = merged
            applyActiveChanges(from: before, oldFiles: oldFiles)
        }
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
            (outdated || $0.vendor == nil || $0.trademarkOwner == nil || $0.isVariable == nil || $0.characterCount == nil || $0.supportsJapanese == nil || $0.isIcon == nil || $0.isHandwriting == nil || $0.fontRevision == nil || $0.faces.contains { $0.localizedFamily == nil }) && FileManager.default.fileExists(atPath: $0.path)
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
                    data.files[index].fontRevision = fresh.fontRevision
                    data.files[index].isHandwriting = fresh.isHandwriting
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
        // Adobe Fonts は設定と関係なく読む。フォントフォルダーは設定がオンのときだけ
        let known = Set(data.files.map(\.path))
        let folders = includeUserFonts ? SystemFolder.scanned.filter { !$0.includesHiddenFiles }.map { URL(fileURLWithPath: $0.path) } : []
        Task.detached(priority: .utility) {
            // Adobe Fonts は、いま macOS に登録されている（Creative Cloud でオンの）ファイルだけ
            let adobe = Self.registeredAdobeFontPaths()
            let urls = (FontScanner.fontURLs(in: folders) + adobe.map { URL(fileURLWithPath: $0) })
                .filter { !known.contains($0.standardizedFileURL.path) }
            let files = urls.compactMap(FontScanner.read).filter { !Self.isHiddenSystemFont($0) }
            await MainActor.run {
                let store = LibraryStore.shared
                // 消えたファイルと、Creative Cloud でオフにした Adobe Fonts（ファイルは残るが登録が外れる）を一覧から外す
                let goneFiles = store.data.files.filter {
                    Self.isInstalled($0) && (Self.isHiddenSystemFont($0) || !FileManager.default.fileExists(atPath: $0.path)
                        || SystemFolder.of($0.path) == .system
                        || (SystemFolder.of($0.path) == .adobeFonts && !adobe.contains($0.path)))
                }
                let gone = Set(goneFiles.map(\.id))
                if !gone.isEmpty {
                    // 消えたファイルは一覧から外すが、セット・プロジェクトからは外さず、戻ってきたら同じ id で入れ直す
                    var updated = store.data
                    // macOS のフォント（System）は読まなくなったので、戻ってくる場所として覚えない
                    for file in goneFiles where !Self.isHiddenSystemFont(file) && SystemFolder.of(file.path) != .system { updated.departed[file.path] = file.id }
                    updated.files.removeAll { gone.contains($0.id) }
                    updated.active.subtract(gone)
                    store.data = updated
                }
                let added = files.isEmpty ? 0 : store.data.add(files)
                guard added > 0 || !gone.isEmpty else { return }
                store.save()
                if added > 0 { store.status = L("フォントフォルダーから%d個のファイルを追加しました", added) }
                store.refreshStates()
            }
        }
    }

    /// macOS に登録されているフォントのうち、Adobe Fonts のフォルダーにあるファイル
    nonisolated static func registeredAdobeFontPaths() -> Set<String> {
        let root = SystemFolder.adobeFonts.path + "/"
        let urls = CTFontManagerCopyAvailableFontURLs() as? [URL] ?? []
        return Set(urls.map { $0.standardizedFileURL.path }.filter { $0.hasPrefix(root) })
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
        let oldFiles = data.files
        sharedFolder = folder.path
        UserDefaults.standard.set(folder.path, forKey: Self.sharedFolderKey)
        data = merged
        write(data, to: target)
        knownModification = modification(of: target)
        applyActiveChanges(from: before, oldFiles: oldFiles)
        validateSidebar()
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
        loadFailed = false
        applyActiveChanges(from: before, oldFiles: oldFiles)
        validateSidebar()
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
