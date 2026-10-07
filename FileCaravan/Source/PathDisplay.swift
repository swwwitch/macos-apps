import Foundation

// Matches FolderHopper's Dropbox-shared component-boundary abbreviation.
// Presentation only: never use this result for filesystem operations.
enum PathDisplay {
    static func string(_ url: URL, shortenDropbox: Bool) -> String {
        if shortenDropbox, let index = url.pathComponents.firstIndex(of: "Dropbox-shared") {
            return "/" + url.pathComponents[index...].joined(separator: "/")
        }
        return url.path
    }
}
