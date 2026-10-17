import AppKit
import ApplicationServices

/// Result of one press. Only lengths of text are kept in the status, never written to a log (B12).
enum PasteOutcome {
    /// `before` → `after` was put on the clipboard and pasted.
    case pasted(appName: String, before: String, after: String, kind: IncrementKind)
    /// The clipboard was pasted as it is: nothing to count up, or the first paste after a copy.
    case unchanged(appName: String, text: String, first: Bool)
    case failed(String)
}

/// The KM macro 「increment-paste」: counts up the text on the clipboard, leaves the new text there
/// (so the next press goes one further) and sends ⌘V to the front app.
final class IncrementPaster {
    /// The changeCount after our last write or as-is paste: an equal count means the user has not copied since.
    private(set) var lastChange: Int?
    /// What the clipboard held before our last write, for 「元に戻す」.
    private(set) var previous: String?
    private(set) var lastWritten: String?

    /// The clipboard still holds what IncrementPaste wrote last, so it can be put back.
    var canRevert: Bool { previous != nil && lastChange == NSPasteboard.general.changeCount }

    func preview(options: Incrementer.Options, firstAsIs: Bool) -> (current: String?, next: IncrementResult?) {
        guard let text = NSPasteboard.general.string(forType: .string) else { return (nil, nil) }
        if firstAsIs && lastChange != NSPasteboard.general.changeCount { return (text, IncrementResult(text: text, kind: .none)) }
        return (text, Incrementer.increment(text, options: options, currentYear: Self.currentYear))
    }
    static var currentYear: Int { Calendar(identifier: .gregorian).component(.year, from: Date()) }

    /// `stillTarget` is checked right before the clipboard is changed and ⌘V is sent (B21).
    func paste(options: Incrementer.Options, firstAsIs: Bool, appName: String, pid: pid_t, stillTarget: () -> Bool) -> PasteOutcome {
        guard AXIsProcessTrusted() else { return .failed(AccessibilityText.text("blocked")) }
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string) else { return .failed(L("fail.noText")) }
        guard stillTarget() else { return .failed(L("fail.target")) }
        guard let events = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: events, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: events, virtualKey: 9, keyDown: false) else { return .failed(L("fail.event")) }
        let outcome: PasteOutcome
        if firstAsIs && lastChange != pasteboard.changeCount {
            // The first press after a copy pastes the copied text; the next one counts up.
            outcome = .unchanged(appName: appName, text: text, first: true)
        } else {
            let result = Incrementer.increment(text, options: options, currentYear: Self.currentYear)
            if result.kind == .none {
                // Nothing to count up: the clipboard (with its formatting) is pasted untouched, like the macro.
                outcome = .unchanged(appName: appName, text: text, first: false)
            } else {
                pasteboard.clearContents()
                guard pasteboard.setString(result.text, forType: .string) else {
                    pasteboard.clearContents(); pasteboard.setString(text, forType: .string)
                    return .failed(L("fail.write"))
                }
                previous = text; lastWritten = result.text
                outcome = .pasted(appName: appName, before: text, after: result.text, kind: result.kind)
            }
        }
        lastChange = pasteboard.changeCount
        // Explicit flags, so the held ⌥ of ⌥V does not leak into ⌘V (same as PasteInARow). Key code 9 = V.
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(pid)
        up.postToPid(pid)
        return outcome
    }

    /// Puts back the text from before the last count-up, only while the clipboard still holds our write (B10).
    func revert() -> Bool {
        guard canRevert, let previous else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(previous, forType: .string) else { return false }
        lastChange = pasteboard.changeCount
        self.previous = nil; lastWritten = nil
        return true
    }
}
