import AppKit
import SwiftUI

/// 左ペインの原稿エディタ。プレーンテキスト・等幅・自動置換なし
struct SourceEditor: NSViewRepresentable {
    @ObservedObject var store: MarkdownStore
    var boldHeadings: Bool
    var fontSize: Double

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        let textView = DroppingTextView()
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        // Find and replace uses FindReplaceBar (the system find bar cannot be enlarged).
        textView.usesFindBar = false
        textView.font = Self.regularFont(fontSize)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 6, height: 8)
        // Markdown must stay exactly as typed.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        // Wrap at the pane width.
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.string = store.text
        context.coordinator.boldHeadings = boldHeadings
        context.coordinator.fontSize = fontSize
        Self.styleHeadings(textView, headings: store.allHeadings, bold: boldHeadings, size: fontSize)
        textView.delegate = context.coordinator
        textView.onDropFile = { url in store.load(url) }
        textView.setAccessibilityLabel(L("原稿"))
        scroll.documentView = textView
        store.editor = textView
        // Report the top visible line so the preview can follow.
        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.didScroll(_:)),
                                               name: NSView.boundsDidChangeNotification, object: scroll.contentView)
        context.coordinator.textView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        // Only when the text changed elsewhere (e.g. restored before the view existed).
        let settingChanged = context.coordinator.boldHeadings != boldHeadings || context.coordinator.fontSize != fontSize
        context.coordinator.boldHeadings = boldHeadings
        context.coordinator.fontSize = fontSize
        if textView.string != store.text {
            textView.string = store.text
            Self.styleHeadings(textView, headings: store.allHeadings, bold: boldHeadings, size: fontSize)
        } else if settingChanged {
            Self.styleHeadings(textView, headings: store.allHeadings, bold: boldHeadings, size: fontSize)
        }
    }

    static func regularFont(_ size: Double) -> NSFont { .monospacedSystemFont(ofSize: size, weight: .regular) }
    static func headingFont(_ size: Double) -> NSFont { .monospacedSystemFont(ofSize: size, weight: .bold) }

    /// 見出しの行だけ太字にする（boldがfalseなら全体を標準の太さに戻す）。属性の変更なのでUndoの履歴には載らない
    @MainActor static func styleHeadings(_ textView: NSTextView, headings: [Heading], bold: Bool, size: Double) {
        let regularFont = regularFont(size), headingFont = headingFont(size)
        guard let storage = textView.textStorage else { return }
        let length = storage.length
        storage.beginEditing()
        storage.addAttribute(.font, value: regularFont, range: NSRange(location: 0, length: length))
        for heading in bold ? headings : [] {
            for range in [heading.range, heading.underline].compactMap({ $0 }) where NSMaxRange(range) <= length {
                storage.addAttribute(.font, value: headingFont, range: range)
            }
        }
        storage.endEditing()
        // Typing continues in the regular weight unless the caret is inside a heading line.
        textView.typingAttributes[.font] = regularFont
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let store: MarkdownStore
        weak var textView: NSTextView?
        var boldHeadings = true
        var fontSize = MarkdownStore.defaultFontSize
        init(store: MarkdownStore) { self.store = store }
        @objc func didScroll(_ notification: Notification) {
            guard let textView, let report = store.onSourceScroll else { return }
            report(Self.topLine(of: textView))
        }

        /// いちばん上に見えている行（0始まり、行の途中は小数）。末尾までスクロールしていれば .infinity
        static func topLine(of textView: NSTextView) -> Double {
            let visible = textView.visibleRect
            if visible.minY <= 1 { return 0 }
            if visible.maxY >= textView.bounds.height - 1 { return .infinity }
            guard let layout = textView.layoutManager, let container = textView.textContainer else { return 0 }
            let point = NSPoint(x: 0, y: visible.minY - textView.textContainerInset.height)
            let glyph = layout.glyphIndex(for: point, in: container)
            let character = layout.characterIndexForGlyph(at: glyph)
            let string = textView.string as NSString
            let paragraph = string.paragraphRange(for: NSRange(location: min(character, string.length), length: 0))
            let line = string.substring(to: paragraph.location).utf16.reduce(0) { $1 == 10 ? $0 + 1 : $0 }
            let glyphs = layout.glyphRange(forCharacterRange: paragraph, actualCharacterRange: nil)
            let rect = layout.boundingRect(forGlyphRange: glyphs, in: container)
            let fraction = rect.height > 0 ? min(max((point.y - rect.minY) / rect.height, 0), 1) : 0
            return Double(line) + fraction
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            store.text = textView.string
            SourceEditor.styleHeadings(textView, headings: store.allHeadings, bold: boldHeadings, size: fontSize)
        }
    }
}

/// Markdown・テキストファイルのドロップは、パスの挿入ではなく読み込みにする
final class DroppingTextView: NSTextView {
    var onDropFile: ((URL) -> Void)?

    private func fileURL(_ sender: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL])?.first
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileURL(sender) != nil ? .copy : super.draggingEntered(sender)
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileURL(sender) != nil ? .copy : super.draggingUpdated(sender)
    }
    // Return continues lists and quotes; Tab and ⇧Tab indent list lines (as in MacDown).
    override func insertNewline(_ sender: Any?) {
        guard let edit = MarkdownFormat.continueList(string, selection: selectedRange()) else { return super.insertNewline(sender) }
        apply(edit)
    }
    override func insertTab(_ sender: Any?) {
        guard let edit = MarkdownFormat.tab(string, selection: selectedRange(), outdent: false) else { return super.insertTab(sender) }
        apply(edit)
    }
    override func insertBacktab(_ sender: Any?) {
        guard let edit = MarkdownFormat.tab(string, selection: selectedRange(), outdent: true) else { return super.insertBacktab(sender) }
        apply(edit)
    }
    /// insertText(_:replacementRange:) は Undo に載り、入力の続きとしてまとまる
    private func apply(_ edit: TextEdit) {
        insertText(edit.replacement, replacementRange: edit.range)
        setSelectedRange(edit.selection)
        scrollRangeToVisible(edit.selection)
    }

    /// 右クリックメニューの先頭に書式の項目を並べる
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        let items = FormatAction.contextMenuItems() + [.separator()]
        for (index, item) in items.enumerated() { menu.insertItem(item, at: index) }
        return menu
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let url = fileURL(sender) {
            onDropFile?(url)
            return true
        }
        return super.performDragOperation(sender)
    }
}
