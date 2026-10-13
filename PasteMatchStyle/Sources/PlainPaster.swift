import AppKit
import ApplicationServices

/// Result of one paste. Only the app name and the menu title are kept for the status, never the text (B12).
enum PasteOutcome {
    /// The app's own menu item (「ペーストしてスタイルを合わせる」 etc.) was pressed.
    case menu(appName: String, title: String)
    /// Plain text was put on the clipboard and ⌘V was sent.
    case plain(appName: String)
    case failed(String)
}

/// ⇧⌘V: the front app's own "paste and match style" menu item when it has one (the KM macros), otherwise
/// the clipboard's text alone and ⌘V. The user's clipboard is put back afterwards unless that is turned off.
final class PlainPaster {
    /// The target reads the clipboard asynchronously after ⌘V; the user's clipboard is restored after this.
    static let restoreDelay: TimeInterval = 1.0

    /// The user's clipboard taken before our own write, and the changeCount of that write.
    /// A second press within the delay keeps the snapshot from the first one.
    private var pendingRestore: (items: [[NSPasteboard.PasteboardType: Data]], change: Int)?

    /// `stillTarget` is checked before the menu item is pressed and again right before ⌘V is sent (B21).
    func paste(appName: String, pid: pid_t, useMenu: Bool, titles: [String], restoreClipboard: Bool,
               stillTarget: () -> Bool) -> PasteOutcome {
        guard AXIsProcessTrusted() else { return .failed(L("fail.access")) }
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return .failed(L("fail.noText")) }
        guard stillTarget() else { return .failed(L("fail.target")) }
        if useMenu, let found = MenuSearch.find(pid: pid, titles: titles),
           AXUIElementPerformAction(found.element, kAXPressAction as CFString) == .success {
            return .menu(appName: appName, title: found.title)
        }
        guard stillTarget() else { return .failed(L("fail.target")) }
        guard let events = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: events, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: events, virtualKey: 9, keyDown: false) else { return .failed(L("fail.event")) }
        let saved = takeSnapshot()
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { restore(saved); return .failed(L("fail.write")) }
        // Explicit flags, so the held ⇧ of ⇧⌘V does not leak into ⌘V. Key code 9 = V.
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(pid)
        up.postToPid(pid)
        if restoreClipboard { restoreLater(saved, after: pasteboard.changeCount) } else { pendingRestore = nil }
        return .plain(appName: appName)
    }

    /// The KM 「Remove Styles」 filter on its own: the clipboard keeps only its text.
    func stripClipboard() -> Bool {
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return false }
        pendingRestore = nil
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
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

/// Finds an enabled menu item with one of the titles in the app's menu bar (Accessibility).
enum MenuSearch {
    struct Found { let element: AXUIElement; let title: String }

    static func find(pid: pid_t, titles: [String]) -> Found? {
        let wanted = Set(titles.map(MenuTitles.normalize).filter { !$0.isEmpty })
        guard !wanted.isEmpty else { return nil }
        let app = AXUIElementCreateApplication(pid)
        // A busy app must not hold up the hotkey; ⌘V is used instead.
        AXUIElementSetMessagingTimeout(app, 0.5)
        guard let bar: AXUIElement = value(app, kAXMenuBarAttribute) else { return nil }
        // The Apple menu is skipped; the Edit menu is searched first and one level deeper.
        let tops = Array(children(bar).dropFirst())
        let isEdit: (AXUIElement) -> Bool = { MenuTitles.editMenuNames.contains(MenuTitles.normalize(value($0, kAXTitleAttribute) ?? "")) }
        for top in tops where isEdit(top) { if let found = search(top, wanted, depth: 1) { return found } }
        for top in tops where !isEdit(top) { if let found = search(top, wanted, depth: 0) { return found } }
        return nil
    }

    /// `element` is a menu bar item or a menu item with a submenu; its child is the AXMenu.
    private static func search(_ element: AXUIElement, _ wanted: Set<String>, depth: Int) -> Found? {
        for menu in children(element) {
            for item in children(menu) {
                let title: String = value(item, kAXTitleAttribute) ?? ""
                if wanted.contains(MenuTitles.normalize(title)) {
                    // A disabled item is skipped; ⌘V with plain text is used instead.
                    if (value(item, kAXEnabledAttribute) as Bool?) == true { return Found(element: item, title: title) }
                } else if depth > 0, !children(item).isEmpty, let found = search(item, wanted, depth: depth - 1) {
                    return found
                }
            }
        }
        return nil
    }

    private static func value<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result as? T
    }
    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        value(element, kAXChildrenAttribute) ?? []
    }
}
