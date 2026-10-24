import AppKit
import CoreServices

/// ウォッチフォルダー：選んだフォルダー（下の階層も）を見張り、新しいフォントファイルをライブラリに足す。
/// 場所はMacごとに覚える（共有ライブラリには入れない）。フォルダーから消えたファイルは「見つからない」に出る
@MainActor
final class WatchFolders: ObservableObject {
    static let shared = WatchFolders()
    static let key = "watchFolders"
    /// ライブラリから取り除いたファイル。ウォッチフォルダーの中にあっても足さない
    static let excludedKey = "watchFoldersExcluded"

    @Published private(set) var folders: [String] {
        didSet {
            UserDefaults.standard.set(folders, forKey: Self.key)
            restart()
            // 一覧の順は重複の優先にも使うので、一覧の印を作り直す
            LibraryStore.shared.invalidate()
        }
    }

    private var stream: FSEventStreamRef?
    private var watched: [String] = []
    private var pendingScan: DispatchWorkItem?
    private var excluded: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.excludedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: Self.excludedKey) }
    }

    private init() {
        folders = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
    }

    /// 起動時に一度読み、見張りを始める
    func start() {
        restart()
        scan()
    }

    func add() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = L("見張るフォルダーを選びます。新しいフォントファイルを見つけるとライブラリに追加します")
        panel.prompt = L("追加")
        guard panel.runModal() == .OK else { return }
        let new = panel.urls.map { $0.standardizedFileURL.path }.filter { !folders.contains($0) }
        guard !new.isEmpty else { return }
        folders += new
        scan()
    }

    /// 一覧の順を入れ替える（上ほど重複の優先が高い）
    func move(_ path: String, by offset: Int) {
        guard let index = folders.firstIndex(of: path), folders.indices.contains(index + offset) else { return }
        folders.swapAt(index, index + offset)
    }

    func remove(_ paths: Set<String>) {
        folders.removeAll { paths.contains($0) }
    }

    /// 取り除いたファイルのうち、ウォッチフォルダーの中にあるものを覚える
    func exclude(_ paths: [String]) {
        let inside = paths.filter { path in folders.contains { path.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") } }
        guard !inside.isEmpty else { return }
        excluded.formUnion(inside)
    }

    func include(_ paths: [String]) {
        let current = excluded
        guard !current.isDisjoint(with: paths) else { return }
        excluded = current.subtracting(paths)
    }

    /// 見張っていなかったフォルダーが見えるようになっていたら（外付けディスクをつないだなど）見張り直す
    func refresh() {
        let existing = folders.filter { FileManager.default.fileExists(atPath: $0) }
        if existing != watched { restart(); scan() }
    }

    /// フォルダーの中で、まだライブラリに無いフォントファイルを読んで足す
    func scan() {
        let urls = folders.map { URL(fileURLWithPath: $0) }
        guard !urls.isEmpty else { return }
        let known = Set(LibraryStore.shared.data.files.map(\.path)).union(excluded)
        Task.detached(priority: .utility) {
            let files = FontScanner.fontURLs(in: urls)
                .filter { !known.contains($0.standardizedFileURL.path) }
                .compactMap(FontScanner.read)
            guard !files.isEmpty else { return }
            await MainActor.run { LibraryStore.shared.importWatched(files) }
        }
    }

    /// 変更の通知は続けて届くので、落ち着いてから1回だけ読む
    private func scheduleScan() {
        pendingScan?.cancel()
        let work = DispatchWorkItem { Task { @MainActor in WatchFolders.shared.scan() } }
        pendingScan = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func restart() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
        let paths = folders.filter { FileManager.default.fileExists(atPath: $0) }
        watched = paths
        guard !paths.isEmpty else { return }
        let callback: FSEventStreamCallback = { _, _, _, _, _, _ in
            Task { @MainActor in WatchFolders.shared.scheduleScan() }
        }
        var context = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        guard let created = FSEventStreamCreate(nil, callback, &context, paths as CFArray,
                                                FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0,
                                                FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)) else { return }
        FSEventStreamSetDispatchQueue(created, DispatchQueue.main)
        FSEventStreamStart(created)
        stream = created
    }
}
