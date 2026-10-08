import AppKit

/// 調べたアプリ1件分の情報
struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleID: String
    let version: String
    let path: String

    /// Bundle IDを持つバンドルだけを受け付ける（フォルダや書類はnil）
    init?(url: URL) {
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { return nil }
        let info = bundle.localizedInfoDictionary?.merging(bundle.infoDictionary ?? [:]) { localized, _ in localized }
            ?? bundle.infoDictionary ?? [:]
        name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        bundleID = identifier
        let short = info["CFBundleShortVersionString"] as? String ?? "-"
        let build = info["CFBundleVersion"] as? String ?? "-"
        version = "\(short) (\(build))"
        path = url.path
    }

    @MainActor var icon: NSImage { NSWorkspace.shared.icon(forFile: path) }
}

/// 一覧の状態。メインウインドウ・Dockアイコンへのドロップ・⌘Oで共有する
@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()
    @Published var items: [AppInfo] = []
    @Published var message: String?

    /// 追加して結果を表示する。同じパスは先頭へ移すだけで重複させない
    func add(_ urls: [URL]) {
        var added = 0
        var skipped: [String] = []
        for url in urls {
            guard let info = AppInfo(url: url) else { skipped.append(url.lastPathComponent); continue }
            items.removeAll { $0.path == info.path }
            items.insert(info, at: 0)
            added += 1
        }
        if skipped.isEmpty {
            message = nil
        } else if added == 0 {
            message = L("Bundle IDがありません：%@", skipped.joined(separator: "、"))
        } else {
            message = L("%@件を追加、%@件を除外", String(added), String(skipped.count))
        }
    }

    func copy(_ text: String, note: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        message = note
    }

    func chooseApps() {
        let panel = NSOpenPanel()
        panel.title = L("Bundle IDを調べるアプリを選択")
        panel.prompt = L("選択")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.applicationBundle, .bundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK { add(panel.urls) }
    }
}
