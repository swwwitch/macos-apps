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
    static let defaultOrder = ["edited", "date", "version"]
    static func order(defaults: UserDefaults = .standard) -> [String] {
        let value = defaults.stringArray(forKey: key) ?? defaultOrder
        return orders.contains(value) ? value : defaultOrder
    }
    static func label(_ order: [String], separator: String = "-") -> String {
        order.map { separator + ["version": "v4", "edited": "edited", "date": "20261006"][$0]! }.joined()
    }

    /// Character placed before each suffix (version, edited, date, parent folder name).
    static let separatorKey = "suffixSeparator"
    static let separators = ["-", "_"]

    /// Status words the palette adds by renaming (1.8.22); written right after "edited", one per name. Editable in Settings.
    static let statusKey = "statusWords"
    static let defaultStatuses = ["wip", "draft", "review", "revised", "updated", "fixed",
                                  "approved", "rejected", "archived", "flattened", "outlined"]
    static func statuses(defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: statusKey).map(validStatuses) ?? defaultStatuses
    }
    /// Words split on commas, spaces or newlines; letters first, then letters and digits. Words the other suffixes read
    /// (edited, v + digits) and duplicates are dropped.
    static func validStatuses(_ words: [String]) -> [String] {
        var result: [String] = []
        for word in words.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) {
            guard word.range(of: "^[A-Za-z][A-Za-z0-9]*$", options: .regularExpression) != nil, word != "edited",
                  word.range(of: "^v[0-9]+$", options: .regularExpression) == nil, !result.contains(word) else { continue }
            result.append(word)
        }
        return result
    }
    static func parseStatuses(_ text: String) -> [String] {
        validStatuses(text.components(separatedBy: CharacterSet(charactersIn: ",、，").union(.whitespacesAndNewlines)))
    }
    static func separator(defaults: UserDefaults = .standard) -> String {
        let value = defaults.string(forKey: separatorKey) ?? "-"
        return separators.contains(value) ? value : "-"
    }
}

private struct VersionedName {
    var base: String
    var version: String?
    var edited = false
    var status: String?
    var date: String?
    let separator: String

