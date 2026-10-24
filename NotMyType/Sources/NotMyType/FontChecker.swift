import AppKit
import CoreText
import SwiftUI

/// フォントの点検（FontExplorer X Pro の「フォントを検査」に当たる）。ファイルを読み、壊れているもの・注意が要るものを一覧にする
enum FontChecker {
    struct Issue: Hashable, Sendable {
        enum Level: Int, Sendable { case broken, warning }
        var level: Level
        var text: String
    }

    struct Result: Identifiable, Sendable {
        var file: FontFile
        var issues: [Issue]
        var id: UUID { file.id }
        var level: Issue.Level { issues.contains { $0.level == .broken } ? .broken : .warning }
    }

    /// 無いと使えないテーブル。アウトラインは glyf・CFF・CFF2・sbix・CBDT のどれか
    static let requiredTables = ["cmap", "head", "hhea", "hmtx", "maxp", "name"]
    static let outlineTables: Set<String> = ["glyf", "CFF ", "CFF2", "sbix", "CBDT"]

    /// 1つのファイルを点検する。問題が無ければ空
    nonisolated static func check(_ file: FontFile) -> [Issue] {
        let url = file.url
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
        if size == 0 { return [Issue(level: .broken, text: L("ファイルの大きさが0です"))] }
        let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] ?? []
        if descriptors.isEmpty { return [Issue(level: .broken, text: L("フォントとして読めません"))] }
        var issues: [Issue] = []
        var names = Set<String>()
        for descriptor in descriptors {
            let font = CTFontCreateWithFontDescriptor(descriptor, 12, nil)
            let name = CTFontCopyPostScriptName(font) as String
            // woff・woff2 はテーブルの一覧を返さないことがあるので、テーブルの点検はしない
            let isWebFont = ["woff", "woff2"].contains(url.pathExtension.lowercased())
            if !isWebFont {
                let tables = FontScanner.tableTags(descriptor)
                let missing = requiredTables.filter { !tables.contains($0) }
                if !missing.isEmpty { issues.append(Issue(level: .broken, text: L("%@：必要なテーブルがありません（%@）", name, missing.joined(separator: ", ")))) }
                if tables.isDisjoint(with: outlineTables) { issues.append(Issue(level: .broken, text: L("%@：字形の形のデータがありません", name))) }
                if !tables.contains("OS/2") { issues.append(Issue(level: .warning, text: L("%@：OS/2テーブルがありません（Windowsや一部のアプリで問題になります）", name))) }
                if !tables.contains("post") { issues.append(Issue(level: .warning, text: L("%@：postテーブルがありません", name))) }
            }
            if CTFontGetGlyphCount(font) == 0 { issues.append(Issue(level: .broken, text: L("%@：字形が1つもありません", name))) }
            if name.isEmpty {
                issues.append(Issue(level: .broken, text: L("PostScript名がありません")))
            } else {
                // PostScript名は63字まで、表示できるASCII（空白と [](){}<>/% を除く）
                let invalid = name.unicodeScalars.contains { $0.value < 33 || $0.value > 126 || "[](){}<>/%".unicodeScalars.contains($0) }
                if invalid { issues.append(Issue(level: .warning, text: L("%@：PostScript名に使えない文字があります", name))) }
                if name.count > 63 { issues.append(Issue(level: .warning, text: L("%@：PostScript名が63字を超えています", name))) }
                if !names.insert(name).inserted { issues.append(Issue(level: .warning, text: L("%@：ファイルの中でPostScript名が重複しています", name))) }
            }
        }
        return issues
    }
}

// MARK: - 画面

@MainActor
final class FontCheckWindow {
    static let shared = FontCheckWindow()
    private var window: NSWindow?

    /// 一覧で選んだフォントを点検する。選んでいなければ、表示しているライブラリ全体（件数を確かめてから）
    func show() {
        let store = LibraryStore.shared
        var files = store.selectedFiles
        if files.isEmpty {
            files = store.visibleFiles
            let alert = NSAlert()
            alert.messageText = L("ライブラリ全体を点検しますか？")
            alert.informativeText = L("%d個のファイルを読みます。件数が多いと数分かかります。一部だけ点検するときは、一覧で選んでから実行します。", files.count)
            alert.addButton(withTitle: L("点検する"))
            alert.addButton(withTitle: L("キャンセル")).keyEquivalent = "\u{1b}"
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        window?.close()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = L("フォントを点検")
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: FontCheckView(files: files)
            .frame(minWidth: 560, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity))
        hosting.sizingOptions = [.minSize]
        window.contentView = hosting
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }
}

private struct FontCheckView: View {
    let files: [FontFile]
    @State private var results: [FontChecker.Result] = []
    @State private var checked = 0
    @State private var finished = false
    @State private var chosen = Set<UUID>()
    @ObservedObject private var store = LibraryStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if !finished {
                    ProgressView(value: Double(checked), total: Double(max(files.count, 1))).frame(maxWidth: 240)
                    Text(L("点検中…（%d／%d）", checked, files.count)).font(.caption).foregroundStyle(.secondary)
                } else {
                    let broken = results.filter { $0.level == .broken }.count
                    Text(L("%d個を点検しました：壊れている %d、注意 %d", files.count, broken, results.count - broken))
                        .font(.callout)
                }
                Spacer()
            }
            List(selection: $chosen) {
                ForEach(results) { result in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: result.level == .broken ? "xmark.octagon" : "exclamationmark.triangle")
                                .foregroundStyle(result.level == .broken ? .red : .orange)
                                .accessibilityLabel(result.level == .broken ? L("壊れている") : L("注意"))
                            Text(result.file.fileName).fontWeight(.semibold)
                            Text(result.file.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        ForEach(result.issues, id: \.self) { issue in
                            Text("・" + issue.text).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tag(result.id)
                }
            }
            .overlay { if finished && results.isEmpty { Text(L("問題のあるフォントは見つかりませんでした")).foregroundStyle(.secondary) } }
            HStack {
                Button(L("Finderで表示")) { store.revealInFinder(selectedFiles) }.disabled(chosen.isEmpty)
                Button(L("新規セットに入れる…")) { store.newSet(with: selectedFiles) }.disabled(chosen.isEmpty)
                Button(L("ライブラリから取り除く…")) {
                    store.remove(selectedFiles)
                    results.removeAll { result in !store.data.files.contains { $0.id == result.id } }
                    chosen.removeAll()
                }
                .disabled(chosen.isEmpty)
                Spacer()
                Button(L("閉じる")) { FontCheckWindow.shared.close() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .task { await run() }
    }

    private var selectedFiles: [FontFile] { results.filter { chosen.contains($0.id) }.map(\.file) }

    /// 裏で点検し、200件ごとに進み具合と結果を画面に返す
    private func run() async {
        let all = files
        var batch: [FontChecker.Result] = []
        for (index, file) in all.enumerated() {
            let issues = await Task.detached(priority: .userInitiated) { FontChecker.check(file) }.value
            if !issues.isEmpty { batch.append(FontChecker.Result(file: file, issues: issues)) }
            if index % 200 == 199 || index == all.count - 1 {
                results += batch
                batch.removeAll()
                checked = index + 1
            }
        }
        results.sort { ($0.level.rawValue, $0.file.fileName) < ($1.level.rawValue, $1.file.fileName) }
        finished = true
    }
}
