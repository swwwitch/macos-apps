import Foundation

struct MovePair: Codable {
    let from: URL; let to: URL; var isSymbolicLink = false
    var identity: String? = nil
    var isCopy: Bool? = nil
    /// The destination is an existing symbolic link that the new link replaces (links into /Applications).
    var replacesLink: Bool? = nil
    /// Created as a symbolic link whatever the batch's operation (Setapp apps sent to /Applications).
    var asLink: Bool? = nil
}
struct MoveFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
enum MoveEngine {
    static func identity(_ url: URL) -> String? {
        guard let a = try? FileManager.default.attributesOfItem(atPath: url.path),
              let inode = a[.systemFileNumber] as? NSNumber, let device = a[.systemNumber] as? NSNumber,
              let created = a[.creationDate] as? Date else { return nil }
        return "\(device):\(inode):\(created.timeIntervalSince1970)"
    }
    static func availabilityReason(_ url: URL) -> String? {
        let components = url.standardizedFileURL.pathComponents
        if components.count > 2, components[1] == "Volumes" {
            let volume = URL(fileURLWithPath: "/Volumes").appendingPathComponent(components[2])
            if !FileManager.default.fileExists(atPath: volume.path) { return L("ボリューム「%@」が未接続です", String(describing: components[2])) }
        }
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]) else {
            return L("フォルダが見つからないか、アクセスできません")
        }
        guard values.isDirectory == true, values.isPackage != true else { return L("移動先として使えるフォルダではありません") }
        if !FileManager.default.isWritableFile(atPath: url.path) { return L("書き込み権限がありません") }
        return nil
    }
    static func destinationDisabledReason(_ sources: [URL], into destination: URL) -> String? {
        if let reason = availabilityReason(destination) { return reason }
        guard !sources.isEmpty else { return L("指定されていません。") }
        let target = destination.resolvingSymlinksInPath().standardizedFileURL
        for source in sources {
            let parent = source.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
            if parent == target { return L("選択中のファイルがあるフォルダ") }
        }
        return nil
    }
    /// True when an item's folder is on a different volume from `destination` (or cannot be read), where moving is not offered.
    static func onOtherVolume(_ sources: [URL], than destination: URL) -> Bool {
        func volume(_ url: URL) -> NSObject? {
            (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.volumeIdentifierKey]))?.volumeIdentifier as? NSObject
        }
        guard let target = volume(destination) else { return false }
        // The parent folder decides, so a symbolic link counts as being where the link itself is.
        return sources.contains { source in volume(source.deletingLastPathComponent()).map { !$0.isEqual(target) } ?? true }
    }
    static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path) || (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }
    /// Apps managed by Setapp live in /Applications/Setapp; a copy would not be updated or licensed, so they are linked.
    static func isSetappItem(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix("/Applications/Setapp/")
    }
    static func isSymbolicLink(_ url: URL) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }
    /// `replaceSymbolicLinks`: an existing symbolic link with the same name is overwritten instead of
    /// getting a numbered name (used when creating links in /Applications). Real files are never replaced.
    /// `linkSource`: sources that become symbolic links in any operation; they also replace a same-named link.
    static func plan(_ sources: [URL], into destination: URL, renameConflicts: Bool = false, replaceSymbolicLinks: Bool = false, linkSource: (URL) -> Bool = { _ in false }) throws -> [MovePair] {
        guard !sources.isEmpty else { throw MoveFailure(message: L("移動するファイルを選択してください。")) }
        let fm = FileManager.default
        let target = destination.resolvingSymlinksInPath().standardizedFileURL
        guard (try? target.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])).map({ $0.isDirectory == true && $0.isPackage != true }) == true else {
            throw MoveFailure(message: L("移動先のフォルダが見つかりません。"))
        }
        let sources = sources.map { $0.standardizedFileURL }
        var names = Set<String>()
        var inputs = Set<String>()
        var result: [MovePair] = []
        let occupied = Set((try fm.contentsOfDirectory(atPath: target.path)).map { $0.precomposedStringWithCanonicalMapping.lowercased() })
        for source in sources {
            guard inputs.insert(source.path).inserted else { throw MoveFailure(message: L("同じ項目が複数選択されています。")) }
            guard fm.fileExists(atPath: source.path) || (try? fm.destinationOfSymbolicLink(atPath: source.path)) != nil else { throw MoveFailure(message: L("選択した項目が見つかりません: %@", String(describing: source.lastPathComponent))) }
            var output = target.appendingPathComponent(source.lastPathComponent)
            guard source.deletingLastPathComponent().resolvingSymlinksInPath() != target else { throw MoveFailure(message: L("すでに移動先にある項目が含まれています。")) }
            let values = try source.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let actualSource = source.resolvingSymlinksInPath()
            if values.isDirectory == true && values.isSymbolicLink != true {
                guard target.path != actualSource.path && !target.path.hasPrefix(actualSource.path + "/") else { throw MoveFailure(message: L("フォルダ自身や、その中には移動できません。")) }
                guard !sources.contains(where: { $0 != source && $0.path.hasPrefix(source.path + "/") }) else { throw MoveFailure(message: L("親フォルダとその中の項目が同時に選択されています。")) }
            }
            func unavailable(_ url: URL) -> Bool {
                let name = url.lastPathComponent.precomposedStringWithCanonicalMapping.lowercased()
                return occupied.contains(name) || names.contains(name) || exists(url)
            }
            var replacesLink = false
            let linked = linkSource(source)
            if replaceSymbolicLinks || linked, isSymbolicLink(output), !names.contains(output.lastPathComponent.precomposedStringWithCanonicalMapping.lowercased()) {
                replacesLink = true
            } else if unavailable(output) {
                guard renameConflicts else { throw MoveFailure(message: L("移動先に同名の項目があります: %@\n上書きせずに中止しました。", String(describing: source.lastPathComponent))) }
                let ext = values.isDirectory == true ? "" : source.pathExtension
                let stem = ext.isEmpty ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent
                var number = 2
                repeat {
                    output = target.appendingPathComponent("\(stem) \(number)" + (ext.isEmpty ? "" : ".\(ext)"))
                    number += 1
                } while unavailable(output)
            }
            names.insert(output.lastPathComponent.precomposedStringWithCanonicalMapping.lowercased())
            result.append(MovePair(from: source, to: output, replacesLink: replacesLink ? true : nil, asLink: linked ? true : nil))
        }
        return result
    }
    static func execute(_ plan: [MovePair], asSymbolicLinks: Bool = false, asCopies: Bool = false, didComplete: ((MovePair) throws -> Void)? = nil) -> (done: [MovePair], error: Error?) {
        var done: [MovePair] = []
        for pair in plan {
            let asSymbolicLinks = asSymbolicLinks || pair.asLink == true
            do {
                if let expected = pair.identity, identity(pair.from) != expected {
                    throw MoveFailure(message: L("項目が削除・置換されたため処理を中止しました: %@", String(describing: pair.from.lastPathComponent)))
                }
                if asSymbolicLinks, pair.replacesLink == true {
                    // Create the new link beside the old one, then rename it over the old link (atomic).
                    guard isSymbolicLink(pair.to) else { throw MoveFailure(message: L("移動先に同名の項目があります: %@\n上書きせずに中止しました。", String(describing: pair.to.lastPathComponent))) }
                    let temporary = pair.to.deletingLastPathComponent().appendingPathComponent(".\(pair.to.lastPathComponent).\(UUID().uuidString)")
                    try FileManager.default.createSymbolicLink(atPath: temporary.path, withDestinationPath: pair.from.path)
                    guard rename(temporary.path, pair.to.path) == 0 else {
                        let code = errno
                        try? FileManager.default.removeItem(at: temporary)
                        throw NSError(domain: NSPOSIXErrorDomain, code: Int(code))
                    }
                    done.append(MovePair(from: pair.from, to: pair.to, isSymbolicLink: true, identity: identity(pair.to)))
                } else if asSymbolicLinks {
                    try FileManager.default.createSymbolicLink(atPath: pair.to.path, withDestinationPath: pair.from.path)
                    done.append(MovePair(from: pair.from, to: pair.to, isSymbolicLink: true, identity: identity(pair.to)))
                } else if asCopies {
                    try FileManager.default.copyItem(at: pair.from, to: pair.to)
                    done.append(MovePair(from: pair.from, to: pair.to, identity: identity(pair.to), isCopy: true))
                } else {
                    try FileManager.default.moveItem(at: pair.from, to: pair.to)
                    var completed = pair; completed.identity = identity(pair.to)
                    done.append(completed)
                }
                try didComplete?(done.last!)
            }
            catch { return (done, error) }
        }
        return (done, nil)
    }
}
