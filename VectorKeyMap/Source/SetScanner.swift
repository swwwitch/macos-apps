import Foundation

/// A .kys the app can compare: the bundled defaults, one found in Illustrator's settings, or one the user added.
struct KeySetSource: Identifiable, Hashable {
    enum Origin: Hashable {
        case bundled
        case detected(version: String)
        case added
    }
    static let bundledID = "bundled"

    let id: String
    let name: String
    let url: URL?
    let origin: Origin
    var isActive = false
}

/// The set Illustrator uses, from /KBSCShortcutFile in its preferences.
struct ActiveSet: Equatable {
    let name: String?
    let isPreset: Bool
}

enum SetScanner {
    private static let prefix = "Adobe Illustrator ", suffix = " Settings"

    /// Sets in ~/Library/Preferences/Adobe Illustrator <version> Settings/<locale>. Release versions come first, newest first.
    /// Versions usually link to one file, so each file is listed once, under its newest version.
    static func scan(preferences: URL) -> (sources: [KeySetSource], active: ActiveSet?) {
        let manager = FileManager.default
        let names = (try? manager.contentsOfDirectory(atPath: preferences.path)) ?? []
        let versions = names.compactMap { name -> String? in
            guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return nil }
            return String(name.dropFirst(prefix.count).dropLast(suffix.count))
        }.sorted { a, b in
            let releaseA = Int(a) != nil, releaseB = Int(b) != nil
            return releaseA != releaseB ? releaseA : a.compare(b, options: .numeric) == .orderedDescending
        }
        var sources: [KeySetSource] = []
        var seen = Set<String>()
        var active: ActiveSet?
        var activeFolder: URL?
        for version in versions {
            let root = preferences.appendingPathComponent(prefix + version + suffix)
            let locales = ((try? manager.contentsOfDirectory(atPath: root.path)) ?? []).filter { $0.contains("_") }.sorted { a, b in
                (a == "ja_JP" ? 0 : 1, a) < (b == "ja_JP" ? 0 : 1, b)
            }
            for locale in locales {
                let folder = root.appendingPathComponent(locale)
                if active == nil, Int(version) != nil, let text = prefsText(folder), let found = activeSet(text) {
                    active = found
                    activeFolder = folder
                }
                let files = ((try? manager.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(".kys") }.sorted()
                for file in files {
                    let url = folder.appendingPathComponent(file).resolvingSymlinksInPath()
                    guard seen.insert(url.path).inserted, manager.fileExists(atPath: url.path) else { continue }
                    sources.append(KeySetSource(id: url.path, name: (file as NSString).deletingPathExtension, url: url, origin: .detected(version: version)))
                }
            }
        }
        if let active, !active.isPreset, let name = active.name, let activeFolder {
            let path = activeFolder.appendingPathComponent(name + ".kys").resolvingSymlinksInPath().path
            if let index = sources.firstIndex(where: { $0.id == path }) { sources[index].isActive = true }
        }
        return (sources, active)
    }

    private static func prefsText(_ folder: URL) -> String? {
        for name in ["Adobe Illustrator 環境設定", "Adobe Illustrator Prefs"] {
            if let data = try? Data(contentsOf: folder.appendingPathComponent(name)) { return String(decoding: data, as: UTF8.self) }
        }
        return nil
    }

    /// /KBSCShortcutFile { /IsPreset 0 /FileName [ 7 73772d32303230 ] }. /FileName is the set's name in hex.
    static func activeSet(_ prefs: String) -> ActiveSet? {
        guard let range = prefs.range(of: "/KBSCShortcutFile") else { return nil }
        let block = prefs[range.upperBound...].prefix(400)
        let isPreset = block.range(of: #"/IsPreset\s+1"#, options: .regularExpression) != nil
        return ActiveSet(name: fileName(block), isPreset: isPreset)
    }

    private static func fileName(_ block: Substring) -> String? {
        guard let match = block.range(of: #"/FileName\s*\[\s*\d+\s+([0-9a-fA-F\s]+)\]"#, options: .regularExpression) else { return nil }
        let hex = block[match].drop { $0 != "[" }.dropFirst().dropLast().split(whereSeparator: \.isWhitespace).dropFirst().joined()
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex, let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) {
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        let name = String(decoding: bytes, as: UTF8.self)
        return name.isEmpty ? nil : name
    }
}
