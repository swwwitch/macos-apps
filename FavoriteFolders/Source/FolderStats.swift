import Foundation

/// Files and total size inside a folder, including subfolders. Hidden files are skipped. A package (.app, .rtfd …)
/// counts as one file, with the size of everything in it. Sizes are the files' logical size, as Finder shows;
/// online-only cloud files are read from their attributes and not downloaded.
struct FolderStats: Equatable {
    var files = 0
    var bytes: Int64 = 0

    private static let keys: [URLResourceKey] = [.isRegularFileKey, .isPackageKey, .isDirectoryKey, .fileSizeKey, .totalFileSizeKey]

    /// `isCancelled` is checked between files so a reload can stop a long count.
    static func measure(_ folder: URL, isCancelled: () -> Bool = { false }) -> FolderStats? {
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys,
                                                              options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return nil }
        var stats = FolderStats()
        for case let url as URL in enumerator {
            if isCancelled() { return nil }
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isPackage == true {
                stats.files += 1; stats.bytes += packageSize(url)
            } else if values.isRegularFile == true {
                stats.files += 1; stats.bytes += Int64(values.totalFileSize ?? values.fileSize ?? 0)
            }
        }
        return stats
    }
    private static func packageSize(_ url: URL) -> Int64 {
        var total: Int64 = 0
        let inner = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .totalFileSizeKey], options: [])
        while let file = inner?.nextObject() as? URL {
            if let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .totalFileSizeKey]), values.isRegularFile == true {
                total += Int64(values.totalFileSize ?? values.fileSize ?? 0)
            }
        }
        return total
    }

    var filesText: String { String(format: L("filesText"), files) }
    /// Finder-style size, e.g. "50.3 MB".
    var sizeText: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}
