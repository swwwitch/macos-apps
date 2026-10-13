import AppKit
import ApplicationServices

/// Result of one ⌃⌥V. Only counts and the app name are kept for the status, never written to a log (B12).
enum PasteOutcome {
    case pasted(appName: String, remaining: Int, next: String?)
    case failed(String)
}

/// Pastes the copied text one line per press, like the KM macro: the line goes on the clipboard, ⌘V is sent
/// to the front app, and the remaining lines are put back on the clipboard afterwards.
/// The queue is also kept in memory, so a quick second press does not depend on that write-back.
final class LinePaster {
    /// The target reads the clipboard asynchronously after ⌘V; the remainder is written back after this.
    static let writeBackDelay: TimeInterval = 1.0

    private(set) var queue: [String] = []
    /// The copied text the queue came from, for 「最初の行からやり直す」.
    private var source: String?
    /// changeCount of our last clipboard write; anything else means the user copied something new.
    private var written: Int?

    /// True while the clipboard still holds what PasteInARow wrote (no newer copy by the user).
    var isCurrent: Bool { written != nil && written == NSPasteboard.general.changeCount }
    var canRestart: Bool { source != nil && isCurrent }

    /// Lines the next press continues with: the running queue, or the clipboard split as it would be loaded.
    func upcoming(trimIndent: Bool, stripMarkers: Bool) -> (lines: [String], loaded: Bool) {
        if isCurrent { return (queue, true) }
        guard let text = NSPasteboard.general.string(forType: .string) else { return ([], false) }
        return (LineRules.lines(from: text, trimIndent: trimIndent, stripMarkers: stripMarkers), false)
    }

    /// What to paste: the first line (⌃⌥V), a line clicked in the window, or all remaining lines at once
    /// (the 「all」 of the KM macro 「02)非連続ペースト」).
    enum Pick {
        case next
        /// The row shown in the window; `text` guards against a list that changed after it was drawn.
        /// `newline`: ⌥-click pastes the line followed by a line break.
        case line(index: Int, text: String, newline: Bool)
        case all
    }

    /// `stillTarget` is checked right before ⌘V is sent (B21).
    func paste(_ pick: Pick, appName: String, pid: pid_t, trimIndent: Bool, stripMarkers: Bool, stillTarget: () -> Bool) -> PasteOutcome {
        guard AXIsProcessTrusted() else { return .failed(L("fail.access")) }
        let pasteboard = NSPasteboard.general
        if !isCurrent {
            guard let text = pasteboard.string(forType: .string) else { reset(); return .failed(L("fail.noText")) }
            let lines = LineRules.lines(from: text, trimIndent: trimIndent, stripMarkers: stripMarkers)
            guard !lines.isEmpty else { reset(); return .failed(L("fail.noLines")) }
            queue = lines
            source = text
        }
        guard !queue.isEmpty else { return .failed(L("fail.finished")) }
        guard stillTarget() else { return .failed(L("fail.target")) }
        guard let events = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: events, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: events, virtualKey: 9, keyDown: false) else { return .failed(L("fail.event")) }
        let line: String
        switch pick {
        case .next: line = queue[0]
        case .line(let index, let text, let newline):
            guard queue.indices.contains(index), queue[index] == text else { return .failed(L("fail.stale")) }
            line = newline ? text + "\n" : text
        case .all: line = queue.joined(separator: "\n")
        }
        pasteboard.clearContents()
        guard pasteboard.setString(line, forType: .string) else { written = pasteboard.changeCount; return .failed(L("fail.write")) }
        switch pick {
        case .next: queue.removeFirst()
        case .line(let index, _, _): queue.remove(at: index)
        case .all: queue.removeAll()
        }
        let change = pasteboard.changeCount
        written = change
        // Explicit flags, so the held ⌃⌥ of ⌃⌥V does not leak into ⌘V (same as KakkoReplace). Key code 9 = V.
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(pid)
        up.postToPid(pid)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.writeBackDelay) { [weak self] in
            // A later press or a new copy by the user has already replaced the clipboard (B10).
            guard let self, pasteboard.changeCount == change else { return }
            pasteboard.clearContents()
            if !self.queue.isEmpty { pasteboard.setString(self.queue.joined(separator: "\n"), forType: .string) }
            self.written = pasteboard.changeCount
        }
        return .pasted(appName: appName, remaining: queue.count, next: queue.first)
    }

    /// The macro's 「clear」: drops the remaining lines and empties the clipboard; 「最初の行からやり直す」 still works.
    func clear() -> Bool {
        let pasteboard = NSPasteboard.general
        if !isCurrent {
            guard let text = pasteboard.string(forType: .string) else { return false }
            source = text
        }
        queue = []
        pasteboard.clearContents()
        written = pasteboard.changeCount
        return true
    }

    /// Puts the whole copied text back on the clipboard; the next press starts again from its first line.
    func restart() -> Bool {
        guard canRestart, let source else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let ok = pasteboard.setString(source, forType: .string)
        reset()
        return ok
    }

    private func reset() { queue = []; source = nil; written = nil }
}
