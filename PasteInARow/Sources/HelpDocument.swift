import AppKit
import SwiftUI

// Canonical source: Shared/AppStandards/HelpDocument.swift (copied into apps by sync-surface.py).
// Renders the bundled help text with a readable hierarchy. Markup (one item per line):
//   # Title        ## Section        ### Subsection
//   - item / ・item / • item           bulleted list (hanging indent)
//   1. item                            numbered list (hanging indent)
//   **bold** inside any line           emphasis (e.g. a key name or a button name)
// Everything else is body text. Blank lines only separate paragraphs.
enum HelpDocument {
    static func attributed(_ text: String, title: String? = nil) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        if let title { lines.insert("# " + title, at: 0) }
        var previousWasHeading = true
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 4
            paragraph.lineBreakStrategy = .standard
            var font = NSFont.systemFont(ofSize: 14)
            var color = NSColor.labelColor
            var body = line
            if line.hasPrefix("### ") {
                body = String(line.dropFirst(4))
                font = .systemFont(ofSize: 15, weight: .semibold)
                paragraph.paragraphSpacingBefore = previousWasHeading ? 4 : 12
                paragraph.paragraphSpacing = 4
                previousWasHeading = true
            } else if line.hasPrefix("## ") {
                body = String(line.dropFirst(3))
                font = .systemFont(ofSize: 19, weight: .bold)
                paragraph.paragraphSpacingBefore = result.length == 0 ? 0 : 22
                paragraph.paragraphSpacing = 8
                previousWasHeading = true
            } else if line.hasPrefix("# ") {
                body = String(line.dropFirst(2))
                font = .systemFont(ofSize: 26, weight: .bold)
                paragraph.paragraphSpacing = 14
                previousWasHeading = true
            } else if let item = listItem(line) {
                body = item.marker + "\t" + item.text
                paragraph.headIndent = 22
                paragraph.firstLineHeadIndent = 4
                paragraph.tabStops = [NSTextTab(textAlignment: .left, location: 22)]
                paragraph.paragraphSpacing = 4
                previousWasHeading = false
            } else {
                paragraph.paragraphSpacing = 9
                previousWasHeading = false
            }
            if font.pointSize == 14 && body.hasPrefix("※") { color = .secondaryLabelColor }
            result.append(styled(body + "\n", font: font, color: color, paragraph: paragraph))
        }
        return result
    }

    private static func listItem(_ line: String) -> (marker: String, text: String)? {
        for prefix in ["- ", "・", "• ", "•"] where line.hasPrefix(prefix) {
            return ("•", String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces))
        }
        // "1. text" / "1．text" / "1) text"
        let digits = line.prefix { $0.isASCII && $0.isNumber }
        if !digits.isEmpty, digits.count <= 2 {
            let rest = line.dropFirst(digits.count)
            for separator in [". ", "．", ") "] where rest.hasPrefix(separator) {
                return (digits + ".", String(rest.dropFirst(separator.count)).trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }

    /// Applies **bold** spans within one paragraph.
    private static func styled(_ text: String, font: NSFont, color: NSColor, paragraph: NSParagraphStyle) -> NSAttributedString {
        let base: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        let parts = text.components(separatedBy: "**")
        guard parts.count >= 3 else { return NSAttributedString(string: text, attributes: base) }
        let output = NSMutableAttributedString()
        let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        for (index, part) in parts.enumerated() {
            var attributes = base
            if index % 2 == 1 { attributes[.font] = bold }
            output.append(NSAttributedString(string: part, attributes: attributes))
        }
        return output
    }

    /// A read-only, selectable, scrolling help view.
    @MainActor static func makeScrollView(_ text: String, title: String? = nil) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        guard let view = scroll.documentView as? NSTextView else { return scroll }
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = true
        view.backgroundColor = .textBackgroundColor
        view.textContainerInset = NSSize(width: 28, height: 24)
        view.textStorage?.setAttributedString(attributed(text, title: title))
        view.setAccessibilityLabel(title ?? "Help")
        return scroll
    }

    /// A help window. Callers keep the returned window and reuse it.
    @MainActor static func makeWindow(windowTitle: String, text: String, heading: String? = nil) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 600), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = windowTitle
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 320)
        window.contentView = makeScrollView(text, title: heading)
        window.center()
        return window
    }
}

/// SwiftUI wrapper for apps whose help lives in a SwiftUI hierarchy.
struct HelpTextView: NSViewRepresentable {
    let text: String
    var title: String?
    func makeNSView(context: Context) -> NSScrollView { HelpDocument.makeScrollView(text, title: title) }
    func updateNSView(_ view: NSScrollView, context: Context) {}
}

/// Help menu link to the app's note article (Info.plist key SWNoteArticleURL; falls back to the support magazine).
@MainActor
final class HelpLinks: NSObject {
    static let shared = HelpLinks()
    static let supportMagazine = "https://note.com/swwwitch/m/m057948d2fbeb"
    static var noteURL: URL {
        let value = Bundle.main.object(forInfoDictionaryKey: "SWNoteArticleURL") as? String
        return URL(string: value ?? supportMagazine) ?? URL(string: supportMagazine)!
    }
    static var noteTitle: String { StartupWindow.text("note記事を開く", "Open the note Article", "打开 note 文章", "note 글 열기") }
    /// Appends a separator and "note記事を開く" unless the menu already has it.
    static func addNoteItem(to menu: NSMenu) {
        guard !menu.items.contains(where: { $0.identifier?.rawValue == "shared.help.note" }) else { return }
        if !menu.items.isEmpty { menu.addItem(.separator()) }
        let item = NSMenuItem(title: noteTitle, action: #selector(openNote), keyEquivalent: "")
        item.target = shared
        item.identifier = .init("shared.help.note")
        item.toolTip = noteURL.absoluteString
        menu.addItem(item)
    }
    @objc static func openNote() { NSWorkspace.shared.open(noteURL) }
    @objc func openNote() { Self.openNote() }
}
