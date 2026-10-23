import AppKit
import UniformTypeIdentifiers

// MARK: - 設定の読み書き

/// サンドボックスのアプリはコンテナの plist をパスで渡さないと CFPreferences が届かない（Bundle ID では空になる。実測、2026-10-24）
/// パスで渡しても cfprefsd を通るので、defaults やアプリ側の読み書きと食い違わない
func preferencesDomain(_ bundleID: String) -> CFString {
    let folder = containerPreferencesFolder(bundleID)
    guard FileManager.default.fileExists(atPath: folder.path) else { return bundleID as CFString }
    return folder.appendingPathComponent(bundleID).path as CFString
}

private func containerPreferencesFolder(_ bundleID: String) -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Containers/\(bundleID)/Data/Library/Preferences")
}

/// 設定ファイルの場所（表示と「Finderで表示」用）
func preferencesFile(_ bundleID: String) -> URL {
    let container = containerPreferencesFolder(bundleID)
    let folder = FileManager.default.fileExists(atPath: container.path) ? container
        : FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences")
    return folder.appendingPathComponent(bundleID + ".plist")
}

/// サンドボックスのアプリ（設定がコンテナにある）。読むと macOS が「ほかのアプリからのデータ」へのアクセスを確認する（Macを再起動するたびに出る）
func isSandboxed(_ bundleID: String) -> Bool {
    FileManager.default.fileExists(atPath: containerPreferencesFolder(bundleID).path)
}

/// フルディスクアクセスがあれば、コンテナを読んでも確認は出ない（システムの TCC.db が開けるかで判定。HotkeyHound と同じ）
var hasFullDiskAccess: Bool {
    let fd = open("/Library/Application Support/com.apple.TCC/TCC.db", O_RDONLY)
    guard fd >= 0 else { return false }
    close(fd)
    return true
}

/// 設定ファイルに中身があるのに1つも読めない。アクセスの確認で拒否されたとき（空の plist は 100 バイトに満たない）
func isUnreadable(_ bundleID: String, _ values: [String: NSObject]) -> Bool {
    guard values.isEmpty,
          let size = (try? FileManager.default.attributesOfItem(atPath: preferencesFile(bundleID).path))?[.size] as? Int else { return false }
    return size > 100
}

/// アプリの設定をすべて読む
func readSettings(_ bundleID: String) -> [String: NSObject] {
    let d = preferencesDomain(bundleID)
    CFPreferencesAppSynchronize(d)
    let keys = CFPreferencesCopyKeyList(d, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String] ?? []
    var result: [String: NSObject] = [:]
    for key in keys {
        if let value = CFPreferencesCopyAppValue(key as CFString, d) as? NSObject { result[key] = value }
    }
    return result
}

/// nil を渡すとキーを削除する
func writeSettings(_ bundleID: String, _ values: [String: NSObject?]) -> Bool {
    let d = preferencesDomain(bundleID)
    for (key, value) in values {
        CFPreferencesSetAppValue(key as CFString, value as CFPropertyList?, d)
    }
    return CFPreferencesAppSynchronize(d)
}

/// Macごとに異なる値（ウインドウの位置・メニューバーの並び・アップデート確認の記録など）
private let machineSpecificKeyPrefixes = [
    "NSWindow Frame ", "NSSplitView Subview Frames ", "NSStatusItem ", "NSToolbar Configuration ",
    "NSTableView ", "NSOutlineView ", "NSNavLastRootDirectory", "NSNavPanel", "NSOSPLast",
    "SULastCheckTime", "SUHasLaunchedBefore", "SUUpdateGroupIdentifier",
]

/// 初めから書き出しに含めないキー。Macごとに異なるキーと、日付の値（初回起動日・最終利用日など）
func isExcludedByDefault(_ key: String, _ value: NSObject?) -> Bool {
    machineSpecificKeyPrefixes.contains { key.hasPrefix($0) } || value is Date
}

func describe(_ value: NSObject?) -> String {
    guard let value else { return L("なし") }
    if CFGetTypeID(value) == CFBooleanGetTypeID(), let n = value as? NSNumber { return n.boolValue ? "true" : "false" }
    switch value {
    case let n as NSNumber: return n.stringValue
    case let s as String: return s
    case let a as NSArray: return L("配列（%@件）", String(a.count))
    case let d as NSDictionary: return L("辞書（%@件）", String(d.count))
    case let d as Data: return L("データ（%@バイト）", String(d.count))
    case let d as Date: return d.formatted()
    default: return value.description
    }
}

