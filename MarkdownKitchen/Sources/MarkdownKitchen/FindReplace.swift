import AppKit
import SwiftUI

/// 原稿の検索・置換。macOS標準の検索バーは欄の大きさを変えられないため自前で持つ。原稿（ウインドウ）ごとに1つ
@MainActor
final class FindReplace: ObservableObject {
    /// メニュー・キーの操作対象のウインドウの検索・置換
    static var shared: FindReplace { MarkdownStore.shared.find }
    private unowned let store: MarkdownStore
    init(store: MarkdownStore) { self.store = store }

    @Published var isVisible = false
    @Published var query = "" { didSet { if query != oldValue { refresh() } } }
    @Published var replacement = ""
    @Published var caseSensitive = false { didSet { if caseSensitive != oldValue { refresh() } } }
    /// 正規表現で探す。置換では $1 などのグループを使える
    @Published var useRegex = false { didSet { if useRegex != oldValue { refresh() } } }
    /// 正規表現の書き方が正しくない
    @Published private(set) var invalidPattern = false
    private var regex: NSRegularExpression?
    private var results: [NSTextCheckingResult] = []
    @Published private(set) var matches: [NSRange] = []
    /// いま選んでいる一致（matches の番号）
    @Published private(set) var current: Int?
    /// 検索欄へフォーカスを移す合図
    @Published private(set) var focusRequest = 0

    private var editor: NSTextView? { store.editor }
    private static let highlight = NSColor.systemYellow.withAlphaComponent(0.4)

    // MARK: - Commands

    /// バーを開いて検索欄へ。1行の中で文字を選んでいれば、それを検索する
    func show() {
        store.bringWindowForward()
        if let editor {
            let selected = (editor.string as NSString).substring(with: editor.selectedRange())
            if !selected.isEmpty, !selected.contains("\n") { query = selected }
        }
        isVisible = true
        refresh()
        focusRequest += 1
    }

    func close() {
        isVisible = false
        clearHighlights()
        if let editor { editor.window?.makeFirstResponder(editor) }
    }

    /// 検索欄の末尾に正規表現の記号を足し、正規表現をオンにする
    func insertSearchToken(_ token: String) {
        query += token
        useRegex = true
        focusRequest += 1
    }

    /// 選んでいる文字を検索語にする（バーは開く）
    func useSelection() {
        guard let editor else { return }
        let selected = (editor.string as NSString).substring(with: editor.selectedRange())
        guard !selected.isEmpty else { NSSound.beep(); return }
        query = selected
        if !isVisible { isVisible = true }
        refresh()
    }

    func jumpToSelection() {
        guard let editor else { return }
        editor.scrollRangeToVisible(editor.selectedRange())
        editor.showFindIndicator(for: editor.selectedRange())
    }

    /// 次（backward なら前）の一致を選ぶ。末尾まで行けば先頭へ戻る
    func findNext(backward: Bool = false) {
        if !isVisible, !query.isEmpty { isVisible = true }
        refresh()
        guard let editor, !matches.isEmpty else { NSSound.beep(); return }
        let selection = editor.selectedRange()
        let index: Int
        if backward {
            index = matches.lastIndex { $0.location < selection.location } ?? matches.count - 1
        } else {
            index = matches.firstIndex { $0.location >= NSMaxRange(selection) && $0 != selection }
                ?? matches.firstIndex { $0.location > selection.location } ?? 0
        }
        select(index)
    }

    /// 選んでいる一致を置き換えて次へ。一致を選んでいなければ次を探すだけ
    func replaceCurrent() {
        guard let editor else { return }
        refresh()
        let selection = editor.selectedRange()
        guard let index = matches.firstIndex(of: selection) else { findNext(); return }
        let text = replacementText(for: index, in: editor.string)
        store.replaceForFind(selection, with: text, actionName: L("置き換え"))
        editor.setSelectedRange(NSRange(location: selection.location + (text as NSString).length, length: 0))
        refresh()
        if !matches.isEmpty { findNext() }
    }

    /// すべての一致を置き換える（1回の取り消しで戻る）
    func replaceAll() {
        guard let editor else { return }
        refresh()
        guard !matches.isEmpty else { NSSound.beep(); return }
        let count = matches.count
        let string = NSMutableString(string: editor.string)
        let original = editor.string
        for index in matches.indices.reversed() {
            string.replaceCharacters(in: matches[index], with: replacementText(for: index, in: original))
        }
        let first = matches[0].location, last = NSMaxRange(matches[matches.count - 1])
        // Replace only the span that changes, so the scroll position stays put.
        let span = NSRange(location: first, length: last - first)
        let delta = string.length - (editor.string as NSString).length
        let newSpan = string.substring(with: NSRange(location: first, length: span.length + delta))
        store.replaceForFind(span, with: newSpan, actionName: L("すべて置き換え"))
        refresh()
        store.message = L("%@件を置き換えました", String(count))
    }

    // MARK: - Matches

    /// 一致を数え直し、原稿に色を付ける（原稿が変わったときにも呼ぶ）
    func refresh() {
        clearHighlights()
        invalidPattern = false
        guard isVisible, let editor, !query.isEmpty else { matches = []; results = []; current = nil; return }
        let string = editor.string as NSString
        var found: [NSRange] = []
        if useRegex {
            regex = try? NSRegularExpression(pattern: query, options: caseSensitive ? [.anchorsMatchLines] : [.caseInsensitive, .anchorsMatchLines])
            guard let regex else { invalidPattern = true; matches = []; results = []; current = nil; return }
            // Empty matches (such as "^" alone) are not counted.
            results = regex.matches(in: editor.string, range: NSRange(location: 0, length: string.length)).filter { $0.range.length > 0 }
            found = results.map(\.range)
        } else {
            regex = nil
            results = []
            var location = 0
            let options: NSString.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
            while location < string.length {
                let range = string.range(of: query, options: options, range: NSRange(location: location, length: string.length - location))
                guard range.location != NSNotFound, range.length > 0 else { break }
                found.append(range)
                location = NSMaxRange(range)
            }
        }
        matches = found
        current = found.firstIndex(of: editor.selectedRange())
        if let layout = editor.layoutManager {
            for range in found { layout.addTemporaryAttribute(.backgroundColor, value: Self.highlight, forCharacterRange: range) }
        }
    }

