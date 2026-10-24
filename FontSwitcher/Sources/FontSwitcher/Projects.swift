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
struct ProjectDraft: Identifiable {
    struct Match: Identifiable, Hashable {
        var name: String
        var file: FontFile
        var id: String { name + "|" + file.id.uuidString }
    }

    let id = UUID()
    var name: String
    var source: String?
    var exact: [Match] = []
    var candidates: [Match] = []
    var missing: [String] = []

    @MainActor
    init(name: String, source: String?, names: [String], files: [FontFile]) {
        self.name = name
        self.source = source
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

// MARK: - 作成の確認

@MainActor
final class ProjectDraftWindow {
    static let shared = ProjectDraftWindow()
    private var window: NSWindow?

    func show(_ draft: ProjectDraft) {
        window?.close()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = L("新規プロジェクト")
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: ProjectDraftView(draft: draft).frame(minWidth: 520, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity))
        hosting.sizingOptions = [.minSize]
        window.contentView = hosting
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }
}

/// 名前を決め、一致したフォントと承認する候補を確かめて作る。見つからないフォントは名前だけ残す
private struct ProjectDraftView: View {
    @State var draft: ProjectDraft
    @State private var approved = Set<String>()
    @State private var activate = true

    init(draft: ProjectDraft) {
        _draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("名前") + L(" :"))
                TextField(L("名前"), text: $draft.name).textFieldStyle(.roundedBorder)
            }
            if let source = draft.source {
                Text(source).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            List {
                Section(L("一致したフォント（%d）", draft.exact.count)) {
                    ForEach(draft.exact) { match in row(match.name, match.file) }
                }
                if !draft.candidates.isEmpty {
                    Section(L("候補：表記が少し異なります。チェックしたものだけ入れます（%d）", draft.candidates.count)) {
                        ForEach(draft.candidates) { match in
                            HStack {
                                Toggle("", isOn: Binding(get: { approved.contains(match.id) },
                                                         set: { if $0 { approved.insert(match.id) } else { approved.remove(match.id) } }))
                                    .labelsHidden()
                                row(match.name, match.file)
                            }
                        }
                    }
                }
                if !draft.missing.isEmpty {
                    Section(L("ライブラリに見つかりません（%d）", draft.missing.count)) {
                        ForEach(draft.missing, id: \.self) { Text(verbatim: $0).foregroundStyle(.secondary).textSelection(.enabled) }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            Toggle(L("作成したらアクティブにする"), isOn: $activate)
            HStack {
                Spacer()
                Button(L("キャンセル")) { ProjectDraftWindow.shared.close() }.keyboardShortcut(.cancelAction)
                Button(L("作成")) {
                    let files = draft.exact.map(\.file) + draft.candidates.filter { approved.contains($0.id) }.map(\.file)
                    let missing = draft.missing + draft.candidates.filter { !approved.contains($0.id) }.map(\.name)
                    LibraryStore.shared.createProject(name: draft.name, source: draft.source, files: files, missing: missing, activate: activate)
                    ProjectDraftWindow.shared.close()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }

    private func row(_ name: String, _ file: FontFile) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: name).textSelection(.enabled)
            if file.faces.first?.postScriptName != name || file.faces.count > 1 {
                Image(systemName: "arrow.right").foregroundStyle(.secondary).accessibilityLabel(L("から"))
                Text(verbatim: file.fileName).foregroundStyle(.secondary)
            }
        }
    }
}

/// 貼り付けで作る：フォント名を1行に1つ
@MainActor
final class ProjectPasteWindow {
    static let shared = ProjectPasteWindow()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = L("フォント名からプロジェクトを作成")
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: ProjectPasteView())
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }
}

private struct ProjectPasteView: View {
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("フォント名を1行に1つ貼り付けます（PostScript名がいちばん確実です）。"))
                .font(.callout).foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .border(Color(nsColor: .separatorColor))
            HStack {
                Spacer()
                Button(L("キャンセル")) { ProjectPasteWindow.shared.close() }.keyboardShortcut(.cancelAction)
                Button(L("次へ")) {
                    let names = FontNameExtractor.names(inText: text)
                    ProjectPasteWindow.shared.close()
                    ProjectDraftWindow.shared.show(ProjectDraft(name: L("名称未設定プロジェクト"), source: nil, names: names,
                                                                files: LibraryStore.shared.data.files))
                    text = ""
                }
                .keyboardShortcut(.defaultAction)
                .disabled(FontNameExtractor.names(inText: text).isEmpty)
            }
        }
        .padding(16)
        .frame(minWidth: 400, minHeight: 300)
    }
}
