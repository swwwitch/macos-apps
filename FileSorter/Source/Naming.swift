import Foundation

/// Pixel size and resolution of an image file.
struct ImageInfo: Equatable {
    var width: Int
    var height: Int
    var dpi: Int
}

enum ShotNaming {
    static let defaultTemplate = "ss-{width}-{height}-{dpi}-{date}"
    static let dateFormat = "yyyyMMdd-HHmmss"

    /// New screenshots: PNG files whose name does not contain "ss-" (already renamed ones do).
    static func isCandidate(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasSuffix(".png") && !lower.contains("ss-") && !name.hasPrefix(".")
    }

    static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }

    /// File name (with .png) from the template. Characters a file name cannot hold become "-".
    static func name(template: String, info: ImageInfo, date: Date) -> String {
        var base = template.isEmpty ? defaultTemplate : template
        for (token, value) in [("{width}", "\(info.width)"), ("{height}", "\(info.height)"), ("{dpi}", "\(info.dpi)"), ("{date}", format(date))] {
            base = base.replacingOccurrences(of: token, with: value)
        }
        base = base.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-").trimmingCharacters(in: .whitespaces)
        return (base.isEmpty ? "ss" : base) + ".png"
    }

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

/// Monitor paths are local to each Mac. Keep the old key available for rollback.
enum WatchFolders {
    static func canonical(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL.resolvingSymlinksInPath().path
    }
    static func normalize(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.filter { !$0.isEmpty }.map(canonical).filter { seen.insert($0).inserted }
    }
    static func migrate(_ defaults: UserDefaults) -> [String] {
        if let saved = defaults.stringArray(forKey: "shotFolders") { return normalize(saved) }
        let location = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") ?? NSHomeDirectory() + "/Desktop"
        return normalize([defaults.string(forKey: "shotFolder") ?? location])
    }
}
