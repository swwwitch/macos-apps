import AppKit

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }
func LF(_ key: String, _ args: CVarArg...) -> String { String(format: L(key), arguments: args) }

/// メニュー項目1つ。path は「ファイル>書き出し>PNG...」の形
struct MenuEntry: Hashable {
    var path: String
    var shortcut: String
    var flags: String = ""
}

/// 1つのバージョンのメニュー全体。保存形式は AiMenuDiff.scpt と同じ TSV（#キー<TAB>値 のメタ行＋「パス<TAB>ショートカット<TAB>状態」）
struct MenuSnapshot {
    static let metaKeys = ["name", "product", "app", "version", "locale", "date", "tool"]
    var meta: [String: String]
    var entries: [MenuEntry]

    var name: String { meta["name"] ?? "" }
    var date: String { meta["date"] ?? "" }
    var locale: String { meta["locale"] ?? "" }

    func tsv() -> String {
        var lines = Self.metaKeys.compactMap { key in meta[key].map { "#\(key)\t\($0)" } }
        lines += entries.map { "\($0.path)\t\($0.shortcut)\t\($0.flags)" }
        return lines.joined(separator: "\n") + "\n"
    }

    static func parse(_ text: String) -> MenuSnapshot {
        var meta: [String: String] = [:]
        var entries: [MenuEntry] = []
        for line in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            if line.hasPrefix("#") {
                if fields.count >= 2 { meta[String(fields[0].dropFirst())] = fields[1] }
            } else {
                entries.append(MenuEntry(path: fields[0],
                                         shortcut: fields.count > 1 ? fields[1] : "",
                                         flags: fields.count > 2 ? fields[2] : ""))
            }
        }
        return MenuSnapshot(meta: meta, entries: entries)
    }

    /// 同じパスが2つ以上あるときは「 #2」「 #3」を付けて区別する
    static func numberingDuplicates(_ entries: [MenuEntry]) -> [MenuEntry] {
        var seen: [String: Int] = [:]
        return entries.map { entry in
            let count = (seen[entry.path] ?? 0) + 1
            seen[entry.path] = count
            guard count > 1 else { return entry }
            var numbered = entry
            numbered.path += " #\(count)"
            return numbered
        }
    }
}

/// 対応するアプリ
enum AdobeApp: String, CaseIterable, Identifiable {
    case illustrator, photoshop, indesign  // 画面のボタンの並び（Ai・Ps・Id）
    var id: String { rawValue }

    var title: String {
        switch self {
        case .illustrator: return "Illustrator"
        case .indesign: return "InDesign"
        case .photoshop: return "Photoshop"
        }
    }
    /// スナップショット名の頭（Ai31.0.0 ja_JP など）
    var prefix: String {
        switch self {
        case .illustrator: return "Ai"
        case .indesign: return "Id"
        case .photoshop: return "Ps"
        }
    }
    var folderPrefix: String { "Adobe " + title }
    var bundlePrefix: String {
        switch self {
        case .illustrator: return "com.adobe.illustrator"
        case .indesign: return "com.adobe.InDesign"
        case .photoshop: return "com.adobe.Photoshop"
        }
    }
    /// 言語フォルダー（ja_JP など）を探す場所
    var localeFolders: [String] {
        switch self {
        case .illustrator: return ["Presets.localized"]
        case .indesign: return ["Presets/InDesign Shortcut Sets", "Presets/InDesign_Workspaces"]
        case .photoshop: return ["Locales"]
        }
    }
}

/// インストールされているアプリ1本
struct AppInstall: Hashable {
    let app: AdobeApp
    let appURL: URL
    let version: String
    let folderName: String
    let locale: String

    var channel: String {
        if folderName.contains("Beta") { return " Beta" }
        if folderName.contains("Prerelease") { return " Prerelease" }
        return ""
    }
    /// スナップショットの名前（例：Ai31.0.0 ja_JP、Ai31.1.0 Beta ja_JP、Ps28.0.0 ja_JP）
    var snapshotName: String { "\(app.prefix)\(version)\(channel) \(locale)" }
    var displayName: String { folderName.replacingOccurrences(of: "Adobe ", with: "") }

    /// /Applications の「Adobe <アプリ名>*」フォルダーから探す（Beta・Prerelease は Bundle ID が別）
    static func discover(_ app: AdobeApp) -> [AppInstall] {
        let fileManager = FileManager.default
        let root = URL(fileURLWithPath: "/Applications")
        let folders = (try? fileManager.contentsOfDirectory(atPath: root.path)) ?? []
        var installs: [AppInstall] = []
        for folder in folders where folder.hasPrefix(app.folderPrefix) {
            let folderURL = root.appendingPathComponent(folder)
            let appNames = ((try? fileManager.contentsOfDirectory(atPath: folderURL.path)) ?? []).filter { $0.hasSuffix(".app") }
            for appName in appNames {
                let appURL = folderURL.appendingPathComponent(appName)
                guard let info = Bundle(url: appURL)?.infoDictionary,
                      (info["CFBundleIdentifier"] as? String)?.hasPrefix(app.bundlePrefix) == true,
                      let version = info["CFBundleShortVersionString"] as? String else { continue }
                installs.append(AppInstall(app: app, appURL: appURL, version: version, folderName: folder,
                                           locale: detectLocale(app, in: folderURL)))
            }
        }
        return installs.sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }

    static func detectLocale(_ app: AdobeApp, in folderURL: URL) -> String {
        for subpath in app.localeFolders {
            let entries = (try? FileManager.default.contentsOfDirectory(atPath: folderURL.appendingPathComponent(subpath).path)) ?? []
            if let locale = entries.sorted().first(where: { $0.range(of: "^[a-z]{2}_[A-Z]{2}$", options: .regularExpression) != nil }) {
                return locale
            }
        }
        return Locale.preferredLanguages.first ?? "unknown"
    }

    var runningApplication: NSRunningApplication? {
        let target = appURL.standardizedFileURL.path
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.standardizedFileURL.path == target && !$0.isTerminated
        }
    }
}

/// スナップショットの置き場所。既定は Application Support/MenuDiff/Snapshots、設定で変えられる
enum SnapshotStore {
    static let folderKey = "snapshotFolder"
    static let folderChanged = Notification.Name("MenuDiffSnapshotFolderChanged")

    static var defaultFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/MenuDiff/Snapshots")
    }

    static var folder: URL {
        if let path = UserDefaults.standard.string(forKey: folderKey), !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return defaultFolder
    }

    /// nil で既定に戻す
    static func setFolder(_ url: URL?) {
        if let url { UserDefaults.standard.set(url.path, forKey: folderKey) } else { UserDefaults.standard.removeObject(forKey: folderKey) }
        NotificationCenter.default.post(name: folderChanged, object: nil)
    }

    static func url(for name: String) -> URL { folder.appendingPathComponent(name + ".tsv") }

    /// そのアプリのスナップショット名（頭の Ai / Id / Ps で見分ける）
    static func names(for app: AdobeApp) -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return files.filter { $0.hasSuffix(".tsv") && $0.hasPrefix(app.prefix) }.map { String($0.dropLast(4)) }
    }

    static func load(_ name: String) -> MenuSnapshot? {
        guard let text = try? String(contentsOf: url(for: name), encoding: .utf8) else { return nil }
        return MenuSnapshot.parse(text)
    }

    static func save(_ snapshot: MenuSnapshot) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try snapshot.tsv().write(to: url(for: snapshot.name), atomically: true, encoding: .utf8)
    }
}
