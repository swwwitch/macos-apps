import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// A list file read into one of the panes. Saving writes back to it in the same encoding.
struct LinkedFile: Equatable {
    var url: URL
    var encoding: String.Encoding
    /// Modification date when it was read or saved: tells whether another app changed it since.
    var date: Date?
    /// The list was changed after it was read or saved.
    var edited = false
    var name: String { url.lastPathComponent }
    var exists: Bool { FileManager.default.fileExists(atPath: url.path) }
    var changedOnDisk: Bool {
        guard let date, let current = ListFile.modificationDate(url) else { return false }
        return current > date.addingTimeInterval(1)
    }
}

enum ListFile {
    /// Reads a list file as text (UTF-8, UTF-16 with a BOM, then Shift_JIS).
    static func read(_ url: URL) throws -> (text: String, encoding: String.Encoding) {
        let data = try Data(contentsOf: url)
        if let text = String(data: data, encoding: .utf8) { return (text, .utf8) }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]), let text = String(data: data, encoding: .utf16) { return (text, .utf16) }
        if let text = String(data: data, encoding: .shiftJIS) { return (text, .shiftJIS) }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    static func modificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    /// Writes atomically. An existing file is first copied to the backup folder. Characters the encoding
    /// cannot hold switch the file to UTF-8 rather than being lost. Returns the encoding used.
    @discardableResult
    static func write(_ text: String, to url: URL, encoding: String.Encoding) throws -> String.Encoding {
        let encoding = text.canBeConverted(to: encoding) ? encoding : .utf8
        guard let data = text.data(using: encoding) else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
        if FileManager.default.fileExists(atPath: url.path) { backUp(url) }
        try data.write(to: url, options: .atomic)
        return encoding
    }

    /// ~/Library/Application Support/ListMatch/Backups (newest 20).
    static var backupFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ListMatch/Backups", isDirectory: true)
    }

    private static func backUp(_ url: URL) {
        let manager = FileManager.default
        let folder = backupFolder
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = url.deletingPathExtension().lastPathComponent + "-" + formatter.string(from: Date()) + (url.pathExtension.isEmpty ? "" : "." + url.pathExtension)
        try? manager.copyItem(at: url, to: folder.appendingPathComponent(name))
        let files = ((try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .sorted { (modificationDate($0) ?? .distantPast) > (modificationDate($1) ?? .distantPast) }
        for old in files.dropFirst(20) { try? manager.removeItem(at: old) }
    }
}

/// Plain-text editor that replaces its contents with a dropped text file instead of inserting the file's path.
final class ListTextView: NSTextView {
    var onFileDrop: ((URL) -> Void)?
    var onPaste: (() -> Void)?

    // Pasted text is split at the chosen separators (typing is left alone).
    override func paste(_ sender: Any?) {
        super.paste(sender)
        let done = onPaste
        DispatchQueue.main.async { done?() }
    }

    private func fileURL(_ info: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return (info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL])?.first
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileURL(sender) != nil ? .copy : super.draggingEntered(sender)
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileURL(sender) != nil ? .copy : super.draggingUpdated(sender)
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = fileURL(sender) else { return super.performDragOperation(sender) }
        onFileDrop?(url)
        return true
    }
}

/// Editable list pane. Plain text only, no smart quotes or autocorrection (they would change addresses).
struct ListEditor: NSViewRepresentable {
    @Binding var text: String
    let label: String
    var onFileDrop: (URL) -> Void
    var onPaste: () -> Void = {}
    /// Ranges to show in a lighter color, valid for `text` (the list the comparison was made from).
    var dimmed: (text: String, ranges: [NSRange]) = ("", [])
    /// Hands out the text view (to select an item clicked in a result).
    var onCreate: (NSTextView) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let view = ListTextView(frame: .zero)
        view.minSize = NSSize(width: 0, height: 0)
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.isRichText = false
        view.importsGraphics = false
        view.allowsUndo = true
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.isContinuousSpellCheckingEnabled = false
        view.isAutomaticLinkDetectionEnabled = false
        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textContainerInset = NSSize(width: 6, height: 8)
        view.drawsBackground = false
        view.string = text
        view.delegate = context.coordinator
        view.onFileDrop = onFileDrop
        view.onPaste = onPaste
        view.setAccessibilityLabel(label)
        scroll.documentView = view
        onCreate(view)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? ListTextView else { return }
        view.onFileDrop = onFileDrop
        view.onPaste = onPaste
        // Replaced from outside (clear, open): keep it undoable.
        if view.string != text {
            if view.shouldChangeText(in: NSRange(location: 0, length: (view.string as NSString).length), replacementString: text) {
                view.replaceCharacters(in: NSRange(location: 0, length: (view.string as NSString).length), with: text)
                view.didChangeText()
            } else {
                view.string = text
            }
        }
        applyDimming(view, context.coordinator)
    }

    /// Lighter color for the items that are also in the other list. Temporary attributes only touch the
    /// display: the text, Undo and saving stay as they are. Applied only when the ranges match the current text.
    private func applyDimming(_ view: NSTextView, _ coordinator: Coordinator) {
        guard let layout = view.layoutManager else { return }
        let ranges = dimmed.text == view.string ? dimmed.ranges : []
        let length = (view.string as NSString).length
        guard ranges != coordinator.dimmedRanges || length != coordinator.dimmedLength else { return }
        coordinator.dimmedRanges = ranges
        coordinator.dimmedLength = length
        let full = NSRange(location: 0, length: length)
        layout.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
        for range in ranges where NSMaxRange(range) <= length {
            layout.addTemporaryAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, forCharacterRange: range)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ListEditor
        var dimmedRanges: [NSRange] = []
        var dimmedLength = -1
        init(_ parent: ListEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            if parent.text != view.string { parent.text = view.string }
        }
    }
}

/// Result list text: clicking a line reports that item (to show it in the list it came from).
final class ResultTextView: NSTextView {
    var onClickItem: ((String) -> Void)?
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // A drag that selected text is left alone; a plain click picks the line.
        guard event.clickCount == 1, selectedRange().length == 0 else { return }
        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndexForInsertion(at: point)
        let source = string as NSString
        guard source.length > 0 else { return }
        let line = source.substring(with: source.lineRange(for: NSRange(location: min(index, source.length - 1), length: 0)))
            .trimmingCharacters(in: .newlines)
        if !line.isEmpty { onClickItem?(line) }
    }
}

/// Read-only, selectable result list.
struct ResultText: NSViewRepresentable {
    let text: String
    let label: String
    var onClickItem: (String) -> Void = { _ in }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        let view = ResultTextView(frame: .zero)
        view.minSize = .zero
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.isVerticallyResizable = true
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = false
        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textContainerInset = NSSize(width: 6, height: 8)
        view.drawsBackground = false
        view.setAccessibilityLabel(label)
        view.onClickItem = onClickItem
        scroll.documentView = view
        scroll.drawsBackground = false
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? ResultTextView else { return }
        view.onClickItem = onClickItem
        if view.string != text { view.string = text }
    }
}
