import AppKit
import SwiftUI

/// 左ペインの原稿エディタ。プレーンテキスト・等幅・自動置換なし
struct SourceEditor: NSViewRepresentable {
    @ObservedObject var store: MarkdownStore
    var boldHeadings: Bool
    var style: String = "rich"
    var appearance: String = "auto"
    var margin: String = "standard"
    var fontName: String = ""
    var lineSpacing: Double = MarkdownStore.defaultLineSpacing

    /// 原稿欄だけの配色。nil はシステムに合わせる（系統の色はこの見た目で解決される）
    static func appearance(_ setting: String) -> NSAppearance? {
        switch setting {
        case "light": return NSAppearance(named: .aqua)
        case "dark": return NSAppearance(named: .darkAqua)
        default: return nil
        }
    }
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
        textView.font = Self.baseFont(fontSize, rich: style == "rich")
        textView.textColor = .textColor
        textView.backgroundColor = Self.editorBackground
        textView.textContainerInset = MarkdownStore.editorInset(margin)
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
        textView.onDropFile = { url in MarkdownStore.open([url], from: store) }
        textView.setAccessibilityLabel(L("原稿"))
        scroll.appearance = Self.appearance(appearance)
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
        if let textView = scroll.documentView as? NSTextView, textView.textContainerInset != MarkdownStore.editorInset(margin) {
            textView.textContainerInset = MarkdownStore.editorInset(margin)
        }
        let wanted = Self.appearance(appearance)
        if scroll.appearance?.name != wanted?.name { scroll.appearance = wanted }
        // Leave the view alone while the input method is composing; touching it drops the marked text.
        guard let textView = scroll.documentView as? NSTextView, !textView.hasMarkedText() else { return }
        // Only when the text changed elsewhere (e.g. restored before the view existed).
        let settingChanged = context.coordinator.boldHeadings != boldHeadings || context.coordinator.fontSize != fontSize
            || context.coordinator.style != style || context.coordinator.fontName != fontName
            || context.coordinator.lineSpacing != lineSpacing
        context.coordinator.lineSpacing = lineSpacing
        context.coordinator.style = style
        context.coordinator.fontName = fontName
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

    /// 原稿欄のフォント。表示メニューの「原稿のフォント…」で選んだものがあればそれ、なければ
    /// MacDown風はシステムのフォント、色分け・プレーンは等幅
    @MainActor static func baseFont(_ size: Double, rich: Bool) -> NSFont {
        if let name = UserDefaults.standard.string(forKey: MarkdownStore.editorFontKey), !name.isEmpty,
           let font = NSFont(name: name, size: size) { return font }
        return rich ? .systemFont(ofSize: size) : regularFont(size)
    }

    /// 同じフォントの太字（太字の無いフォントはそのまま）
    @MainActor static func boldVersion(_ font: NSFont, size: CGFloat? = nil) -> NSFont {
        let sized = size.map { NSFontManager.shared.convert(font, toSize: $0) } ?? font
        return NSFontManager.shared.convert(sized, toHaveTrait: .boldFontMask)
    }

    /// 原稿欄の表示："rich"（MacDown風：文字の大きさ・色）・"color"（等幅で色分け）・"plain"（等幅、飾りなし）
    static var currentStyle: String {
        let defaults = UserDefaults.standard
        if let style = defaults.string(forKey: MarkdownStore.editorStyleKey) { return style }
        // Earlier versions had an on/off switch for coloring.
        return defaults.object(forKey: MarkdownStore.colorizeKey) as? Bool == false ? "plain" : "rich"
    }

