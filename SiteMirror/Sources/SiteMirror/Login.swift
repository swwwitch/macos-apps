import AppKit
import WebKit

/// 取り込みに渡すログイン情報（Cookie と Basic 認証）
struct LoginSession: @unchecked Sendable {
    let cookies: [HTTPCookie]
    let credential: URLCredential?
}

/// ログインが必要なサイトのための、アプリ内のブラウザーと、そこで得たログイン情報
/// Cookie はアプリ専用の WebKit の保存場所（~/Library/WebKit/<Bundle ID>）に残り、次に起動しても使える。
/// Basic 認証の名前とパスワードは起動している間だけ持つ
@MainActor
final class Login: NSObject, ObservableObject, WKNavigationDelegate, NSWindowDelegate {
    static let shared = Login()

    /// ログイン情報があるホスト（www. を除いたもの）。画面の表示に使う
    @Published private(set) var hosts = Set<String>()
    private var credentials: [String: URLCredential] = [:]
    private var window: NSWindow?
    private var webView: WKWebView?
    private let address = NSTextField(labelWithString: "")

    private static func siteKey(_ host: String) -> String {
        let lower = host.lowercased()
        return lower.hasPrefix("www.") ? String(lower.dropFirst(4)) : lower
    }

    /// そのサイト（サブドメインを含む）に送る Cookie と認証
    func session(for url: URL) async -> LoginSession {
        let key = Login.siteKey(url.host ?? "")
        let all = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        return LoginSession(cookies: all.filter { Login.matches($0.domain, key) }, credential: credentials[key])
    }

    /// Cookie の domain（先頭の . は任意）がサイトか、その親・子のドメインか
    private static func matches(_ domain: String, _ key: String) -> Bool {
        let cookie = siteKey(domain.hasPrefix(".") ? String(domain.dropFirst()) : domain)
        return cookie == key || key.hasSuffix("." + cookie) || cookie.hasSuffix("." + key)
    }

    func isLoggedIn(_ url: URL?) -> Bool {
        guard let host = url?.host else { return false }
        return hosts.contains(Login.siteKey(host))
    }

    /// Cookie の有無を読み直す
    func refresh() {
        Task {
            let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
            var found = Set(credentials.keys)
            for cookie in cookies {
                let domain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
                found.insert(Login.siteKey(domain))
            }
            hosts = found
        }
    }

    /// アプリ内のブラウザーで開始 URL を開く。ログインしたら「完了」で閉じる
    func show(_ url: URL) {
        if window == nil {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .default()
            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = self
            webView.allowsBackForwardNavigationGestures = true
            self.webView = webView

            let note = NSTextField(wrappingLabelWithString: L("このウインドウでサイトにログインしてから「完了」を押します。ログインの状態（Cookie）を取り込みに使います。"))
            note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            note.textColor = .secondaryLabelColor
            address.lineBreakMode = .byTruncatingMiddle
            address.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            address.textColor = .secondaryLabelColor
            address.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            let back = NSButton(image: NSImage(systemSymbolName: "chevron.left", accessibilityDescription: L("戻る"))!, target: webView, action: #selector(WKWebView.goBack(_:)))
            back.bezelStyle = .texturedRounded
            let clear = NSButton(title: L("ログイン情報を消去…"), target: self, action: #selector(clearAll))
            let done = NSButton(title: L("完了"), target: self, action: #selector(finish))
            done.keyEquivalent = "\r"
            let bar = NSStackView(views: [back, address, clear, done])
            bar.spacing = 8
            let stack = NSStackView(views: [note, bar, webView])
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 8
            stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            for view in [note, bar, webView] as [NSView] {
                view.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 12).isActive = true
                view.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -12).isActive = true
            }
            webView.setContentHuggingPriority(.defaultLow, for: .vertical)

            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 760),
                                  styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.title = L("ログイン")
            window.isReleasedWhenClosed = false
            window.contentView = stack
            window.contentMinSize = NSSize(width: 640, height: 480)
            window.delegate = self
            window.center()
            self.window = window
        }
        webView?.load(URLRequest(url: url))
        address.stringValue = url.absoluteString
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func finish() { window?.performClose(nil) }

    func windowWillClose(_ notification: Notification) { refresh() }

    /// すべてのサイトの Cookie などを消し、Basic 認証の名前とパスワードも忘れる
    @objc private func clearAll() {
        let alert = NSAlert()
        alert.messageText = L("ログイン情報を消去しますか？")
        alert.informativeText = L("このアプリ内のブラウザーに残っている、すべてのサイトのCookieなどを消去します。")
        alert.addButton(withTitle: L("消去"))
        let cancel = alert.addButton(withTitle: L("キャンセル"))
        cancel.keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        credentials = [:]
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { [weak self] in
            MainActor.assumeIsolated {
                self?.refresh()
                self?.webView?.reload()
            }
        }
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        address.stringValue = webView.url?.absoluteString ?? ""
        refresh()
    }

    /// Basic・Digest 認証は名前とパスワードを尋ね、取り込みでも使う
    func webView(_ webView: WKWebView, respondTo challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let space = challenge.protectionSpace
        guard [NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest].contains(space.authenticationMethod) else {
            return (.performDefaultHandling, nil)
        }
        let alert = NSAlert()
        alert.messageText = L("%@ にログイン", space.host)
        alert.informativeText = space.realm ?? ""
        let user = NSTextField(frame: NSRect(x: 0, y: 30, width: 260, height: 24))
        user.placeholderString = L("名前")
        let password = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        password.placeholderString = L("パスワード")
        let fields = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 54))
        fields.addSubview(user)
        fields.addSubview(password)
        alert.accessoryView = fields
        alert.window.initialFirstResponder = user
        alert.addButton(withTitle: L("ログイン"))
        let cancel = alert.addButton(withTitle: L("キャンセル"))
        cancel.keyEquivalent = "\u{1b}"
        guard alert.runModal() == .alertFirstButtonReturn else { return (.cancelAuthenticationChallenge, nil) }
        let credential = URLCredential(user: user.stringValue, password: password.stringValue, persistence: .forSession)
        credentials[Login.siteKey(space.host)] = credential
        refresh()
        return (.useCredential, credential)
    }
}