    /// 置き換える文字。正規表現なら $1 などを展開する
    private func replacementText(for index: Int, in string: String) -> String {
        guard useRegex, let regex, results.indices.contains(index) else { return replacement }
        return regex.replacementString(for: results[index], in: string, offset: 0, template: Self.template(replacement))
    }

    /// 置換欄の \1〜\9 を $1〜$9 と同じに扱う（\\1 は文字の「\1」）
    nonisolated static func template(_ replacement: String) -> String {
        replacement.replacingOccurrences(of: #"(?<!\\)((?:\\\\)*)\\([1-9])"#, with: "$1\\$$2", options: .regularExpression)
    }

    private func select(_ index: Int) {
        guard let editor, matches.indices.contains(index) else { return }
        let range = matches[index]
        editor.setSelectedRange(range)
        editor.scrollRangeToVisible(range)
        editor.showFindIndicator(for: range)
        current = index
    }

    private func clearHighlights() {
        guard let editor, let layout = editor.layoutManager else { return }
        layout.removeTemporaryAttribute(.backgroundColor, forCharacterRange: NSRange(location: 0, length: (editor.string as NSString).length))
    }
}

/// 原稿ペインの上の検索・置換バー
struct FindReplaceBar: View {
    @ObservedObject var find: FindReplace
    @FocusState private var queryFocused: Bool

    var body: some View {
        // The two fields share a grid column, so they are always the same width.
        Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                HStack(spacing: 4) {
                    TextField(L("検索"), text: $find.query)
                        .textFieldStyle(.roundedBorder)
                        .focused($queryFocused)
                        .onSubmit { find.findNext() }
                        .accessibilityLabel(L("検索"))
                    // Helpers (like InDesign's @ menu): regex tokens, so choosing one turns on (.*).
                    helperMenu(L("検索の特殊文字")) {
                        Button(L("改行")) { find.insertSearchToken(#"\n"#) }
                        Button(L("タブ")) { find.insertSearchToken(#"\t"#) }
                        Button(L("空行")) { find.insertSearchToken(#"^[ \t]*\n"#) }
                    }
                }
                .frame(maxWidth: .infinity)
                HStack(spacing: 6) {
                Text(status)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle((find.matches.isEmpty && !find.query.isEmpty) || find.invalidPattern ? .orange : .secondary)
                    .frame(minWidth: 56, alignment: .trailing)
                ControlGroup {
                    Button { find.findNext(backward: true) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel(L("前を検索"))
                    Button { find.findNext() } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel(L("次を検索"))
                }
                .fixedSize()
                .disabled(find.matches.isEmpty)
                // Icon toggles (lit when on) with the full name as a tooltip.
                Toggle(isOn: $find.caseSensitive) { Text("Aa").font(.body.weight(.semibold)) }
                    .toggleStyle(.button)
                    .help(L("大文字と小文字を区別"))
                    .accessibilityLabel(L("大文字と小文字を区別"))
                Toggle(isOn: $find.useRegex) { Text("(.*)").font(.system(.body, design: .monospaced).weight(.semibold)) }
                    .toggleStyle(.button)
                    .help(L("正規表現で探します。置換では $1 や \\1 で一致したグループを使えます"))
                    .accessibilityLabel(L("正規表現"))
                }
                .fixedSize()
            }
            GridRow {
                HStack(spacing: 4) {
                    TextField(L("置換"), text: $find.replacement)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { find.replaceCurrent() }
                        .accessibilityLabel(L("置換"))
                    // Group references work only with regular expressions.
                    helperMenu(find.useRegex ? L("置換の特殊文字") : L("置換の特殊文字（正規表現のときに使えます）")) {
                        Button(L("見つかったテキスト")) { find.replacement += "$0" }
                        Divider()
                        ForEach(1...5, id: \.self) { number in
                            Button(L("検索結果%@", String(number))) { find.replacement += "$\(number)" }
                        }
                    }
                    .disabled(!find.useRegex)
                }
                .frame(maxWidth: .infinity)
                HStack(spacing: 6) {
                Button(L("置き換え")) { find.replaceCurrent() }
                    .disabled(find.matches.isEmpty)
                    .help(L("選んでいる1か所を置き換えて、次を探します"))
                Button(L("すべて置き換え")) { find.replaceAll() }
                    .disabled(find.matches.isEmpty)
                Button(L("完了")) { find.close() }
                }
                .fixedSize()
            }
        }
        // A size larger than the system find bar.
        .controlSize(.large)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.bar)
        .onExitCommand { find.close() }
        .onChange(of: find.focusRequest) { _, _ in queryFocused = true }
        .onAppear { queryFocused = true }
    }

    /// 欄の右の「@」メニュー
    private func helperMenu<Content: View>(_ help: String, @ViewBuilder content: () -> Content) -> some View {
        Menu { content() } label: { Image(systemName: "at") }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(help)
            .accessibilityLabel(help)
    }

    private var status: String {
        if find.query.isEmpty { return "" }
        if find.invalidPattern { return L("正規表現が正しくありません") }
        if find.matches.isEmpty { return L("見つかりません") }
        if let current = find.current { return "\(current + 1) / \(find.matches.count)" }
        return L("%@件", String(find.matches.count))
    }
}
