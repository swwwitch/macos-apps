import Foundation

/// Preserve the Store UI's explicit rename operation without changing the direct edition.
enum StoreFileOperations {
    static func renameVersion(_ source: URL, manager: FileManager = .default) throws -> URL {
        var floor = 1
        for _ in 0..<32 {
            let candidate = try Duplicator.versionDestination(source, after: floor, manager: manager)
            do {
                // FileManager refuses an existing destination; never remove it first.
                try manager.moveItem(at: source, to: candidate.url)
                return candidate.url
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError {
                floor = candidate.version
            }
        }
        throw NSError(domain: "CommandDee.Store", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not reserve a version name. Try again."])
    }
}
