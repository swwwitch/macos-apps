import Foundation

/// User documents must never be written into an application's hidden container.
enum OutputDirectoryPolicy {
    static var isSandboxed: Bool {
        #if APP_STORE_BUILD
        return true
        #else
        return ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        #endif
    }

    static func isUserDirectory(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        let parts = url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        for i in parts.indices where parts[i] == "Library" && i + 1 < parts.count {
            if ["Containers", "Group Containers"].contains(parts[i + 1]) { return false }
        }
        return true
    }
}
