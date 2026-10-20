import AppKit
import UniformTypeIdentifiers

#if !APP_STORE
/// One installed version of an app whose yearly versions share a bundle ID (Adobe installs them side by side).
struct InstalledVersion: Identifiable, Hashable {
    /// CFBundleVersion: what Launch Services matches LSHandlerPreferredVersions against (InDesign: 20550, not 20.5.5.119).
    let version: String
    let shortVersion: String
    /// Copies with the same version (e.g. 「Adobe Illustrator」 and 「Adobe Illustrator 2025」) cannot be told apart by Launch Services.
    let urls: [URL]
    var id: String { version }
    var label: String {
        let names = urls.map(Application.versionedName).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        return names.joined(separator: " / ") + "（\(shortVersion)）"
    }
}

/// Opens a file type with a chosen version of an app that shares its bundle ID with other versions.
/// The public API (LSSetDefaultRoleHandlerForContentType, NSWorkspace.setDefaultApplication) stores the bundle ID only,
/// with the version "-" (newest). The version is written as LSHandlerPreferredVersions into Launch Services' own
/// record, and lsd is restarted to read it (measured on macOS 26: honored by Finder's open and urlForApplication(toOpen:)).
enum VersionPinning {
    static let products: [(name: String, bundleID: String)] = [
        ("Illustrator", "com.adobe.illustrator"),
        ("Photoshop", "com.adobe.Photoshop"),
        ("InDesign", "com.adobe.InDesign"),
        ("InCopy", "com.adobe.InCopy"),
        ("After Effects", "com.adobe.AfterEffects")
    ]
    static let anyVersion = "-"
    static var recordURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist")
    }
    static var backupFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/ExtensionLinker/LaunchServicesBackups", isDirectory: true)
    }

    /// Installed versions, newest first. Copies in the Trash are left out.
    static func versions(of bundleID: String) -> [InstalledVersion] {
        let urls = (LSCopyApplicationURLsForBundleIdentifier(bundleID as CFString, nil)?.takeRetainedValue() as? [URL] ?? [])
            .filter { !$0.path.contains("/.Trash/") }
        var grouped: [String: (short: String, urls: [URL])] = [:]
        for url in urls {
            guard let info = Bundle(url: url)?.infoDictionary, let version = info["CFBundleVersion"] as? String else { continue }
            grouped[version, default: ((info["CFBundleShortVersionString"] as? String) ?? version, [])].urls.append(url)
        }
        return grouped.map { InstalledVersion(version: $0.key, shortVersion: $0.value.short, urls: $0.value.urls.sorted { $0.path < $1.path }) }
            .sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }
    static func bundleVersion(of url: URL) -> String? { Bundle(url: url)?.infoDictionary?["CFBundleVersion"] as? String }

    /// Preferred version per content type in the record; "-" or no entry means the newest.
    static func pinnedVersions(for types: [String]) -> [String: String] {
        guard let handlers = try? readRecord().handlers else { return [:] }
        var result: [String: String] = [:]
        for type in types {
            let key = recordKey(for: type)
            let entry = handlers.first { matches($0, key) }
            result[type] = (entry?["LSHandlerPreferredVersions"] as? [String: Any])?["LSHandlerRoleAll"] as? String ?? anyVersion
        }
        return result
    }

    struct Change {
        let bundleID: String
        /// nil: back to the newest.
        let version: String?
        let types: [String]
    }

    /// Writes all changes at once, restarts lsd once and confirms what Launch Services now opens.
    /// On a failed confirmation the previous record is put back.
    static func apply(_ changes: [Change]) async throws {
        let original = try Data(contentsOf: recordURL)
        var record = try readRecord(original)
        try checkNothingPending(record.handlers)
        let now = Int(Date().timeIntervalSinceReferenceDate)
        for change in changes {
            for type in change.types {
                let key = recordKey(for: type)
                var entry = record.handlers.first { matches($0, key) } ?? key.newEntry
                record.handlers.removeAll { matches($0, key) }
                // lsd itself writes bundle IDs in lowercase.
                entry["LSHandlerRoleAll"] = change.bundleID.lowercased()
                entry["LSHandlerPreferredVersions"] = ["LSHandlerRoleAll": change.version ?? anyVersion]
                entry["LSHandlerModificationDate"] = now
                record.handlers.append(entry)
            }
        }
        record.root["LSHandlers"] = record.handlers
        let data = try PropertyListSerialization.data(fromPropertyList: record.root, format: record.format, options: 0)
        try backUp(original)
        try data.write(to: recordURL, options: .atomic)
        await restartLaunchServices()
        guard await confirm(changes) else {
            try? original.write(to: recordURL, options: .atomic)
            await restartLaunchServices()
            throw NSError(domain: "DutiGUI", code: 2, userInfo: [NSLocalizedDescriptionKey: L("版の切り替えを確認できなかったため、元に戻しました。")])
        }
    }

    /// Declared types are recorded by identifier; dynamic ones (dyn.…, e.g. .ait without a declaring app) by filename extension.
    private struct RecordKey {
        let field: String
        let value: String
        var newEntry: [String: Any] {
            field == "LSHandlerContentTag" ? ["LSHandlerContentTagClass": "public.filename-extension", field: value] : [field: value]
        }
    }
    private static func recordKey(for type: String) -> RecordKey {
        if let utType = UTType(type), utType.isDynamic, let ext = utType.preferredFilenameExtension {
            return RecordKey(field: "LSHandlerContentTag", value: ext)
        }
        return RecordKey(field: "LSHandlerContentType", value: type)
    }
    private static func matches(_ entry: [String: Any], _ key: RecordKey) -> Bool {
        guard (entry[key.field] as? String)?.caseInsensitiveCompare(key.value) == .orderedSame else { return false }
        return key.field == "LSHandlerContentType" || entry["LSHandlerContentTagClass"] as? String == "public.filename-extension"
    }
    /// The content type an entry stands for.
    private static func contentType(of entry: [String: Any]) -> String? {
        if let type = entry["LSHandlerContentType"] as? String { return type }
        guard entry["LSHandlerContentTagClass"] as? String == "public.filename-extension", let ext = entry["LSHandlerContentTag"] as? String else { return nil }
        return UTType(filenameExtension: ext)?.identifier
    }

    private struct Record {
        var root: [String: Any]
        var handlers: [[String: Any]]
        var format: PropertyListSerialization.PropertyListFormat
    }
    private static func readRecord(_ data: Data? = nil) throws -> Record {
        var format = PropertyListSerialization.PropertyListFormat.binary
        let data = try data ?? Data(contentsOf: recordURL)
        guard let root = try PropertyListSerialization.propertyList(from: data, options: [], format: &format) as? [String: Any] else {
            throw NSError(domain: "DutiGUI", code: 3, userInfo: [NSLocalizedDescriptionKey: L("関連付けの記録を読み込めませんでした。")])
        }
        return Record(root: root, handlers: root["LSHandlers"] as? [[String: Any]] ?? [], format: format)
    }
    /// lsd keeps recent changes in memory for a while (measured: minutes) and drops them when it is restarted.
    /// A record that disagrees with what Launch Services answers means such changes are waiting; write nothing then.
    private static func checkNothingPending(_ handlers: [[String: Any]]) throws {
        for entry in handlers {
            guard let type = contentType(of: entry), let recorded = entry["LSHandlerRoleAll"] as? String,
                  NSWorkspace.shared.urlForApplication(withBundleIdentifier: recorded) != nil else { continue }
            let current = LSCopyDefaultRoleHandlerForContentType(type as CFString, .all)?.takeRetainedValue() as String?
            if current?.caseInsensitiveCompare(recorded) != .orderedSame {
                throw NSError(domain: "DutiGUI", code: 4, userInfo: [NSLocalizedDescriptionKey: L("macOSが関連付けの変更をまだ保存していません。数分待ってからもう一度実行してください。")])
            }
        }
    }
    /// Keeps the 10 newest copies of the record before each change.
    private static func backUp(_ data: Data) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        try data.write(to: backupFolder.appendingPathComponent("launchservices.secure-\(formatter.string(from: Date())).plist"), options: .atomic)
        let old = (try? fm.contentsOfDirectory(at: backupFolder, includingPropertiesForKeys: nil))?.filter { $0.pathExtension == "plist" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }.dropFirst(10) ?? []
        for url in old { try? fm.removeItem(at: url) }
    }
    private static func restartLaunchServices() async {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            process.arguments = ["lsd"]
            try? process.run()
            process.waitUntilExit()
        }.value
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
    private static func confirm(_ changes: [Change]) async -> Bool {
        // Right after the restart this process may still answer from the old record, so wait for the expected version
        // (for "-", the newest one, which Launch Services picks).
        let expected = changes.map { $0.version ?? versions(of: $0.bundleID).first?.version }
        for attempt in 0..<20 {
            let done = zip(changes, expected).allSatisfy { change, version in
                change.types.allSatisfy { type in
                    guard let utType = UTType(type), let url = NSWorkspace.shared.urlForApplication(toOpen: utType),
                          Bundle(url: url)?.bundleIdentifier?.caseInsensitiveCompare(change.bundleID) == .orderedSame else { return false }
                    return version.map { bundleVersion(of: url) == $0 } ?? true
                }
            }
            if done { return true }
            if attempt < 19 { try? await Task.sleep(nanoseconds: 250_000_000) }
        }
        return false
    }
}
#endif
