import AppKit
import ApplicationServices
import Carbon

/// Result of one ⌥⌘C run. Only the app name and counts are kept, never the clipboard text (B12).
enum CleanOutcome {
    case cleaned(appName: String, changed: Bool)
    case failed(String)
}

/// Sends ⌘C to the target, waits for the clipboard to change, then writes the cleaned plain text back.
/// The text representations of the copied content are kept in memory only, for 「元のコピー内容に戻す」.
final class ClipboardCleaner {
    static let copyTimeout: TimeInterval = 1.0
    private static let poll: TimeInterval = 0.02
    /// Some apps write several representations right after bumping changeCount.
    private static let settle: TimeInterval = 0.05
    /// Kept for restore: text-like types only (Excel also offers large images/PDF that would be slow to read).
    private static let restorableTypes: [NSPasteboard.PasteboardType] = [.string, .html, .rtf, .tabularText]

    private(set) var busy = false
    private var original: (items: [NSPasteboard.PasteboardType: Data], written: Int)?
    var canRestore: Bool { original != nil && original?.written == NSPasteboard.general.changeCount }

    /// `stillTarget` is checked right before ⌘C is sent (the front app may have changed since the key press).
    func run(target: TargetApp, appName: String, pid: pid_t, replaceApostrophe: Bool,
             stillTarget: () -> Bool, completion: @escaping (CleanOutcome) -> Void) {
        guard !busy else { return }
        guard AXIsProcessTrusted() else { completion(.failed(L("fail.access"))); return }
        guard stillTarget() else { completion(.failed(L("fail.target"))); return }
        let pasteboard = NSPasteboard.general
        let before = pasteboard.changeCount
        guard Self.sendCopy(to: pid) else { completion(.failed(L("fail.event"))); return }
        busy = true
        let deadline = Date().addingTimeInterval(Self.copyTimeout)
        func wait() {
            if pasteboard.changeCount != before {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.settle) { [weak self] in
                    guard let self else { return }
                    self.busy = false
                    completion(self.rewrite(profile: target.profile, appName: appName, replaceApostrophe: replaceApostrophe))
                }
            } else if Date() >= deadline {
                busy = false
                completion(.failed(L("fail.timeout")))
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.poll) { wait() }
            }
        }
        wait()
    }

    /// ⌘C straight to the target process with explicit flags, so the held ⌥ of ⌥⌘C does not leak in
    /// (same method as KakkoReplace/MightyEdit's ⌘V). Key code 8 = the C key position.
    private static func sendCopy(to pid: pid_t) -> Bool {
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false) else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(pid)
        up.postToPid(pid)
        return true
    }

    /// Title of the target's focused window via AX (no Automation permission needed); nil if unreadable.
    static func focusedWindowTitle(pid: pid_t) -> String? {
        let app = AXUIElementCreateApplication(pid)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window, CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success else { return nil }
        return title as? String
    }

    /// Gives the pressed key back to the browser when no Google Sheets window is in front (e.g. Chrome's ⌥⌘C).
    /// Posted to the process directly, so it does not hit our own hotkey again.
    static func passThrough(_ shortcut: Shortcut, to pid: pid_t) {
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(shortcut.code), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(shortcut.code), keyDown: false) else { return }
        var flags: CGEventFlags = []
        if shortcut.modifiers & UInt32(cmdKey) != 0 { flags.insert(.maskCommand) }
        if shortcut.modifiers & UInt32(optionKey) != 0 { flags.insert(.maskAlternate) }
        if shortcut.modifiers & UInt32(controlKey) != 0 { flags.insert(.maskControl) }
        if shortcut.modifiers & UInt32(shiftKey) != 0 { flags.insert(.maskShift) }
        down.flags = flags
        up.flags = flags
        down.postToPid(pid)
        up.postToPid(pid)
    }

    private func rewrite(profile: CleanProfile, appName: String, replaceApostrophe: Bool) -> CleanOutcome {
        let pasteboard = NSPasteboard.general
        let copied = pasteboard.changeCount
        guard let text = pasteboard.string(forType: .string) else { return .failed(L("fail.noText")) }
        var saved: [NSPasteboard.PasteboardType: Data] = [:]
        for type in Self.restorableTypes { if let data = pasteboard.data(forType: type) { saved[type] = data } }
        let cleaned = CleanRules.clean(text, profile: profile, replaceApostrophe: replaceApostrophe)
        // Never overwrite a newer copy made by someone else meanwhile (B10).
        guard pasteboard.changeCount == copied else { return .failed(L("fail.changed")) }
        pasteboard.clearContents()
        guard pasteboard.setString(cleaned, forType: .string) else { return .failed(L("fail.write")) }
        original = (saved, pasteboard.changeCount)
        return .cleaned(appName: appName, changed: cleaned != text)
    }

    /// Puts back the copied content (text representations) if nothing was copied after our rewrite.
    func restore() -> Bool {
        guard canRestore, let original else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        for (type, data) in original.items { item.setData(data, forType: type) }
        let written = original.items.isEmpty ? true : pasteboard.writeObjects([item])
        self.original = nil
        return written
    }
}
