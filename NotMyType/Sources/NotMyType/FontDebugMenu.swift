import AppKit
import SwiftUI

/// AppKit tracks modifier keys while menus are open; keep SwiftUI's submenu
/// hidden without replacing its menu delegate or intercepting keyboard events.
@MainActor
final class FontDebugVisibility: NSObject {
    static let shared = FontDebugVisibility()
    private var timer: Timer?

    func start() {
        NotificationCenter.default.addObserver(self, selector: #selector(beginTracking), name: NSMenu.didBeginTrackingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(endTracking), name: NSMenu.didEndTrackingNotification, object: nil)
        DispatchQueue.main.async { self.refresh() }
    }

    @objc private func beginTracking() {
        refresh()
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.05, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
        self.timer = timer
        RunLoop.main.add(timer, forMode: .eventTracking)
    }

    @objc private func endTracking() {
        timer?.invalidate()
        timer = nil
        refresh()
    }

    @objc private func refresh() {
        guard let tools = NSApp.mainMenu?.items.first(where: { $0.title == L("ツール") })?.submenu,
              let links = tools.items.first(where: { $0.title == L("リンク集") })?.submenu else { return }
        let hidden = !NSEvent.modifierFlags.contains(.option)
        for item in links.items where item.title == L("デバッグ") {
            if item.isHidden != hidden { item.isHidden = hidden }
        }
    }
}

/// Open service-managed folders without modifying their contents.
struct FontDebugMenu: View {
    private let folders: [(name: String, path: String)] = [
        ("Adobe Fonts", "~/Library/Application Support/Adobe/CoreSync/plugins/livetype"),
        ("OH MY FONT", "/Library/Fonts/oh_my_font"),
        ("フォントワークスLETS", "~/Library/Fonts/"),
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