func typeName(_ value: NSObject?) -> String {
    guard let value else { return "" }
    if CFGetTypeID(value) == CFBooleanGetTypeID() { return L("真偽") }
    switch value {
    case is NSNumber: return L("数値")
    case is String: return L("文字列")
    case is NSArray: return L("配列")
    case is NSDictionary: return L("辞書")
    case is Data: return L("データ")
    case is Date: return L("日付")
    default: return ""
    }
}

@MainActor
func appURL(_ bundleID: String) -> URL? {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
}

@MainActor
func appIcon(_ bundleID: String) -> NSImage {
    if let url = appURL(bundleID) { return NSWorkspace.shared.icon(forFile: url.path) }
    return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
}

// MARK: - 書き出しファイル

let packageType = UTType(exportedAs: "jp.dtp-transit.settingscourier", conformingTo: .xmlPropertyList)

/// 書き出しファイル1つ分。バックアップも同じ形式で、replace が真なら取り込むときにファイルにないキーを消す（元どおりにする）
struct Package {
    struct App {
        let bundleID: String
        let name: String
        let values: [String: NSObject]
    }
    let apps: [App]
    let host: String
    let created: Date?
    let replace: Bool

    func data() throws -> Data {
        let root: [String: Any] = [
            "format": "SettingsCourier", "version": 1, "created": Date(),
            "host": host, "replace": replace,
            "apps": apps.map { ["bundleID": $0.bundleID, "name": $0.name, "values": $0.values] as [String: Any] },
        ]
        return try PropertyListSerialization.data(fromPropertyList: root, format: .xml, options: 0)
    }

    init(apps: [App], replace: Bool, host: String = Host.current().localizedName ?? "") {
        self.apps = apps
        self.replace = replace
        self.host = host
        created = nil
    }

    init?(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              root["format"] as? String == "SettingsCourier",
              let list = root["apps"] as? [[String: Any]] else { return nil }
        apps = list.compactMap { d in
            guard let id = d["bundleID"] as? String, let values = d["values"] as? [String: NSObject] else { return nil }
            return App(bundleID: id, name: d["name"] as? String ?? id, values: values)
        }
        host = root["host"] as? String ?? ""
        created = root["created"] as? Date
        replace = root["replace"] as? Bool ?? false
    }
}

// MARK: - モデル

struct CourierApp: Identifiable, Hashable {
    let bundleID: String
    let name: String
    var id: String { bundleID }
}

/// 取り込むアプリごとの差分
struct ImportPlan: Identifiable {
    let app: Package.App
    /// 書き込む値。nil はキーの削除（バックアップから戻すとき）
    let writes: [String: NSObject?]
    let changed: Int
    let added: Int
    let removed: Int
    let installed: Bool
    /// このMacの今の設定を読めなかった（アクセスの確認で拒否された）。書き込まない
    let unreadable: Bool
    var id: String { app.bundleID }
}

@MainActor
final class Courier: ObservableObject {
    static let shared = Courier()

    static let appsKey = "apps"
    static let excludedKeysKey = "excludedKeys"
    static let includedKeysKey = "includedKeys"

    @Published private(set) var apps: [CourierApp] = []
    /// 書き出しから外したキー（Bundle ID → キー）
    @Published private(set) var excludedKeys: [String: [String]] = [:]
    /// 初めから外すキーのうち、書き出しに含めることにしたもの
    @Published private(set) var includedKeys: [String: [String]] = [:]
    /// 読み直すたびに増やし、画面に設定を読み直させる
    @Published private(set) var revision = 0
    @Published var message: (title: String, body: String)?
    @Published private(set) var isWorking = false
    /// このセッションでサンドボックスのアプリの設定を読んでよいか（［設定を読む］・書き出し・取り込みで真にする）
    @Published var readsContainers = false
    /// 開いた書き出しファイル。メインウインドウが取り込みの確認を出す（起動直後に開いたときも取りこぼさない）
    @Published var pendingImport: PackageBox?
    /// 受け渡しフォルダーにある書き出しファイル（Folder.swift）
    @Published var folderEntries: [FolderEntry] = []
    /// 最後の自動書き出しの結果（設定の「受け渡しフォルダー」に出す）
    @Published var lastAutoExport: String?
    /// 取り込みのために終了させたアプリ。終了の通知で自動書き出しをしない（取り込む前の値で上書きしてしまう）
    var suppressAutoExport: [String: Date] = [:]
    /// フォルダーから取り込むファイルの書き出し日時（Bundle ID → 日時）。取り込みが済んだら処理済みにする
    var folderImportDates: [String: Date] = [:]

