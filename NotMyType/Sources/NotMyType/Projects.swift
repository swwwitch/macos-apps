import AppKit
import CoreGraphics
import SwiftUI

/// 制作ファイルから使っているフォント名を取り出す。形式はファイルの先頭のバイトで見分ける（拡張子は見ない）。
/// 取り出し方は 2026-10-24 にユーザーの実ファイルで確かめた（IDML 2件・AI 3件）
enum FontNameExtractor {
    enum Failure: Error { case unsupported, unreadable }

    static let fileExtensions: Set<String> = ["idml", "indd", "pdf", "ai"]
    /// INDD の先頭16バイト（InDesign の文書の目印）
    private static let inddSignature: [UInt8] = [0x06, 0x06, 0xED, 0xF5, 0xD8, 0x1D, 0x46, 0xE5, 0xBD, 0x31, 0xEF, 0xE7, 0xFE, 0x74, 0xB7, 0x1D]

    static func names(in url: URL) throws -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { throw Failure.unreadable }
        let head = (try? handle.read(upToCount: 16)) ?? Data()
        try? handle.close()
        if head.starts(with: [0x50, 0x4B, 0x03, 0x04]) { return try idmlNames(url) }      // PK：IDML（zip）
        if head.starts(with: Array("%PDF".utf8)) { return pdfNames(url) }                  // PDF・PDF互換のAI
        if head.starts(with: inddSignature) { return inddNames(url) }
        throw Failure.unsupported
    }

    /// 貼り付けた文字：1行に1つ。空行と前後の空白は捨てる
    static func names(inText text: String) -> [String] {
        unique(text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    // MARK: IDML

    /// Stories・Styles・Spreads の AppliedFont（ファミリー名）と FontStyle（スタイル名）を集め、
    /// Resources/Fonts.xml（ファミリー・スタイル・PostScript名の表。使っていない書体も並ぶ）と突き合わせる
    private static func idmlNames(_ url: URL) throws -> [String] {
        let used = unzip(url, ["Stories/*", "Resources/Styles.xml", "Spreads/*", "MasterSpreads/*"])
        let fonts = unzip(url, ["Resources/Fonts.xml"])
        guard !fonts.isEmpty else { throw Failure.unreadable }
        let families = Set(matches(#"<AppliedFont type="string">([^<]*)</AppliedFont>"#, in: used).map(decodeEntities))
        let styles = Set(matches(#"FontStyle="([^"]*)""#, in: used).map(decodeEntities))
        var result: [String] = []
        let entries = matches(#"<Font\s[^>]*>"#, in: fonts, group: 0).map { element -> (family: String, style: String, postScript: String) in
            (attribute("FontFamily", element), attribute("FontStyleName", element), attribute("PostScriptName", element))
        }
        for family in families.sorted() {
            let members = entries.filter { $0.family == family }
            // 使っているスタイルだけ。どれも当たらなければ Regular、それも無ければ先頭の書体
            var chosen = members.filter { styles.contains($0.style) }
            if chosen.isEmpty { chosen = members.filter { $0.style == "Regular" || $0.style == "R" } }
            if chosen.isEmpty, let first = members.first { chosen = [first] }
            // Fonts.xml に無いファミリーは名前のまま（あいまいな照合に回す）
            result += chosen.isEmpty ? [family] : chosen.map(\.postScript)
        }
        return unique(result.filter { !$0.isEmpty })
    }

    private static func unzip(_ url: URL, _ patterns: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", url.path] + patterns
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    private static func attribute(_ name: String, _ element: String) -> String {
        matches(name + #"="([^"]*)""#, in: element).first.map(decodeEntities) ?? ""
    }

    private static func decodeEntities(_ text: String) -> String {
        text.replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    // MARK: INDD

    /// INDD は非公開の形式だが、文書の XMP に stFnt:fontName の一覧がある。使っている書体があるファミリーの全スタイルが並ぶので、
    /// IDML より多くなる（同じ文書で IDML 24件・INDD 67件、2026-10-24 実測）
    private static func inddNames(_ url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return [] }
        return unique(xmpFontNames(data).filter { !$0.isEmpty && !$0.hasPrefix("ATC-") })
    }

    // MARK: PDF・AI

    /// ページ（と中のフォーム XObject）の Resources/Font の BaseFont。埋め込みの「ABCDEF+」を外し、Type0 は DescendantFonts の名前を使う。
    /// AI は XMP の stFnt:fontName にも一覧があり、PDF の部分に入っていないフォントも拾える（ATC- で始まる合成フォントは除く）
    private static func pdfNames(_ url: URL) -> [String] {
        var names: [String] = []
        if let document = CGPDFDocument(url as CFURL), document.numberOfPages > 0 {
            let collector = PDFFontCollector()
            for index in 1...document.numberOfPages {
                guard let page = document.page(at: index)?.dictionary else { continue }
                var resources: CGPDFDictionaryRef?
                if CGPDFDictionaryGetDictionary(page, "Resources", &resources), let resources { collector.walk(resources) }
            }
            names += collector.names
        }
        if let data = try? Data(contentsOf: url, options: .alwaysMapped) {
            names += xmpFontNames(data)
        }
        return unique(names.map(stripSubsetPrefix).filter { !$0.isEmpty && !$0.hasPrefix("ATC-") })
    }

    private static func xmpFontNames(_ data: Data) -> [String] {
        let open = Data("<stFnt:fontName>".utf8), close = Data("</stFnt:fontName>".utf8)
        var names: [String] = []
        var cursor = data.startIndex
        while let start = data.range(of: open, in: cursor..<data.endIndex) {
            cursor = start.upperBound
            // 途中で切れたメタデータの断片（INDD の中にある）は、閉じタグが遠くにあり NUL などが混じる。短く、印字できる名前だけ取る
            let limit = data.index(start.upperBound, offsetBy: 256, limitedBy: data.endIndex) ?? data.endIndex
            guard let end = data.range(of: close, in: start.upperBound..<limit) else { continue }
            let name = String(decoding: data[start.upperBound..<end.lowerBound], as: UTF8.self)
            if !name.isEmpty, !name.contains("<"), name.unicodeScalars.allSatisfy({ $0.value >= 0x20 }) { names.append(name) }
            cursor = end.upperBound
        }
        return names
    }

    private static func stripSubsetPrefix(_ name: String) -> String {
        guard name.count > 7, name.dropFirst(6).first == "+", name.prefix(6).allSatisfy({ $0.isUppercase }) else { return name }
        return String(name.dropFirst(7))
    }

    // MARK: 共通

    private static func matches(_ pattern: String, in text: String, group: Int = 1) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range(at: group), in: text).map { String(text[$0]) }
        }
    }

    private static func unique(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }
}

/// CGPDF の辞書を辿ってフォント名を集める（同じ辞書は1回だけ）
private final class PDFFontCollector {
    var names: [String] = []
    private var seen = Set<UnsafeRawPointer>()

    func walk(_ resources: CGPDFDictionaryRef) {
        guard seen.insert(unsafeBitCast(resources, to: UnsafeRawPointer.self)).inserted else { return }
        var fonts: CGPDFDictionaryRef?
        if CGPDFDictionaryGetDictionary(resources, "Font", &fonts), let fonts {
            CGPDFDictionaryApplyBlock(fonts, { _, object, info in
                guard let info else { return true }
                let collector = Unmanaged<PDFFontCollector>.fromOpaque(info).takeUnretainedValue()
                var font: CGPDFDictionaryRef?
                if CGPDFObjectGetValue(object, .dictionary, &font), let font { collector.addFont(font) }
                return true
            }, Unmanaged.passUnretained(self).toOpaque())
        }
        var objects: CGPDFDictionaryRef?
        if CGPDFDictionaryGetDictionary(resources, "XObject", &objects), let objects {
            CGPDFDictionaryApplyBlock(objects, { _, object, info in
                guard let info else { return true }
                let collector = Unmanaged<PDFFontCollector>.fromOpaque(info).takeUnretainedValue()
                var stream: CGPDFStreamRef?
                var inner: CGPDFDictionaryRef?
                if CGPDFObjectGetValue(object, .stream, &stream), let stream, let dictionary = CGPDFStreamGetDictionary(stream),
                   CGPDFDictionaryGetDictionary(dictionary, "Resources", &inner), let inner {
                    collector.walk(inner)
                }
                return true
            }, Unmanaged.passUnretained(self).toOpaque())
        }
    }

    private func addFont(_ font: CGPDFDictionaryRef) {
        // Type0 の BaseFont は「名前-Identity-H」のように CMap 名が付くので、子のフォントの名前を使う
        var descendants: CGPDFArrayRef?
        var child: CGPDFDictionaryRef?
        if CGPDFDictionaryGetArray(font, "DescendantFonts", &descendants), let descendants,
           CGPDFArrayGetDictionary(descendants, 0, &child), let child, let name = baseFont(child) {
            names.append(name)
        } else if let name = baseFont(font) {
            names.append(name)
        }
    }

    private func baseFont(_ dictionary: CGPDFDictionaryRef) -> String? {
        var name: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(dictionary, "BaseFont", &name), let name else { return nil }
        return String(cString: name)
    }
}

/// 取り出した名前をライブラリと照合する。PostScript名の完全一致は確定、
/// 大文字・小文字や記号・空白の違いだけで一致したもの（ファミリー＋スタイル名も見る）は候補として承認を待つ
struct ProjectDraft {
    struct Match: Hashable {
        var name: String
        var file: FontFile
    }

    var exact: [Match] = []
    var candidates: [Match] = []
    var missing: [String] = []

    @MainActor
    init(names: [String], files: [FontFile]) {
        var byPostScript: [String: FontFile] = [:]
        var byKey: [String: FontFile] = [:]
        // 同じ名前のファイルが複数あるときは、見つかるもの・先に登録したものを使う
        for file in files where FileManager.default.fileExists(atPath: file.path) {
            for face in file.faces {
                if byPostScript[face.postScriptName] == nil { byPostScript[face.postScriptName] = file }
                for name in [face.postScriptName, face.fullName, face.family + " " + face.style] {
                    let key = Self.key(name)
                    if byKey[key] == nil { byKey[key] = file }
                }
            }
        }
        for name in names {
            if let file = byPostScript[name] {
                exact.append(Match(name: name, file: file))
            } else if let file = byKey[Self.key(name)] {
                candidates.append(Match(name: name, file: file))
            } else {
                missing.append(name)
            }
        }
    }

    /// 照合用：小文字にして、英数字以外（空白・ハイフン・下線など）を除く
    static func key(_ name: String) -> String {
        String(name.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }
}

// MARK: - 参照するファイル・フォルダーからの読み込み

enum ProjectSources {
    /// 参照するファイル・フォルダーからフォント名を集める。フォルダーは下の階層まで制作ファイルを探す（隠しファイル・パッケージの中は見ない）
    /// unreachable は見つからないファイル・フォルダー（外付けディスクが外れている、同期の途中など）
    static func collectNames(_ sources: [ProjectSource]) -> (names: [String], unreadable: [String], unreachable: [String]) {
        var names: [String] = []
        var unreadable: [String] = []
        var unreachable: [String] = []
        func read(_ url: URL) {
            if let found = try? FontNameExtractor.names(in: url) { names += found } else { unreadable.append(url.lastPathComponent) }
        }
        for source in sources {
            switch source.kind {
            case .names: names += source.names
            case .file, .folder:
                guard let path = source.path else { continue }
                guard FileManager.default.fileExists(atPath: path) else { unreachable.append((path as NSString).lastPathComponent); continue }
                if source.kind == .file { read(URL(fileURLWithPath: path)) }
                else { for url in productionFiles(in: URL(fileURLWithPath: path)) { read(url) } }
            }
        }
        var seen = Set<String>()
        return (names.filter { seen.insert($0).inserted }, unreadable, unreachable)
    }

    static func productionFiles(in folder: URL) -> [URL] {
        let items = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey],
                                                   options: [.skipsHiddenFiles, .skipsPackageDescendants])
        var found: [URL] = []
        while let item = items?.nextObject() as? URL {
            if FontNameExtractor.fileExtensions.contains(item.pathExtension.lowercased()) { found.append(item) }
        }
        return found.sorted { $0.path < $1.path }
    }
}

/// フォルダーを元にするプロジェクトのフォルダーを見張り、中が変わったら読み直す
@MainActor
final class ProjectFolderWatcher {
    static let shared = ProjectFolderWatcher()
    private var stream: FSEventStreamRef?
    private var paths: [String] = []
    private var pending: DispatchWorkItem?

    func update() {
        let wanted = Array(Set(LibraryStore.shared.data.projects.flatMap { project in
            project.sources.filter { $0.kind == .folder }.compactMap(\.path)
        }.filter { FileManager.default.fileExists(atPath: $0) })).sorted()
        guard wanted != paths else { return }
        paths = wanted
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
        guard !wanted.isEmpty else { return }
        let callback: FSEventStreamCallback = { _, _, _, _, _, _ in
            Task { @MainActor in ProjectFolderWatcher.shared.schedule() }
        }
        var context = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        guard let created = FSEventStreamCreate(nil, callback, &context, wanted as CFArray,
                                                FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 2.0,
                                                FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)) else { return }
        FSEventStreamSetDispatchQueue(created, DispatchQueue.main)
        FSEventStreamStart(created)
        stream = created
    }

    /// 保存の途中などで続けて届くので、落ち着いてから読む
    private func schedule() {
        pending?.cancel()
        let work = DispatchWorkItem { Task { @MainActor in LibraryStore.shared.rebuildFolderProjects() } }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }
}

// MARK: - 編集の画面

@MainActor
final class ProjectEditorWindow {
    static let shared = ProjectEditorWindow()
    private var window: NSWindow?
    private var projectID: UUID?

    func show(_ id: UUID) {
        if projectID != id { window?.close(); window = nil }
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 600),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = L("プロジェクトを編集")
            window.isReleasedWhenClosed = false
            let hosting = NSHostingView(rootView: ProjectEditorView(projectID: id)
                .frame(minWidth: 560, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity))
            hosting.sizingOptions = [.minSize]
            window.contentView = hosting
            window.center()
            self.window = window
            projectID = id
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }

    func closeIfShowing(_ id: UUID) { if projectID == id { close() } }
}

/// 名前・参照するファイル・フォルダー（ファイル・フォルダー・フォント名）・照合の結果（一致・候補・見つからない）
private struct ProjectEditorView: View {
    let projectID: UUID
    @ObservedObject private var store = LibraryStore.shared
    @State private var selectedSources = Set<UUID>()
    @State private var tab = 0
    @State private var pasting = false
    @State private var pastedText = ""
    /// 名前は打っている間はここに持ち、確定（Return・欄を離れる・画面を閉じる）で保存する。
    /// 1文字ごとに保存すると、共有ライブラリ（数MB）を書き直して一覧も作り直すので、取りこぼしが出ていた
    @State private var nameDraft: String?
    @FocusState private var nameFocused: Bool

    var body: some View {
        if let project = store.project(projectID) {
            content(project)
        } else {
            Text(L("このプロジェクトは削除されました")).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func content(_ project: FontProject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("名前") + L(" :"))
                TextField(L("名前"), text: Binding(get: { nameDraft ?? project.name }, set: { nameDraft = $0 }))
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .onSubmit { commitName() }
                    .onChange(of: nameFocused) { _, focused in if !focused { commitName() } }
            }
            GroupBox(L("参照するファイル・フォルダー")) {
                VStack(alignment: .leading, spacing: 6) {
                    List(project.sources, selection: $selectedSources) { source in
                        sourceRow(source).tag(source.id)
                            .contextMenu {
                                if let path = source.path {
                                    Button(L("Finderで表示")) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
                                }
                                Button(L("外す")) { store.removeProjectSources(projectID, [source.id]) }
                            }
                    }
                    .frame(height: 120)
                    .overlay {
                        if project.sources.isEmpty {
                            Text(L("ファイル・フォルダー・フォント名を指定します")).foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 6) {
                        Button(L("ファイルを指定…")) { chooseFiles() }
                        Button(L("フォルダーを指定…")) { chooseFolders() }
                        Button(L("フォント名を貼り付け…")) { pasting = true }
                        Button { store.removeProjectSources(projectID, selectedSources); selectedSources.removeAll() } label: {
                            Image(systemName: "minus")
                        }
                        .disabled(selectedSources.isEmpty)
                        .help(L("選んだものを外す")).accessibilityLabel(L("選んだものを外す"))
                        Spacer()
                        if store.rebuildingProjects.contains(projectID) { ProgressView().controlSize(.small) }
                        Button(L("読み直す")) { store.rebuildProject(projectID) }
                            .disabled(project.sources.isEmpty || store.rebuildingProjects.contains(projectID))
                    }
                    Text(L("フォルダーは下の階層の制作ファイル（IDML・INDD・PDF・AI）を全部調べ、中が変わると自動で読み直します。"))
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(4)
            }
            if !project.excludedFiles.isEmpty {
                Button(L("外したフォントをすべて戻す")) { store.restoreProjectFonts(projectID) }
            }
            Picker("", selection: $tab) {
                Text(L("一致（%d）", project.matched.filter { !project.excludedFiles.contains($0) }.count)).tag(0)
                Text(L("候補（%d）", project.candidates.filter { !project.excludedFiles.contains($0.file) }.count)).tag(1)
                Text(L("見つからない（%d）", project.missing.count)).tag(2)
            }
            .pickerStyle(.segmented).labelsHidden()
            fontList(project)
            HStack {
                Text(L("候補は表記が少し異なるフォントです。チェックしたものだけプロジェクトに入ります。"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(L("アクティブにする")) { store.activateProject(projectID) }
                    .disabled(project.files.isEmpty)
                Button(L("閉じる")) { commitName(); ProjectEditorWindow.shared.close() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .sheet(isPresented: $pasting) { pasteSheet }
        .onDisappear { commitName() }
    }

    private func commitName() {
        guard let draft = nameDraft else { return }
        nameDraft = nil
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != store.project(projectID)?.name else { return }
        store.updateProject(projectID) { $0.name = trimmed }
    }

    @ViewBuilder private func fontList(_ project: FontProject) -> some View {
        let byID = Dictionary(store.data.files.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        List {
            switch tab {
            case 0:
                ForEach(project.matched.filter { !project.excludedFiles.contains($0) }, id: \.self) { id in
                    if let file = byID[id] { fileRow(file) }
                }
            case 1:
                ForEach(project.candidates.filter { !project.excludedFiles.contains($0.file) }, id: \.self) { candidate in
                    HStack(spacing: 8) {
                        Toggle("", isOn: Binding(get: { project.approved.contains(candidate.name) },
                                                 set: { store.approveProjectCandidate(projectID, candidate.name, $0) }))
                            .labelsHidden()
                        Text(verbatim: candidate.name).textSelection(.enabled)
                        Image(systemName: "arrow.right").foregroundStyle(.secondary).accessibilityLabel(L("から"))
                        Text(verbatim: byID[candidate.file]?.fileName ?? "—").foregroundStyle(.secondary)
                    }
                }
            default:
                ForEach(project.missing, id: \.self) { Text(verbatim: $0).foregroundStyle(.secondary).textSelection(.enabled) }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func fileRow(_ file: FontFile) -> some View {
        HStack {
            Text(file.faces.first?.displayFamily ?? file.fileName)
            Text(file.faces.map(\.postScriptName).joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            if store.states[file.id] == .active { Image(systemName: "checkmark.circle").foregroundStyle(.secondary).accessibilityLabel(L("アクティブ")) }
        }
    }

    private func sourceRow(_ source: ProjectSource) -> some View {
        HStack(spacing: 6) {
            switch source.kind {
            case .file:
                Image(systemName: "doc").accessibilityHidden(true)
                pathText(source.path)
            case .folder:
                Image(systemName: "folder").accessibilityHidden(true)
                pathText(source.path)
            case .names:
                Image(systemName: "text.quote").accessibilityHidden(true)
                Text(L("フォント名 %d個", source.names.count))
                Text(source.names.prefix(3).joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private func pathText(_ path: String?) -> some View {
        let path = path ?? ""
        let exists = FileManager.default.fileExists(atPath: path)
        return HStack(spacing: 6) {
            Text((path as NSString).lastPathComponent).foregroundStyle(exists ? .primary : .secondary)
            Text((path as NSString).deletingLastPathComponent).font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            if !exists { Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange).help(L("見つかりません")) }
        }
        .help(path)
    }

    private var pasteSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("フォント名を1行に1つ貼り付けます（PostScript名がいちばん確実です）。"))
                .font(.callout).foregroundStyle(.secondary)
            TextEditor(text: $pastedText)
                .font(.system(.body, design: .monospaced))
                .border(Color(nsColor: .separatorColor))
                .frame(minWidth: 380, minHeight: 220)
            HStack {
                Spacer()
                Button(L("キャンセル")) { pasting = false; pastedText = "" }.keyboardShortcut(.cancelAction)
                Button(L("追加")) {
                    store.addProjectSources(projectID, [ProjectSource(kind: .names, names: FontNameExtractor.names(inText: pastedText))])
                    pasting = false
                    pastedText = ""
                }
                .keyboardShortcut(.defaultAction)
                .disabled(FontNameExtractor.names(inText: pastedText).isEmpty)
            }
        }
        .padding(16)
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.message = L("フォントを調べる制作ファイル（IDML・INDD・PDF・AI）を選びます")
        panel.prompt = L("選択")
        guard panel.runModal() == .OK else { return }
        store.addProjectSources(projectID, panel.urls.map { ProjectSource(kind: .file, path: $0.path) })
    }

    private func chooseFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = L("制作ファイルの入ったフォルダーを選びます。中が変わると自動で読み直します")
        panel.prompt = L("選択")
        guard panel.runModal() == .OK else { return }
        store.addProjectSources(projectID, panel.urls.map { ProjectSource(kind: .folder, path: $0.path) })
    }
}
