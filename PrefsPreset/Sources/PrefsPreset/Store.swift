import AppKit
import UniformTypeIdentifiers

// MARK: - 値の読み書き

/// "NSGlobalDomain" は CFPreferences では kCFPreferencesAnyApplication
func cfDomain(_ domain: String) -> CFString {
    domain == "NSGlobalDomain" ? kCFPreferencesAnyApplication : domain as CFString
}

/// 起動音（StartupMute）は defaults ではなく NVRAM にある。値は「再生する」の真偽で扱う
let nvramDomain = "NVRAM"

/// NVRAM の StartupMute を「起動時にサウンドを再生」として読む。未設定なら nil（既定は再生する）
func readStartupSound() -> NSObject? {
    let p = Process()
    let pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/nvram")
    p.arguments = ["StartupMute"]
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    guard (try? p.run()) != nil else { return nil }
    let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    p.waitUntilExit()
    guard p.terminationStatus == 0 else { return nil }
    return NSNumber(value: !output.contains("%01"))
}

/// 管理者権限でシェルコマンドを実行する。認証ダイアログでキャンセルされたら false
@discardableResult
func runAsAdministrator(_ command: String) -> Bool {
    var error: NSDictionary?
    NSAppleScript(source: "do shell script \"\(command)\" with administrator privileges")?.executeAndReturnError(&error)
    return error == nil
}

/// /Library/Preferences/FeatureFlags/Domain/UIKit.plist（root のみ読み書きできる）。キーは機能フラグ名、値は Enabled の真偽
/// 読むにも管理者権限が要るので、PrefsPreset で最後に書き込めた値を「現在の値」として扱う
let featureFlagDomain = "FeatureFlags/UIKit"
private let featureFlagFile = "/Library/Preferences/FeatureFlags/Domain/UIKit.plist"
private func featureFlagMemoKey(_ key: String) -> String { "appliedFeatureFlag." + key }

func readFeatureFlag(_ key: String) -> NSObject? {
    UserDefaults.standard.object(forKey: featureFlagMemoKey(key)) as? NSNumber
}

func writeFeatureFlag(_ key: String, _ value: NSObject?) {
    let command: String
    switch (value as? NSNumber)?.boolValue {
    case let enabled?: command = "/usr/bin/defaults write \(featureFlagFile) \(key) -dict-add Enabled -bool \(enabled ? "YES" : "NO")"
    case nil: command = "/usr/bin/defaults delete \(featureFlagFile) \(key)"
    }
    guard runAsAdministrator(command) else { return }
    UserDefaults.standard.set(value, forKey: featureFlagMemoKey(key))
}

/// 管理者のパスワードを求める保存先
let administratorDomains: Set<String> = [nvramDomain, featureFlagDomain]

/// NVRAM の書き込みには管理者権限が要る。認証ダイアログを出し、キャンセルされたら書かない
func writeStartupSound(_ value: NSObject?) {
    let command: String
    switch (value as? NSNumber)?.boolValue {
    case false?: command = "/usr/sbin/nvram StartupMute=%01"
    case true?: command = "/usr/sbin/nvram StartupMute=%00"
    case nil: command = "/usr/sbin/nvram -d StartupMute"
    }
    runAsAdministrator(command)
}

/// システムのキーボードショートカット（com.apple.symbolichotkeys の AppleSymbolicHotKeys）。キーは番号
/// 値は "キーコード,修飾キー" の文字列、無効なら "off"。未登録（macOS の既定）は nil
let hotkeyDomain = "SymbolicHotKeys"
private let hotkeysDomain = "com.apple.symbolichotkeys" as CFString
private let hotkeysKey = "AppleSymbolicHotKeys" as CFString

func readHotkey(_ id: String) -> NSObject? {
    CFPreferencesAppSynchronize(hotkeysDomain)
    guard let all = CFPreferencesCopyAppValue(hotkeysKey, hotkeysDomain) as? [String: Any],
          let entry = all[id] as? [String: Any] else { return nil }
    if (entry["enabled"] as? Bool) == false { return "off" as NSString }
    guard let value = entry["value"] as? [String: Any], let parameters = value["parameters"] as? [Int],
          parameters.count == 3 else { return nil }
    return "\(parameters[1]),\(parameters[2])" as NSString
}

