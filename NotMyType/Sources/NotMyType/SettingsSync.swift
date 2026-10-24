import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Immutable, per-change records. No Mac replaces a file written by another Mac.
/// Registers merge per UserDefaults key (arrays/data remain one setting), ordered by
/// logical revision then UUID, so offline edits converge without relying on wall clocks.
enum SettingsSyncJournal {
    struct State {
        var values: NSDictionary
        var revision: Int64
        var modified: Date?
        var hasRecords: Bool
    }
    enum Failure: Error { case invalidRecord(String), revisionOverflow }

    static func read(_ directory: URL, app: String) throws -> State {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return State(values: [:], revision: 0, modified: nil, hasRecords: false)
        }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "plist" }
        var winners: [String: (Int64, String, Any?)] = [:]
        var revision: Int64 = 0
        var modified: Date?
        for file in files {
            // A partially downloaded record must not look like a deleted setting.
            guard let record = NSDictionary(contentsOf: file), record["version"] as? Int == 2,
                  record["app"] as? String == app, let id = record["id"] as? String,
                  UUID(uuidString: id) != nil, let clock = record["revision"] as? NSNumber,
                  clock.int64Value >= 0, let date = record["modified"] as? Date,
                  let values = record["values"] as? NSDictionary,
                  let deleted = record["deleted"] as? [String],
                  Set(deleted).isDisjoint(with: Set(values.allKeys.compactMap { $0 as? String })),
                  values.allKeys.allSatisfy({ $0 is String }) else {
                throw Failure.invalidRecord(file.lastPathComponent)
            }
            let n = clock.int64Value
            revision = max(revision, n)
            modified = max(modified ?? .distantPast, date)
            func accept(_ key: String, _ value: Any?) {
                if let old = winners[key], old.0 > n || (old.0 == n && old.1 >= id) { return }
                winners[key] = (n, id, value)
            }
            for (key, value) in values { accept(key as! String, value) }
            for key in deleted { accept(key, nil) }
        }
        let result = NSMutableDictionary()
        for (key, entry) in winners { if let value = entry.2 { result[key] = value } }
        return State(values: result, revision: revision, modified: modified, hasRecords: !files.isEmpty)
    }

    static func changes(from baseline: NSDictionary, to values: NSDictionary) -> (NSDictionary, [String]) {
        let changed = NSMutableDictionary()
        for (key, value) in values {
            let key = key as! String
            if !equal(baseline[key], value) { changed[key] = value }
        }
        let removed = baseline.allKeys.compactMap { $0 as? String }.filter { values[$0] == nil }
        return (changed, removed)
    }

    static func equal(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case let (a?, b?): return NSDictionary(dictionary: ["v": a]).isEqual(to: ["v": b])
        default: return false
        }
    }

    static func append(_ directory: URL, app: String, device: String, revision: Int64,
                       values: NSDictionary, deleted: [String]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let record: NSDictionary = ["version": 2, "app": app, "id": id, "device": device,
                                    "modified": Date(), "revision": NSNumber(value: revision),
                                    "values": values, "deleted": deleted]
        let data = try PropertyListSerialization.data(fromPropertyList: record, format: .xml, options: 0)
        // A unique file is created exactly once. Atomic rename prevents partial reads on this Mac.
        let file = directory.appendingPathComponent(id + ".plist")
        guard !FileManager.default.fileExists(atPath: file.path) else { throw Failure.invalidRecord(id) }
        try data.write(to: file, options: .atomic)
    }

    static func synchronize(directory: URL, app: String, device: String,
                            baseline: NSDictionary?, current: NSDictionary, seed: NSDictionary) throws -> State {
        var state = try read(directory, app: app)
        if !state.hasRecords {
            // Migration seeds share revision zero; real edits always outrank a late-arriving seed.
            try append(directory, app: app, device: device, revision: 0, values: seed, deleted: [])
            state = try read(directory, app: app)
        }
        let delta = changes(from: baseline ?? state.values, to: current)
        if delta.0.count > 0 || !delta.1.isEmpty {
            guard state.revision < Int64.max else { throw Failure.revisionOverflow }
            try append(directory, app: app, device: device, revision: state.revision + 1,
                       values: delta.0, deleted: delta.1)
            state = try read(directory, app: app)
        }
        return state
    }

    /// Accept app-side normalization, excluding user edits that arrived during I/O.
    static func acceptedBaseline(remote: NSDictionary, captured: NSDictionary,
                                 beforeApply: NSDictionary, afterApply: NSDictionary) -> NSDictionary {
        let pending = changes(from: captured, to: beforeApply)
        let result = afterApply.mutableCopy() as! NSMutableDictionary
        let pendingKeys = Set(pending.0.allKeys.compactMap { $0 as? String } + pending.1)
        for key in pendingKeys {
            if let value = remote[key] { result[key] = value }
            else { result.removeObject(forKey: key) }
        }
        return result
    }

    /// Preserve edits made while a background scan/write was in flight.
    static func overlayEdits(from captured: NSDictionary, to current: NSDictionary, on remote: NSDictionary) -> NSDictionary {
        let delta = changes(from: captured, to: current)
        let result = remote.mutableCopy() as! NSMutableDictionary
        for (key, value) in delta.0 { result[key as! String] = value }
        for key in delta.1 { result.removeObject(forKey: key) }
        return result
    }
}

