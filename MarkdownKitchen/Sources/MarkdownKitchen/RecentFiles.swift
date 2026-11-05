import AppKit
import SwiftUI

/// Use macOS's persistent recent-document list, shared with the Dock menu.
@MainActor
final class RecentFiles: ObservableObject {
    static let shared = RecentFiles()
    @Published private(set) var urls: [URL]

    private init() {
        urls = NSDocumentController.shared.recentDocumentURLs
    }

    func record(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        urls = NSDocumentController.shared.recentDocumentURLs
    }

    func clear() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        urls = NSDocumentController.shared.recentDocumentURLs
    }
}

struct RecentFilesMenu: View {
    @ObservedObject private var recent = RecentFiles.shared

    var body: some View {
        Menu(L("最近使ったファイル")) {
            if recent.urls.isEmpty {
                Button(L("最近使ったファイルはありません")) {}
                    .disabled(true)
            } else {
                ForEach(recent.urls, id: \.self) { url in
                    Button(title(for: url)) {
                        MarkdownStore.open([url], from: MarkdownStore.shared)
                    }
                    .help(url.path)
                }
                Divider()
                Button(L("履歴を消去")) { recent.clear() }
            }
        }
    }

    private func title(for url: URL) -> String {
        let duplicateName = recent.urls.filter { $0.lastPathComponent == url.lastPathComponent }.count > 1
        return duplicateName ? url.path : url.lastPathComponent
    }
}