/// ほかの番号の割り当ては変えずに、1件だけ差し替える
func writeHotkey(_ id: String, _ value: NSObject?) {
    CFPreferencesAppSynchronize(hotkeysDomain)
    var all = CFPreferencesCopyAppValue(hotkeysKey, hotkeysDomain) as? [String: Any] ?? [:]
    switch value as? String {
    case nil:
        all[id] = nil
    case "off":
        var entry = all[id] as? [String: Any] ?? [:]
        entry["enabled"] = false
        all[id] = entry
    case let text?:
        let numbers = text.split(separator: ",").compactMap { Int($0) }
        guard numbers.count == 2 else { return }
        // ファンクションキーなど文字を持たないキーの文字コードは 65535
        let character = hotkeyCharacters[numbers[0]] ?? 65535
        all[id] = ["enabled": true, "value": ["type": "standard", "parameters": [character, numbers[0], numbers[1]]]]
    }
    CFPreferencesSetAppValue(hotkeysKey, all as CFPropertyList, hotkeysDomain)
    CFPreferencesAppSynchronize(hotkeysDomain)
}

/// 文字を持つキーの文字コード（キーコード → ASCII）。一覧の選択肢で使うもの
private let hotkeyCharacters: [Int: Int] = [28: 56, 24: 61, 27: 45, 50: 96]

/// 他のプロセスが書いた値も拾えるよう、同期してから読む
func readValue(domain: String, key: String) -> NSObject? {
    if domain == nvramDomain { return readStartupSound() }
    if domain == hotkeyDomain { return readHotkey(key) }
    if domain == featureFlagDomain { return readFeatureFlag(key) }
    let d = cfDomain(domain)
    CFPreferencesAppSynchronize(d)
    return CFPreferencesCopyAppValue(key as CFString, d) as? NSObject
}

/// nil を渡すとキーを削除して既定値に戻す
func writeValue(_ value: NSObject?, domains: [String], key: String) {
    for domain in domains {
        if domain == nvramDomain { writeStartupSound(value); continue }
        if domain == hotkeyDomain { writeHotkey(key, value); continue }
        if domain == featureFlagDomain { writeFeatureFlag(key, value); continue }
        let d = cfDomain(domain)
        CFPreferencesSetAppValue(key as CFString, value as CFPropertyList?, d)
        CFPreferencesAppSynchronize(d)
    }
}

func run(_ path: String, _ args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    try? p.run()
    p.waitUntilExit()
}

/// 書き換えたあと再起動が必要なプロセス
func processToRestart(for domain: String) -> String? {
    switch domain {
    case "com.apple.dock", "com.apple.spaces": return "Dock"
    case "com.apple.finder", "com.apple.desktopservices": return "Finder"
    case "com.apple.screencapture": return "SystemUIServer"
    case "com.apple.controlcenter", "com.apple.menuextra.clock": return "ControlCenter"
    case "com.apple.WindowManager": return "WindowManager"
    default: return nil
    }
}

/// ログインし直すまで反映されないことがあるドメイン
func needsLogout(_ domain: String) -> Bool {
    ["NSGlobalDomain", "com.apple.HIToolbox", "com.apple.spaces"].contains(domain) || trackpadDomains.contains(domain)
}

// MARK: - 値の表示と変換

func isBoolean(_ value: NSObject?) -> Bool {
    guard let value else { return false }
    return CFGetTypeID(value) == CFBooleanGetTypeID()
}

func choiceKey(_ value: NSObject) -> String {
    if let n = value as? NSNumber { return n.stringValue }
    if let s = value as? String { return s }
    return ""
}

func choiceLabel(_ item: PrefItem, _ key: String) -> String? {
    item.choices.first { $0.key == key }.map { L($0.value) }
}