/// Shared settings export/import and sync.
/// 書き出し・読み込み writes and reads the same keys as a "<App>-Settings.plist" file the user picks.
/// 設定の同期 appends immutable changes to "<App>-Settings.sync" in a folder the user picks
/// (iCloud Drive, Dropbox or any folder; modeled on Alfred's preferences folder). No iCloud entitlement needed.
/// Per-Mac state (login, residency, menu bar, excluded apps, window sizes, local paths, the folder itself) is never synced.
/// Per-key logical revisions resolve simultaneous changes deterministically. Legacy plist files are read only.
/// The folder is kept as a security-scoped bookmark for sandboxed builds.
/// Main-actor isolated (Swift 6 language mode compiles it); file I/O runs on a private queue.
@MainActor
final class SettingsSync: NSObject, ObservableObject {
    static let shared = SettingsSync()
    private static let folderKey = "settingsSyncFolder"
    private static let bookmarkKey = "settingsSyncFolderBookmark"
    private static let deviceKey = "settingsSyncDeviceID"
    private static let lastSyncKey = "settingsSyncLastDate"

    struct Configuration {
        /// Exact keys and key prefixes to sync.
        var keys: Set<String> = []
        var prefixes: [String] = []
        /// What is synced and what stays per Mac, already localized.
        var note: String
        var perMac: String
        /// Optional 「追加する」 on import: returns the current values with the file's new items added, and how many.
        /// Without it, importing replaces the synced settings.
        var merge: ((_ file: NSDictionary, _ current: NSDictionary) -> (values: NSDictionary, added: Int))? = nil
        /// Older per-app export files (extension without dot) and a converter to UserDefaults values.
        var legacyExtensions: [String] = []
        var legacyImport: ((Data) -> NSDictionary?)? = nil
    }

    /// Called on the main thread after settings from another Mac were applied.
    var onImport: (@MainActor () -> Void)?

    private var configuration = Configuration(note: "", perMac: "")
    private let defaults = UserDefaults.standard
    private nonisolated static let queue = DispatchQueue(label: "SettingsSync")
    /// Carries plist values across the file queue; NSDictionary is not Sendable.
    private struct Record: @unchecked Sendable { let value: NSDictionary? }
    private var lastValues: NSDictionary?
    private var lastRemoteValues: NSDictionary?
    private var pendingExport: DispatchWorkItem?
    private var timer: Timer?
    private var applying = false
    private var started = false
    private var synchronizing = false
    private var synchronizeAgain = false
    private var generation = UUID()
    private var baselineKey: String { "settingsSyncV2Baseline:" + (folder?.standardizedFileURL.path ?? "") }
    private var scopedURL: URL?
    @Published private(set) var pathText = ""
    @Published private(set) var statusText = ""
    @Published private(set) var statusIsError = false
    @Published private(set) var isEnabled = false
    @Published private(set) var isAvailable = false
    @Published private(set) var transferText = ""
    @Published private(set) var transferIsError = false

