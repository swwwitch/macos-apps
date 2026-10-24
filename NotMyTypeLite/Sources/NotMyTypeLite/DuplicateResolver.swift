import AppKit
import SwiftUI

/// 重複フォントを解決：ウォッチフォルダーの順で優先が決まらない重複を左右にカードで並べ、選んだものをその組の優先として覚える
@MainActor
enum DuplicateResolver {
    /// 1組の重複。candidates は優先の候補として残っているファイル（2つ以上）
    struct Item: Identifiable {
        var name: String
        var group: [FontFile]
        var candidates: [FontFile]
        /// 先頭2つの分かれ目のフォルダーの組（向きは問わない）。同じ組の数で並べる
        var key: String
        var id: String { name }
    }

    static func folder(of file: FontFile) -> String { (file.path as NSString).deletingLastPathComponent }

    /// 2つのフォルダーが分かれる最初のフォルダー。片方がもう片方の中にあるときはそれぞれのフォルダー
    static func branch(_ a: String, _ b: String) -> (String, String) {
        let left = a.split(separator: "/", omittingEmptySubsequences: false)
        let right = b.split(separator: "/", omittingEmptySubsequences: false)
        var index = 0
        while index < left.count && index < right.count && left[index] == right[index] { index += 1 }
        guard index < left.count && index < right.count else { return (a, b) }
        return (left[...index].joined(separator: "/"), right[...index].joined(separator: "/"))
    }

    /// 優先が決まらない組を、同じ分かれ目の組が多い順に並べる（上から選ぶほど早く片付く）
    static func items(skipping skipped: Set<String>) -> [Item] {
        let store = LibraryStore.shared
        var items: [Item] = []
        for group in store.undecidedDuplicateGroups {
            guard let name = group.first?.faces.first?.postScriptName, !skipped.contains(name) else { continue }
            let candidates = store.preferenceCandidates(group)
            guard candidates.count > 1 else { continue }
            let (a, b) = branch(folder(of: candidates[0]), folder(of: candidates[1]))
            items.append(Item(name: name, group: group, candidates: candidates, key: [a, b].sorted().joined(separator: "\n")))
        }
        var counts: [String: Int] = [:]
        for item in items { counts[item.key, default: 0] += 1 }
        return items.sorted {
            let left = counts[$0.key] ?? 0, right = counts[$1.key] ?? 0
            return left != right ? left > right : $0.name < $1.name
        }
    }

    /// file をこの組の優先にする（簡易版はフォルダーの規則を持たない、ユーザー指定）
    static func choose(_ file: FontFile, in item: Item) {
        LibraryStore.shared.pickPreferred(file, in: item.group)
    }

    /// 画面に出す場所：ホームは「~」、Dropbox は「Dropbox」から
    static func display(_ path: String) -> String {
        let encoded = PortablePath.encode(path)
        if encoded.hasPrefix("$DROPBOX-"), let slash = encoded.firstIndex(of: "/") { return "Dropbox" + encoded[slash...] }
        return encoded
    }
}

@MainActor
final class DuplicateResolverWindow {
    static let shared = DuplicateResolverWindow()
    private var window: NSWindow?

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 600),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = L("重複フォントを解決")
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: DuplicateResolverView()
            .frame(minWidth: 720, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity))
        hosting.sizingOptions = [.minSize]
        window.contentView = hosting
        window.center()
        self.window = window
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            Task { @MainActor in DuplicateResolverWindow.shared.window = nil }
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }
}

private struct DuplicateResolverView: View {
    @ObservedObject private var store = LibraryStore.shared
    @State private var items: [DuplicateResolver.Item] = []
    @State private var skipped = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let item = items.first {
                HStack {
                    Text(item.candidates.first?.faces.first?.fullName ?? item.name).font(.title3).fontWeight(.semibold)
                    Text(item.name).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                    Spacer()
                    Text(L("残り %d組", items.count)).font(.callout).foregroundStyle(.secondary).monospacedDigit()
                }
                Text(L("優先するほうを選びます。選んだものは、この組の優先として覚えます。"))
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(item.candidates) { file in
                            DuplicateCard(file: file) { choose(file, in: item) }
                        }
                    }
                    .padding(.bottom, 4)
                }
            } else {
                Spacer()
                HStack {
                    Spacer()
                    Text(L("優先が決まらない重複はありません")).foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            }
            HStack {
                if !skipped.isEmpty {
                    Button(L("スキップした組を戻す")) { skipped.removeAll(); reload() }
                }
                Spacer()
                Button(L("スキップ")) {
                    if let item = items.first { skipped.insert(item.name); reload() }
                }
                .disabled(items.isEmpty)
                Button(L("閉じる")) { DuplicateResolverWindow.shared.close() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .onAppear { reload() }
    }

    private func choose(_ file: FontFile, in item: DuplicateResolver.Item) {
        DuplicateResolver.choose(file, in: item)
        reload()
    }

    private func reload() { items = DuplicateResolver.items(skipping: skipped) }
}

/// 候補のカード：プレビューと見分けるための情報、優先にするボタン
private struct DuplicateCard: View {
    @ObservedObject private var store = LibraryStore.shared
    @AppStorage(LibraryStore.sampleTextKey) private var sample = LibraryStore.defaultSampleText
    let file: FontFile
    let choose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            preview
                .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 3) {
                info(L("形式"), file.format)
                info(L("バージョン"), PreviewFonts.version(file: file) ?? "—")
                info(L("字形数"), file.glyphCount.map { "\($0)" } ?? "—")
                info(L("大きさ"), size)
                info(L("更新日"), modified)
                info(L("状態"), store.states[file.id] == .active ? L("アクティブ") : L("非アクティブ"))
            }
            .font(.caption)
            Text(DuplicateResolver.display(file.path))
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(3).truncationMode(.middle).textSelection(.enabled)
                .help(file.path)
            Spacer(minLength: 0)
            HStack {
                Button(L("Finderで表示")) { store.revealInFinder([file]) }.controlSize(.small)
                Spacer()
                Button(L("こちらを優先"), action: choose).buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .frame(width: 330)
        .frame(minHeight: 330)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor)))
    }

    @ViewBuilder private var preview: some View {
        if let face = file.faces.first, let font = PreviewFonts.font(file: file, face: face, size: 26) {
            Text(sample).font(Font(font)).lineLimit(2)
        } else {
            Text(L("プレビューできません")).foregroundStyle(.secondary)
        }
    }

    private var attributes: [FileAttributeKey: Any] { (try? FileManager.default.attributesOfItem(atPath: file.path)) ?? [:] }

    private var size: String {
        guard let bytes = attributes[.size] as? Int64 ?? (attributes[.size] as? Int).map(Int64.init) else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var modified: String {
        guard let date = attributes[.modificationDate] as? Date else { return "—" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func info(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text(value).lineLimit(1).truncationMode(.middle)
        }
    }
}
