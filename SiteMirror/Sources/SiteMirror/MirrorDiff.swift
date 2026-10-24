import Foundation
import CryptoKit

/// Compares the saved, rewritten files before and after this run, not HTTP validators.
/// Only paths in SiteMirror's manifest are read. Snapshots never replace the user's files.
final class MirrorDiff {
    struct Snapshot {
        var hash: String?
        var text: String?
        var existed: Bool
    }
    struct Item {
        let path: String
        let state: State
        var detail: String = ""
    }
    enum State: CaseIterable {
        case added, changed, unchanged, unavailable, unverified, removed, unreadable
        var title: String {
            switch self {
            case .added: L("追加")
            case .changed: L("変更")
            case .unchanged: L("変更なし")
            case .unavailable: L("サイトで削除・非公開（404／410）")
            case .unverified: L("未確認（対象外・未到達・取得失敗など）")
            case .removed: L("保存先から削除")
            case .unreadable: L("比較できません")
            }
        }
    }
    private let root: URL
    private let oldPaths: Set<String>
    private var before: [String: Snapshot] = [:]
    private var textBudget = 8 * 1024 * 1024
    private static let textLimit = 256 * 1024

    init(root: URL, paths: Set<String>) {
        self.root = root
        self.oldPaths = paths
        for path in paths.sorted() {
            var snapshot = snapshot(path, includeText: textBudget > 0)
            if (snapshot.text?.utf8.count ?? 0) > textBudget { snapshot.text = nil }
            before[path] = snapshot
            textBudget -= snapshot.text?.utf8.count ?? 0
        }
    }

    private func file(_ path: String) -> URL? {
        guard !path.hasPrefix("/") else { return nil }
        let base = root.resolvingSymlinksInPath().standardizedFileURL
        let target = root.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
        guard target.path.hasPrefix(base.path + "/") else { return nil }
        return target
    }

    private func snapshot(_ path: String, includeText: Bool) -> Snapshot {
        guard let url = file(path) else { return Snapshot(existed: true) }
        guard FileManager.default.fileExists(atPath: url.path) else { return Snapshot(existed: false) }
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hasher = SHA256()
            var small = Data()
            var size = 0
            while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
                hasher.update(data: chunk)
                size += chunk.count
                if includeText, size <= Self.textLimit { small.append(chunk) } else { small.removeAll() }
            }
            let hash = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            var text: String?
            if includeText, size <= Self.textLimit, !small.contains(0) {
                text = String(data: small, encoding: .utf8)
                    ?? String(data: small, encoding: .shiftJIS)
            }
            return Snapshot(hash: hash, text: text, existed: true)
        } catch { return Snapshot(existed: true) }
    }

    /// Successful paths only are compared. Untouched old files must never be called unchanged/deleted.
    func compare(successful: Set<String>, gone: Set<String>, removed: Set<String>) -> [Item] {
        var detailsRemaining = 100
        return oldPaths.union(successful).sorted().map { path in
            if removed.contains(path) { return Item(path: path, state: .removed) }
            if gone.contains(path) { return Item(path: path, state: .unavailable) }
            guard successful.contains(path) else { return Item(path: path, state: .unverified) }
            let current = snapshot(path, includeText: detailsRemaining > 0)
            guard let newHash = current.hash else { return Item(path: path, state: .unreadable) }
            guard let old = before[path], old.existed else { return Item(path: path, state: .added) }
            guard let oldHash = old.hash else { return Item(path: path, state: .unreadable) }
            guard oldHash != newHash else { return Item(path: path, state: .unchanged) }
            var detail = L("バイナリ・大きなファイル、または表示上限のため変更箇所は省略しました。")
            if detailsRemaining > 0, let previousText = old.text, let currentText = current.text {
                detailsRemaining -= 1
                detail = Self.lineDiff(previousText, currentText)
            }
            return Item(path: path, state: .changed, detail: detail)
        }
    }

    static func lineDiff(_ before: String, _ after: String) -> String {
        // BSD diff's unified format: '-' is the previous file, '+' is the current file.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SiteMirror-diff-" + UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let old = directory.appendingPathComponent("before")
            let new = directory.appendingPathComponent("after")
            let output = directory.appendingPathComponent("output")
            try before.write(to: old, atomically: true, encoding: .utf8)
            try after.write(to: new, atomically: true, encoding: .utf8)
            FileManager.default.createFile(atPath: output.path, contents: nil)
            let handle = try FileHandle(forWritingTo: output)
            defer { try? handle.close() }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/diff")
            process.arguments = ["-u", "-L", "before", "-L", "after", old.path, new.path]
            process.standardOutput = handle
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus <= 1 else { return L("変更箇所を表示できませんでした。") }
            let result = try String(contentsOf: output, encoding: .utf8)
            if result.isEmpty { return L("文字コードまたは改行形式など、保存バイト列が変わりました。") }
            if result.count > 32_000 { return String(result.prefix(32_000)) + "\n" + L("以降の変更箇所は省略しました。") }
            return result
        } catch { return L("変更箇所を表示できませんでした。") }
    }

    func report(items: [Item], partial: Bool, resumed: Bool) -> String {
        var lines = [L("再取得の差分"), Date().formatted(), "",
            L("この実行の直前と直後に保存されたファイルを比較しています。HTML・CSSはリンク書き換え後の内容です。"),
            L("未確認は削除を意味しません。404／410でも認証や一時的な状態の影響を受ける場合があります。"),
            L("変更行は - が前回、+ が今回です。テキストは1ファイル256KB・合計8MB・変更100件まで、各差分は32000文字まで表示します。"), ""]
        if oldPaths.isEmpty { lines.append(L("初回取得のため、前回との差分はありません。保存ファイルを追加として記載します。")) }
        if partial { lines.append(L("中止・取得失敗・上限などがあるため、今回取得できた範囲の比較です。")) }
        if resumed { lines.append(L("続きからの取得では、再開直前の保存内容と比較しています。中止前からの通算差分ではありません。")) }
        lines.append("")
        for state in State.allCases {
            let group = items.filter { $0.state == state }
            lines.append("\(state.title): \(group.count)")
        }
        for state in State.allCases {
            let group = items.filter { $0.state == state }
            guard !group.isEmpty else { continue }
            lines += ["", "=== \(state.title) ==="]
            for item in group {
                lines.append(item.path.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r"))
                if !item.detail.isEmpty { lines += [item.detail, ""] }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
