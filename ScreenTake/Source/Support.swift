import AppKit

/// Selects a file in Path Finder when it is running (this Mac's file viewer) through AppleScript `reveal`, as MenuShot does;
/// otherwise in the default file viewer.
@MainActor enum FileReveal {
    static let pathFinderIDs = ["com.cocoatech.PathFinder-setapp", "com.cocoatech.PathFinder"]

    static func reveal(_ url: URL) {
        if let id = pathFinderIDs.first(where: { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty }) {
            // Asks for Automation permission the first time; when refused or failing, Finder takes over.
            let path = url.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            var error: NSDictionary?
            _ = NSAppleScript(source: "tell application id \"\(id)\"\nactivate\nreveal POSIX file \"\(path)\"\nend tell")?.executeAndReturnError(&error)
            if error == nil { return }
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
