import AppKit

// Help text lives in Localizations/<lang>.lproj/Help.txt (ja, en, zh-Hans, ko), rendered by HelpDocument.
@MainActor
final class LocalHelp: NSObject {
    static let shared = LocalHelp()
    private var window: NSWindow?
    static let title = "PrefsPreset"
    /// Help body from <lang>.lproj/Help.txt; unsupported languages resolve to the development region (en).
    static var content: String {
        let url = Bundle.main.url(forResource: "Help", withExtension: "txt")
            ?? Bundle.main.url(forResource: "Help", withExtension: "txt", subdirectory: nil, localization: "en")
        if let url, let text = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "Help is not available. Reinstall the app."
    }
    @objc func show() {
        if window == nil {
            window = HelpDocument.makeWindow(windowTitle: L(Self.title + "ヘルプ"), text: Self.content, heading: Self.title)
        }
        NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
    }
}