func describe(_ value: NSObject?, _ item: PrefItem) -> String {
    guard let value else { return L("未設定（既定値）") }
    if let label = choiceLabel(item, choiceKey(value)) { return label }
    if isBoolean(value), let n = value as? NSNumber { return n.boolValue ? L("オン") : L("オフ") }
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

/// 入力された文字列を、手本の値と同じ型の値にする。手本がなければ中身から推定する
func makeValue(_ raw: String, like sample: NSObject?, item: PrefItem) -> NSObject {
    if isBoolean(sample) { return NSNumber(value: raw == "1") }
    if sample is NSNumber {
        if let i = Int(raw) { return NSNumber(value: i) }
        if let d = Double(raw) { return NSNumber(value: d) }
    }
    if sample is String { return raw as NSString }
    if !item.choices.isEmpty, item.choices.allSatisfy({ ["0", "1"].contains($0.key) }) {
        return NSNumber(value: raw == "1")
    }
    if let i = Int(raw) { return NSNumber(value: i) }
    if let d = Double(raw) { return NSNumber(value: d) }
    return raw as NSString
}

// MARK: - モデル

enum Target: Equatable {
    /// キーを削除して既定値に戻す
    case unset
    case value(NSObject)

    init(_ object: NSObject?) {
        self = object.map { .value($0) } ?? .unset
    }

    var object: NSObject? {
        if case .value(let v) = self { return v }
        return nil
    }
}

struct Entry: Identifiable {
    let item: PrefItem
    var current: NSObject?
    /// 「変更後」の値。現在の値と異なれば［適用］で書き込む
    var target: Target = .unset

    var id: String { item.domains[0] + "\u{1}" + item.key }
    var isChanged: Bool { current != target.object }
}

@MainActor
final class Store: ObservableObject {
    static let shared = Store()
    @Published var entries: [Entry]
    @Published var presetURL: URL?
    @Published var message: (title: String, body: String)?
    /// ［適用］の確認中・書き込み中。二重に適用しない
    @Published private(set) var isApplying = false

    init() {
        entries = catalog.map { Entry(item: $0) }
        refreshCurrent()
    }

    var changed: [Entry] { entries.filter(\.isChanged) }

    /// 現在の値を読み直す。変更していない項目は「変更後」も追従させる
    func refreshCurrent() {
        for i in entries.indices {
            let wasChanged = entries[i].isChanged
            entries[i].current = readValue(domain: entries[i].item.domains[0], key: entries[i].item.key)
            if !wasChanged { entries[i].target = Target(entries[i].current) }
        }
    }

    func index(_ id: String) -> Int? { entries.firstIndex { $0.id == id } }

    func setTarget(_ id: String, _ target: Target) {
        guard let i = index(id) else { return }
        entries[i].target = target
    }

    /// メニューで選んだ値（文字列化したもの）を設定する
    func setTarget(_ id: String, key: String) {
        guard let i = index(id) else { return }
        let e = entries[i]
        entries[i].target = .value(makeValue(key, like: e.current ?? e.target.object, item: e.item))
    }

    /// 入力欄の文字列を設定する。空なら既定値に戻す
    func setTarget(_ id: String, text: String) {
        guard let i = index(id) else { return }
        let e = entries[i]
        let t = text.trimmingCharacters(in: .whitespaces)
        entries[i].target = t.isEmpty ? .unset : .value(makeValue(t, like: e.current ?? e.target.object, item: e.item))
    }

    func revert(_ ids: [String]) {
        for i in entries.indices where ids.contains(entries[i].id) {
            entries[i].target = Target(entries[i].current)
        }
    }

    func revertAll() { revert(entries.map(\.id)) }

    /// おすすめの設定を「変更後」に入れる。ほかの行の変更はそのまま。現在の値と異なる件数を返す
    func loadRecommended() -> Int {
        var count = 0
        for r in recommended {
            guard let i = entries.firstIndex(where: { $0.item.domains[0] == r.domain && $0.item.key == r.key }) else { continue }
            entries[i].target = .value(r.value)
            if entries[i].isChanged { count += 1 }
        }
        return count
    }

    /// 一覧にないドメインとキーを追加する
    func addCustom(domain: String, key: String, label: String) {
        let item = PrefItem(category: customCategory, label: label.isEmpty ? key : label,
                            domains: [domain], key: key, choices: [:])
        var entry = Entry(item: item, current: readValue(domain: domain, key: key))
        if entries.contains(where: { $0.id == entry.id }) { return }
        entry.target = Target(entry.current)
        entries.append(entry)
    }

    // MARK: ファイル

    func presetData(_ list: [(Entry, NSObject?)]) throws -> Data {
        let items: [[String: Any]] = list.map { e, value in
            var d: [String: Any] = [
                "label": e.item.label, "category": e.item.category,
                "domains": e.item.domains, "key": e.item.key,
            ]
            if let value { d["value"] = value }
            return d
        }
        let root: [String: Any] = [
            "format": "PrefsPreset", "version": 1, "created": Date(),
            "host": Host.current().localizedName ?? "", "entries": items,
        ]
        return try PropertyListSerialization.data(fromPropertyList: root, format: .xml, options: 0)
    }

    /// 全項目の「変更後」の値をセットとして書き出す
    func save(to url: URL) {
        do {
            try presetData(entries.map { ($0, $0.target.object) }).write(to: url, options: .atomic)
            presetURL = url
        } catch {
            message = (L("書き出せませんでした"), error.localizedDescription)
        }
    }

    /// セットの値を「変更後」に入れる。セットにない項目は現在の値のまま
    func load(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            guard let root = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  root["format"] as? String == "PrefsPreset",
                  let items = root["entries"] as? [[String: Any]] else {
                message = (L("読み込めませんでした"), L("PrefsPresetのセットファイルではありません。"))
                return false
            }
            entries.removeAll { $0.item.category == customCategory }
            refreshCurrent()
            revertAll()
            for d in items {
                guard let domains = d["domains"] as? [String], let first = domains.first,
                      let key = d["key"] as? String else { continue }
                let target = Target(d["value"] as? NSObject)
                if let i = entries.firstIndex(where: { $0.item.domains[0] == first && $0.item.key == key }) {
                    entries[i].target = target
                } else {
                    let item = PrefItem(category: customCategory, label: d["label"] as? String ?? key,
                                        domains: domains, key: key, choices: [:])
                    entries.append(Entry(item: item, current: readValue(domain: first, key: key), target: target))
                }
            }
            presetURL = url
            return true
        } catch {
            message = (L("読み込めませんでした"), error.localizedDescription)
            return false
        }
    }

    // MARK: 適用

    static var backupFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/PrefsPreset/Backups")
    }

    /// 書き換える項目の現在の値をバックアップとして保存
    func backup(_ list: [Entry]) throws -> URL {
        let folder = Store.backupFolder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)
            .dateSeparator(.dash).timeSeparator(.omitted))
        let url = folder.appendingPathComponent("Backup \(stamp).prefspreset")
        try presetData(list.map { ($0, $0.current) }).write(to: url, options: .atomic)
        return url
    }

    func apply() {
        let list = changed
        guard !list.isEmpty, !isApplying else { return }
        isApplying = true
        defer { isApplying = false }
        let backupURL: URL
        do {
            backupURL = try backup(list)
        } catch {
            message = (L("バックアップできなかったため中止しました"), error.localizedDescription)
            return
        }
        for e in list {
            writeValue(e.target.object, domains: e.item.domains, key: e.item.key)
        }
        run("/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings", ["-u"])
        let domains = Set(list.flatMap { $0.item.domains })
        let processes = Set(domains.compactMap(processToRestart)).sorted()
        for name in processes { run("/usr/bin/killall", [name]) }
        refreshCurrent()

        // 書き込んだのに現在の値が「変更後」と一致しない項目は失敗として示す
        let failed = changed.filter { e in list.contains { $0.id == e.id } }
        var body = L("%@件の設定を書き込みました。", String(list.count - failed.count))
        if !failed.isEmpty {
            body += "\n" + L("書き込めなかった項目：%@", failed.map { L($0.item.label) }.joined(separator: L("、")))
        }
        if !processes.isEmpty { body += "\n" + L("再起動：%@", processes.joined(separator: L("、"))) }
        if domains.contains(featureFlagDomain) {
            body += "\n\n" + L("キャップスロックインジケータは、Macを再起動すると反映されます。")
        }
        if domains.contains(where: needsLogout) {
            body += "\n\n" + L("キーボード・トラックパッドなど一部の設定は、ログインし直すと反映されます。")
        }
        body += "\n\n" + L("元の値は「%@」に保存しました。ファイルメニューの「開く…」で読み込んで適用すると元に戻せます。", backupURL.lastPathComponent)
        message = (failed.isEmpty ? L("適用しました") : L("一部の設定を適用できませんでした"), body)
    }
}

