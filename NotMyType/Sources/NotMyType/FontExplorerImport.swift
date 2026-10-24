import AppKit
import SQLite3
import SwiftUI

/// FontExplorer X Pro のセット。フォルダーの中のセットは folder にフォルダー名が入る
struct FontExplorerSet: Identifiable, Hashable, Sendable {
    let id: Int64
    let name: String
    let folder: String?
    let paths: [String]

    /// NotMyType のセットの名前（フォルダーの中なら「フォルダー / セット」）
    var title: String { folder.map { "\($0) / \(name)" } ?? name }
}

/// FontExplorer X Pro のデータベース（SQLite）からセットを読む。2026-10-24 にこの Mac の 7.1.3 のデータベースで確かめた形：
/// sourceItems の type 7 がセット（51 はアプリ用のセット）、8 がセットのフォルダー（parentSerialID で親を指す）、
/// setContainers がセットとフォントファイル（containers.path）の対応。スマートセット（6）とアプリのセット（31〜33）は読まない
enum FontExplorerImport {
    enum Failure: Error { case notFound, unreadable }

    static var databaseURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Linotype/FontExplorer X/FontExplorer X.fexdb")
    }

    static var isAvailable: Bool { FileManager.default.fileExists(atPath: databaseURL.path) }

    /// FontExplorer が開いていても読めるよう、作業用フォルダーに写してから読み取りだけで開く
    static func readSets() throws -> [FontExplorerSet] {
        guard isAvailable else { throw Failure.notFound }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("NotMyType-FEX-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let copy = folder.appendingPathComponent("db.fexdb")
        try FileManager.default.copyItem(at: databaseURL, to: copy)
        for suffix in ["-wal", "-shm"] {
            let side = URL(fileURLWithPath: databaseURL.path + suffix)
            if FileManager.default.fileExists(atPath: side.path) {
                try? FileManager.default.copyItem(at: side, to: URL(fileURLWithPath: copy.path + suffix))
            }
        }
        var database: OpaquePointer?
        guard sqlite3_open_v2(copy.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let database else {
            sqlite3_close(database)
            throw Failure.unreadable
        }
        defer { sqlite3_close(database) }

        var folders: [Int64: String] = [:]
        try query(database, "SELECT serialID, title FROM sourceItems WHERE type = 8") { row in
            folders[sqlite3_column_int64(row, 0)] = text(row, 1)
        }
        var paths: [Int64: [String]] = [:]
        try query(database, "SELECT sc.serialID, c.path FROM setContainers sc JOIN containers c ON c.containerID = sc.containerID") { row in
            if let path = text(row, 1), !path.isEmpty { paths[sqlite3_column_int64(row, 0), default: []].append(path) }
        }
        var sets: [FontExplorerSet] = []
        try query(database, "SELECT serialID, title, parentSerialID FROM sourceItems WHERE type IN (7, 51)") { row in
            let id = sqlite3_column_int64(row, 0)
            let parent = sqlite3_column_int64(row, 2)
            sets.append(FontExplorerSet(id: id, name: text(row, 1) ?? "", folder: parent == 0 ? nil : folders[parent], paths: paths[id] ?? []))
        }
        return sets.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private static func query(_ database: OpaquePointer, _ sql: String, _ each: (OpaquePointer) -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw Failure.unreadable }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW { each(statement) }
    }

    private static func text(_ row: OpaquePointer, _ column: Int32) -> String? {
        sqlite3_column_text(row, column).map { String(cString: $0) }
    }
}

// MARK: - 画面

@MainActor
final class FontExplorerImportWindow {
    static let shared = FontExplorerImportWindow()
    private var window: NSWindow?

    func show() {
        let sets: [FontExplorerSet]
        do {
            sets = try FontExplorerImport.readSets()
        } catch {
            let alert = NSAlert()
            alert.messageText = L("FontExplorer X Proのセットを読み込めません")
            alert.informativeText = (error as? FontExplorerImport.Failure) == .notFound
                ? L("FontExplorer X Proのデータベースが見つかりません（%@）。", FontExplorerImport.databaseURL.path)
                : L("FontExplorer X Proのデータベースを読めませんでした。")
            alert.runModal()
            return
        }
        window?.close()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = L("FontExplorer X Proのセットを読み込む")
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: FontExplorerImportView(sets: sets)
            .frame(minWidth: 520, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity))
        hosting.sizingOptions = [.minSize]
        window.contentView = hosting
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }
}

/// 読み込むセットを選ぶ。同じ名前のセットがあれば、そのセットにフォントを足す
private struct FontExplorerImportView: View {
    let sets: [FontExplorerSet]
    @ObservedObject private var store = LibraryStore.shared
    @State private var chosen: Set<Int64>
    @State private var addFiles = true

    init(sets: [FontExplorerSet]) {
        self.sets = sets
        _chosen = State(initialValue: Set(sets.map(\.id)))
    }

    var body: some View {
        let known = Set(store.data.files.map(\.path))
        let existingSets = Set(store.data.sets.map(\.name))
        VStack(alignment: .leading, spacing: 12) {
            Text(L("FontExplorer X Proのセット（%d）", sets.count)).font(.headline)
            List(sets) { set in
                let inLibrary = set.paths.filter { known.contains(URL(fileURLWithPath: $0).standardizedFileURL.path) }.count
                HStack(spacing: 8) {
                    Toggle("", isOn: Binding(get: { chosen.contains(set.id) },
                                             set: { if $0 { chosen.insert(set.id) } else { chosen.remove(set.id) } }))
                        .labelsHidden()
                    Image(systemName: "folder").foregroundStyle(.secondary).accessibilityHidden(true)
                    Text(set.title).lineLimit(1)
                    if existingSets.contains(set.title) {
                        Text(L("同じ名前のセットに足す")).font(.caption).foregroundStyle(.orange)
                    }
                    Spacer()
                    Text(L("%d個（ライブラリに %d）", set.paths.count, inLibrary))
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            HStack {
                Button(L("すべて選択")) { chosen = Set(sets.map(\.id)) }
                Button(L("すべて解除")) { chosen.removeAll() }
            }
            Toggle(L("ライブラリに無いフォントファイルも追加する"), isOn: $addFiles)
            Text(L("FontExplorer X Proのセットを、同じ名前のセットとして読み込みます（フォルダーの中のセットは「フォルダー / セット」）。フォントファイルは動かしません。見つからないファイルは飛ばします。スマートセットは読み込みません。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("キャンセル")) { FontExplorerImportWindow.shared.close() }.keyboardShortcut(.cancelAction)
                Button(L("読み込む")) {
                    store.importFontExplorerSets(sets.filter { chosen.contains($0.id) }, addFiles: addFiles)
                    FontExplorerImportWindow.shared.close()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(chosen.isEmpty || store.isBusy)
            }
        }
        .padding(20)
    }
}
