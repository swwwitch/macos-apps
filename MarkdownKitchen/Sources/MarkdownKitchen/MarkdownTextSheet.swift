import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct MarkdownTextRequest: Identifiable {
    let id = UUID()
    let source: String
}

/// The supplied converter runs entirely from a bundled file, with its original options.
struct MarkdownTextSheet: View {
    let request: MarkdownTextRequest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            MarkdownTextWebView(source: request.source)
            HStack {
                Spacer()
                Button(L("閉じる")) { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(minWidth: 700, idealWidth: 960, maxWidth: 1100, minHeight: 480, idealHeight: 720, maxHeight: 900)
    }
}

private struct MarkdownTextWebView: NSViewRepresentable {
    let source: String
    static let settingsKey = "markdownKitchen.textConversionSettings"

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "markdownText")
        let values = [source, UserDefaults.standard.string(forKey: Self.settingsKey) ?? ""]
        let json = String(data: try! JSONEncoder().encode(values), encoding: .utf8)!
        let script = "const initial = \(json); window.markdownTextSource = initial[0]; window.markdownTextSettings = initial[1];"
        configuration.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        if let url = Bundle.main.url(forResource: "markdown2text", withExtension: "html") {
            view.loadFileURL(url, allowingReadAccessTo: url)
        } else {
            view.loadHTMLString("<p>Markdown → テキスト変換のリソースが見つかりません。</p>", baseURL: nil)
        }
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {}

    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "markdownText")
        view.stopLoading()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let url = navigationAction.request.url
            decisionHandler(url?.isFileURL == true || url?.absoluteString == "about:blank" ? .allow : .cancel)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame,
                  let body = message.body as? [String: String], let value = body["value"] else { return }
            switch body["action"] {
            case "settings": UserDefaults.standard.set(value, forKey: MarkdownTextWebView.settingsKey)
            case "copy":
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            case "save":
                guard let window = message.webView?.window else { return }
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.plainText]
                panel.nameFieldStringValue = "converted.txt"
                panel.beginSheetModal(for: window) { response in
                    guard response == .OK, let url = panel.url else { return }
                    do { try value.write(to: url, atomically: true, encoding: .utf8) }
                    catch { NSAlert(error: error).beginSheetModal(for: window) }
                }
            default: break
            }
        }
    }
}
