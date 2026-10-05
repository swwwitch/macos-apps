import Foundation

enum ParentFolderSettings {
    static let key = "skippedParentFolderName"
    static func skippedName(defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: key) ?? NSUserName()
    }
}

enum Duplicator {
    enum Mode { case version, date, edited, parent }

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
            throw NSError(domain: "CommandDee", code: 3, userInfo: [NSLocalizedDescriptionKey: "親フォルダー名を取得できません。"])
        }
        let tag = "-" + parentName
        // A dotted parent name must not become the extension of a suffix-only filename.
        let fullName = source.lastPathComponent
        let removesFullSuffix = fullName.hasSuffix(tag)
        let stem = removesFullSuffix ? String(fullName.dropLast(tag.count))
            : (parts.stem.hasSuffix(tag) ? String(parts.stem.dropLast(tag.count)) : parts.stem + tag)
        guard !stem.isEmpty, stem != ".", stem != ".." else {
            throw NSError(domain: "CommandDee", code: 4, userInfo: [NSLocalizedDescriptionKey: "親フォルダー名を外すとファイル名が空になるため、処理できません。"])
        }
        return parent.appendingPathComponent(stem + (removesFullSuffix ? "" : parts.suffix))
    }

    static func renameParentToggled(_ source: URL, skipping skippedName: String = "", manager: FileManager = .default) throws -> URL {
        let destination = try parentToggleDestination(source, skipping: skippedName)
        func collision() -> NSError {
            NSError(domain: "CommandDee", code: 2, userInfo: [NSLocalizedDescriptionKey:
                "「\(destination.lastPathComponent)」がすでに存在するため名前を変更しませんでした。既存ファイルは上書きしていません。"])
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
                "「\(destination.lastPathComponent)」がすでに存在するため複製しませんでした。既存ファイルは上書きしていません。"])
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
                               timeZone: TimeZone = .current, manager: FileManager = .default) throws -> URL {
        let parts = try nameParts(source)
        var stem = parts.stem
        if let range = stem.range(of: "-(?:[0-9]{6}|[0-9]{8})$", options: .regularExpression) {
            stem = String(stem[..<range.lowerBound])
        }
        if edited && stem.hasSuffix("-edited") {
            stem = String(stem.dropLast("-edited".count))
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd"
        let name = stem + (edited ? "-edited-" : "-") + formatter.string(from: date) + parts.suffix
        let destination = source.deletingLastPathComponent().appendingPathComponent(name)
        return try copyWithoutReplacing(source, to: destination, manager: manager)
    }

    /// copyItem never overwrites a destination, including a concurrent creator.
    static func duplicate(_ source: URL, manager: FileManager = .default) throws -> URL {
        let parts = try nameParts(source)
        let suffix = parts.suffix
        var stem = parts.stem
        if let range = stem.range(of: "-v[0-9]+$", options: .regularExpression) {
            stem = String(stem[..<range.lowerBound])
        }
        let parent = source.deletingLastPathComponent()
        let pattern = "^" + NSRegularExpression.escapedPattern(for: stem)
            + "-v([0-9]+)" + NSRegularExpression.escapedPattern(for: suffix) + "$"
        let regex = try NSRegularExpression(pattern: pattern)
        var lastCollision = 1
        while true {
            // Rescan after a concurrent collision; never fill gaps in the sequence.
            let names = try manager.contentsOfDirectory(atPath: parent.path)
            var maximum = lastCollision
            for name in names {
                let range = NSRange(name.startIndex..., in: name)
                guard let match = regex.firstMatch(in: name, range: range),
                      let numberRange = Range(match.range(at: 1), in: name) else { continue }
                guard let number = Int(name[numberRange]), number < Int.max else {
                    throw NSError(domain: "CommandDee", code: 1, userInfo: [NSLocalizedDescriptionKey: "バージョン番号が大きすぎるため、次の番号を作成できません。"])
                }
                maximum = max(maximum, number)
            }
            guard maximum < Int.max else {
                throw NSError(domain: "CommandDee", code: 1, userInfo: [NSLocalizedDescriptionKey: "次のバージョン番号を作成できません。"])
            }
            let version = maximum + 1
            let candidate = parent.appendingPathComponent("\(stem)-v\(version)\(suffix)")
            do {
                try manager.copyItem(at: source, to: candidate)
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