    private func text(_ ja: String, _ en: String, _ zh: String, _ ko: String) -> String { StartupWindow.text(ja, en, zh, ko) }
    var title: String { text("設定の同期", "Settings Sync", "设置同步", "설정 동기화") }
    /// Settings tab holding both groups: (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView()))
    var tabTitle: String { text("設定の共有", "Sharing", "设置共享", "설정 공유") }
    var transferTitle: String { text("書き出し・読み込み", "Export & Import", "导出与导入", "내보내기 및 가져오기") }
    var exportTitle: String { text("書き出す…", "Export…", "导出…", "내보내기…") }
    var importTitle: String { text("読み込む…", "Import…", "导入…", "가져오기…") }
    private var appName: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App" }

    var folder: URL? { defaults.string(forKey: Self.folderKey).map { URL(fileURLWithPath: $0, isDirectory: true) } }
    var enabled: Bool { folder != nil }
    private var fileName: String { "\(appName)-Settings.plist" }
    private var file: URL? { folder?.appendingPathComponent(fileName) }
    private var journal: URL? { folder?.appendingPathComponent("\(appName)-Settings.sync", isDirectory: true) }
    /// The folder is missing (sync service off, volume not mounted, or no sandbox access).
    var available: Bool { folder.map { FileManager.default.fileExists(atPath: $0.path) } ?? false }

    func isSynced(_ key: String) -> Bool {
        !key.hasPrefix("settingsSync") && (configuration.keys.contains(key) || configuration.prefixes.contains { key.hasPrefix($0) })
    }

