import Foundation

/// カスタム: the synced folder the sources are relative to. A source starting with / or ~ is used as is.
enum SyncFolder {
    static let defaultPath = "~/sw Dropbox/takano masahiro/sync-setting/ai"
    static let storeKey = "syncFolder"

    static func expand(_ path: String) -> URL { URL(fileURLWithPath: (path as NSString).expandingTildeInPath) }
    static func isAbsolute(_ path: String) -> Bool { path.hasPrefix("/") || path.hasPrefix("~") }
    /// An empty synced folder means the default (an empty path would resolve against the working directory).
    static func base(_ path: String) -> URL { expand(path.trimmingCharacters(in: .whitespaces).isEmpty ? defaultPath : path) }
    static func resolve(_ path: String, base: String) -> URL {
        isAbsolute(path) ? expand(path) : Self.base(base).appendingPathComponent(path)
    }
    /// Relative when inside `base`, otherwise absolute (with ~). Compared precomposed: NSOpenPanel and saved paths can be NFD.
    static func relative(_ url: URL, base: String) -> String {
        let path = url.standardizedFileURL.path.precomposedStringWithCanonicalMapping
        let prefix = Self.base(base).standardizedFileURL.path.precomposedStringWithCanonicalMapping + "/"
        if path.hasPrefix(prefix) { return String(path.dropFirst(prefix.count)) }
        return (path as NSString).abbreviatingWithTildeInPath
    }
    /// 2.12–2.13 saved absolute paths: those inside `base` become relative.
    static func normalize(_ path: String, base: String) -> String {
        isAbsolute(path) ? relative(expand(path), base: base) : path
    }

    /// The keyboard shortcut source up to 2.13 was one .kys: its folder becomes the source and its name the set.
    /// `legacyDefault` (the 2.12 default, a file that did not exist) gives `defaultSource`.
    static func migrateShortcutSource(stored: String?, name: String?, base: String, defaultSource: String, legacyDefault: String) -> (source: String, name: String) {
        var name = name ?? ""
        guard var source = stored, source != legacyDefault, !source.isEmpty else { return (defaultSource, name) }
        source = normalize(source, base: base)
        if (source as NSString).pathExtension.lowercased() == "kys" {
            if name.isEmpty { name = ((source as NSString).lastPathComponent as NSString).deletingPathExtension.precomposedStringWithCanonicalMapping }
            source = (source as NSString).deletingLastPathComponent
        }
        return (source.isEmpty ? defaultSource : source, name)
    }
}

/// Symbolic links from Illustrator's folders to files kept in a synced folder.
enum SymbolicLinks {
    enum Linked: Equatable {
        case created
        case existing
        /// A link to another file was replaced, or a real file was moved to `backup`.
        case replaced(backup: URL?)
    }
    struct Summary: Equatable {
        var created = 0, replaced = 0, existing = 0
        /// Where real files were moved; nil when none were.
        var backups: URL?
        var moved = 0
        var total: Int { created + replaced + existing }
    }
    enum LinkError: LocalizedError, Equatable {
        /// The source folder is Illustrator's folder itself (or links back into it): linking would move the sources away.
        case sameFolder(String)
        case noFiles(String)
        var errorDescription: String? {
            switch self {
            case .sameFolder(let path): return String(format: NSLocalizedString("links.sameFolder", comment: ""), path)
            case .noFiles(let path): return String(format: NSLocalizedString("links.noFiles", comment: ""), path)
            }
        }
    }

    /// A folder name for one run of backups.
    static var stamp: String {
        ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withYear, .withMonth, .withDay, .withTime])
    }
    static func samePath(_ a: URL, _ b: URL) -> Bool {
        a.standardizedFileURL.path.precomposedStringWithCanonicalMapping == b.standardizedFileURL.path.precomposedStringWithCanonicalMapping
    }
    /// The real location, symbolic links resolved (for the same-folder check).
    static func real(_ url: URL) -> URL { url.resolvingSymlinksInPath().standardizedFileURL }

    /// The files of a folder to link: not hidden, not folders (Temp.localized and the like stay as they are), by name.
    static func files(in folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true }
            .sorted { $0.lastPathComponent.precomposedStringWithCanonicalMapping < $1.lastPathComponent.precomposedStringWithCanonicalMapping }
    }

    /// Makes 「<folder>/<source name>」 a symbolic link to `source`. A real file there is moved into `backups` first
    /// (and moved back when the link cannot be made); a link to elsewhere is replaced in one step.
    static func link(_ source: URL, into folder: URL, backups: URL) throws -> Linked {
        let fm = FileManager.default
        let destination = folder.appendingPathComponent(source.lastPathComponent)
        if let target = try? fm.destinationOfSymbolicLink(atPath: destination.path) {
            if samePath(URL(fileURLWithPath: target, relativeTo: folder), source) { return .existing }
            try replaceLink(destination, with: source)
            return .replaced(backup: nil)
        }
        guard fm.fileExists(atPath: destination.path) else {
            try fm.createSymbolicLink(at: destination, withDestinationURL: source)
            return .created
        }
        try fm.createDirectory(at: backups, withIntermediateDirectories: true)
        let moved = backups.appendingPathComponent(source.lastPathComponent)
        try fm.moveItem(at: destination, to: moved)
        do { try fm.createSymbolicLink(at: destination, withDestinationURL: source) } catch {
            try? fm.moveItem(at: moved, to: destination)
            throw error
        }
        return .replaced(backup: moved)
    }

    /// A new link under a temporary name, renamed over the old one: rename(2) replaces it atomically.
    private static func replaceLink(_ destination: URL, with source: URL) throws {
        let fm = FileManager.default
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString)")
        try fm.createSymbolicLink(at: temporary, withDestinationURL: source)
        guard rename(temporary.path, destination.path) == 0 else {
            let code = errno
            try? fm.removeItem(at: temporary)
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(code))
        }
    }

    /// Links every file of `source` into `folder` (made when missing). Refuses when `source` is `folder` or any file
    /// already resolves into `folder`: moving the "real" file aside would then take the source away.
    static func linkAll(from source: URL, into folder: URL, backups: URL, where include: (URL) -> Bool = { _ in true }) throws -> Summary {
        let files = try files(in: source).filter(include)
        guard !files.isEmpty else { throw LinkError.noFiles(source.path) }
        let realFolder = real(folder)
        if samePath(real(source), realFolder) || files.contains(where: { samePath(real($0).deletingLastPathComponent(), realFolder) }) {
            throw LinkError.sameFolder(source.path)
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var summary = Summary()
        for file in files {
            switch try link(file, into: folder, backups: backups) {
            case .created: summary.created += 1
            case .existing: summary.existing += 1
            case .replaced(let backup):
                summary.replaced += 1
                if backup != nil { summary.moved += 1; summary.backups = backups }
            }
        }
        return summary
    }
}
