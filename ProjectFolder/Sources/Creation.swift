import Foundation

/// File-name rules shared by every mode: NFC spelling, Windows-safe names, the volume's case rule.
enum FileNames {
    /// Characters Windows does not allow in names, and its reserved device names.
    static let windowsCharacters = CharacterSet(charactersIn: "\\*?\"<>|")
    static let windowsReserved = Set(["CON", "PRN", "AUX", "NUL"] + (1...9).map { "COM\($0)" } + (1...9).map { "LPT\($0)" })

    /// True when Windows (and so a shared Dropbox folder opened there) cannot use this one name.
    static func windowsProblem(_ name: String) -> Bool {
        if name.rangeOfCharacter(from: windowsCharacters) != nil { return true }
        if name.hasSuffix(" ") || name.hasSuffix(".") { return true }
        let base = name.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? name
        return windowsReserved.contains(base.uppercased())
    }

    /// Whether the volume holding `url` tells "A" from "a" (rare on Macs; APFS is case-insensitive by default).
    static func caseSensitive(at url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]))?.volumeSupportsCaseSensitiveNames ?? false
    }

    /// Foundation writes new names decomposed (NFD). This renames the item to the composed (NFC) spelling, through a
    /// temporary name because APFS treats both spellings as the same name. Returns the item's URL either way.
    @discardableResult
    static func makeNFC(_ url: URL) -> URL {
        // Paths stay Strings: URL.path and lastPathComponent may hand back the NFD spelling.
        let parent = url.deletingLastPathComponent().path
        let wanted = url.lastPathComponent.precomposedStringWithCanonicalMapping
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: parent),
              let onDisk = names.first(where: { $0 == wanted }) else { return url }
        let target = (parent as NSString).appendingPathComponent(wanted)
        if onDisk.unicodeScalars.elementsEqual(wanted.unicodeScalars) { return URL(fileURLWithPath: target) }
        let temporary = (parent as NSString).appendingPathComponent(".foldermaker-\(UUID().uuidString)")
        let current = (parent as NSString).appendingPathComponent(onDisk)
        guard rename(current, temporary) == 0 else { return URL(fileURLWithPath: current) }
        if renamex_np(temporary, target, UInt32(RENAME_EXCL)) != 0 { _ = rename(temporary, current); return URL(fileURLWithPath: current) }
        return URL(fileURLWithPath: target)
    }
}

/// What one press of 「作成」 made, kept for 「直前の作成を取り消す」 (in memory until the next creation or quit).
struct CreationRecord: Equatable {
    struct Item: Equatable {
        var url: URL
        var isFile: Bool
        var modified: Date?
        var size: Int?
    }
    var items: [Item] = []
    /// AT-Recent links and the folders they point to.
    var links: [(link: URL, target: URL)] = []
    static func == (a: CreationRecord, b: CreationRecord) -> Bool {
        a.items == b.items && a.links.map(\.link) == b.links.map(\.link)
    }

    mutating func addFolder(_ url: URL) { items.append(Item(url: url, isFile: false)) }
    mutating func addFile(_ url: URL) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        items.append(Item(url: url, isFile: true, modified: attributes?[.modificationDate] as? Date, size: (attributes?[.size] as? NSNumber)?.intValue))
    }

    struct UndoResult: Equatable { var trashed = 0; var kept: [String] = [] }

    /// Children first. A file goes to the Trash only when its size and date are as written; a folder only when it is
    /// empty apart from .DS_Store. Anything changed since stays, and so do the folders around it.
    func undo(trash: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) -> UndoResult {
        var result = UndoResult()
        let fm = FileManager.default
        for (link, target) in links {
            guard let destination = try? fm.destinationOfSymbolicLink(atPath: link.path),
                  URL(fileURLWithPath: destination).standardizedFileURL.path == target.standardizedFileURL.path else { continue }
            if (try? trash(link)) != nil { result.trashed += 1 }
        }
        for item in items.reversed() {
            guard fm.fileExists(atPath: item.url.path) else { continue }
            var untouched: Bool
            if item.isFile {
                let attributes = try? fm.attributesOfItem(atPath: item.url.path)
                untouched = attributes?[.modificationDate] as? Date == item.modified && (attributes?[.size] as? NSNumber)?.intValue == item.size
            } else {
                untouched = ((try? fm.contentsOfDirectory(atPath: item.url.path)) ?? ["?"]).allSatisfy { $0 == ".DS_Store" }
            }
            if untouched, (try? trash(item.url)) != nil { result.trashed += 1 } else { result.kept.append(item.url.lastPathComponent) }
        }
        return result
    }
}

/// Makes folders and files for the bulk and project modes (and the structure inside a single folder).
enum Creator {
    struct Result {
        var record = CreationRecord()
        var created: [URL] = []
        var existing = 0
        var invalid = 0
        var failures: [String] = []
        var missingTemplates = Set<String>()
    }

    /// Each level is made on its own, so implied parent folders ("a" for "a/b") are recorded and spelled NFC too.
    static func make(_ entries: [BulkNames.Entry], in parent: URL, projectName: String, nfc: Bool,
                     templates: URL = FileTemplates.folder, date: Date = Date()) -> Result {
        var result = Result()
        let fm = FileManager.default
        for entry in entries {
            guard let path = entry.path else { result.invalid += 1; continue }
            let parts = path.split(separator: "/").map(String.init)
            var folder = parent
            for (index, part) in parts.enumerated() {
                let isLast = index == parts.count - 1
                let url = folder.appendingPathComponent(nfc ? part.precomposedStringWithCanonicalMapping : part, isDirectory: !(isLast && entry.isFile))
                if fm.fileExists(atPath: url.path) {
                    if isLast { result.existing += 1 }
                    folder = url
                    continue
                }
                do {
                    if isLast && entry.isFile {
                        var source: URL?
                        switch FileTemplates.lookup(fileName: part, explicit: entry.template, in: templates) {
                        case .template(let url): source = url
                        case .missing(let name): result.missingTemplates.insert(name)
                        case .none: break
                        }
                        // Bulk passes no name: {{project}} is the line's top folder, or the destination folder.
                        let project = !projectName.isEmpty ? projectName : (parts.count > 1 ? parts[0] : parent.lastPathComponent)
                        try FileTemplates.write(to: url, template: source, project: project, date: date)
                        let final = nfc ? FileNames.makeNFC(url) : url
                        result.record.addFile(final)
                        result.created.append(final)
                    } else {
                        try fm.createDirectory(at: url, withIntermediateDirectories: false)
                        let final = nfc ? FileNames.makeNFC(url) : url
                        result.record.addFolder(final)
                        if isLast { result.created.append(final) }
                        folder = final
                    }
                } catch {
                    result.failures.append(path + "：" + error.localizedDescription)
                    break
                }
            }
        }
        return result
    }
}
