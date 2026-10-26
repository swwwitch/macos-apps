import AppKit
import SwiftUI

/// Open service-managed folders without modifying their contents.
struct FontDebugMenu: View {
    private let folders: [(name: String, path: String)] = [
        ("Adobe Fonts", "~/Library/Application Support/Adobe/CoreSync/plugins/livetype"),
        ("OH MY FONT", "/Library/Fonts/oh_my_font"),
        ("フォントワークスLETS", "~/Library/Application Support/Fontworks/LETS/Download Font/Font"),
        ("Morisawa Fonts", "~/Library/Fonts/MorisawaFonts")
    ]

    var body: some View {
        ForEach(folders, id: \.path) { folder in
            Button(folder.name) { openFolder(folder.path) }
        }
    }

    private func openFolder(_ path: String) {
        let url = path.hasPrefix("~/")
            ? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(String(path.dropFirst(2)))
            : URL(fileURLWithPath: path, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            showError(L("フォルダーが見つかりません"), path: url.path)
            return
        }
        guard NSWorkspace.shared.open(url) else {
            showError(L("フォルダーを開けませんでした"), path: url.path)
            return
        }
    }

    private func showError(_ message: String, path: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = path
        alert.runModal()
    }
}