    private var deviceID: String {
        if let id = defaults.string(forKey: Self.deviceKey) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: Self.deviceKey)
        return id
    }

    private func currentValues() -> NSDictionary {
        let domain = Bundle.main.bundleIdentifier.flatMap { defaults.persistentDomain(forName: $0) } ?? defaults.dictionaryRepresentation()
        return domain.filter { isSynced($0.key) } as NSDictionary
    }

    /// Default folder for the chooser: Dropbox (custom locations included, from ~/.dropbox/info.json), else iCloud Drive.
    private static var suggestedFolder: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        if let data = try? Data(contentsOf: home.appendingPathComponent(".dropbox/info.json")),
           let info = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]],
           let root = (info["personal"]?["path"] ?? info["business"]?["path"]) as? String,
           FileManager.default.fileExists(atPath: root) {
            return URL(fileURLWithPath: root, isDirectory: true)
        }
        return home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    func start(_ configuration: Configuration) {
        self.configuration = configuration
        guard !started else { return }
        started = true
        NotificationCenter.default.addObserver(self, selector: #selector(defaultsChanged), name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(check), name: NSApplication.didBecomeActiveNotification, object: nil)
        if enabled { accessFolder(); resume() }
        refreshStatus()
    }

    /// Resolves the saved bookmark; sandboxed builds can only reach the folder through it.
    private func accessFolder() {
        guard scopedURL == nil, let data = defaults.data(forKey: Self.bookmarkKey) else { return }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) else { return }
        if url.startAccessingSecurityScopedResource() { scopedURL = url }
        if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            defaults.set(fresh, forKey: Self.bookmarkKey)
        }
    }

    private func releaseFolder() {
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
    }

    private func resume(checkNow: Bool = true) {
        lastValues = defaults.dictionary(forKey: baselineKey).map { $0 as NSDictionary } ?? currentValues()
        lastRemoteValues = nil
        timer?.invalidate()
        // Resident apps are rarely active, so poll as well.
        timer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(check), userInfo: nil, repeats: true)
        if checkNow { check() }
    }

    /// UserDefaults may post from any thread.
    @objc private nonisolated func defaultsChanged() {
        DispatchQueue.main.async { [weak self] in MainActor.assumeIsolated { self?.scheduleExport() } }
    }

    private func scheduleExport() {
        guard enabled, !applying else { return }
        pendingExport?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.exportIfChanged() } }
        pendingExport = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private func exportIfChanged() { synchronize() }

    /// Both polling and local edits use one serialized read/merge/write transaction.
    /// A successful import does not create a new record (no echo between Macs).
    private func synchronize() {
        guard available, let folder, let journal, let legacyFile = file else { refreshStatus(); return }
        guard !synchronizing else { synchronizeAgain = true; return }
        synchronizing = true
        let epoch = generation
        let app = Bundle.main.bundleIdentifier ?? appName
        let device = deviceID
        let captured = Record(value: currentValues())
        let baseline = Record(value: lastValues)
        let lastSync = defaults.object(forKey: Self.lastSyncKey) as? Date ?? .distantPast
        Self.queue.async { [weak self] in
            var result: Record = Record(value: nil)
            var date: Date?
            var failed = false
            do {
                var seed = captured.value!
                // The old shared file is consulted only to seed an empty v2 journal.
                // It is never updated. Conflict copies remain available for manual import.
                if !FileManager.default.fileExists(atPath: journal.path), baseline.value != nil,
                   let old = NSDictionary(contentsOf: legacyFile), old["app"] as? String == app,
                   let modified = old["modified"] as? Date, modified > lastSync,
                   old["device"] as? String != device, let values = old["values"] as? NSDictionary {
                    seed = values
                }
                var coordinationError: NSError?
                var operationError: Error?
                NSFileCoordinator().coordinate(writingItemAt: folder, options: [], error: &coordinationError) { _ in
                    do {
                        let state = try SettingsSyncJournal.synchronize(directory: journal, app: app, device: device,
                            baseline: baseline.value, current: captured.value!, seed: seed)
                        result = Record(value: state.values)
                        date = state.modified
                    } catch { operationError = error }
                }
                failed = coordinationError != nil || operationError != nil || result.value == nil
            }
            let received = result
            let finishedDate = date
            let didFail = failed
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.synchronizing = false
                    guard self.generation == epoch, self.folder == folder else {
                        if self.enabled { self.synchronize() }
                        return
                    }
                    if !didFail, let raw = received.value {
                        let remote = NSMutableDictionary()
                        for (key, value) in raw {
                            if let key = key as? String, self.isSynced(key) { remote[key] = value }
                        }
                        let beforeApply = self.currentValues()
                        let merged = SettingsSyncJournal.overlayEdits(from: captured.value!, to: beforeApply, on: remote)
                        if remote != self.lastRemoteValues, merged != beforeApply { self.apply(merged) }
                        // onImport may normalize data or fill defaults. Treat that as an
                        // accepted import, not a fresh user edit to echo to every Mac.
                        let accepted = SettingsSyncJournal.acceptedBaseline(remote: remote, captured: captured.value!,
                            beforeApply: beforeApply, afterApply: self.currentValues())
                        self.lastRemoteValues = remote
                        self.lastValues = accepted
                        self.defaults.set(accepted, forKey: self.baselineKey)
                        if let finishedDate { self.defaults.set(finishedDate, forKey: Self.lastSyncKey) }
                    }
                    self.refreshStatus(failed: didFail)
                    let again = self.synchronizeAgain
                    self.synchronizeAgain = false
                    if again || (!didFail && self.currentValues() != self.lastValues) { self.scheduleExport() }
                }
            }
        }
    }

    /// Same layout for the sync file and an exported file, so either can be imported.
    private func makeRecord(_ values: NSDictionary) -> NSDictionary {
        ["version": 1, "app": Bundle.main.bundleIdentifier ?? appName, "device": deviceID,
         "deviceName": Host.current().localizedName ?? "", "modified": Date(), "values": values]
    }

    private func readRecord(at file: URL, _ completion: @escaping @MainActor (NSDictionary?) -> Void) {
        Self.queue.async {
            var error: NSError?
            var read: NSDictionary?
            // A coordinated read also downloads a file that the sync service keeps online only.
            NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &error) { url in
                read = NSDictionary(contentsOf: url)
            }
            let record = Record(value: read)
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(record.value) } }
        }
    }

    /// Poll immutable records, preserving local changes that have not yet been saved.
    @objc func check() { synchronize() }

    private func readSyncRecord(in folder: URL, completion: @escaping @MainActor (NSDictionary?) -> Void) {
        let directory = folder.appendingPathComponent("\(appName)-Settings.sync", isDirectory: true)
        let legacy = folder.appendingPathComponent(fileName)
        let app = Bundle.main.bundleIdentifier ?? appName
        Self.queue.async {
            let value: NSDictionary?
            if let state = try? SettingsSyncJournal.read(directory, app: app), state.hasRecords {
                value = ["app": app, "values": state.values, "modified": state.modified ?? Date(), "deviceName": "Settings Sync"]
            } else if FileManager.default.fileExists(atPath: directory.path) {
                // Do not replace an unreadable v2 journal with an older plist.
                value = nil
            } else { value = NSDictionary(contentsOf: legacy) }
            let record = Record(value: value)
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(record.value) } }
        }
    }

    private func apply(_ values: NSDictionary, removingMissing: Bool = true) {
        pendingExport?.cancel()
        applying = true
        if removingMissing {
            for key in currentValues().allKeys.compactMap({ $0 as? String }) where values[key] == nil { defaults.removeObject(forKey: key) }
        }
        for (key, value) in values { if let key = key as? String, isSynced(key) { defaults.set(value, forKey: key) } }
        lastValues = currentValues()
        onImport?()
        applying = false
    }

    // MARK: Settings

    var noteText: String {
        configuration.note + " " + text(
            "フォルダーはこのMacの中でも、iCloud DriveやDropboxなど同期サービスの中でも構いません。同期サービスでは、このフォルダーを常にこのMacに保存する（オフラインで使用可能にする）設定にしてください。",
            "The folder can be local or inside a sync service such as iCloud Drive or Dropbox. With a sync service, keep this folder downloaded and available offline.",
            "文件夹可以位于本机，也可以位于 iCloud 云盘、Dropbox 等同步服务中。使用同步服务时，请将此文件夹设为始终保留在本机（可离线使用）。",
            "폴더는 이 Mac 안이나 iCloud Drive, Dropbox 같은 동기화 서비스 안에 둘 수 있습니다. 동기화 서비스에서는 이 폴더를 항상 이 Mac에 보관(오프라인 사용 가능)하도록 설정하세요.")
    }
    var perMacText: String {
        configuration.perMac + " " + text(
            "変更ごとに別ファイルへ保存し、同じファイルを上書きしません。別の設定項目の変更は両方を反映します。同じ項目（一覧は一覧全体）の同時変更は変更番号と固有IDで決定します。すべてのMacを新方式対応版へ更新してください。旧plistと競合コピーは保持されますが、新方式へ移行後は自動同期しません。",
            "Each change is saved in a separate file. Changes to different keys are combined; simultaneous edits to one key (including a whole list) are resolved by logical revision and unique ID. Update all Macs to this sync version. Old plist files and conflict copies are preserved but are not synced after migration.",
            "每次更改保存为独立文件。不同设置的更改会合并；同一设置（包括整个列表）的同时更改按逻辑版本和唯一 ID 决定。请更新所有 Mac。旧 plist 和冲突副本会保留，但迁移后不再自动同步。",
            "변경마다 별도 파일에 저장합니다. 다른 설정의 변경은 합치며, 같은 설정(목록 전체 포함)의 동시 변경은 논리 버전과 고유 ID로 결정합니다. 모든 Mac을 업데이트하세요. 이전 plist와 충돌 사본은 보관하지만 전환 후 자동 동기화하지 않습니다.")
    }
    var chooseTitle: String { text("同期フォルダーを設定…", "Set Sync Folder…", "设置同步文件夹…", "동기화 폴더 설정…") }
    var revealTitle: String { text("Finderで表示", "Reveal in Finder", "在访达中显示", "Finder에서 보기") }
    var nowTitle: String { text("今すぐ同期", "Sync Now", "立即同步", "지금 동기화") }
    var stopTitle: String { text("同期を停止", "Stop Syncing", "停止同步", "동기화 중지") }

    @objc func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = text("このフォルダーで同期", "Sync with This Folder", "使用此文件夹同步", "이 폴더로 동기화")
        panel.message = text("設定を保存して共有するフォルダーを選んでください（iCloud Drive・Dropboxなど）",
                             "Choose a folder to save and share settings (iCloud Drive, Dropbox, etc.)",
                             "请选择用于保存和共享设置的文件夹（iCloud 云盘、Dropbox 等）",
                             "설정을 저장하고 공유할 폴더를 선택하세요(iCloud Drive, Dropbox 등)")
        panel.directoryURL = folder ?? Self.suggestedFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        use(url)
    }

    /// Starts syncing with `url`. When the folder already holds different settings, ask which side wins.
    private func use(_ url: URL) {
        readSyncRecord(in: url) { [weak self] record in
            guard let self else { return }
            let values = record?["values"] as? NSDictionary
            var useSaved = false
            if let values, values != self.currentValues() {
                let alert = NSAlert()
                alert.messageText = self.text("このフォルダーには保存済みの設定があります", "This folder already has saved settings", "此文件夹中已有保存的设置", "이 폴더에 저장된 설정이 있습니다")
                let device = (record?["deviceName"] as? String) ?? "?"
                alert.informativeText = self.text("「\(device)」で保存した設定と、このMacの設定が異なります。どちらを使いますか？",
                                                  "The settings saved on “\(device)” differ from this Mac’s settings. Which do you want to use?",
                                                  "在“\(device)”上保存的设置与此 Mac 的设置不同。要使用哪一个？",
                                                  "“\(device)”에서 저장한 설정이 이 Mac의 설정과 다릅니다. 어느 쪽을 사용하시겠습니까?")
                alert.addButton(withTitle: self.text("保存済みの設定を使う", "Use Saved Settings", "使用已保存的设置", "저장된 설정 사용"))
                alert.addButton(withTitle: self.text("このMacの設定を使う", "Use This Mac’s Settings", "使用此 Mac 的设置", "이 Mac의 설정 사용"))
                alert.addButton(withTitle: self.text("キャンセル", "Cancel", "取消", "취소"))
                switch alert.runModal() {
                case .alertFirstButtonReturn: useSaved = true
                case .alertSecondButtonReturn: break
                default: return
                }
            }
            self.pendingExport?.cancel()
            self.generation = UUID()
            self.releaseFolder()
            self.defaults.set(url.path, forKey: Self.folderKey)
            if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                self.defaults.set(bookmark, forKey: Self.bookmarkKey)
                self.accessFolder()
            } else {
                self.defaults.removeObject(forKey: Self.bookmarkKey)
            }
            if useSaved, let values {
                self.apply(values)
                self.defaults.set(record?["modified"] as? Date ?? Date(), forKey: Self.lastSyncKey)
                self.defaults.set(values, forKey: self.baselineKey)
                self.resume(checkNow: true)
            } else {
                // Explicit replacement becomes a new immutable change, including deletions.
                self.defaults.set(Date(), forKey: Self.lastSyncKey)
                self.resume(checkNow: false)
                self.lastValues = nil
                self.exportIfChanged()
            }
            self.refreshStatus()
        }
    }

    // MARK: Export & Import

    var transferNoteText: String {
        configuration.note + " " + text(
            "\(appName)-Settings.plist に書き出し、別のMacへの移行や控えに使えます。同期フォルダーのファイルも読み込めます。",
            "Exports to \(appName)-Settings.plist for moving to another Mac or keeping a backup. The file in a sync folder can be imported too.",
            "导出为 \(appName)-Settings.plist，可用于迁移到其他 Mac 或备份。也可以导入同步文件夹中的文件。",
            "\(appName)-Settings.plist로 내보내 다른 Mac으로 옮기거나 백업할 수 있습니다. 동기화 폴더의 파일도 가져올 수 있습니다.")
    }

    @objc func exportToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.propertyList]
        panel.nameFieldStringValue = fileName
        panel.message = text("書き出すファイルの名前と場所を選んでください", "Choose a name and location for the settings file",
                             "请选择要导出的文件名称和位置", "내보낼 파일의 이름과 위치를 선택하세요")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if makeRecord(currentValues()).write(to: url, atomically: true) {
            report(text("「\(url.lastPathComponent)」に書き出しました", "Exported to “\(url.lastPathComponent)”",
                        "已导出到“\(url.lastPathComponent)”", "“\(url.lastPathComponent)”(으)로 내보냈습니다"))
        } else {
            report(text("書き出せませんでした", "Could not export the settings", "无法导出设置", "설정을 내보내지 못했습니다"), error: true)
        }
    }

    /// Replaces the synced settings with the file's (or adds its new items when the app supports it). Nothing changes on Cancel.
    @objc func importFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.propertyList] + configuration.legacyExtensions.compactMap { UTType(filenameExtension: $0) }
            + (configuration.legacyExtensions.isEmpty ? [] : [.json])
        panel.allowsMultipleSelection = false
        panel.message = text("読み込む \(appName) の設定ファイルを選んでください", "Choose a \(appName) settings file to import",
                             "请选择要导入的 \(appName) 设置文件", "가져올 \(appName) 설정 파일을 선택하세요")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        readRecord(at: url) { [weak self] record in
            guard let self else { return }
            let bundleID = Bundle.main.bundleIdentifier ?? self.appName
            var values = record?["values"] as? NSDictionary
            if record?["app"] as? String ?? bundleID != bundleID { values = nil }
            // An older per-app file holds only some of the keys: replacing keeps the ones it lacks.
            let legacy = values == nil
            if legacy, let convert = self.configuration.legacyImport, let data = try? Data(contentsOf: url) { values = convert(data) }
            guard let values else {
                self.report(self.text("\(self.appName)の設定ファイルとして読み込めませんでした", "This is not a \(self.appName) settings file",
                                      "无法作为 \(self.appName) 设置文件导入", "\(self.appName) 설정 파일로 가져올 수 없습니다"), error: true)
                return
            }
            let synced = NSMutableDictionary()
            for (key, value) in values { if let key = key as? String, self.isSynced(key) { synced[key] = value } }
            let alert = NSAlert()
            alert.messageText = self.text("「\(url.lastPathComponent)」を読み込みます", "Import “\(url.lastPathComponent)”?",
                                          "要导入“\(url.lastPathComponent)”吗？", "“\(url.lastPathComponent)”을(를) 가져오시겠습니까?")
            let merge = self.configuration.merge
            if merge != nil {
                alert.informativeText = self.text("「追加する」は今の設定を残し、まだ無い項目だけを加えます。「置き換える」は設定をファイルの内容にします（今の設定は消えます）。",
                                                  "Add keeps the current settings and adds only new items. Replace uses the file’s settings (the current settings are lost).",
                                                  "“添加”保留当前设置，只添加尚未有的项目。“替换”使用文件中的设置（当前设置将被清除）。",
                                                  "‘추가’는 현재 설정을 유지하고 없는 항목만 더합니다. ‘바꾸기’는 파일의 설정으로 바꿉니다(현재 설정은 사라집니다).")
                alert.addButton(withTitle: self.text("追加する", "Add", "添加", "추가"))
            } else {
                alert.informativeText = self.text("このMacの設定がファイルの内容に置き換わります。",
                                                  "This Mac’s settings will be replaced with the file’s settings.",
                                                  "此 Mac 的设置将被替换为文件中的设置。",
                                                  "이 Mac의 설정이 파일의 설정으로 바뀝니다.")
            }
            alert.addButton(withTitle: self.text("置き換える", "Replace", "替换", "바꾸기"))
            alert.addButton(withTitle: self.text("キャンセル", "Cancel", "取消", "취소")).keyEquivalent = "\u{1b}"
            let answer = alert.runModal()
            let add = merge != nil && answer == .alertFirstButtonReturn
            let replace = answer == (merge != nil ? .alertSecondButtonReturn : .alertFirstButtonReturn)
            guard add || replace else { return }
            if add, let merge {
                let result = merge(synced, self.currentValues())
                self.apply(result.values, removingMissing: false)
                self.report(self.text("\(result.added)件を追加しました", "Added \(result.added) items", "已添加 \(result.added) 项", "\(result.added)개를 추가했습니다"))
            } else {
                self.apply(synced, removingMissing: !legacy)
                self.report(self.text("設定を読み込みました", "Imported the settings", "已导入设置", "설정을 가져왔습니다"))
            }
            // Pass the imported settings on to the sync folder.
            if self.enabled { self.lastValues = nil; self.exportIfChanged() }
        }
    }

    private func report(_ message: String, error: Bool = false) {
        transferText = message
        transferIsError = error
        if error { NSSound.beep() }
    }

    @objc func reveal() {
        guard let folder else { return }
        if let journal, FileManager.default.fileExists(atPath: journal.path) { NSWorkspace.shared.activateFileViewerSelecting([journal]) }
        else if let file, FileManager.default.fileExists(atPath: file.path) { NSWorkspace.shared.activateFileViewerSelecting([file]) }
        else { NSWorkspace.shared.open(folder) }
    }

    @objc func stop() {
        generation = UUID()
        pendingExport?.cancel()
        synchronizeAgain = false
        defaults.removeObject(forKey: Self.folderKey)
        defaults.removeObject(forKey: Self.bookmarkKey)
        releaseFolder()
        timer?.invalidate(); timer = nil
        refreshStatus()
    }

    @objc func syncNow() {
        guard enabled else { return }
        synchronize()
    }

    private func refreshStatus(failed: Bool = false) {
        pathText = folder.map { ($0.path as NSString).abbreviatingWithTildeInPath }
            ?? text("同期フォルダーが設定されていません", "No sync folder set", "未设置同步文件夹", "동기화 폴더가 설정되지 않음")
        isEnabled = enabled
        isAvailable = available
        statusIsError = failed || (enabled && !available)
        guard enabled else { statusText = text("同期していません", "Not syncing", "未同步", "동기화하지 않음"); return }
        if !available {
            statusText = text("同期フォルダーが見つかりません。同期サービスが動いているか確認するか、フォルダーを設定し直してください。",
                              "The sync folder cannot be found. Check that the sync service is running, or set the folder again.",
                              "找不到同步文件夹。请确认同步服务正在运行，或重新设置文件夹。",
                              "동기화 폴더를 찾을 수 없습니다. 동기화 서비스가 실행 중인지 확인하거나 폴더를 다시 설정하세요.")
            return
        }
        if failed { statusText = text("同期ファイルを読み書きできませんでした。同期サービスの状態とファイルを確認してください", "Could not read or write sync files. Check the sync service and files.", "无法读写同步文件，请检查同步服务和文件。", "동기화 파일을 읽거나 쓸 수 없습니다. 동기화 서비스와 파일을 확인하세요."); return }
        if let date = defaults.object(forKey: Self.lastSyncKey) as? Date {
            let when = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
            statusText = text("最終同期：\(when)", "Last synced: \(when)", "上次同步：\(when)", "마지막 동기화: \(when)")
        } else { statusText = text("同期の準備中…", "Preparing to sync…", "正在准备同步…", "동기화 준비 중…") }
    }
}

