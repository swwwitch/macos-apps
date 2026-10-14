import SwiftUI

/// HTMLリンクを入れる範囲（シートを開いた時点の選択）
struct HTMLLinkRequest: Identifiable {
    let id = UUID()
    let range: NSRange
    let selectedText: String
}

/// ツールの「HTMLリンク...」：リンク先とテキストを入れて <a href="…">…</a> にする
struct HTMLLinkSheet: View {
    let request: HTMLLinkRequest
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var text = ""
    @FocusState private var focus: Field?
    private enum Field { case url, text }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("HTMLリンク")).font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
                GridRow {
                    Text(L("リンク先")).gridColumnAlignment(.trailing)
                    TextField("https://", text: $url).focused($focus, equals: .url)
                }
                GridRow {
                    Text(L("テキスト"))
                    TextField(L("（空ならリンク先を使います）"), text: $text).focused($focus, equals: .text)
                }
            }
            Text(HTMLLinkSheet.tag(url: url, text: text))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
            HStack {
                Spacer()
                Button(L("キャンセル")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L("挿入")) {
                    MarkdownStore.shared.insertHTMLLink(request, tag: HTMLLinkSheet.tag(url: url, text: text))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear(perform: prefill)
    }

    /// 選択した文字をテキストに。選択がURLならリンク先に、そうでなければクリップボードのURLをリンク先に
    private func prefill() {
        let selected = request.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if HTMLLinkSheet.isURL(selected) {
            url = selected
            text = selected
            focus = .text
            return
        }
        text = request.selectedText
        if let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           HTMLLinkSheet.isURL(clip) {
            url = clip
        }
        focus = .url
    }

    static func isURL(_ string: String) -> Bool {
        string.range(of: #"^(https?://|mailto:)\S+$"#, options: .regularExpression) != nil
    }

    /// <a href="リンク先">テキスト</a>。テキストが空ならリンク先を表示する
    static func tag(url: String, text: String) -> String {
        let href = url.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "&quot;")
        let label = text.isEmpty ? href : text
        return "<a href=\"\(href)\">\(label)</a>"
    }
}
