import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: MarkdownStore
    @ObservedObject private var find: FindReplace
    init(store: MarkdownStore) {
        self.store = store
        find = store.find
    }
    @AppStorage(MarkdownStore.levelsKey) private var storedLevels = "12345"
    @AppStorage(MarkdownStore.boldHeadingsKey) private var boldHeadings = true
    @AppStorage(MarkdownStore.editorStyleKey) private var editorStyle = SourceEditor.currentStyle
    @AppStorage(MarkdownStore.editorAppearanceKey) private var editorAppearance = "auto"
    @AppStorage(MarkdownStore.marginKey) private var margin = "standard"
    @AppStorage(MarkdownStore.editorFontKey) private var editorFont = ""
    @AppStorage(MarkdownStore.lineSpacingKey) private var lineSpacing = MarkdownStore.defaultLineSpacing
    @AppStorage(MarkdownStore.fontSizeKey) private var fontSize = MarkdownStore.defaultFontSize
    /// 右ペインの表示：見出し／プレビュー。起動したときはいつもプレビュー
    @State private var rightPane = RightPane.preview.rawValue

    private enum RightPane: String { case headings, preview }
    @AppStorage(MarkdownStore.copyFormatKey) private var copyFormat = HeadingParser.Format.markdown.rawValue
    @State private var selection: Heading.ID?

    private var levels: Set<Int> { MarkdownStore.levels(from: storedLevels) }
    private var headings: [Heading] { store.headings(levels: levels) }

    private func levelBinding(_ level: Int) -> Binding<Bool> {
        Binding(get: { levels.contains(level) }, set: { on in
            var next = levels
            if on { next.insert(level) } else { next.remove(level) }
            storedLevels = next.sorted().map(String.init).joined()
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            HSplitView {
                sourcePane.frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
                headingPane.frame(minWidth: 200, idealWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.secondary.opacity(0.25)))
            .padding(.horizontal, 16)
            footer
        }
        .background(Color(nsColor: AppSurface.color), ignoresSafeAreaEdges: [])
        // The window registers itself after the first layout pass.
        .onAppear { DispatchQueue.main.async { store.refreshDocumentEdited() } }
        .sheet(item: $store.rewriteRequest) { RewriteSheet(request: $0) }
        .sheet(item: $store.htmlLinkRequest) { HTMLLinkSheet(request: $0) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Image(nsImage: currentAppIcon()).resizable().scaledToFit()
                    .frame(width: 44, height: 44).accessibilityHidden(true)
                AppVersionLabel()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Markdownを整形・加工"))
                    .font(.title2.weight(.semibold))
                Text(L("原稿を整え、見出しとプレビューで確かめる"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Text size for both panes.
            ControlGroup {
                Button { MarkdownStore.changeFontSize(by: -1) } label: { Image(systemName: "textformat.size.smaller") }
                    .disabled(fontSize <= MarkdownStore.fontSizes.lowerBound)
                    .help(L("文字を小さく（⌘−）"))
                    .accessibilityLabel(L("文字を小さく"))
                Button { MarkdownStore.changeFontSize(by: 1) } label: { Image(systemName: "textformat.size.larger") }
                    .disabled(fontSize >= MarkdownStore.fontSizes.upperBound)
                    .help(L("文字を大きく（⌘+）"))
                    .accessibilityLabel(L("文字を大きく"))
            }
            .fixedSize()
            Button { SettingsWindow.shared.show() } label: {
                Label(L("設定"), systemImage: "gearshape")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// 原稿・見出しのバーの高さ（左右でそろえる）
    static let paneBarHeight: CGFloat = 38

    private func paneBar<Trailing: View>(_ title: String, detail: String?, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.headline)
            if let detail {
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 4)
            trailing()
        }
        // Regular-size controls: the small size was hard to hit.
        .controlSize(.regular)
        .padding(.horizontal, 10)
        .frame(height: Self.paneBarHeight)
        .background(.bar)
    }

    private var sourcePane: some View {
        VStack(spacing: 0) {
            paneBar(L("原稿"), detail: nil) {
                // Raising/lowering rewrites the source, so the buttons sit on the source pane.
                Button { store.shiftHeadings(by: -1, levels: levels) } label: { Image(systemName: "decrease.indent") }
                    .disabled(headings.isEmpty)
                    .help(L("すべての見出しを1段上げる（#を1つ減らす、⌘[）"))
                    .accessibilityLabel(L("すべての見出しを1段上げる"))
                Button { store.shiftHeadings(by: 1, levels: levels) } label: { Image(systemName: "increase.indent") }
                    .disabled(headings.isEmpty)
                    .help(L("すべての見出しを1段下げる（#を1つ増やす、⌘]）"))
                    .accessibilityLabel(L("すべての見出しを1段下げる"))
                Menu(L("整形")) { TidyMenuItems(levels: levels) }
                    .menuStyle(.button)
                    .fixedSize()
                    .disabled(store.text.isEmpty)
                    .help(L("スペース・空行・記号の整理、改行や行の操作、HTMLの変換、目次の挿入。範囲を選択していればその中だけ（⌘Zで戻せます）"))
                Menu(L("Doorkeeper用に整形")) { DoorkeeperThemeMenuItems() }
                    .menuStyle(.button)
                    .fixedSize()
                    .disabled(store.text.isEmpty)
                    .help(L("テーマを選んで、原稿の ## と ### を装飾付きのHTML見出しに変換します。範囲を選択していればその中だけ（⌘Zで戻せます）"))
            }
            Divider()
            if let url = store.fileURL { linkedFileBar(url) }
            if find.isVisible {
                FindReplaceBar(find: find)
                Divider()
            }
            SourceEditor(store: store, boldHeadings: boldHeadings, style: editorStyle, appearance: editorAppearance, margin: margin, fontName: editorFont, lineSpacing: lineSpacing, fontSize: fontSize)
        }
    }

    /// 原稿と連携しているファイル（⌘Sの上書き先）を示す帯
    private func linkedFileBar(_ url: URL) -> some View {
        let exists = FileManager.default.fileExists(atPath: url.path)
        let folder = (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: exists ? url.path : "/System/Library/CoreServices/Finder.app"))
                    .resizable().frame(width: 18, height: 18)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Text(url.lastPathComponent).font(.callout.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                        if !exists {
                            Label(L("ファイルが見つかりません"), systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(.orange)
                        } else if store.isEdited {
                            Text(L("未保存"))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(Color.orange.opacity(0.18)))
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(folder).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                }
                Spacer(minLength: 4)
                Button(L("Finderで表示")) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    .disabled(!exists)
                Button(L("連携を解除")) { store.unlinkFile() }
                    .help(L("原稿はそのまま残し、ファイルとの連携だけを外します（⌘Sは「別名で保存…」になります）"))
            }
            .controlSize(.small)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.08))
            .help(url.path)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L("連携しているファイル：%@", url.lastPathComponent))
            Divider()
        }
    }

    private var headingPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Picker(L("右ペインの表示"), selection: $rightPane) {
                    Text(L("見出し")).tag(RightPane.headings.rawValue)
                    Text(L("プレビュー")).tag(RightPane.preview.rawValue)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                if rightPane == RightPane.headings.rawValue {
                    Text(L("%@件", String(headings.count))).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                if rightPane == RightPane.headings.rawValue {
                    copyMenu
                } else {
                    Button(L("HTMLをコピー")) { store.copyHTML() }
                        .disabled(store.text.isEmpty)
                        .help(L("プレビューと同じHTMLを全文コピーします"))
                }
            }
            .controlSize(.regular)
            .padding(.horizontal, 10)
            .frame(height: Self.paneBarHeight)
            .background(.bar)
            Divider()
            if rightPane == RightPane.preview.rawValue {
                PreviewView(store: store, markdown: store.text, fontSize: fontSize, margin: margin)
                    .background(Color(nsColor: .textBackgroundColor))
            } else {
                headingList
            }
        }
    }

    private var format: HeadingParser.Format { HeadingParser.Format(rawValue: copyFormat) ?? .markdown }

    /// 形式のポップアップ（一覧の見た目も変わる）と「コピー」
    private var copyMenu: some View {
        HStack(spacing: 6) {
            // A Picker in .menu style collapsed its title at the small control size; a Menu shows the chosen format.
            Menu(format.title) {
                ForEach(HeadingParser.Format.allCases, id: \.self) { item in
                    Button { copyFormat = item.rawValue } label: {
                        if item == format { Label(item.title, systemImage: "checkmark") } else { Text(item.title) }
                    }
                }
            }
            .menuStyle(.button)
            .fixedSize()
            .help(L("一覧の見た目とコピーの形式"))
            .accessibilityLabel(L("一覧の見た目とコピーの形式"))
            Button(L("コピー")) { copy(format) }
                .disabled(headings.isEmpty)
                .help(L("表示中の形式で見出しをまとめてコピー（⇧⌘C）"))
        }
    }

    private var headingList: some View {
        VStack(spacing: 0) {
            levelRow
            Divider()
            ZStack {
                Color(nsColor: .textBackgroundColor)
                if headings.isEmpty {
                    Text(L("見出しはありません"))
                        .foregroundStyle(.secondary)
                } else {
                    let base = headings.map(\.level).min() ?? 1
                    List(selection: $selection) {
                        ForEach(Array(headings.enumerated()), id: \.element.id) { index, heading in
                            // Same layout as the copied text: blank line where the level changes (spaced format).
                            let gap = format == .markdownSpaced && index > 0 && headings[index - 1].level != heading.level
                            row(heading, base: base, index: index)
                                .padding(.top, gap ? fontSize * 1.2 : 0)
                                .tag(heading.id)
                        }
                        // Dragging a heading moves its whole section (body and subheadings) in the source.
                        .onMove { from, to in
                            if let index = from.first { store.moveSection(from: index, to: to, shown: headings) }
                            selection = nil
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .onChange(of: selection) { _, id in
                        if let id, let heading = headings.first(where: { $0.id == id }) { store.reveal(heading) }
                    }
                }
            }
        }
    }

    /// 抜き出すレベルのチェックボックス（横並び）
    private var levelRow: some View {
        // Levels missing from the source are dimmed; their checked state is kept for later.
        let present = Set(store.allHeadings.map(\.level))
        return HStack(spacing: 14) {
            ForEach(MarkdownStore.selectableLevels, id: \.self) { level in
                Toggle(String(repeating: "#", count: level), isOn: levelBinding(level))
                    .toggleStyle(.checkbox)
                    .disabled(!present.contains(level))
                    .help(present.contains(level) ? "" : L("原稿にこのレベルの見出しはありません"))
                    .font(.system(.body, design: .monospaced))
                    .accessibilityLabel(L("見出し%@を抜き出す", String(level)))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(.bar)
    }

    /// 一覧の1行。選んだ形式のコピー結果と同じ見た目にする
    private func row(_ heading: Heading, base: Int, index: Int) -> some View {
        let depth = heading.level - base
        return HStack(spacing: 0) {
            switch format {
            case .markdown, .markdownSpaced:
                Text(String(repeating: "#", count: heading.level) + " ")
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundStyle(.secondary)
            case .tree:
                if depth > 0 {
                    Text(String(repeating: "\u{3000}", count: depth - 1) + "└ ")
                        .font(.system(size: fontSize))
                        .foregroundStyle(.secondary)
                }
            case .simpleTOC:
                // Numbered top-level entries are bold, as in the copied table of contents.
                Text(HeadingParser.simpleTOCPrefix(headings, index: index, base: base))
                    .font(.system(size: fontSize, weight: depth == 0 ? .semibold : .regular))
            case .indented:
                EmptyView()
            }
            Text(heading.title.isEmpty ? " " : heading.title)
                .font(.system(size: fontSize, weight: (format == .simpleTOC ? depth == 0 : heading.level <= 2) ? .semibold : .regular))
                .foregroundStyle(format == .simpleTOC && depth > 0 ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        // Tab-indented text: one tab per level below 1.
        .padding(.leading, format == .indented ? CGFloat(heading.level - 1) * fontSize * 2 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L("見出し%@：%@", String(heading.level), heading.title))
        .contextMenu {
            Button(L("原稿で表示")) { store.reveal(heading) }
            Button(L("この見出しをコピー")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(heading.title, forType: .string)
                store.message = L("%@をコピーしました", heading.title)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(store.message ?? statsText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(rawStatsText)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// 本文（記号・タグ・空行を除く）の行数・文字数。選択していれば選択範囲も同じ数え方で続ける
    private var statsText: String {
        let content = TextStats.content(store.text)
        var parts = [L("%@行・%@文字", String(content.lines), String(content.characters))]
        if !store.selectedText.isEmpty {
            let selected = TextStats.content(store.selectedText)
            parts.append(L("選択範囲：%@行・%@文字", String(selected.lines), String(selected.characters)))
        }
        return parts.joined(separator: "   ")
    }

    /// ツールチップ：原稿をそのまま数えた行数・文字数
    private var rawStatsText: String {
        let raw = TextStats.raw(store.text)
        return L("原稿全体：%@行・%@文字（記号・タグ・空行を含む）", String(raw.lines), String(raw.characters))
    }

    private func copy(_ format: HeadingParser.Format) {
        copyFormat = format.rawValue
        store.copyHeadings(levels: levels, format: format)
    }
}

/// 原稿のバーの「整形」メニュー（6項目とその他を続けて並べる）
struct TidyMenuItems: View {
    let levels: Set<Int>
    var body: some View {
        TidyRuleItems()
        Divider()
        TidyToolItems(levels: levels)
    }
}

/// 整形の6項目（ツールメニューでは「整形」のサブメニュー）
struct TidyRuleItems: View {
    var body: some View {
        // 「すべて整える」でまとめて実行するもの
        Button(L("行頭のスペースを削除")) { MarkdownStore.shared.tidy([.leadingSpaces]) }
        Button(L("行末のスペースを削除")) { MarkdownStore.shared.tidy([.trailingSpaces]) }
        Button(L("スペースやタブだけの行を空に")) { MarkdownStore.shared.tidy([.whitespaceLines]) }
        Button(L("連続する空行を1行に")) { MarkdownStore.shared.tidy([.blankLines]) }
        Button(L("記号のあとにスペースを入れる")) { MarkdownStore.shared.tidy([.markerSpaces]) }
        Button(L("リストの記号を「-」にそろえる")) { MarkdownStore.shared.tidy([.listMarkers]) }
        Button(L("英数字を半角に")) { MarkdownStore.shared.tidy([.halfwidthAlphanumerics]) }
        Button(L("和欧間のスペースを削除")) { MarkdownStore.shared.tidy([.japaneseLatinSpaces]) }
        Divider()
        Button(L("すべて整える")) { MarkdownStore.shared.tidy(MarkdownTidy.Rule.standard) }
        Divider()
        // 「すべて整える」に入れないもの（文章を変えるので、選んだときだけ）
        Button(L("空行を削除")) { MarkdownStore.shared.tidy([.removeBlankLines]) }
        Button(L("twitter.comをx.comに")) { MarkdownStore.shared.tidy([.twitterToX]) }
        Button(L("utmパラメーターを削除")) { MarkdownStore.shared.tidy([.removeUTM]) }
        Button(L("divブロックで囲む")) { MarkdownStore.shared.transformLines(L("divブロックで囲む"), done: L("divブロックで囲みました"), LineTools.wrapInDiv) }
    }
}

/// ツールの項目（整形のほか）。用途ごとに区切る：改行・空行／行の操作／変換／目次
/// ツールメニューでは変換に Doorkeeper用に整形、見出しの区切りに上げ下げが加わる（原稿のバーには専用のボタンがある）
struct TidyToolItems: View {
    let levels: Set<Int>
    var inToolsMenu = false
    var body: some View {
        // 書き直し
        Button(L("文字数を指定して書き直す…")) { MarkdownStore.shared.beginRewrite() }
        Button(L("HTMLリンク…")) { MarkdownStore.shared.beginHTMLLink() }
        Divider()
        // 改行・空行
        Button(L("要素間に空行を入れる")) { MarkdownStore.shared.transformLines(L("要素間に空行を入れる"), done: L("要素間に空行を入れました"), LineTools.separateBlocks) }
        Button(L("強制改行を改段落に")) { MarkdownStore.shared.transformLines(L("強制改行を改段落に"), done: L("強制改行を改段落にしました"), LineTools.hardBreaksToParagraphs) }
        Button(L("改行を削除")) { MarkdownStore.shared.transformLines(L("改行を削除"), done: L("改行を削除しました"), LineTools.joinLines) }
        Divider()
        // 行の操作
        Button(L("重複行を削除")) { MarkdownStore.shared.transformLines(L("重複行を削除"), done: L("重複行を削除しました"), LineTools.removeDuplicates) }
        Button(L("並べ替え（昇順）")) { MarkdownStore.shared.transformLines(L("並べ替え（昇順）"), done: L("行を並べ替えました")) { LineTools.sort($0, descending: false) } }
        Button(L("並べ替え（降順）")) { MarkdownStore.shared.transformLines(L("並べ替え（降順）"), done: L("行を並べ替えました")) { LineTools.sort($0, descending: true) } }
        Divider()
        // 変換
        Button(L("HTML→Markdown")) { MarkdownStore.shared.convertHTMLToMarkdown() }
        Button(L("HTMLをMinify")) { MarkdownStore.shared.tidy([.minifyHTML]) }
        if inToolsMenu { Menu(L("Doorkeeper用に整形")) { DoorkeeperThemeMenuItems() } }
        Divider()
        // 見出し
        Button(L("目次を挿入")) { MarkdownStore.shared.insertTableOfContents(levels: levels) }
        if inToolsMenu {
            Menu(L("見出しレベルの変更（すべて）")) {
                ShortcutButton(action: .raiseHeadings, title: L("1段上げる"))
                ShortcutButton(action: .lowerHeadings, title: L("1段下げる"))
            }
        }
    }
}

extension HeadingParser.Format {
    /// コピーメニューに出す名前
    var title: String {
        switch self {
        case .markdown: return L("Markdown（# 見出し）")
        case .markdownSpaced: return L("Markdown（レベルが変わるところに空行）")
        case .tree: return L("ツリー（└ 見出し）")
        case .simpleTOC: return L("シンプル目次")
        case .indented: return L("タブで字下げしたテキスト")
        }
    }
}

// Main-window header uses the same icon resource as the distributed app.
@MainActor private func currentAppIcon() -> NSImage {
    let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String ?? "AppIcon"
    let filename = name.hasSuffix(".icns") ? name : name + ".icns"
    if let url = Bundle.main.resourceURL?.appendingPathComponent(filename),
       let image = NSImage(contentsOf: url) { return image }
    return NSApp.applicationIconImage
}
/// Shown under the header icon: version, then build in parentheses (「1.4.5」「（15）」).
private func appVersionText() -> String {
    let info = Bundle.main.infoDictionary ?? [:]
    let version = info["CFBundleShortVersionString"] as? String ?? ""
    guard let build = info["CFBundleVersion"] as? String, !build.isEmpty, build != version else { return version }
    let japanese = Bundle.main.preferredLocalizations.first?.hasPrefix("ja") ?? false
    return version + "\n" + (japanese ? "（\(build)）" : "(\(build))")
}
/// Placed under the header icon.
private struct AppVersionLabel: View {
    var body: some View {
        Text(appVersionText()).font(.system(size: 10)).foregroundStyle(.secondary)
            .multilineTextAlignment(.center).fixedSize()
    }
}
