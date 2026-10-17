import AppKit
import ApplicationServices

/// Result of one paste. Only counts and the app name are kept for the status, never written to a log (B12).
enum PasteOutcome {
    case pasted(appName: String, remaining: Int, next: String?)
    case failed(String)
}

enum AddOutcome {
    case added(appName: String, count: Int, total: Int)
    case failed(String)
}

/// One line in the slot. A starred line stays after it is pasted.
struct SlotItem: Equatable {
    var text: String
    var starred = false
}

/// The slot: lines added with ⌃⌥⌘C only, kept in memory apart from the clipboard.
/// ⌃⌥V pastes them from the top, the window pastes any of them. For each paste the line is put on the clipboard,
/// ⌘V is sent to the target, and the user's clipboard is put back afterwards.
final class LinePaster {
    /// The target reads the clipboard asynchronously after ⌘V; the user's clipboard is restored after this.
    static let restoreDelay: TimeInterval = 1.0

    private(set) var queue: [SlotItem] = []
    /// Where ⌃⌥V continues. It moves past starred lines (they stay) and wraps to the top at the end.
    private(set) var cursor = 0
    /// Every line added since the slot was last empty, for 「最初からやり直す」.
    private var history: [String] = []
    var canRestart: Bool { !history.isEmpty && queue.map(\.text) != history }
    /// The row the next ⌃⌥V pastes.
    var nextIndex: Int? { queue.isEmpty ? nil : (cursor < queue.count ? cursor : 0) }

    func toggleStar(_ index: Int) {
        guard queue.indices.contains(index) else { return }
        queue[index].starred.toggle()
    }

    /// The user's clipboard taken before our own write, and the changeCount of that write.
    /// A second paste or add within the delay keeps the snapshot from the first one.
    private var pendingRestore: (items: [[NSPasteboard.PasteboardType: Data]], change: Int)?

    /// What to paste: the first line (⌃⌥V), a line chosen in the window, or all lines at once
    /// (the 「all」 of the KM macro 「02)非連続ペースト」).
    enum Pick {
        case next
        /// The row shown in the window; `text` guards against a list that changed after it was drawn.
        /// `newline` (⌘Return): the line is followed by a line break. `keep` (⌥Return): the line stays in the slot.
        case line(index: Int, text: String, newline: Bool, keep: Bool)
        case all
    }