    init() {
        reload()
        watchTerminations()
    }

    /// UserDefaults から読み直す（起動時と、設定の共有で読み込んだ後）
    func reload() {
        let d = UserDefaults.standard
        apps = (d.array(forKey: Courier.appsKey) as? [[String]] ?? [])
            .compactMap { $0.count == 2 ? CourierApp(bundleID: $0[0], name: $0[1]) : nil }
        excludedKeys = d.dictionary(forKey: Courier.excludedKeysKey) as? [String: [String]] ?? [:]
        includedKeys = d.dictionary(forKey: Courier.includedKeysKey) as? [String: [String]] ?? [:]
        refresh()
    }

    func refresh() { revision += 1 }

    /// 画面を開いたり切り替えたりしただけで読んでよいか。サンドボックスのアプリは確認が出るので、操作するまで読まない
    func canRead(_ bundleID: String) -> Bool {
        readsContainers || !isSandboxed(bundleID) || hasFullDiskAccess
    }

    /// ［設定を読む］・書き出し・取り込み：利用者の操作なので、確認が出てもよい
    func allowContainerReads() {
        guard !readsContainers else { return }
        readsContainers = true
        refresh()
    }

    private func saveApps() {
        UserDefaults.standard.set(apps.map { [$0.bundleID, $0.name] }, forKey: Courier.appsKey)
    }

    // MARK: 登録

    func add(bundleID: String, name: String) {
        guard !apps.contains(where: { $0.bundleID == bundleID }) else { return }
        apps.append(CourierApp(bundleID: bundleID, name: name))
        apps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        saveApps()
    }

