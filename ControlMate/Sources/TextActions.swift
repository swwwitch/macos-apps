import AppKit
import ApplicationServices

/// Every type of every clipboard item, so formatted text goes back as it was.
struct ClipboardContents {
    var items: [[NSPasteboard.PasteboardType: Data]]

    static func read(_ pasteboard: NSPasteboard = .general) -> ClipboardContents {
        ClipboardContents(items: (pasteboard.pasteboardItems ?? []).map { item in
            var types: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let data = item.data(forType: type) { types[type] = data } }
            return types
        })
    }

    /// Returns the change count after writing.
    @discardableResult
    func write(_ pasteboard: NSPasteboard = .general) -> Int {
        pasteboard.clearContents()
        let objects: [NSPasteboardItem] = items.map { types in
            let item = NSPasteboardItem()
            for (type, data) in types { item.setData(data, forType: type) }
            return item
        }
        if !objects.isEmpty { pasteboard.writeObjects(objects) }
        return pasteboard.changeCount
    }

    var plainText: String {
        items.compactMap { $0[.string].flatMap { String(data: $0, encoding: .utf8) } }.joined()
    }
}

/// The editing commands: ⌃K / ⌃X kill into ControlMate's own kill buffer, ⌃Y yanks it, ⌃S selects a paragraph,
/// ⌃⇧↑↓ swap paragraphs. The text is read and selected with the Accessibility API; cut, copy and paste go through the
/// app's own menu items so formatting is kept and the held ⌃ never mixes in. Ported from the JXA scripts
/// MoveParagraph / SelectParagraph / CutToLineStart.
final class TextActions: @unchecked Sendable {
    private let queue = DispatchQueue(label: "ControlMate actions", qos: .userInteractive)
    /// The kill buffer, separate from the clipboard. Kept in memory only.
    private var killed: ClipboardContents?
    /// Where the last kill left the caret, so the next kill there joins it (⌃K ⌃K takes the line and its break).
    private var lastKill: (pid: pid_t, caret: Int, length: Int)?
    private var lastSelect: (pid: pid_t, time: Date)?
    /// Called on the main thread with a short message when a command could not be carried out, and nil on success.
    var onResult: (@MainActor (String?) -> Void)?

    static let clipboardTimeout: TimeInterval = 1.0
    /// Too short and the restored clipboard is what gets pasted.
    static let pasteSettle: TimeInterval = 0.15

    func perform(_ action: Action, extend: Bool, pid: pid_t) {
        let doubleTap = NSEvent.doubleClickInterval
        queue.async { [self] in
            let failure: String?
            switch action {
            case .killToLineEnd: failure = kill(pid: pid, forward: true)
            case .killToLineStart: failure = kill(pid: pid, forward: false)
            case .yank: failure = yank(pid: pid)
            case .selectParagraph: failure = selectParagraph(pid: pid, doubleTap: doubleTap)
            case .moveParagraphUp: failure = moveParagraph(pid: pid, up: true)
            case .moveParagraphDown: failure = moveParagraph(pid: pid, up: false)
            case .paragraphStart: failure = moveToParagraphEdge(pid: pid, end: false, extend: extend)
            case .paragraphEnd: failure = moveToParagraphEdge(pid: pid, end: true, extend: extend)
            case .keys: failure = nil
            }
            if let onResult { DispatchQueue.main.async { MainActor.assumeIsolated { onResult(failure) } } }
        }
    }

    // MARK: Commands

    private func kill(pid: pid_t, forward: Bool) -> String? {
        let saved = ClipboardContents.read()
        var cut: ClipboardContents?
        if let field = FocusedText(pid: pid) {
            let range = forward ? TextRanges.killToLineEnd(field.text, selection: field.selection)
                                : TextRanges.killToLineStart(field.text, selection: field.selection)
            guard range.length > 0 else { return nil }  // At the end (⌃K) or the start (⌃X): nothing to take.
            if field.select(range), let contents = cutSelection(pid: pid) {
                cut = contents
                // The kill joins the previous one when the caret has not moved and nothing else changed the text.
                if let last = lastKill, last.pid == pid, last.caret == range.location, last.length == field.text.length,
                   let previous = killed {
                    let joined = forward ? previous.plainText + contents.plainText : contents.plainText + previous.plainText
                    cut = ClipboardContents(items: [[.string: Data(joined.utf8)]])
                }
                lastKill = (pid, range.location, field.text.length - range.length)
            }
        }
        if cut == nil {
            // No text through Accessibility (or the selection was refused): select with keys and cut.
            KeySender.send(Stroke(code: forward ? 124 : 123, mods: [.shift, .command], label: ""), to: pid)
            cut = cutSelection(pid: pid)
            if cut == nil && forward {
                KeySender.send(Stroke(code: 124, mods: .shift, label: ""), to: pid)
                cut = cutSelection(pid: pid)
            }
            lastKill = nil
        }
        guard let cut else { return L("result.killFailed") }
        restore(saved)
        killed = cut
        return nil
    }

