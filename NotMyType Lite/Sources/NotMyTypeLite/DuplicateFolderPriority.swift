import Foundation

/// Installed font folders precede watched folders. Match directory boundaries,
/// including nested vendor folders, without resolving away their installation path.
enum DuplicateFolderPriority {
    static let userFonts = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Fonts", isDirectory: true).path + "/"

    static func rank(path: String, folderPrefixes: [String], userFontsPrefix: String = userFonts) -> Int {
        if path.hasPrefix(userFontsPrefix) { return -2 }
        if path.hasPrefix("/Library/Fonts/") { return -1 }
        return folderPrefixes.firstIndex { path.hasPrefix($0) } ?? folderPrefixes.count
    }
}
