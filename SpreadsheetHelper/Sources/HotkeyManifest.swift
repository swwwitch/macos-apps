import Foundation
#if canImport(AppKit)
import AppKit
#endif

// 共通部品：Shared/HotkeyManifest/HotkeyManifest.swift（各アプリへは sync.py がビルド時にコピーする。コピー先は直接編集しない）

/// 登録しているグローバルホットキーを共通の JSON に書き出す。HotkeyHound が「自作アプリ」として読む。
/// Carbon の共有登録はほかのアプリから一覧できないため、各アプリが自分で申告する。
/// 書き出し先：~/Library/Application Support/swwwitch/Hotkeys/<Bundle ID>.json
enum HotkeyManifest {
    struct Item: Codable, Equatable {
        /// アプリ内で一意な識別子（設定キーや機能名）
        var id: String
        /// 機能名（アプリの表示言語で）
        var title: String
        /// 仮想キーコード（kVK_*）
        var keyCode: Int
        /// Carbon の修飾キー（cmdKey 256・shiftKey 512・optionKey 2048・controlKey 4096）
        var modifiers: Int
        /// 設定で有効か（登録できたかではない）
        var enabled: Bool = true
        /// 効く範囲："all"（既定）／"only"（apps が前面のときだけ）／"except"（apps 以外）／"custom"（note に説明）
        var scope: String = "all"
        /// scope が only・except のときの Bundle ID
        var apps: [String] = []
        /// 補足（パレット表示中だけ など）
        var note: String?
    }

    private struct Document: Codable {
        var app: String
        var bundleID: String
        var version: String?
        var updated: Date
        var hotkeys: [Item]
    }

    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/swwwitch/Hotkeys")
    }

    // Touched only from the main thread (publish is called there).
    nonisolated(unsafe) private static var lastPublished: [Item]?

    /// 現在のホットキー一覧を書き出す。前回と同じなら何もしない。設定を変えたとき・起動時に呼ぶ（メインスレッド）。
    static func publish(_ items: [Item]) {
        #if APP_STORE
        // App Store 版はサンドボックス内にしか書けず、HotkeyHound から読めない
        return
        #else
        guard items != lastPublished, let bundleID = Bundle.main.bundleIdentifier else { return }
        lastPublished = items
        let info = Bundle.main.infoDictionary ?? [:]
        let document = Document(app: info["CFBundleName"] as? String ?? ProcessInfo.processInfo.processName, bundleID: bundleID,
                                version: info["CFBundleShortVersionString"] as? String, updated: Date(), hotkeys: items)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(document) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: folder.appendingPathComponent(bundleID + ".json"), options: .atomic)
        #endif
    }

    #if canImport(AppKit)
    /// 前面アプリ専用（scope "only"）で同じキーを申告している、起動中のほかの自作アプリがあるか。
    /// アプリ全体で効くキー（KageTrimmer の ⌃⌥⌘U など）は、これが true の間は登録を外して譲る（AiHelper の単位パレット）。
    /// apps の Bundle ID は前方一致（com.adobe.illustrator で Beta なども含む）。
    static func claimedByOtherApp(keyCode: Int, modifiers: Int, front: NSRunningApplication?) -> Bool {
        guard let frontID = front?.bundleIdentifier?.lowercased(), let own = Bundle.main.bundleIdentifier,
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return false }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file), let document = try? decoder.decode(Document.self, from: data),
                  document.bundleID != own, !NSRunningApplication.runningApplications(withBundleIdentifier: document.bundleID).isEmpty else { continue }
            if document.hotkeys.contains(where: { item in
                item.enabled && item.keyCode == keyCode && item.modifiers == modifiers && item.scope == "only"
                    && item.apps.contains { frontID.hasPrefix($0.lowercased()) }
            }) { return true }
        }
        return false
    }
    #endif
}