    private func yank(pid: pid_t) -> String? {
        guard let killed else { return L("result.nothingKilled") }
        let saved = ClipboardContents.read()
        let written = killed.write()
        menuCommand("V", pid: pid)
        Thread.sleep(forTimeInterval: Self.pasteSettle)
        // A clipboard changed by someone else in the meantime is left as it is.
        if NSPasteboard.general.changeCount == written { saved.write() }
        lastKill = nil
        return nil
    }

    /// ⌃A / ⌃E: the caret to the start / end of its paragraph (⇧: the selection is extended there).
    /// Without Accessibility text, ⌘← / ⌘→ (the visual line) instead.
    private func moveToParagraphEdge(pid: pid_t, end: Bool, extend: Bool) -> String? {
        if let field = FocusedText(pid: pid),
           field.select(TextRanges.paragraphEdge(field.text, selection: field.selection, end: end, extend: extend)) { return nil }
        KeySender.send(Stroke(code: end ? 124 : 123, mods: extend ? [.shift, .command] : .command, label: ""), to: pid)
        return nil
    }

    /// ⌃S selects the paragraph and copies it; pressed again within the double-click interval, the selection is cut.
    private func selectParagraph(pid: pid_t, doubleTap: TimeInterval) -> String? {
        if let last = lastSelect, last.pid == pid, Date().timeIntervalSince(last.time) < doubleTap {
            lastSelect = nil
            return clipboardCommand("X", pid: pid) ? nil : L("result.cutFailed")
        }
        lastSelect = (pid, Date())
        if let field = FocusedText(pid: pid), field.select(TextRanges.paragraphSelection(field.text, selection: field.selection)) {
            return clipboardCommand("C", pid: pid) ? nil : L("result.copyFailed")
        }
        // Without Accessibility text: the visual line, from its end back to its start.
        KeySender.send(Stroke(code: 124, mods: .command, label: ""), to: pid)
        KeySender.send(Stroke(code: 123, mods: [.shift, .command], label: ""), to: pid)
        return clipboardCommand("C", pid: pid) ? nil : L("result.copyFailed")
    }

    /// Swaps the caret's paragraph with the one above or below: the lower one is cut (break included) and pasted at the
    /// start of the upper one, so formatting moves too. A last paragraph without a break gets one for the move.
    private func moveParagraph(pid: pid_t, up: Bool) -> String? {
        guard let field = FocusedText(pid: pid) else { return L("result.noText") }
        let text = field.text
        guard let pair = TextRanges.swapPair(text, selection: field.selection, up: up) else { return nil }  // Already at the top or bottom.
        let (upper, lower) = (pair.upper, pair.lower)
        let moving = pair.movingIsUpper ? upper : lower
        let offsetInParagraph = field.selection.location - moving.start
        let upperBreak = text.substring(with: NSRange(location: upper.contentEnd, length: upper.end - upper.contentEnd))
        let addedBreak = lower.end == lower.contentEnd
        if addedBreak {
            guard field.select(NSRange(location: lower.contentEnd, length: 0)), field.replaceSelection(with: upperBreak),
                  field.waitForLength(text.length + (upperBreak as NSString).length) else { return L("result.moveFailed") }
        }
        let breakLength = (upperBreak as NSString).length
        let lowerEnd = addedBreak ? lower.contentEnd + breakLength : lower.end
        let lowerLength = lowerEnd - lower.start
        let total = text.length + (addedBreak ? breakLength : 0)

        let saved = ClipboardContents.read()
        var moved = false
        if field.select(NSRange(location: lower.start, length: lowerLength)), cutSelection(pid: pid) != nil, field.waitForLength(total - lowerLength),
           field.select(NSRange(location: upper.start, length: 0)) {
            menuCommand("V", pid: pid)
            Thread.sleep(forTimeInterval: Self.pasteSettle)
            moved = field.waitForLength(total)
        }
        restore(saved)
        guard moved else { return L("result.moveFailed") }
        if addedBreak {
            _ = field.select(NSRange(location: total - breakLength, length: breakLength))
            _ = field.replaceSelection(with: "")
        }
        let movedStart = pair.movingIsUpper ? upper.start + lowerLength : upper.start
        let movedLength = moving.contentEnd - moving.start
        let caret = movedStart + min(offsetInParagraph, movedLength)
        let caretEnd = min(caret + field.selection.length, movedStart + movedLength)
        _ = field.select(NSRange(location: caret, length: caretEnd - caret))
        return nil
    }

    // MARK: Clipboard