    /// 選んだ・ドロップしたアプリを登録する。最後に足したアプリの Bundle ID を返す
    @discardableResult
    func add(_ urls: [URL]) -> String? {
        var last: String?
        for url in urls {
            guard let id = Bundle(url: url)?.bundleIdentifier else { continue }
            add(bundleID: id, name: FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""))
            last = id
        }
        return last
    }

    func chooseApps() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = L("追加")
        panel.message = L("設定を運ぶアプリを選んでください")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return nil }
        return add(panel.urls)
    }

    /// 一覧から外す（アプリの設定そのものはそのまま）
    func remove(_ bundleID: String) {
        apps.removeAll { $0.bundleID == bundleID }
        saveApps()
        excludedKeys[bundleID] = nil
        includedKeys[bundleID] = nil
        saveSelections()
    }

    // MARK: 書き出すキーの選択

    func isIncluded(_ bundleID: String, _ key: String, _ value: NSObject?) -> Bool {
        if excludedKeys[bundleID]?.contains(key) == true { return false }
        if isExcludedByDefault(key, value) { return includedKeys[bundleID]?.contains(key) == true }
        return true
    }

    func setIncluded(_ bundleID: String, _ keys: [(key: String, value: NSObject?)], _ include: Bool) {
        for (key, value) in keys {
            excludedKeys[bundleID, default: []].removeAll { $0 == key }
            includedKeys[bundleID, default: []].removeAll { $0 == key }
            if include, isExcludedByDefault(key, value) { includedKeys[bundleID, default: []].append(key) }
            if !include, !isExcludedByDefault(key, value) { excludedKeys[bundleID, default: []].append(key) }
        }
        if excludedKeys[bundleID]?.isEmpty == true { excludedKeys[bundleID] = nil }
        if includedKeys[bundleID]?.isEmpty == true { includedKeys[bundleID] = nil }
        saveSelections()
    }

    /// 選択を初めの状態（Macごとに異なるキーと日付だけ外す）に戻す
    func resetSelection(_ bundleID: String) {
        excludedKeys[bundleID] = nil
        includedKeys[bundleID] = nil
        saveSelections()
    }

    private func saveSelections() {
        let d = UserDefaults.standard
        d.set(excludedKeys, forKey: Courier.excludedKeysKey)
        d.set(includedKeys, forKey: Courier.includedKeysKey)
    }

    /// 書き出しに含める値
    func exportedValues(_ bundleID: String) -> [String: NSObject] {
        readSettings(bundleID).filter { isIncluded(bundleID, $0.key, $0.value) }
    }

    // MARK: 書き出し

    /// メインウインドウの一覧で選んでいるアプリ（画面の @AppStorage と同じキー）
    static let selectedAppKey = "selectedApp"

    var selectedApp: CourierApp? {
        let id = UserDefaults.standard.string(forKey: Courier.selectedAppKey)
        return apps.first { $0.bundleID == id }
    }

    /// 選んでいるアプリの設定を書き出す。受け渡しフォルダーがあればそこへ、なければ（または toFile なら）保存先を選ぶ
    func export(_ app: CourierApp? = nil, toFile: Bool = false) {
        guard let app = app ?? selectedApp else {
            message = (L("書き出すアプリがありません"), L("左の一覧でアプリを選んでください。"))
            return
        }
        allowContainerReads()
        guard !isUnreadable(app.bundleID, readSettings(app.bundleID)) else {
            message = (L("設定を読めませんでした"), L("%@の設定を読めませんでした。macOSの「ほかのアプリからのデータ」へのアクセスの確認で［許可］を選ぶか、設定の「起動・常駐」からフルディスクアクセスを許可してから、もう一度書き出してください。", app.name))
            return
        }
        let folder = toFile ? nil : self.folder
        var url = URL(fileURLWithPath: "/")
        if folder == nil {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [packageType]
            panel.nameFieldStringValue = "\(app.name).settingscourier"
            NSApp.activate(ignoringOtherApps: true)
            guard panel.runModal() == .OK, let chosen = panel.url else { return }
            url = chosen
        }
        defer { scanFolder() }
        let values = exportedValues(app.bundleID)
        let package = Package(apps: [.init(bundleID: app.bundleID, name: app.name, values: values)], replace: false)
        do {
            if let folder {
                url = try writeToFolder(package, app, in: folder)
                markHandled(app.bundleID, Date())
            } else {
                try package.data().write(to: url, options: .atomic)
            }
            message = (L("書き出しました"),
                       L("%@の設定（%@項目）を「%@」に保存しました。ほかのMacのSettingsCourierでこのファイルを開いて取り込みます。",
                         app.name, String(values.count), url.lastPathComponent))
        } catch {
            message = (L("書き出せませんでした"), error.localizedDescription)
        }
    }

    // MARK: 取り込み

    func choosePackage() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [packageType]
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// このMacの今の値と比べて、書き込む値を決める。このMacで外したキーは書き込まない
    func plan(_ package: Package) -> [ImportPlan] {
        allowContainerReads()
        return package.apps.map { app in
            let current = readSettings(app.bundleID)
            var writes: [String: NSObject?] = [:]
            var changed = 0, added = 0, removed = 0
            for (key, value) in app.values {
                // バックアップから戻すときは、このMacで外したキーも元どおりにする
                if !package.replace, !isIncluded(app.bundleID, key, value) { continue }
                if let now = current[key] {
                    if !now.isEqual(value) { writes[key] = value; changed += 1 }
                } else {
                    writes[key] = value; added += 1
                }
            }
            if package.replace {
                for key in current.keys where app.values[key] == nil {
                    writes[key] = .some(nil); removed += 1
                }
            }
            // このMacと同じなら、フォルダーのそのファイルは処理済み
            if writes.isEmpty, !isUnreadable(app.bundleID, current), let date = folderImportDates[app.bundleID] {
                markHandled(app.bundleID, date)
            }
            return ImportPlan(app: app, writes: writes, changed: changed, added: added, removed: removed,
                              installed: appURL(app.bundleID) != nil, unreadable: isUnreadable(app.bundleID, current))
        }
    }

    static var backupFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/SettingsCourier/Backups")
    }

    /// 書き換えるアプリの設定をすべて（外したキーも）保存する。取り込むと元どおりになる
    private func backup(_ plans: [ImportPlan]) throws -> URL {
        let folder = Courier.backupFolder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)
            .dateSeparator(.dash).timeSeparator(.omitted))
        let url = folder.appendingPathComponent("Backup \(stamp).settingscourier")
        let package = Package(apps: plans.map { .init(bundleID: $0.app.bundleID, name: $0.app.name, values: readSettings($0.app.bundleID)) },
                              replace: true)
        try package.data().write(to: url, options: .atomic)
        return url
    }

    /// 起動中のアプリは終了するときに設定を書き戻すので、先に終了しないと上書きされる
    /// 終了させたアプリを返す（書き込み後に起動し直す）。キャンセルか終了しなかったときは nil
    private func quitRunningApps(_ plans: [ImportPlan]) -> [NSRunningApplication]? {
        let running = plans.flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0.app.bundleID) }
            .filter { !$0.isTerminated }
        guard !running.isEmpty else { return [] }
        let names = running.map { $0.localizedName ?? $0.bundleIdentifier ?? "" }.joined(separator: L("、"))
        let alert = NSAlert()
        alert.messageText = L("%@を終了してから書き込みますか？", names)
        alert.informativeText = L("起動中のアプリは終了するときに設定を書き戻すため、先に終了します。書き込んだあとで起動し直します。")
        alert.addButton(withTitle: L("終了して取り込む"))
        alert.addButton(withTitle: L("キャンセル"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        for app in running {
            if let id = app.bundleIdentifier { suppressAutoExport[id] = Date().addingTimeInterval(30) }
            app.terminate()
        }
        let deadline = Date().addingTimeInterval(10)
        while running.contains(where: { !$0.isTerminated }), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        if running.contains(where: { !$0.isTerminated }) {
            message = (L("取り込みを中止しました"),
                       L("%@が終了しなかったため、書き込みませんでした。アプリを終了してからもう一度取り込んでください。", names))
            return nil
        }
        return running
    }

    /// 選んだアプリに書き込む。成功・一部失敗・取消を区別して伝える
    func apply(_ plans: [ImportPlan]) {
        // 今の設定を読めないアプリに書くと、空のバックアップしか残らない
        let plans = plans.filter { !$0.writes.isEmpty && !$0.unreadable }
        guard !plans.isEmpty, !isWorking else { return }
        isWorking = true
        defer { isWorking = false; refresh(); scanFolder() }
        guard let quitted = quitRunningApps(plans) else { return }
        let backupURL: URL
        do {
            backupURL = try backup(plans)
        } catch {
            message = (L("バックアップできなかったため中止しました"), error.localizedDescription)
            return
        }
        var failed: [String] = []
        var written = 0
        for p in plans {
            _ = writeSettings(p.app.bundleID, p.writes)
            // 読み直して、書き込めたかを確かめる
            let now = readSettings(p.app.bundleID)
            let wrong = p.writes.filter { key, value in
                guard let value else { return now[key] != nil }
                return !(now[key]?.isEqual(value) ?? false)
            }
            if wrong.isEmpty {
                written += 1
                if let date = folderImportDates[p.app.bundleID] { markHandled(p.app.bundleID, date) }
            } else {
                failed.append(p.app.name)
            }
            add(bundleID: p.app.bundleID, name: p.app.name)
        }
        for app in quitted {
            if let url = app.bundleURL { NSWorkspace.shared.openApplication(at: url, configuration: .init()) }
        }
        var body = L("%@個のアプリに書き込みました。", String(written))
        if !failed.isEmpty { body += "\n" + L("書き込めなかったアプリ：%@", failed.joined(separator: L("、"))) }
        if !quitted.isEmpty {
            body += "\n" + L("起動し直したアプリ：%@", quitted.compactMap(\.localizedName).joined(separator: L("、")))
        }
        body += "\n\n" + L("元の設定は「%@」に保存しました。このファイルを取り込むと元に戻せます。", backupURL.lastPathComponent)
        message = (failed.isEmpty ? L("取り込みました") : L("一部のアプリに書き込めませんでした"), body)
    }

    func showBackupFolder() {
        try? FileManager.default.createDirectory(at: Courier.backupFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Courier.backupFolder)
    }
}

/// Finder・Dock・メニューから開いた書き出しファイルを、確認画面に渡す
@MainActor
func openPackage(_ url: URL? = nil) {
    guard let url = url ?? Courier.shared.choosePackage() else { return }
    guard let package = Package(url: url) else {
        Courier.shared.message = (L("読み込めませんでした"), L("SettingsCourierの書き出しファイルではありません。"))
        return
    }
    // フォルダーから取り込むときの記録を、ファイルを開いた取り込みに持ち込まない
    Courier.shared.folderImportDates = [:]
    Courier.shared.pendingImport = PackageBox(package: package, name: url.lastPathComponent)
}

/// 取り込みの確認画面に渡す入れ物
final class PackageBox: NSObject, Identifiable {
    let package: Package
    let name: String
    init(package: Package, name: String) { self.package = package; self.name = name }
}