// MARK: - ファイルの選択

let presetType = UTType(exportedAs: "jp.dtp-transit.prefspreset", conformingTo: .xmlPropertyList)

/// ［開く］の結果を画面側で受け取るための通知
extension Notification.Name {
    static let presetLoaded = Notification.Name("PrefsPresetLoaded")
}

@MainActor
func choosePresetFile() -> URL? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [presetType]
    NSApp.activate(ignoringOtherApps: true)
    return panel.runModal() == .OK ? panel.url : nil
}

@MainActor
func savePreset() {
    let store = Store.shared
    let panel = NSSavePanel()
    panel.allowedContentTypes = [presetType]
    panel.nameFieldStringValue = store.presetURL?.lastPathComponent
        ?? "\(Host.current().localizedName ?? "Mac").prefspreset"
    NSApp.activate(ignoringOtherApps: true)
    if panel.runModal() == .OK, let url = panel.url { store.save(to: url) }
}

@MainActor
func openPreset(_ url: URL? = nil) {
    guard let url = url ?? choosePresetFile() else { return }
    if Store.shared.load(from: url) {
        NotificationCenter.default.post(name: .presetLoaded, object: nil)
    }
}

@MainActor
func showBackupFolder() {
    try? FileManager.default.createDirectory(at: Store.backupFolder, withIntermediateDirectories: true)
    NSWorkspace.shared.open(Store.backupFolder)
}

@MainActor
func loadRecommended() {
    if Store.shared.loadRecommended() == 0 {
        Store.shared.message = (L("おすすめの設定"), L("おすすめの設定は、このMacにすべて適用済みです。"))
    } else {
        NotificationCenter.default.post(name: .presetLoaded, object: nil)
    }
}
