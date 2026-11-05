import AppKit
import SwiftUI

/// Keep a per-Mac history even when the system recent-document list is unavailable.
@MainActor
final class RecentFiles: ObservableObject {
    static let shared = RecentFiles()
    private static let key = "markdownKitchen.recentFiles"
    @Published private(set) var urls: [URL]

    private init() {
        if let paths = UserDefaults.standard.stringArray(forKey: Self.key) {
            urls = paths.map { URL(fileURLWithPath: $0) }
        } else {
            urls = NSDocumentController.shared.recentDocumentURLs
        }
    }

    private func persist() {
        UserDefaults.standard.set(urls.map(\.path), forKey: Self.key)
    }

    func record(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        urls.removeAll { DocumentFileIdentity.matches($0, url) }
        urls.insert(url.standardizedFileURL, at: 0)
        urls = Array(urls.prefix(20))
        persist()
    }

    func remove(_ url: URL) {
        let remaining = urls.filter { $0 != url }
        NSDocumentController.shared.clearRecentDocuments(nil)
        for item in remaining.reversed() {
            NSDocumentController.shared.noteNewRecentDocumentURL(item)
        }
        urls = remaining
        persist()
    }

    func open(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            let alert = NSAlert()
            alert.messageText = L("「%@」が見つかりません", url.lastPathComponent)
            alert.informativeText = L("ファイルが移動または削除された可能性があります。新しい場所を指定するか、履歴から除外できます。")
            alert.addButton(withTitle: L("場所を指定…"))
            alert.addButton(withTitle: L("履歴から除外"))
            alert.addButton(withTitle: L("キャンセル"))
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                let panel = NSOpenPanel()
                panel.allowedContentTypes = MarkdownStore.readableTypes
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                guard panel.runModal() == .OK, let replacement = panel.url else { return }
                // Retain the old entry if the replacement cannot be read.
                guard FileManager.default.isReadableFile(atPath: replacement.path) else { return }
                remove(url)
                MarkdownStore.open([replacement], from: MarkdownStore.shared)
            case .alertSecondButtonReturn: remove(url)
            default: break
            }
            return
        }
        MarkdownStore.open([url], from: MarkdownStore.shared)
    }

    func clear() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        urls = []
        persist()
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
                        recent.open(url)
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
