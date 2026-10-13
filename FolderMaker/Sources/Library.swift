import Foundation

/// 名前の規則: pattern, date style and the names of the three fields (empty = the standard names).
struct NamingRule: Codable, Equatable {
    var pattern = FolderName.defaultPattern
    var dateStyle = FolderName.DateStyle.compact.rawValue
    var clientLabel = ""
    var regionLabel = ""
    var memoLabel = ""
    var style: FolderName.DateStyle { FolderName.DateStyle(rawValue: dateStyle) ?? .compact }
}

/// Projects, the naming rule and file templates, kept in Application Support or in a shared folder (Dropbox …)
/// so several Macs use the same ones: <folder>/FolderMaker/Library.json and <folder>/FolderMaker/Templates.
enum Library {
    struct Contents: Codable, Equatable {
        var projects: [Project]
        var rule: NamingRule
    }

    static var localFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("FolderMaker", isDirectory: true)
    }
    /// The shared folder chosen in Settings, or empty for this Mac only.
    nonisolated(unsafe) static var sharedPath = ""
    static var folder: URL {
        sharedPath.isEmpty ? localFolder : URL(fileURLWithPath: NSString(string: sharedPath).expandingTildeInPath, isDirectory: true).appendingPathComponent("FolderMaker", isDirectory: true)
    }
    static var file: URL { folder.appendingPathComponent("Library.json") }

    static func load(from file: URL = file) -> Contents? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(Contents.self, from: data)
    }
    static func save(_ contents: Contents, to file: URL = file) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(contents).write(to: file, options: .atomic)
    }
    static func modified(_ file: URL = file) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date
    }
}
