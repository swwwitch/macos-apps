import AppKit

// Help text lives in Localizations/<lang>.lproj/Help.txt (ja, en, zh-Hans, ko), rendered by HelpDocument.
@MainActor
final class LocalHelp: NSObject {
    static let shared = LocalHelp()
    private var window: NSWindow?
    static let title = "PodiumFlight"
    /// Help body from <lang>.lproj/Help.txt, chosen like the UI strings (Bundle.main.preferredLocalizations).
    /// Unsupported languages resolve to the development region (en); English is the last resort.
    static var content: String {
        let url = Bundle.main.url(forResource: "Help", withExtension: "txt")
            ?? Bundle.main.url(forResource: "Help", withExtension: "txt", subdirectory: nil, localization: "en")
        if let url, let text = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "Help is not available. Reinstall the app."
    }
    func install() {
        let main = NSApp.mainMenu ?? NSMenu()
        let help = NSApp.helpMenu ?? NSMenu(title: L("ヘルプ"))
        if !main.items.contains(where: { $0.submenu === help }) {
            let root = NSMenuItem(); root.submenu = help; main.addItem(root)
        }
        if !help.items.contains(where: { $0.target === self }) {
            let item = help.addItem(withTitle: L(Self.title + "ヘルプ"), action: #selector(show), keyEquivalent: "?")
            item.target = self
        }
        HelpLinks.addNoteItem(to: help)
        NSApp.mainMenu = main
        NSApp.helpMenu = help
    }
    @objc func show() {
        if window == nil {
            window = HelpDocument.makeWindow(windowTitle: L(Self.title + "ヘルプ"), text: Self.content, heading: Self.title)
        }
        NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
    }
}