    /// 2つの見た目で色を変える（ライト／ダーク）
    private static func dynamic(_ light: NSColor, _ dark: NSColor) -> NSColor {
        NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light }
    }
    /// 原稿欄の地と文字。ダークでは真っ黒・真っ白を避けて MacDown のように少し柔らかく
    static let editorBackground = dynamic(.textBackgroundColor, NSColor(srgbRed: 0.17, green: 0.17, blue: 0.17, alpha: 1))
    static let editorText = dynamic(.textColor, NSColor(srgbRed: 0.82, green: 0.82, blue: 0.82, alpha: 1))
    private static let richHeading = dynamic(NSColor(srgbRed: 0.10, green: 0.50, blue: 0.52, alpha: 1), NSColor(srgbRed: 0.50, green: 0.80, blue: 0.80, alpha: 1))
    private static let richLink = dynamic(NSColor(srgbRed: 0.24, green: 0.48, blue: 0.24, alpha: 1), NSColor(srgbRed: 0.58, green: 0.78, blue: 0.56, alpha: 1))
    /// 見出しレベルごとの文字の大きさ（MacDown風）
    private static let headingScale: [Int: CGFloat] = [1: 1.6, 2: 1.45, 3: 1.3, 4: 1.15, 5: 1.05, 6: 1.05]

    /// 原稿の見た目。属性の変更なのでUndoの履歴には載らない
    @MainActor static func styleHeadings(_ textView: NSTextView, headings: [Heading], bold: Bool, size: Double,
                                         style: String = SourceEditor.currentStyle) {
        let rich = style == "rich", plain = style == "plain"
        let regularFont = baseFont(size, rich: rich)
        let boldFont = boldVersion(regularFont)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = UserDefaults.standard.object(forKey: MarkdownStore.lineSpacingKey) as? Double ?? MarkdownStore.defaultLineSpacing
        guard let storage = textView.textStorage else { return }
        let length = storage.length
        let whole = NSRange(location: 0, length: length)
        storage.beginEditing()
        storage.addAttribute(.font, value: regularFont, range: whole)
        storage.addAttribute(.foregroundColor, value: editorText, range: whole)
        storage.removeAttribute(.backgroundColor, range: whole)
        storage.addAttribute(.paragraphStyle, value: paragraphStyle, range: whole)
        if !plain {
            let italicFont = NSFontManager.shared.convert(regularFont, toHaveTrait: .italicFontMask)
            let codeFont = rich ? Self.regularFont(size) : regularFont
            for span in MarkdownSyntax.spans(in: storage.string, headings: headings) where NSMaxRange(span.range) <= length {
                switch span.style {
                case .heading: storage.addAttribute(.foregroundColor, value: rich ? richHeading : NSColor.systemBlue, range: span.range)
                case .markup, .rule, .comment: storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: span.range)
                case .strong: storage.addAttribute(.font, value: boldFont, range: span.range)
                case .emphasis: storage.addAttribute(.font, value: italicFont, range: span.range)
                case .link: storage.addAttribute(.foregroundColor, value: rich ? richLink : NSColor.systemTeal, range: span.range)
                case .linkTarget: storage.addAttribute(.foregroundColor, value: rich ? richLink : NSColor.secondaryLabelColor, range: span.range)
                case .quote: storage.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: span.range)
                case .listMarker: storage.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: span.range)
                case .code:
                    // Code keeps a fixed-width font even in the MacDown style.
                    storage.addAttribute(.font, value: codeFont, range: span.range)
                    storage.addAttribute(.foregroundColor, value: NSColor.systemPink, range: span.range)
                    storage.addAttribute(.backgroundColor, value: NSColor.systemPink.withAlphaComponent(0.08), range: span.range)
                }
            }
            // Headings: larger by level in the MacDown style; bold there always, otherwise by the setting.
            if rich || bold {
                for heading in headings {
                    let font: NSFont = rich ? boldVersion(regularFont, size: size * (headingScale[heading.level] ?? 1)) : boldFont
                    for range in [heading.range, heading.underline].compactMap({ $0 }) where NSMaxRange(range) <= length {
                        storage.addAttribute(.font, value: font, range: range)
                    }
                }
            }
        }
        storage.endEditing()
        // Typing continues in the plain style; the next restyle colors it.
        textView.typingAttributes[.font] = regularFont
        textView.typingAttributes[.foregroundColor] = editorText
        textView.typingAttributes[.backgroundColor] = nil
        textView.typingAttributes[.paragraphStyle] = paragraphStyle
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let store: MarkdownStore
        weak var textView: NSTextView?
        var boldHeadings = true
        var style = "rich"
        var fontName = ""
        var lineSpacing = MarkdownStore.defaultLineSpacing
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
            // Lines as the preview counts them (CR, CR+LF and LF are one line break each).
            let line = string.substring(to: paragraph.location).normalizedLineBreaks.utf16.reduce(0) { $1 == 10 ? $0 + 1 : $0 }
            let glyphs = layout.glyphRange(forCharacterRange: paragraph, actualCharacterRange: nil)
            let rect = layout.boundingRect(forGlyphRange: glyphs, in: container)
            let fraction = rect.height > 0 ? min(max((point.y - rect.minY) / rect.height, 0), 1) : 0
            return Double(line) + fraction
        }

        func textDidChange(_ notification: Notification) {
            // Sync and restyle after the input method commits; restyling marked text discards it.
            guard let textView = notification.object as? NSTextView, !textView.hasMarkedText() else { return }
            store.text = textView.string
            SourceEditor.styleHeadings(textView, headings: store.allHeadings, bold: boldHeadings, size: fontSize)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, !textView.hasMarkedText() else { return }
            let range = textView.selectedRange()
            let selected = range.length > 0 ? (textView.string as NSString).substring(with: range) : ""
            // Publish only on change, so moving the caret does not redraw the window.
            if store.selectedText != selected { store.selectedText = selected }
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
        var items = FormatAction.contextMenuItems()
        if selectedRange().length > 0 {
            let rewrite = NSMenuItem(title: L("文字数を指定して書き直す…"), action: #selector(rewriteSelection(_:)), keyEquivalent: "")
            rewrite.target = self
            items = [rewrite] + (items.isEmpty ? [] : [.separator()]) + items
        }
        guard !items.isEmpty else { return menu }
        let all = items + [.separator()]
        for (index, item) in all.enumerated() { menu.insertItem(item, at: index) }
        return menu
    }

    @objc func rewriteSelection(_ sender: Any?) {
        MarkdownStore.shared.beginRewrite()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let url = fileURL(sender) {
            onDropFile?(url)
            return true
        }
        return super.performDragOperation(sender)
    }
}
