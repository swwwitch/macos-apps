import Foundation

final class PFHistoryArchive: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    let folders: [Data]
    required init?(coder: NSCoder) {
        folders = coder.decodeObject(of: [NSArray.self, NSData.self], forKey: "folders") as? [Data] ?? []
    }
    func encode(with coder: NSCoder) { coder.encode(folders, forKey: "folders") }
}
struct Destination: Hashable {
    let url: URL
    let origin: String
}
enum FolderHistory {
    static func preferences(_ domain: String) -> [String: Any] {
        // Read via preferences service first, then disk. Never change another app's preferences.
        if let values = CFPreferencesCopyMultiple(nil, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: Any], !values.isEmpty { return values }
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/\(domain).plist")
        guard let data = try? Data(contentsOf: url), let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return [:] }
        return values
    }
    static func resolve(_ data: Data) -> URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale)
    }
    static func read() -> (items: [Destination], notes: [String]) {
        #if APP_STORE
        return ([], [])
        #else
        var result: [Destination] = [], notes: [String] = []
        let finder = preferences("com.apple.finder")
        let entries = finder["FXRecentFolders"] as? [[String: Any]] ?? []
        for entry in entries {
            if let data = entry["file-bookmark"] as? Data, let url = resolve(data) {
                result.append(Destination(url: url, origin: L("Finderの履歴")))
            }
        }
        if finder.isEmpty { notes.append(L("Finderの履歴を読み取れませんでした。")) }
        for domain in ["com.cocoatech.PathFinder-setapp", "com.cocoatech.PathFinder"] {
            guard let data = preferences(domain)["PFFileHistoryManager"] as? Data else { continue }
            do {
                let decoder = try NSKeyedUnarchiver(forReadingFrom: data)
                decoder.requiresSecureCoding = true
                decoder.setClass(PFHistoryArchive.self, forClassName: "PFFileHistoryMgr")
                let history = decoder.decodeObject(of: PFHistoryArchive.self, forKey: NSKeyedArchiveRootObjectKey)
                decoder.finishDecoding()
                if let error = decoder.error { throw error }
                guard let history else { notes.append(L("Path Finderの履歴形式を読み取れませんでした。")); continue }
                result += history.folders.compactMap { resolve($0).map { Destination(url: $0, origin: L("Path Finderの履歴")) } }
            } catch { notes.append(L("Path Finderの履歴: %@", String(describing: error.localizedDescription))) }
        }
        var seen = Set<String>()
        result = result.filter {
            let url = $0.url.standardizedFileURL
            guard url.isFileURL, seen.insert(url.path).inserted else { return false }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            return values == nil || (values?.isDirectory == true && values?.isPackage != true)
        }
        return (result, notes)
        #endif
    }
}