    /// The change count right after ControlMate's own cut; restore() leaves a clipboard changed after it alone.
    private var ownCutCount: Int?

    /// Cuts the selection and returns what the cut put on the clipboard, or nil when nothing changed.
    private func cutSelection(pid: pid_t) -> ClipboardContents? {
        let before = NSPasteboard.general.changeCount
        menuCommand("X", pid: pid)
        guard waitForClipboard(after: before) else { return nil }
        ownCutCount = NSPasteboard.general.changeCount
        return ClipboardContents.read()
    }

    /// ⌘X / ⌘C into the clipboard (for ⌃S), true when the clipboard changed.
    private func clipboardCommand(_ character: String, pid: pid_t) -> Bool {
        let before = NSPasteboard.general.changeCount
        menuCommand(character, pid: pid)
        return waitForClipboard(after: before)
    }

    private func waitForClipboard(after count: Int) -> Bool {
        let deadline = Date().addingTimeInterval(Self.clipboardTimeout)
        while NSPasteboard.general.changeCount == count && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
        return NSPasteboard.general.changeCount != count
    }

    /// Puts the clipboard back unless something else changed it after ControlMate's own cut.
    private func restore(_ saved: ClipboardContents) {
        defer { ownCutCount = nil }
        // Nothing to put back when no cut happened.
        guard let ownCutCount, ownCutCount == NSPasteboard.general.changeCount else { return }
        saved.write()
    }

    // MARK: Menu commands

    /// Presses the app's ⌘+character menu item (no other modifier); without one, types ⌘+character to the app.
    /// The menu is preferred so the ⌃ still held for the command does not mix in.
    private func menuCommand(_ character: String, pid: pid_t) {
        if let item = Self.menuItem(character, pid: pid), AXUIElementPerformAction(item, kAXPressAction as CFString) == .success { return }
        let codes: [String: Int64] = ["X": 7, "C": 8, "V": 9]
        if let code = codes[character] { KeySender.send(Stroke(code: code, mods: .command, label: ""), to: pid) }
    }

    /// Menu names change with the language, so the item is found by its key.
    static func menuItem(_ character: String, pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)
        guard let bar: AXUIElement = AX.value(app, kAXMenuBarAttribute) else { return nil }
        for barItem in AX.children(bar) {
            for menu in AX.children(barItem) {
                for item in AX.children(menu) {
                    guard (AX.value(item, kAXMenuItemCmdCharAttribute) as String?) == character,
                          (AX.value(item, kAXMenuItemCmdModifiersAttribute) as Int?) == 0,  // 0 is ⌘ alone
                          (AX.value(item, kAXEnabledAttribute) as Bool?) != false else { continue }
                    return item
                }
            }
        }
        return nil
    }
}

/// The focused text field of an app, read through the Accessibility API.
struct FocusedText {
    let element: AXUIElement
    let text: NSString
    let selection: NSRange

    init?(pid: pid_t) {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)
        guard let element: AXUIElement = AX.value(app, kAXFocusedUIElementAttribute),
              let text: String = AX.value(element, kAXValueAttribute),
              let range = AX.range(element) else { return nil }
        self.element = element
        self.text = text as NSString
        self.selection = range
    }

    /// Sets the selection and reads it back: some fields (Chrome's rich text) report success and change nothing.
    func select(_ range: NSRange) -> Bool {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let value = AXValueCreate(.cfRange, &cfRange),
              AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value) == .success else { return false }
        return AX.range(element) == range
    }

    func replaceSelection(with string: String) -> Bool {
        AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, string as CFString) == .success
    }

    /// Waits (up to 1 second) for the text to reach a length after a cut or paste.
    func waitForLength(_ length: Int) -> Bool {
        for _ in 0..<20 {
            if let text: String = AX.value(element, kAXValueAttribute), (text as NSString).length == length { return true }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }
}

enum AX {
    static func value<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? T
    }
    static func children(_ element: AXUIElement) -> [AXUIElement] { value(element, kAXChildrenAttribute) ?? [] }
    static func range(_ element: AXUIElement) -> NSRange? {
        guard let value: AXValue = AX.value(element, kAXSelectedTextRangeAttribute) else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range) else { return nil }
        return NSRange(location: range.location, length: range.length)
    }
}

/// Types keys straight to one app with exactly the given modifiers, so the ⌃ held for the command does not mix in.
enum KeySender {
    static func send(_ stroke: Stroke, to pid: pid_t) {
        let source = CGEventSource(stateID: .privateState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(stroke.code), keyDown: down) else { continue }
            event.flags = stroke.flags
            event.setIntegerValueField(.eventSourceUserData, value: KeyTap.marker)
            event.postToPid(pid)
        }
        Thread.sleep(forTimeInterval: 0.03)
    }
}
