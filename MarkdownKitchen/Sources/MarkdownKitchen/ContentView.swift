import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject private var store = MarkdownStore.shared
    @AppStorage(MarkdownStore.levelsKey) private var storedLevels = "12345"
    @AppStorage(MarkdownStore.boldHeadingsKey) private var boldHeadings = true
    @AppStorage(MarkdownStore.fontSizeKey) private var fontSize = MarkdownStore.defaultFontSize
    /// 右ペインの表示：見出し／プレビュー
    @AppStorage("markdownKitchen.rightPane") private var rightPane = RightPane.headings.rawValue

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
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: currentAppIcon()).resizable().scaledToFit()
                .frame(width: 44, height: 44).accessibilityHidden(true)
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
                    .help(L("見出しを1段上げる（#を1つ減らす、⌘[）"))
                    .accessibilityLabel(L("見出しを1段上げる"))
                Button { store.shiftHeadings(by: 1, levels: levels) } label: { Image(systemName: "increase.indent") }
                    .disabled(headings.isEmpty)
                    .help(L("見出しを1段下げる（#を1つ増やす、⌘]）"))
                    .accessibilityLabel(L("見出しを1段下げる"))
                Menu(L("整形")) { TidyMenuItems(levels: levels) }
                    .menuStyle(.button)
                    .fixedSize()
                    .disabled(store.text.isEmpty)
                    .help(L("行末の空白・空行・リストの記号・英数字・和欧間のスペースの整理、HTML→Markdown、目次の挿入。範囲を選択していればその中だけ（⌘Zで戻せます）"))
                Menu(L("Doorkeeper用に整形")) { DoorkeeperThemeMenuItems() }
                    .menuStyle(.button)
                    .fixedSize()
                    .disabled(store.text.isEmpty)
                    .help(L("テーマを選んで、原稿の ## と ### を装飾付きのHTML見出しに変換します。範囲を選択していればその中だけ（⌘Zで戻せます）"))
            }
            Divider()
            if let url = store.fileURL { linkedFileBar(url) }
            SourceEditor(store: store, boldHeadings: boldHeadings, fontSize: fontSize)
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
                PreviewView(markdown: store.text, fontSize: fontSize)
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
            .accessibilityLabel(L("表示とコピーの形式"))
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
                            row(heading, base: base)
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
    private func row(_ heading: Heading, base: Int) -> some View {
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
            case .indented:
                EmptyView()
            }
            Text(heading.title.isEmpty ? " " : heading.title)
                .font(.system(size: fontSize, weight: heading.level <= 2 ? .semibold : .regular))
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
            Text(store.message ?? L("%@行・%@文字", String(lineCount), String(store.text.count)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var lineCount: Int { store.text.isEmpty ? 0 : HeadingParser.splitLines(store.text).count }

    private func copy(_ format: HeadingParser.Format) {
        copyFormat = format.rawValue
        store.copyHeadings(levels: levels, format: format)
    }
}

/// 「整形」メニューの項目（原稿のバーと編集メニューで共有）
struct TidyMenuItems: View {
    let levels: Set<Int>
    var body: some View {
        Button(L("行末の空白を削除")) { MarkdownStore.shared.tidy([.trailingSpaces]) }
        Button(L("連続する空行を1行に")) { MarkdownStore.shared.tidy([.blankLines]) }
        Button(L("リストの記号を「-」にそろえる")) { MarkdownStore.shared.tidy([.listMarkers]) }
        Button(L("英数字を半角に")) { MarkdownStore.shared.tidy([.halfwidthAlphanumerics]) }
        Button(L("和欧間のスペースを削除")) { MarkdownStore.shared.tidy([.japaneseLatinSpaces]) }
        Divider()
        Button(L("すべて整える")) { MarkdownStore.shared.tidy(MarkdownTidy.Rule.standard) }
        Divider()
        Button(L("HTMLをMinify")) { MarkdownStore.shared.tidy([.minifyHTML]) }
        Button(L("HTML→Markdown")) { MarkdownStore.shared.convertHTMLToMarkdown() }
        Divider()
        Button(L("目次を挿入")) { MarkdownStore.shared.insertTableOfContents(levels: levels) }
    }
}

extension HeadingParser.Format {
    /// コピーメニューに出す名前
    var title: String {
        switch self {
        case .markdown: return L("Markdown（# 見出し）")
        case .markdownSpaced: return L("Markdown（レベルが変わるところに空行）")
        case .tree: return L("ツリー（└ 見出し）")
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
