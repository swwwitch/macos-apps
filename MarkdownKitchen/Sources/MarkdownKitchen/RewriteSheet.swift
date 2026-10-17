import SwiftUI

/// 書き直す範囲（シートを開いた時点の選択）
struct RewriteRequest: Identifiable {
    let id = UUID()
    let range: NSRange
    let original: String
}

/// 「文字数を指定して書き直す...」のシート：目標の文字数を入れて書き直し、元の文と見比べて置き換える
struct RewriteSheet: View {
    let request: RewriteRequest
    @Environment(\.dismiss) private var dismiss
    @AppStorage("markdownKitchen.rewriteTarget") private var target = 200
    @State private var result = ""
    @State private var attempt = 0
    @State private var task: Task<Void, Never>?
    @State private var error: String?

    private var running: Bool { task != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("文字数を指定して書き直す")).font(.headline)
            pane(L("元の文章：%@文字", String(Rewriter.count(request.original)))) {
                ScrollView { Text(request.original).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(6) }
            }
            HStack(spacing: 8) {
                Text(L("目標の文字数"))
                TextField("", value: $target, format: .number)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .onSubmit(start)
                Text(L("文字くらい"))
                Spacer()
                if running {
                    ProgressView().controlSize(.small)
                    Text(L("書き直しています（%@回目）…", String(attempt))).foregroundStyle(.secondary)
                    Button(L("中止")) { stop() }
                } else {
                    Button(result.isEmpty ? L("書き直す") : L("もう一度書き直す"), action: start)
                        .disabled(target <= 0)
                }
            }
            pane(result.isEmpty ? L("書き直した文章") : resultTitle) {
                TextEditor(text: $result).font(.body).disabled(running)
            }
            if let error {
                Text(error).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            Text(L("Mac内のApple Intelligenceのモデルで書き直します（原稿は外部に送りません）。文字数はMarkdownの記号・HTMLのタグ・改行を除いて数えます。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("キャンセル")) { stop(); dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L("置き換える")) {
                    MarkdownStore.shared.applyRewrite(request, with: result)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(running || result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 560, height: 560)
        .onDisappear { task?.cancel() }
    }

    private var resultTitle: String {
        let count = Rewriter.count(result)
        let percent = target > 0 ? Int((Double(count - target) / Double(target) * 100).rounded()) : 0
        return L("書き直した文章：%@文字（目標との差 %@%%）", String(count), (percent > 0 ? "+" : "") + String(percent))
    }

    private func pane<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.callout).foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12)))
        }
    }

    private func start() {
        guard !running, target > 0 else { return }
        error = nil
        if let reason = Rewriter.unavailableReason {
            error = reason
            return
        }
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            task = Task {
                do {
                    let text = try await Rewriter.rewrite(request.original, target: target) { attempt = $0 }
                    if !Task.isCancelled { result = text }
                } catch {
                    if !Task.isCancelled {
                        self.error = L("書き直せませんでした：%@", error.localizedDescription)
                    }
                }
                task = nil
            }
        }
        #endif
    }

    private func stop() {
        task?.cancel()
        task = nil
    }
}