    /// `stillTarget` is checked right before ⌘V is sent (B21).
    func paste(_ pick: Pick, appName: String, pid: pid_t, stillTarget: () -> Bool) -> PasteOutcome {
        guard AXIsProcessTrusted() else { return .failed(AccessibilityText.text("blocked")) }
        guard !queue.isEmpty else { return .failed(L("fail.empty")) }
        guard stillTarget() else { return .failed(L("fail.target")) }
        guard let events = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: events, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: events, virtualKey: 9, keyDown: false) else { return .failed(L("fail.event")) }
        let line: String
        let first = nextIndex ?? 0
        switch pick {
        case .next: line = queue[first].text
        case .line(let index, let text, let newline, _):
            guard queue.indices.contains(index), queue[index].text == text else { return .failed(L("fail.stale")) }
            line = newline ? text + "\n" : text
        case .all: line = queue.map(\.text).joined(separator: "\n")
        }
        let pasteboard = NSPasteboard.general
        let saved = takeSnapshot()
        pasteboard.clearContents()
        guard pasteboard.setString(line, forType: .string) else { restore(saved); return .failed(L("fail.write")) }
        switch pick {
        case .next:
            if queue[first].starred { cursor = first + 1 } else { queue.remove(at: first); cursor = first }
        case .line(let index, _, _, let keep):
            if !keep && !queue[index].starred {
                queue.remove(at: index)
                if index < cursor { cursor -= 1 }
            }
        case .all:
            queue.removeAll { !$0.starred }
            cursor = 0
        }
        // Explicit flags, so the held ⌃⌥ of ⌃⌥V does not leak into ⌘V (same as KakkoReplace). Key code 9 = V.
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(pid)
        up.postToPid(pid)
        restoreLater(saved, after: pasteboard.changeCount)
        return .pasted(appName: appName, remaining: queue.count, next: nextIndex.map { queue[$0].text })
    }

    /// ⌃⌥⌘C: sends ⌘C to the front app, waits for the copy, and adds its lines to the end of the slot.
    /// The clipboard is put back to what it was before, so adding does not replace the user's copy.
    private(set) var adding = false
    func addSelection(appName: String, pid: pid_t, trimIndent: Bool, stripMarkers: Bool,
                      stillTarget: () -> Bool, completion: @escaping (AddOutcome) -> Void) {
        guard !adding else { return }
        guard AXIsProcessTrusted() else { completion(.failed(AccessibilityText.text("blocked"))); return }
        guard stillTarget() else { completion(.failed(L("fail.target"))); return }
        let pasteboard = NSPasteboard.general
        let saved = takeSnapshot()
        let before = pasteboard.changeCount
        guard let events = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: events, virtualKey: 8, keyDown: true),
              let up = CGEvent(keyboardEventSource: events, virtualKey: 8, keyDown: false) else { completion(.failed(L("fail.event"))); return }
        // Explicit flags, so the held ⌃⌥⌘ of the hotkey does not leak into ⌘C. Key code 8 = C.
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(pid)
        up.postToPid(pid)
        adding = true
        let deadline = Date().addingTimeInterval(1.0)
        func wait() {
            if pasteboard.changeCount != before {
                // Some apps write several representations right after bumping changeCount.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    guard let self else { return }
                    self.adding = false
                    let text = pasteboard.string(forType: .string)
                    // Put the user's clipboard back right away.
                    self.restore(saved)
                    guard let text else { completion(.failed(L("fail.addNoText"))); return }
                    let added = LineRules.lines(from: text, trimIndent: trimIndent, stripMarkers: stripMarkers)
                    guard !added.isEmpty else { completion(.failed(L("fail.noLines"))); return }
                    if self.queue.isEmpty { self.history = []; self.cursor = 0 }
                    self.queue += added.map { SlotItem(text: $0) }
                    self.history += added
                    completion(.added(appName: appName, count: added.count, total: self.queue.count))
                }
            } else if Date() >= deadline {
                adding = false
                completion(.failed(L("fail.addTimeout")))
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { wait() }
            }
        }
        wait()
    }

    /// The macro's 「clear」: removes the unstarred lines. 「最初からやり直す」 still brings them back.
    func clear() { queue.removeAll { !$0.starred }; cursor = 0 }

    /// Puts every line added since the slot was last empty back, in the order they were added.
    func restart() -> Bool {
        guard canRestart else { return false }
        let starred = Set(queue.filter(\.starred).map(\.text))
        queue = history.map { SlotItem(text: $0, starred: starred.contains($0)) }
        cursor = 0
        return true
    }

    // MARK: - Clipboard

    /// Every representation of the user's clipboard, or the one already saved when our own write is still on it.
    private func takeSnapshot() -> [[NSPasteboard.PasteboardType: Data]] {
        let pasteboard = NSPasteboard.general
        if let pendingRestore, pendingRestore.change == pasteboard.changeCount { return pendingRestore.items }
        return (pasteboard.pasteboardItems ?? []).map { item in
            var saved: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let data = item.data(forType: type) { saved[type] = data } }
            return saved
        }
    }
    private func restore(_ items: [[NSPasteboard.PasteboardType: Data]]) {
        let pasteboard = NSPasteboard.general
        pendingRestore = nil
        pasteboard.clearContents()
        let objects = items.map { saved -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in saved { item.setData(data, forType: type) }
            return item
        }
        if !objects.isEmpty { pasteboard.writeObjects(objects) }
    }
    private func restoreLater(_ items: [[NSPasteboard.PasteboardType: Data]], after change: Int) {
        pendingRestore = (items, change)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.restoreDelay) { [weak self] in
            // A later paste or a new copy by the user has already replaced the clipboard (B10).
            guard let self, NSPasteboard.general.changeCount == change else { return }
            self.restore(items)
        }
    }
}
