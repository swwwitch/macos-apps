import Foundation

struct MoveError: LocalizedError { let key: String; var errorDescription: String? { NSLocalizedString(key, comment: "") } }
struct FileIdentity: Equatable {
    let device: UInt64
    let inode: UInt64
    static func read(_ url: URL) -> FileIdentity? {
        guard let a = try? FileManager.default.attributesOfItem(atPath: url.path),
              let d = a[.systemNumber] as? NSNumber, let i = a[.systemFileNumber] as? NSNumber else { return nil }
        return FileIdentity(device: d.uint64Value, inode: i.uint64Value)
    }
}
struct MoveItem { let source: URL; let identity: FileIdentity }
struct MovePlan {
    let source: URL; let destination: URL; let sourceID: FileIdentity; let destinationID: FileIdentity
    let items: [MoveItem]
}
struct MoveProgress { var total = 0; var processed = 0; var moved = 0; var skipped = 0; var failed = 0; var cancelled = false; var error: String?; var journal: URL? }
final class Cancellation: @unchecked Sendable {
    private let lock = NSLock(); private var value = false
    func cancel() { lock.lock(); value = true; lock.unlock() }
    var requested: Bool { lock.lock(); defer { lock.unlock() }; return value }
}
enum MoveEngine {
    static func exists(_ u: URL) -> Bool { FileIdentity.read(u) != nil }
    static func plan(source: URL, destination: URL, includeHidden: Bool, includeFolders: Bool, cancel: Cancellation) throws -> MovePlan {
        let fm = FileManager.default
        let s = source.resolvingSymlinksInPath().standardizedFileURL
        let d = destination.resolvingSymlinksInPath().standardizedFileURL
        for u in [s, d] {
            let r = try u.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            guard r.isDirectory == true, r.isPackage != true else { throw MoveError(key: "invalidFolder") }
        }
        guard s != d, !d.path.hasPrefix(s.path + "/"), s.path != "/" else { throw MoveError(key: "nestedFolder") }
        guard fm.isReadableFile(atPath: s.path), fm.isWritableFile(atPath: s.path), fm.isWritableFile(atPath: d.path) else { throw MoveError(key: "permissionError") }
        guard let sid = FileIdentity.read(s), let did = FileIdentity.read(d) else { throw MoveError(key: "invalidFolder") }
        let urls = try fm.contentsOfDirectory(at: s, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: includeHidden ? [] : [.skipsHiddenFiles])
        var items: [MoveItem] = []
        for u in urls {
            if cancel.requested { throw MoveError(key: "cancelled") }
            let v = try u.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if !includeFolders && v.isDirectory == true && v.isSymbolicLink != true { continue }
            guard let id = FileIdentity.read(u) else { throw MoveError(key: "changedSource") }
            items.append(MoveItem(source: u, identity: id))
        }
        return MovePlan(source: s, destination: d, sourceID: sid, destinationID: did, items: items)
    }
    // Direct argv, no shell or glob expansion. Bounded batches avoid ARG_MAX for large folders.
    static func run(_ plan: MovePlan, cancel: Cancellation, journalDirectory: URL, progress: (MoveProgress) -> Void) -> MoveProgress {
        var result = MoveProgress(total: plan.items.count)
        let fm = FileManager.default
        var handle: FileHandle?
        func record(_ value: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]); data.append(10)
            try handle?.write(contentsOf: data)
        }
        do {
            try fm.createDirectory(at: journalDirectory, withIntermediateDirectories: true)
            let url = journalDirectory.appendingPathComponent(UUID().uuidString + ".jsonl")
            guard fm.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) else { throw MoveError(key: "journalError") }
            handle = try FileHandle(forWritingTo: url); result.journal = url
            defer { try? handle?.close() }
            try record(["event":"start", "source":plan.source.path, "destination":plan.destination.path, "count":plan.items.count, "date":ISO8601DateFormatter().string(from: Date())])
            var offset = 0
            while offset < plan.items.count {
                if cancel.requested { result.cancelled = true; break }
                guard FileIdentity.read(plan.source) == plan.sourceID, FileIdentity.read(plan.destination) == plan.destinationID else { throw MoveError(key: "changedFolder") }
                var batch: [MoveItem] = []; var bytes = plan.destination.path.utf8.count + 32
                while offset < plan.items.count && batch.count < 128 {
                    let item = plan.items[offset]; let size = item.source.path.utf8.count + 1
                    if !batch.isEmpty && bytes + size > 64_000 { break }
                    offset += 1
                    if FileIdentity.read(item.source) != item.identity {
                        result.failed += 1; result.processed += 1
                        try record(["event":"changed", "source":item.source.path]); continue
                    }
                    let dest = plan.destination.appendingPathComponent(item.source.lastPathComponent)
                    if exists(dest) {
                        result.skipped += 1; result.processed += 1
                        try record(["event":"skipped", "source":item.source.path, "destination":dest.path]); continue
                    }
                    batch.append(item); bytes += size
                }
                if batch.isEmpty { progress(result); continue }
                try record(["event":"attempt", "names":batch.map { $0.source.lastPathComponent }]); try handle?.synchronize()
                let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/mv")
                p.arguments = ["-n"] + batch.map { $0.source.path } + [plan.destination.path + "/"]
                // Drain stderr concurrently with the child (readDataToEndOfFile before wait).
                let pipe = Pipe(); p.standardError = pipe; p.standardOutput = FileHandle.nullDevice
                try p.run(); let errorData = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
                for item in batch {
                    let dest = plan.destination.appendingPathComponent(item.source.lastPathComponent)
                    let status: String
                    if !exists(item.source) && exists(dest) { result.moved += 1; status = "moved" }
                    else if FileIdentity.read(item.source) == item.identity && exists(dest) && p.terminationStatus == 0 { result.skipped += 1; status = "skipped" }
                    else { result.failed += 1; status = "failed" }
                    result.processed += 1
                    try record(["event":status, "source":item.source.path, "destination":dest.path])
                }
                try handle?.synchronize(); progress(result)
                if p.terminationStatus != 0 {
                    result.error = String(data: errorData.prefix(4096), encoding: .utf8) ?? "mv failed"
                    break
                }
            }
            if cancel.requested && result.processed < result.total { result.cancelled = true }
            try record(["event":"finish", "moved":result.moved, "skipped":result.skipped, "failed":result.failed, "cancelled":result.cancelled]); try handle?.synchronize()
        } catch { result.error = error.localizedDescription }
        progress(result); return result
    }
}
