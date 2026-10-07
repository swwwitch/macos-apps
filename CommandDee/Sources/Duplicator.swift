import Foundation
import Darwin

enum ParentFolderSettings {
    static let key = "skippedParentFolderName"
    static func skippedName(defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: key) ?? NSUserName()
    }
}

enum NamingSettings {
    static let key = "suffixOrder"
    static let orders = [
        ["version", "edited", "date"], ["version", "date", "edited"],
        ["edited", "version", "date"], ["edited", "date", "version"],
        ["date", "version", "edited"], ["date", "edited", "version"]
    ]
    static func order(defaults: UserDefaults = .standard) -> [String] {
        let value = defaults.stringArray(forKey: key) ?? orders[0]
        return orders.contains(value) ? value : orders[0]
    }
    static func label(_ order: [String]) -> String {
        order.map { ["version": "-v4", "edited": "-edited", "date": "-20261006"][$0]! }.joined()
    }
}

private struct VersionedName {
    var base: String
    var version: String?
    var edited = false
    var date: String?

    init(_ stem: String) {
        base = stem
        while let range = base.range(of: "-(?:v[0-9]+|edited|[0-9]{6}|[0-9]{8})$", options: .regularExpression) {
            let token = String(base[range].dropFirst())
            if token == "edited" {
                guard !edited else { break }
                edited = true
            } else if token.hasPrefix("v") {
                guard version == nil else { break }
                version = String(token.dropFirst())
            } else {
                guard date == nil else { break }
                date = token
            }
            base = String(base[..<range.lowerBound])
        }
    }

    func rendered(order: [String]) -> String {
        let validOrder = NamingSettings.orders.contains(order) ? order : NamingSettings.orders[0]
        return base + validOrder.compactMap { component -> String? in
            switch component {
            case "version": return version.map { "-v" + $0 }
            case "edited": return edited ? "-edited" : nil
            default: return date.map { "-" + $0 }
            }
        }.joined()
    }
}

enum Duplicator {
    enum Mode { case version, date, edited, parent, renameVersion, swapNames }

    /// One atomic filesystem operation: no temporary name or partially completed exchange.
    static func swapNames(_ sources: [URL]) throws -> [URL] {
        func invalid(_ message: String) -> NSError {
            NSError(domain: "CommandDee", code: 5, userInfo: [NSLocalizedDescriptionKey: message])
        }
        guard sources.count == 2 else { throw invalid(L("error.swapCount")) }
        let a = sources[0].standardizedFileURL
        let b = sources[1].standardizedFileURL
        guard a != b, a.deletingLastPathComponent().resolvingSymlinksInPath() == b.deletingLastPathComponent().resolvingSymlinksInPath() else {
            throw invalid(L("error.swapDistinct"))
        }
        var first = stat(), second = stat()
        guard lstat(a.path, &first) == 0, lstat(b.path, &second) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        guard first.st_dev != second.st_dev || first.st_ino != second.st_ino else {
            throw invalid(L("error.swapSameItem"))
        }
        guard (first.st_mode & S_IFMT) == (second.st_mode & S_IFMT) else {
            throw invalid(L("error.swapKind"))
        }
        guard renameatx_np(AT_FDCWD, a.path, AT_FDCWD, b.path, UInt32(RENAME_SWAP)) == 0 else {
            let failure = NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            throw invalid(L("error.swapFailed") + "\n" + failure.localizedDescription)
        }
        return [b, a]
    }

    private static func nameParts(_ source: URL) throws -> (stem: String, suffix: String) {
        let values = try source.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        let ext = values.isDirectory == true && values.isPackage != true ? "" : source.pathExtension
        let suffix = ext.isEmpty ? "" : "." + ext
        let name = source.lastPathComponent
        return (suffix.isEmpty ? name : String(name.dropLast(suffix.count)), suffix)
    }

    static func parentToggleDestination(_ source: URL, skipping skippedName: String = "") throws -> URL {
        let parts = try nameParts(source)
        let parent = source.deletingLastPathComponent()
        var namingParent = parent
        while !skippedName.isEmpty && namingParent.lastPathComponent == skippedName {
            let ancestor = namingParent.deletingLastPathComponent()
            guard ancestor.path != namingParent.path else { break }
            namingParent = ancestor
        }
        let parentName = namingParent.lastPathComponent
        guard !parentName.isEmpty, parentName != "/" else {
            throw NSError(domain: "CommandDee", code: 3, userInfo: [NSLocalizedDescriptionKey: L("error.noParentName")])
        }
        let tag = "-" + parentName
        // A dotted parent name must not become the extension of a suffix-only filename.
        let fullName = source.lastPathComponent
        let removesFullSuffix = fullName.hasSuffix(tag)
        let stem = removesFullSuffix ? String(fullName.dropLast(tag.count))
            : (parts.stem.hasSuffix(tag) ? String(parts.stem.dropLast(tag.count)) : parts.stem + tag)
        guard !stem.isEmpty, stem != ".", stem != ".." else {
            throw NSError(domain: "CommandDee", code: 4, userInfo: [NSLocalizedDescriptionKey: L("error.emptyName")])
        }
        return parent.appendingPathComponent(stem + (removesFullSuffix ? "" : parts.suffix))
    }

