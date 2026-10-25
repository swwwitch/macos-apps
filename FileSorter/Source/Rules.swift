import Foundation

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// Moves files added to a folder when their name contains a keyword or ends in one of the extensions.
struct SortRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var enabled = true
    var folder: String
    var keywords: [String] = []
    var extensions: [String] = []
    var destination: String

    /// Names are compared composed and case-insensitively (file systems may hand over decomposed kana).
    func matches(_ fileName: String) -> Bool {
        guard enabled else { return false }
        let name = fileName.precomposedStringWithCanonicalMapping.lowercased()
        if keywords.contains(where: { !$0.isEmpty && name.contains($0.precomposedStringWithCanonicalMapping.lowercased()) }) { return true }
        let ext = (name as NSString).pathExtension
        return extensions.contains { !$0.isEmpty && $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". ")) == ext }
    }

    static func list(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "," || $0 == "、" || $0 == "\n" }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static var defaults: [SortRule] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let shared = home + "/sw Dropbox/takano masahiro/Dropbox-shared"
        return [
            SortRule(name: L("preset.invoice"), folder: home + "/Downloads", keywords: ["請求書", "invoice"], destination: shared + "/sw経理関連2017-2018/PDF-IN"),
            SortRule(name: L("preset.music"), folder: home + "/Downloads", extensions: ["mp3", "m4a", "flac"], destination: shared + "/music"),
        ]
    }
}

enum FileNames {
    /// A free URL in `folder`: "name.ext", then "name 2.ext", "name 3.ext", …
    static func unique(_ name: String, in folder: URL, exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> URL {
        let base = (name as NSString).deletingPathExtension, ext = (name as NSString).pathExtension
        var candidate = folder.appendingPathComponent(name), number = 2
        while exists(candidate) {
            candidate = folder.appendingPathComponent("\(base) \(number)" + (ext.isEmpty ? "" : ".\(ext)"))
            number += 1
        }
        return candidate
    }
}

/// Files still being written are skipped until they settle.
enum PartialFile {
    static let suffixes = [".download", ".crdownload", ".part", ".partial", ".tmp", ".opdownload"]
    static func isPartial(_ name: String) -> Bool {
        let lower = name.lowercased()
        return name.hasPrefix(".") || suffixes.contains { lower.hasSuffix($0) }
    }
}
