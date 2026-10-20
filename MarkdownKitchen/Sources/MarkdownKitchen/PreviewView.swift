import AppKit
import SwiftUI
import WebKit

/// 右ペインのプレビュー。入力のたびにページを読み直さず本文だけ差し替えて、スクロール位置を保つ
struct PreviewView: NSViewRepresentable {
    let store: MarkdownStore
    let markdown: String
    let fontSize: Double
    var margin: String = "standard"

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.setAccessibilityLabel(L("プレビュー"))
        context.coordinator.webView = webView
        context.coordinator.margin = MarkdownStore.previewMargin(margin)
        context.coordinator.update(body: MarkdownHTML.render(markdown, lineAnchors: true), fontSize: fontSize)
        let coordinator = context.coordinator
        store.onSourceScroll = { [weak coordinator] line in coordinator?.scroll(toLine: line) }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.update(body: MarkdownHTML.render(markdown, lineAnchors: true), fontSize: fontSize)
        context.coordinator.setMargin(MarkdownStore.previewMargin(margin))
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.store.onSourceScroll = nil
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        let store: MarkdownStore
        init(store: MarkdownStore) { self.store = store }
        weak var webView: WKWebView?
        private var loaded = false
        private var shownBody: String?
        private var shownSize: Double?
        private var pending: (String, Double)?

        /// 本文の余白（CSSの margin）
        var margin = MarkdownStore.previewMargin("standard")

        func setMargin(_ value: String) {
            guard value != margin else { return }
            margin = value
            if loaded { webView?.evaluateJavaScript("document.body.style.margin = '\(value)';") }
        }

        func update(body: String, fontSize: Double) {
            guard body != shownBody || fontSize != shownSize, let webView else { return }
            guard loaded else {
                if shownBody == nil {
                    shownBody = body; shownSize = fontSize
                    webView.loadHTMLString(Self.page(body: body, fontSize: fontSize), baseURL: URL(string: "https://localhost/"))
                } else {
                    pending = (body, fontSize)
                }
                return
            }
            shownBody = body; shownSize = fontSize
            let json = (try? JSONEncoder().encode([body])).flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
            webView.evaluateJavaScript("document.body.innerHTML = \(json)[0]; document.documentElement.style.fontSize = '\(fontSize)px'; mkHighlight();")
        }

        /// 原稿の行に合わせてスクロールする（目印の span の間は行数で割り振る）
        func scroll(toLine line: Double) {
            guard loaded, let webView else { return }
            let argument = line.isInfinite ? "Infinity" : String(line)
            let lines = store.text.normalizedLineBreaks.components(separatedBy: "\n").count
            webView.evaluateJavaScript("mkScrollTo(\(argument), \(lines))")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true
            webView.evaluateJavaScript("document.body.style.margin = '\(margin)';")
            if let (body, size) = pending { pending = nil; update(body: body, fontSize: size) }
        }

        /// リンクはブラウザで開き、プレビューの中では移動しない
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        /// 同梱の highlight.js（Resources/highlight）。見つからなければ色付けなし
        static let highlightScript: String = resource("highlight.min", "js")
        /// GitHub 風の配色。ダークモードでは github-dark
        static let highlightStyles: String = resource("github.min", "css")
            + "\n@media (prefers-color-scheme: dark) {\n" + resource("github-dark.min", "css") + "\n}"

        private static func resource(_ name: String, _ type: String) -> String {
            guard let url = Bundle.main.url(forResource: name, withExtension: type, subdirectory: "highlight"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
            // A literal "</script>" inside the inline script would end it early.
            return text.replacingOccurrences(of: "</script", with: "<\\/script")
        }

        static func page(body: String, fontSize: Double) -> String {
            """
            <!doctype html><html style="font-size:\(fontSize)px"><head><meta charset="utf-8">
            <style>
            :root { color-scheme: light dark; }
            body { font-family: -apple-system, "Hiragino Sans", sans-serif; font-size: 1rem; line-height: 1.7; margin: 18px 24px; color: #222; }
            h1, h2, h3, h4, h5, h6 { line-height: 1.35; margin: 1.4em 0 .5em; }
            img { max-width: 100%; height: auto; }
            a { color: #0a6ed1; }
            code { font-family: ui-monospace, Menlo, monospace; font-size: .9em; background: rgba(127,127,127,.15); padding: .1em .3em; border-radius: 3px; }
            pre { background: rgba(127,127,127,.12); padding: .8em 1em; border-radius: 6px; overflow-x: auto; }
            pre code { background: none; padding: 0; }
            blockquote { margin: 1em 0; padding: 0 1em; border-left: 3px solid rgba(127,127,127,.4); color: #666; }
            hr { border: none; border-top: 1px solid rgba(127,127,127,.35); }
            @media (prefers-color-scheme: dark) { body { color: #ddd; } a { color: #5ab0ff; } blockquote { color: #aaa; } }
            .hljs { background: transparent; }
            table { border-collapse: collapse; margin: 1em 0; }
            th, td { border: 1px solid rgba(127,127,127,.45); padding: .35em .7em; vertical-align: top; }
            th { background: rgba(127,127,127,.12); }
            \(Self.highlightStyles)
            </style>
            <script>\(Self.highlightScript)</script>
            <script>
            // Code blocks get syntax colors (highlight.js, bundled; blocks without a language are detected).
            function mkHighlight() {
              if (!window.hljs) return;
              hljs.configure({ ignoreUnescapedHTML: true });
              document.querySelectorAll('pre code:not([data-highlighted])').forEach(function (block) { hljs.highlightElement(block); });
            }
            document.addEventListener('DOMContentLoaded', mkHighlight);
            function mkScrollTo(line, total) {
              var max = document.documentElement.scrollHeight - window.innerHeight;
              if (line === Infinity) { window.scrollTo(0, max); return; }
              var marks = document.querySelectorAll('span[data-line]');
              function top(m) { var e = m.nextElementSibling || m; return e.getBoundingClientRect().top + window.scrollY; }
              var prev = null, next = null;
              for (var i = 0; i < marks.length; i++) {
                if (+marks[i].dataset.line <= line) prev = marks[i]; else { next = marks[i]; break; }
              }
              var y0 = prev ? top(prev) : 0, l0 = prev ? +prev.dataset.line : 0;
              var y1 = next ? top(next) : document.documentElement.scrollHeight, l1 = next ? +next.dataset.line : total;
              var y = l1 > l0 ? y0 + (y1 - y0) * (line - l0) / (l1 - l0) : y0;
              window.scrollTo(0, Math.max(0, Math.min(max, y - 12)));
            }
            </script></head><body>\(body)</body></html>
            """
        }
    }
}