    static func renameParentToggled(_ source: URL, skipping skippedName: String = "", manager: FileManager = .default) throws -> URL {
        let destination = try parentToggleDestination(source, skipping: skippedName)
        func collision() -> NSError {
            NSError(domain: "CommandDee", code: 2, userInfo: [NSLocalizedDescriptionKey:
                L("error.renameExists", destination.lastPathComponent)])
        }
        if (try? manager.attributesOfItem(atPath: destination.path)) != nil { throw collision() }
        do { try manager.moveItem(at: source, to: destination) }
        catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError { throw collision() }
            throw error
        }
        return destination
    }

    private static func copyWithoutReplacing(_ source: URL, to destination: URL,
                                              manager: FileManager) throws -> URL {
        func collision() -> NSError {
            NSError(domain: "CommandDee", code: 2, userInfo: [NSLocalizedDescriptionKey:
                L("error.copyExists", destination.lastPathComponent)])
        }
        if (try? manager.attributesOfItem(atPath: destination.path)) != nil { throw collision() }
        do { try manager.copyItem(at: source, to: destination) }
        catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError { throw collision() }
            throw error
        }
        return destination
    }

    static func duplicateDated(_ source: URL, edited: Bool = false, date: Date = Date(),
                               timeZone: TimeZone = .current, manager: FileManager = .default,
                               order: [String] = NamingSettings.order()) throws -> URL {
        let parts = try nameParts(source)
        var name = VersionedName(parts.stem)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd"
        let today = formatter.string(from: date)
        // A no-op preserves the original file and avoids collision alerts.
        let isToday = name.date == today || name.date == String(today.suffix(6))
        if isToday && (!edited || name.edited) { return source }
        name.date = today
        if edited { name.edited = true }
        let destination = source.deletingLastPathComponent().appendingPathComponent(name.rendered(order: order) + parts.suffix)
        return try copyWithoutReplacing(source, to: destination, manager: manager)
    }

    static func duplicate(_ source: URL, manager: FileManager = .default,
                          order: [String] = NamingSettings.order()) throws -> URL {
        try incrementVersion(source, rename: false, manager: manager, order: order)
    }

    static func renameVersion(_ source: URL, manager: FileManager = .default,
                              order: [String] = NamingSettings.order()) throws -> URL {
        try incrementVersion(source, rename: true, manager: manager, order: order)
    }

    private static func incrementVersion(_ source: URL, rename: Bool, manager: FileManager,
                                         order: [String]) throws -> URL {
        let parts = try nameParts(source)
        let suffix = parts.suffix
        var parsed = VersionedName(parts.stem)
        let parent = source.deletingLastPathComponent()
        var lastCollision = 1
        while true {
            // Rescan after a concurrent collision; never fill gaps in the sequence.
            let names = try manager.contentsOfDirectory(atPath: parent.path)
            var maximum = lastCollision
            for name in names {
                guard suffix.isEmpty || name.hasSuffix(suffix) else { continue }
                let sibling = VersionedName(suffix.isEmpty ? name : String(name.dropLast(suffix.count)))
                guard sibling.base == parsed.base, sibling.date == parsed.date,
                      sibling.edited == parsed.edited, let digits = sibling.version else { continue }
                guard let number = Int(digits), number < Int.max else {
                    throw NSError(domain: "CommandDee", code: 1, userInfo: [NSLocalizedDescriptionKey: L("error.versionTooLarge")])
                }
                maximum = max(maximum, number)
            }
            guard maximum < Int.max else {
                throw NSError(domain: "CommandDee", code: 1, userInfo: [NSLocalizedDescriptionKey: L("error.versionNext")])
            }
            let version = maximum + 1
            parsed.version = String(version)
            let candidate = parent.appendingPathComponent(parsed.rendered(order: order) + suffix)
            do {
                if rename { try manager.moveItem(at: source, to: candidate) }
                else { try manager.copyItem(at: source, to: candidate) }
                return candidate
            } catch let error as NSError {
                if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError {
                    lastCollision = version
                    continue
                }
                throw error
            }
        }
    }
}