/// Contents of the 「設定の同期」 group: SettingsSection(SettingsSync.shared.title) { SettingsSyncView() }
struct SettingsSyncView: View {
    @ObservedObject private var sync = SettingsSync.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sync.pathText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(sync.isEnabled ? .primary : .secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Text(sync.statusText)
                .font(.system(size: 11))
                .foregroundColor(sync.statusIsError ? .red : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        HStack(spacing: 8) {
            Button(sync.chooseTitle) { sync.chooseFolder() }
            Button(sync.revealTitle) { sync.reveal() }.disabled(!sync.isAvailable)
            Button(sync.nowTitle) { sync.syncNow() }.disabled(!sync.isAvailable)
            Button(sync.stopTitle) { sync.stop() }.disabled(!sync.isEnabled)
        }
        Text(sync.noteText).font(.system(size: 11)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        Text(sync.perMacText).font(.system(size: 11)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

/// Contents of the 「書き出し・読み込み」 group.
struct SettingsTransferView: View {
    @ObservedObject private var sync = SettingsSync.shared
    var body: some View {
        HStack(spacing: 8) {
            Button(sync.exportTitle) { sync.exportToFile() }
            Button(sync.importTitle) { sync.importFromFile() }
        }
        if !sync.transferText.isEmpty {
            Text(sync.transferText)
                .font(.system(size: 11))
                .foregroundColor(sync.transferIsError ? .red : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        Text(sync.transferNoteText).font(.system(size: 11)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

/// The 「設定の共有」 tab shared by every app: 書き出し・読み込み, then 設定の同期.
/// SwiftUI: (SettingsSync.shared.tabTitle, AnyView(SettingsSharingView()))
/// AppKit: (SettingsSync.shared.tabTitle, SettingsSync.shared.sharingPage())
struct SettingsSharingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(SettingsSync.shared.transferTitle) { SettingsTransferView() }
            SettingsSection(SettingsSync.shared.title) { SettingsSyncView() }
        }
    }
}

extension SettingsSync {
    /// AppKit settings page; its height follows the wrapped text at the page width.
    func sharingPage() -> NSView { SettingsHostingPage(observing: self) { SettingsSharingView() } }
}
