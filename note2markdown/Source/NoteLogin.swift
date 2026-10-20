import AppKit
import WebKit

/// Signing in to note inside the app (option, off by default). The session lives in the app's own WebKit store;
/// when the option is on, its note.com cookies are sent with the API request so bought or own paid articles load in full.
@MainActor
final class NoteLogin: NSObject, ObservableObject, WKNavigationDelegate, NSWindowDelegate {
    static let shared = NoteLogin()
    static let loginURL = URL(string: "https://note.com/login")!

    @Published private(set) var isSignedIn = false
    private var window: NSWindow?
    private var store: WKHTTPCookieStore { WKWebsiteDataStore.default().httpCookieStore }

    private static func isNoteCookie(_ cookie: HTTPCookie) -> Bool {
        let domain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
        return domain == "note.com" || domain.hasSuffix(".note.com")
    }

    private func noteCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            store.getAllCookies { continuation.resume(returning: $0.filter(Self.isNoteCookie)) }
        }
    }

    /// The Cookie header for note.com, or nil when not signed in.
    func cookieHeader() async -> String? {
        let cookies = await noteCookies().filter { $0.expiresDate.map { $0 > Date() } ?? true }
        guard cookies.contains(where: { $0.name.lowercased().contains("session") }) else { return nil }
        return HTTPCookie.requestHeaderFields(with: cookies)["Cookie"]
    }

    func refresh() {
        Task { isSignedIn = await cookieHeader() != nil }
    }

    func showWindow() {
        if window == nil {
            let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 520, height: 680))
            webView.navigationDelegate = self
            webView.load(URLRequest(url: Self.loginURL))
            let w = NSWindow(contentRect: webView.frame, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            w.title = L("loginWindowTitle"); w.isReleasedWhenClosed = false; w.delegate = self
            w.contentView = webView; w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
    }

    /// Closes the window once note leaves the login page with a session.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url, url.host?.hasSuffix("note.com") == true, !url.path.hasPrefix("/login") else { return }
        Task {
            let signedIn = await cookieHeader() != nil
            isSignedIn = signedIn
            if signedIn { window?.close() }
        }
    }

    func windowWillClose(_ notification: Notification) {
        refresh()
        // A fresh page next time (the web view keeps no state worth keeping).
        DispatchQueue.main.async { self.window = nil }
    }

    func signOut() {
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            let note = records.filter { $0.displayName == "note.com" || $0.displayName.hasSuffix(".note.com") }
            WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: note) {
                MainActor.assumeIsolated { self.refresh() }
            }
        }
    }
}
