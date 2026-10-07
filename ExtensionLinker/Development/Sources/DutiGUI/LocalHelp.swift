import AppKit

// Generated from Shared/Help; the body is bundled per language as Localizations/<lang>.lproj/Help.txt.
@MainActor
final class LocalHelp: NSObject {
    static let shared = LocalHelp()
    private var window: NSWindow?
    static let title = "ExtensionLinker"
    /// Help body in the UI language (<lang>.lproj/Help.txt), chosen by the same rule as Localizable.strings.
    /// Unsupported languages resolve to the development region (en); en is also the explicit fallback.
    static var content: String {
        let url = Bundle.main.url(forResource: "Help", withExtension: "txt")
            ?? Bundle.main.url(forResource: "Help", withExtension: "txt", subdirectory: nil, localization: "en")
        let text = url.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        return (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    func install() {
        let main = NSApp.mainMenu ?? NSMenu()
        let help = NSApp.helpMenu ?? NSMenu(title: L("ヘルプ"))
        if !main.items.contains(where: { $0.submenu === help }) {
            let root = NSMenuItem(); root.submenu = help; main.addItem(root)
        }
        if !help.items.contains(where: { $0.target === self }) {
            let item = help.addItem(withTitle: L("%@ヘルプ", Self.title), action: #selector(show), keyEquivalent: "?")
            item.target = self
        }
        HelpLinks.addNoteItem(to: help)
        NSApp.mainMenu = main
        NSApp.helpMenu = help
    }
    @objc func show() {
        if window == nil {
            window = HelpDocument.makeWindow(windowTitle: L("%@ヘルプ", Self.title), text: Self.content, heading: Self.title)
        }
        NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
    }
}