    /// Only the chosen separator is recognized, so names like IMG_20261010 stay intact with "-".
    init(_ stem: String, separator: String = "-", statuses: [String] = NamingSettings.statuses()) {
        base = stem
        self.separator = separator
        let pattern = NSRegularExpression.escapedPattern(for: separator) + "(?:v[0-9]+|edited|"
            + statuses.map { $0 + "|" }.joined() + "[0-9]{6}|[0-9]{8})$"
        while let range = base.range(of: pattern, options: .regularExpression) {
            let token = String(base[range].dropFirst())
            if token == "edited" {
                guard !edited else { break }
                edited = true
            } else if statuses.contains(token) {
                guard status == nil else { break }
                status = token
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
        let validOrder = NamingSettings.orders.contains(order) ? order : NamingSettings.defaultOrder
        return base + validOrder.compactMap { component -> String? in
            switch component {
            case "version": return version.map { separator + "v" + $0 }
            case "edited":
                let marks = (edited ? separator + "edited" : "") + (status.map { separator + $0 } ?? "")
                return marks.isEmpty ? nil : marks
            default: return date.map { separator + $0 }
            }
        }.joined()
    }
}

enum Duplicator {
    enum Mode: Equatable { case version, renameDate, date, edited, parent, swapNames, status(String) }

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

    /// Adds the parent name with `separator`; removes it after either separator, so names made with the other setting still toggle off.
    static func parentToggleDestination(_ source: URL, skipping skippedName: String = "",
                                        separator: String = NamingSettings.separator()) throws -> URL {
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
        let tags = NamingSettings.separators.map { $0 + parentName }
        // A dotted parent name must not become the extension of a suffix-only filename.
        let fullName = source.lastPathComponent
        let fullTag = tags.first { fullName.hasSuffix($0) }
        let removesFullSuffix = fullTag != nil
        let stem: String
        if let fullTag { stem = String(fullName.dropLast(fullTag.count)) }
        else if let tag = tags.first(where: { parts.stem.hasSuffix($0) }) { stem = String(parts.stem.dropLast(tag.count)) }
        else { stem = parts.stem + separator + parentName }
        guard !stem.isEmpty, stem != ".", stem != ".." else {
            throw NSError(domain: "CommandDee", code: 4, userInfo: [NSLocalizedDescriptionKey: L("error.emptyName")])
        }
        return parent.appendingPathComponent(stem + (removesFullSuffix ? "" : parts.suffix))
    }

    static func renameParentToggled(_ source: URL, skipping skippedName: String = "", separator: String = NamingSettings.separator(),
                                    manager: FileManager = .default) throws -> URL {
        let destination = try parentToggleDestination(source, skipping: skippedName, separator: separator)
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

    /// The name ⌃D / ⌃⌘D would give, or nil when the item already carries today's date.
    static func datedDestination(_ source: URL, date: Date = Date(), timeZone: TimeZone = .current,
                                 order: [String] = NamingSettings.order(),
                                 separator: String = NamingSettings.separator()) throws -> URL? {
        let parts = try nameParts(source)
        var name = VersionedName(parts.stem, separator: separator)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd"
        let today = formatter.string(from: date)
        if name.date == today || name.date == String(today.suffix(6)) { return nil }
        name.date = today
        return source.deletingLastPathComponent().appendingPathComponent(name.rendered(order: order) + parts.suffix)
    }

    /// rename: add or update the date on the item itself instead of a copy (⌃D 「日付付き」).
    static func duplicateDated(_ source: URL, rename: Bool = false, date: Date = Date(),
                               timeZone: TimeZone = .current, manager: FileManager = .default,
                               order: [String] = NamingSettings.order(),
                               separator: String = NamingSettings.separator()) throws -> URL {
        // A no-op preserves the original file and avoids collision alerts.
        guard let destination = try datedDestination(source, date: date, timeZone: timeZone, order: order, separator: separator) else { return source }
        return rename ? try moveWithoutReplacing(source, to: destination, manager: manager)
            : try copyWithoutReplacing(source, to: destination, manager: manager)
    }

    private static func moveWithoutReplacing(_ source: URL, to destination: URL,
                                              manager: FileManager) throws -> URL {
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

    /// The name ⌃⌘E would give, or nil when the item is already marked edited.
    static func editedDestination(_ source: URL, order: [String] = NamingSettings.order(),
                                  separator: String = NamingSettings.separator()) throws -> URL? {
        let parts = try nameParts(source)
        var name = VersionedName(parts.stem, separator: separator)
        if name.edited { return nil }
        name.edited = true
        return source.deletingLastPathComponent().appendingPathComponent(name.rendered(order: order) + parts.suffix)
    }

    /// ⌘E: duplicate with -edited- added; an existing date or version is kept as is.
    static func duplicateEdited(_ source: URL, manager: FileManager = .default,
                                order: [String] = NamingSettings.order(),
                                separator: String = NamingSettings.separator()) throws -> URL {
        guard let destination = try editedDestination(source, order: order, separator: separator) else { return source }
        return try copyWithoutReplacing(source, to: destination, manager: manager)
    }

    /// The name the palette's status list would give, or nil when the item already carries that status. Another status is replaced.
    static func statusDestination(_ source: URL, status: String, order: [String] = NamingSettings.order(),
                                  separator: String = NamingSettings.separator()) throws -> URL? {
        let parts = try nameParts(source)
        var name = VersionedName(parts.stem, separator: separator)
        if name.status == status { return nil }
        name.status = status
        return source.deletingLastPathComponent().appendingPathComponent(name.rendered(order: order) + parts.suffix)
    }

    static func currentStatus(_ source: URL, separator: String = NamingSettings.separator()) throws -> String? {
        VersionedName(try nameParts(source).stem, separator: separator).status
    }

    /// Palette only: renames the item itself (no copy).
    static func renameStatus(_ source: URL, status: String, manager: FileManager = .default,
                             order: [String] = NamingSettings.order(),
                             separator: String = NamingSettings.separator()) throws -> URL {
        guard let destination = try statusDestination(source, status: status, order: order, separator: separator) else { return source }
        return try moveWithoutReplacing(source, to: destination, manager: manager)
    }

    /// The next version name for ⌘D: one above the highest sibling (at least `after` + 1); reads the folder only.
    static func versionDestination(_ source: URL, after floor: Int = 1, manager: FileManager = .default,
                                   order: [String] = NamingSettings.order(),
                                   separator: String = NamingSettings.separator()) throws -> (url: URL, version: Int) {
        let parts = try nameParts(source)
        let suffix = parts.suffix
        let statuses = NamingSettings.statuses()
        var parsed = VersionedName(parts.stem, separator: separator, statuses: statuses)
        let parent = source.deletingLastPathComponent()
        // Never fill gaps in the sequence.
        let names = try manager.contentsOfDirectory(atPath: parent.path)
        var maximum = floor
        for name in names {
            guard suffix.isEmpty || name.hasSuffix(suffix) else { continue }
            let sibling = VersionedName(suffix.isEmpty ? name : String(name.dropLast(suffix.count)), separator: separator, statuses: statuses)
            guard sibling.base == parsed.base, sibling.date == parsed.date,
                  sibling.edited == parsed.edited, sibling.status == parsed.status, let digits = sibling.version else { continue }
            guard let number = Int(digits), number < Int.max else {
                throw NSError(domain: "CommandDee", code: 1, userInfo: [NSLocalizedDescriptionKey: L("error.versionTooLarge")])
            }
            maximum = max(maximum, number)
        }
        guard maximum < Int.max else {
            throw NSError(domain: "CommandDee", code: 1, userInfo: [NSLocalizedDescriptionKey: L("error.versionNext")])
        }
        parsed.version = String(maximum + 1)
        return (parent.appendingPathComponent(parsed.rendered(order: order) + suffix), maximum + 1)
    }

    static func duplicate(_ source: URL, manager: FileManager = .default,
                          order: [String] = NamingSettings.order(),
                          separator: String = NamingSettings.separator()) throws -> URL {
        var lastCollision = 1
        while true {
            // Rescan after a concurrent collision.
            let candidate = try versionDestination(source, after: lastCollision, manager: manager, order: order, separator: separator)
            do {
                try manager.copyItem(at: source, to: candidate.url)
                return candidate.url
            } catch let error as NSError {
                if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError {
                    lastCollision = candidate.version
                    continue
                }
                throw error
            }
        }
    }
}
