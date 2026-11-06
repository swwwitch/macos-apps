import AppKit
import ApplicationServices

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

enum TargetKind: Sendable { case accessibilityText, googleDocs }

/// What the window shows about the document being worked on.
struct TargetInfo: Equatable, Sendable {
    let pid: pid_t
    let appName: String
    let title: String
    let kind: TargetKind
}

enum TargetError: LocalizedError {
    case notTrusted, noText, documentChanged, notFront, interrupted, bodyNotFocused, copyFailed, findBarFailed, findCountDiffers, writeIgnored, bulkUnavailable

    var errorDescription: String? {
        switch self {
        case .notTrusted: return L("error.notTrusted")
        case .noText: return L("error.noText")
        case .documentChanged: return L("error.documentChanged")
        case .notFront: return L("error.notFront")
        case .interrupted: return L("error.interrupted")
        case .bodyNotFocused: return L("error.bodyNotFocused")
        case .copyFailed: return L("error.copyFailed")
        case .findBarFailed: return L("error.findBarFailed")
        case .findCountDiffers: return L("error.findCountDiffers")
        case .writeIgnored: return L("error.writeIgnored")
        case .bulkUnavailable: return L("error.bulkUnavailable")
        }
    }
}

/// Result of replacing. A stop reason means the run ended early; `replaced` still lists what was changed.
struct ReplaceOutcome {
    var replaced: [Match] = []
    var skipped = 0
    var stopReason: String?
    /// The text after replacing when it is known without reading the target again.
    var text: String?
    /// False when a replacement may have happened without being confirmed: offsets can no longer be trusted.
    var isReliable = true
    /// Done with Docs' own 「すべて置換」: one undo takes it all back.
    var usedBulkReplace = false
}

/// A document whose whole text can be read, shown and changed.
protocol TextTarget: AnyObject {
    var info: TargetInfo { get }
    /// Selecting a match needs the target in front (Google Docs) or works from behind (Accessibility text).
    var showsInBackground: Bool { get }
    /// True for the same document, even when its window title changed by being edited.
    func isSameDocument(as other: TextTarget) -> Bool
    func readAll() throws -> String
    func selectedText() throws -> String
    func show(_ match: Match, keyword: String, in text: String) throws
    func replace(_ plan: [Match], keywords: [String], with replacement: String, in text: String,
                 progress: @escaping (Int) -> Void, isCancelled: @escaping () -> Bool) -> ReplaceOutcome
}

enum AX {
    static func value(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success ? result : nil
    }
    static func string(_ element: AXUIElement, _ name: String) -> String? { value(element, name) as? String }
    static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let result = value(element, name), CFGetTypeID(result) == AXUIElementGetTypeID() else { return nil }
        return (result as! AXUIElement)
    }
    static func children(_ element: AXUIElement) -> [AXUIElement] { value(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] }
    static func range(_ range: NSRange) -> AXValue {
        var cfRange = CFRange(location: range.location, length: range.length)
        return AXValueCreate(.cfRange, &cfRange)!
    }
    static func string(in element: AXUIElement, range: NSRange) -> String? {
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString, Self.range(range), &result) == .success else { return nil }
        return result as? String
    }
    static func window(of app: AXUIElement) -> AXUIElement? {
        element(app, kAXFocusedWindowAttribute) ?? element(app, kAXMainWindowAttribute) ?? (value(app, kAXWindowsAttribute) as? [AXUIElement])?.first
    }
    /// Waits for a condition without spinning. Runs off the main thread.
    @discardableResult static func wait(_ timeout: TimeInterval, every step: TimeInterval = 0.03, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if condition() { return true }
            if Date() >= deadline { return false }
            Thread.sleep(forTimeInterval: step)
        }
    }
}

enum TargetDetector {
    static let browsers: Set<String> = ["com.apple.Safari", "com.apple.SafariTechnologyPreview", "com.google.Chrome", "com.google.Chrome.canary",
                                        "org.mozilla.firefox", "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser", "com.vivaldi.Vivaldi"]

    /// The document open in the front window of an app, or nil when it has no text this app can read.
    static func resolve(_ app: NSRunningApplication) -> TextTarget? {
        guard AXIsProcessTrusted() else { return nil }
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1.5)
        let element = AXUIElementCreateApplication(app.processIdentifier)
        let name = app.localizedName ?? ""
        let isBrowser = browsers.contains(app.bundleIdentifier ?? "")
        // Chromium builds its accessibility tree only on request.
        if isBrowser { AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue) }
        guard let window = AX.window(of: element) else { return nil }
        let title = AX.string(window, kAXTitleAttribute) ?? ""
        if isBrowser {
            guard let url = pageURL(in: window), isGoogleDocument(url) else { return nil }
            return GoogleDocsTarget(app: app, axApp: element, window: window, windowTitle: title, appName: name)
        }
        guard let area = textArea(app: element, window: window) else { return nil }
        return AccessibilityTextTarget(area: area, info: TargetInfo(pid: app.processIdentifier, appName: name, title: title, kind: .accessibilityText))
    }

    static func isGoogleDocument(_ url: URL) -> Bool {
        guard url.host == "docs.google.com" else { return false }
        let parts = url.pathComponents
        guard let document = parts.firstIndex(of: "document"), parts.indices.contains(document + 2) else { return false }
        return parts[document + 1] == "d"
    }

    /// The first web area of a window. Its contents are not searched: they can be very large.
    private static func pageURL(in window: AXUIElement) -> URL? {
        var queue = [window]
        var visited = 0
        while !queue.isEmpty, visited < 600 {
            let element = queue.removeFirst()
            visited += 1
            if AX.string(element, kAXRoleAttribute) == "AXWebArea" {
                let raw = AX.value(element, "AXURL")
                if let url = raw as? URL { return url }
                if let text = raw as? String, let url = URL(string: text) { return url }
                continue
            }
            queue += AX.children(element)
        }
        return nil
    }

    /// A text field on a web page or in an Electron app shows only part of the document (VS Code: the visible lines).
    private static func isInWebContent(_ element: AXUIElement) -> Bool {
        var current = element
        for _ in 0..<60 {
            guard let parent = AX.element(current, kAXParentAttribute) else { return false }
            if AX.string(parent, kAXRoleAttribute) == "AXWebArea" { return true }
            current = parent
        }
        return false
    }

    /// The focused text area, otherwise the longest text area of the window. Text inside web content is left out.
    private static func textArea(app: AXUIElement, window: AXUIElement) -> AXUIElement? {
        if let focused = AX.element(app, kAXFocusedUIElementAttribute), AX.string(focused, kAXRoleAttribute) == kAXTextAreaRole, AX.string(focused, kAXValueAttribute) != nil {
            return isInWebContent(focused) ? nil : focused
        }
        var queue = [window]
        var visited = 0
        var best: (element: AXUIElement, length: Int)?
        while !queue.isEmpty, visited < 1500 {
            let element = queue.removeFirst()
            visited += 1
            let role = AX.string(element, kAXRoleAttribute)
            if role == "AXWebArea" { continue }
            if role == kAXTextAreaRole, let text = AX.string(element, kAXValueAttribute) {
                let length = (text as NSString).length
                if best == nil || length > best!.length { best = (element, length) }
                continue
            }
            queue += AX.children(element)
        }
        return best?.element
    }
}

/// A native text view (TextEdit and the like): read, selected and changed through Accessibility, even from behind.
final class AccessibilityTextTarget: TextTarget {
    let info: TargetInfo
    let showsInBackground = true
    private let area: AXUIElement

    init(area: AXUIElement, info: TargetInfo) { self.area = area; self.info = info }

    func isSameDocument(as other: TextTarget) -> Bool {
        guard let other = other as? AccessibilityTextTarget else { return false }
        return CFEqual(area, other.area)
    }

    func readAll() throws -> String {
        guard let text = AX.string(area, kAXValueAttribute) else { throw TargetError.noText }
        return text
    }
    func selectedText() throws -> String { AX.string(area, kAXSelectedTextAttribute) ?? "" }

    private func currentText(in range: NSRange) -> String? {
        if let text = AX.string(in: area, range: range) { return text }
        guard let whole = AX.string(area, kAXValueAttribute) as NSString?, NSMaxRange(range) <= whole.length else { return nil }
        return whole.substring(with: range)
    }
    private func select(_ range: NSRange) -> Bool {
        AXUIElementSetAttributeValue(area, kAXSelectedTextRangeAttribute as CFString, AX.range(range)) == .success
    }

    func show(_ match: Match, keyword: String, in text: String) throws {
        guard select(match.range) else { throw TargetError.writeIgnored }
        // Selecting scrolls TextEdit; other apps may need the visible range too.
        AXUIElementSetAttributeValue(area, kAXVisibleCharacterRangeAttribute as CFString, AX.range(match.range))
    }

    func replace(_ plan: [Match], keywords: [String], with replacement: String, in text: String,
                 progress: @escaping (Int) -> Void, isCancelled: @escaping () -> Bool) -> ReplaceOutcome {
        var outcome = ReplaceOutcome()
        let length = (replacement as NSString).length
        for (index, match) in plan.enumerated() {
            if isCancelled() { outcome.stopReason = L("status.cancelled"); break }
            progress(index)
            guard currentText(in: match.range) == match.text else { outcome.skipped += 1; continue }
            guard select(match.range), AXUIElementSetAttributeValue(area, kAXSelectedTextAttribute as CFString, replacement as CFString) == .success,
                  AX.wait(0.5, until: { length == 0 || currentText(in: NSRange(location: match.range.location, length: length)) == replacement }) else {
                outcome.stopReason = TargetError.writeIgnored.errorDescription
                outcome.isReliable = false
                break
            }
            outcome.replaced.append(match)
        }
        return outcome
    }
}

/// Keeps the clipboard across keystroke work and gives it back unless something else copied in the meantime.
final class ClipboardKeeper {
    private let board = NSPasteboard.general
    private var saved: [[NSPasteboard.PasteboardType: Data]] = []
    private var lastOwnChange = 0

    func save() {
        saved = (board.pasteboardItems ?? []).map { item in
            var copy: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let data = item.data(forType: type) { copy[type] = data } }
            return copy
        }
        lastOwnChange = board.changeCount
    }
    func put(_ text: String) {
        board.clearContents()
        board.setString(text, forType: .string)
        // Clipboard history apps skip this entry (nspasteboard.org).
        board.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        lastOwnChange = board.changeCount
    }
    /// Waits for a copy made by the target app and returns its text.
    func waitForCopy(after change: Int, timeout: TimeInterval) -> String? {
        guard AX.wait(timeout, until: { board.changeCount != change }) else { return nil }
        var text: String?
        AX.wait(0.5) { text = board.string(forType: .string); return text != nil }
        lastOwnChange = board.changeCount
        return text
    }
    var changeCount: Int { board.changeCount }
    func restore() {
        guard board.changeCount == lastOwnChange else { return }
        board.clearContents()
        let items = saved.map { copy -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in copy { item.setData(data, forType: type) }
            return item
        }
        if !items.isEmpty { board.writeObjects(items) }
    }
}

/// A Google Docs page. The body is drawn on a canvas and its text is not in the Accessibility tree (measured 2026-11-06),
/// so it is reached with the keys anyone would press: ⌘A ⌘C to read, Docs' own find bar to reach a match, ⌘V to change it.
/// Every key checks that the same window is still in front, and a change happens only after the selection was copied and compared.
final class GoogleDocsTarget: TextTarget {
    let info: TargetInfo
    let showsInBackground = false
    private let app: NSRunningApplication
    private let axApp: AXUIElement
    private let window: AXUIElement
    private let windowTitle: String
    private let clipboard = ClipboardKeeper()

    private enum Key { static let a: CGKeyCode = 0, c: CGKeyCode = 8, v: CGKeyCode = 9, f: CGKeyCode = 3, left: CGKeyCode = 123, right: CGKeyCode = 124, escape: CGKeyCode = 53, enter: CGKeyCode = 36, delete: CGKeyCode = 51, h: CGKeyCode = 4, tab: CGKeyCode = 48 }

    init(app: NSRunningApplication, axApp: AXUIElement, window: AXUIElement, windowTitle: String, appName: String) {
        self.app = app; self.axApp = axApp; self.window = window; self.windowTitle = windowTitle
        info = TargetInfo(pid: app.processIdentifier, appName: appName, title: Self.documentName(windowTitle), kind: .googleDocs)
    }

    func isSameDocument(as other: TextTarget) -> Bool {
        guard let other = other as? GoogleDocsTarget else { return false }
        return info.pid == other.info.pid && windowTitle == other.windowTitle
    }

    /// 「名前 - Google ドキュメント」 → 「名前」, whatever language Docs is in.
    static func documentName(_ title: String) -> String {
        guard let range = title.range(of: " - ", options: .backwards) else { return title }
        return String(title[..<range.lowerBound])
    }

    private var isInFront: Bool {
        (AX.value(axApp, kAXFrontmostAttribute) as? Bool) == true && AX.window(of: axApp).flatMap { AX.string($0, kAXTitleAttribute) } == windowTitle
    }
    private var focused: AXUIElement? { AX.element(axApp, kAXFocusedUIElementAttribute) }
    private var focusedRole: String? { focused.flatMap { AX.string($0, kAXRoleAttribute) } }

    private func press(_ key: CGKeyCode, _ flags: CGEventFlags = []) throws {
        guard isInFront else { throw TargetError.interrupted }
        let source = CGEventSource(stateID: .privateState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true), let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else { throw TargetError.interrupted }
        down.flags = flags; up.flags = flags
        down.postToPid(app.processIdentifier); up.postToPid(app.processIdentifier)
    }

    /// Brings the document forward for `body`, then gives back the clipboard and the focus.
    private func session<T>(_ body: () throws -> T) throws -> T {
        guard AXIsProcessTrusted() else { throw TargetError.notTrusted }
        clipboard.save()
        defer {
            clipboard.restore()
            DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
        }
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        app.activate(options: [.activateIgnoringOtherApps])
        guard AX.wait(2, until: { isInFront }) else { throw TargetError.notFront }
        Thread.sleep(forTimeInterval: 0.15)
        return try body()
    }

    /// The document body takes the keys. Esc leaves the find bar or a menu; anything else needs a click from the user.
    private func focusBody() throws {
        if focusedRole == kAXTextAreaRole { return }
        try press(Key.escape)
        guard AX.wait(0.8, until: { focusedRole == kAXTextAreaRole }) else { throw TargetError.bodyNotFocused }
    }

    private func copySelection(timeout: TimeInterval) throws -> String? {
        let change = clipboard.changeCount
        try press(Key.c, .maskCommand)
        return clipboard.waitForCopy(after: change, timeout: timeout)
    }

    func readAll() throws -> String {
        try session {
            try focusBody()
            try press(Key.a, .maskCommand)
            Thread.sleep(forTimeInterval: 0.15)
            let copied = try? copySelection(timeout: 5)
            // Never leave everything selected: the next key would replace the document.
            try press(Key.left)
            guard let text = copied else { throw TargetError.copyFailed }
            return text
        }
    }

    func selectedText() throws -> String {
        try session {
            try focusBody()
            return try copySelection(timeout: 0.6) ?? ""
        }
    }

    /// The find bar's 「2 / 5」, found near the focused field. Its words differ by language, its two numbers do not.
    private func findPosition() -> (current: Int, total: Int)? {
        guard var element = focused else { return nil }
        for _ in 0..<5 {
            guard let parent = AX.element(element, kAXParentAttribute) else { return nil }
            element = parent
            var queue = [element]
            var visited = 0
            while !queue.isEmpty, visited < 80 {
                let next = queue.removeFirst()
                visited += 1
                if AX.string(next, kAXRoleAttribute) == kAXStaticTextRole, let text = AX.string(next, kAXValueAttribute), let position = Self.parsePosition(text) { return position }
                queue += AX.children(next)
            }
        }
        return nil
    }

    static func parsePosition(_ text: String) -> (current: Int, total: Int)? {
        let numbers = text.split(whereSeparator: { !$0.isNumber })
        guard numbers.count == 2, text.count <= 24, let current = Int(numbers[0]), let total = Int(numbers[1]) else { return nil }
        return (current, total)
    }

    /// Opens the find bar on a keyword and returns its position once the count settles at `total`.
    private func openFindBar(keyword: String, total: Int) throws -> (current: Int, total: Int) {
        try press(Key.f, .maskCommand)
        guard AX.wait(1.5, until: { focusedRole == kAXTextFieldRole }) else { throw TargetError.findBarFailed }
        // Only inside the find field: ⌘A and ⌘V must never reach the body here.
        try press(Key.a, .maskCommand)
        Thread.sleep(forTimeInterval: 0.05)
        clipboard.put(keyword)
        guard focusedRole == kAXTextFieldRole else { throw TargetError.findBarFailed }
        try press(Key.v, .maskCommand)
        guard AX.wait(1.5, until: { focused.flatMap { AX.string($0, kAXValueAttribute) } == keyword }) else { throw TargetError.findBarFailed }

        // The count settles shortly after the field changes.
        var last: (current: Int, total: Int)?
        let settled = AX.wait(2, every: 0.08) {
            let now = findPosition()
            defer { last = now }
            return now?.total == total && last?.total == total
        }
        guard settled, let start = last else {
            try? press(Key.escape)
            throw TargetError.findCountDiffers
        }
        return start
    }

    /// Selects one hit of the find bar and proves it by copying it. Throws when the document no longer matches what was read.
    private func select(keyword: String, index: Int, total: Int, expected: String) throws {
        let start = try openFindBar(keyword: keyword, total: total)

        let wanted = index + 1
        for attempt in 0..<2 {
            let current = attempt == 0 ? start.current : (findPosition()?.current ?? start.current)
            if current == wanted { break }
            let forward = (wanted - current + total) % total
            let backward = total - forward
            for _ in 0..<min(forward, backward) {
                try press(Key.enter, forward <= backward ? [] : .maskShift)
                Thread.sleep(forTimeInterval: 0.03)
            }
            if AX.wait(1.5, until: { findPosition()?.current == wanted }) { break }
        }
        guard findPosition()?.current == wanted else {
            try? press(Key.escape)
            throw TargetError.findBarFailed
        }
        try press(Key.escape)
        guard AX.wait(1, until: { focusedRole == kAXTextAreaRole }) else { throw TargetError.bodyNotFocused }
        guard try copySelection(timeout: 1) == expected else {
            try? press(Key.right)
            throw TargetError.findCountDiffers
        }
    }

    func show(_ match: Match, keyword: String, in text: String) throws {
        guard let position = Matcher.findBarPosition(of: match.range, keyword: keyword, in: text as NSString) else { throw TargetError.findCountDiffers }
        try session {
            try focusBody()
            try select(keyword: keyword, index: position.index, total: position.total, expected: match.text)
        }
    }

    /// Pastes over the selection, then reads back what is now before the cursor.
    private func paste(_ replacement: String) throws {
        guard focusedRole == kAXTextAreaRole else { throw TargetError.bodyNotFocused }
        if replacement.isEmpty {
            try press(Key.delete)
            Thread.sleep(forTimeInterval: 0.2)
            return
        }
        clipboard.put(replacement)
        try press(Key.v, .maskCommand)
        Thread.sleep(forTimeInterval: 0.3)
        for _ in 0..<replacement.count { try press(Key.left, .maskShift) }
        Thread.sleep(forTimeInterval: 0.12)
        let written = try copySelection(timeout: 1)
        try press(Key.right)
        guard written == replacement else { throw TargetError.writeIgnored }
    }

    /// The keywords for 「すべて置換」, when it would give exactly the text that replacing one by one gives.
    /// It also rewrites what the plan leaves out (excluded rows, 「サーバ」 inside 「サーバー」), so the two results are compared first.
    static func bulkKeywords(_ plan: [Match], keywords: [String], replacement: String, text: String) -> (order: [String], expected: String)? {
        guard plan.count >= 2 else { return nil }
        let expected = NSMutableString(string: text)
        for match in plan.sorted(by: { $0.range.location > $1.range.location }) { expected.replaceCharacters(in: match.range, with: replacement) }
        let order = Set(plan.map { keywords[$0.keywordIndex] }).sorted { ($0 as NSString).length > ($1 as NSString).length }
        let simulated = order.reduce(text) { $0.replacingOccurrences(of: $1, with: replacement, options: .literal) }
        return simulated == expected as String ? (order, expected as String) : nil
    }

    private func descendants(of root: AXUIElement) -> [AXUIElement] {
        var queue = [root]
        var found: [AXUIElement] = []
        while !queue.isEmpty, found.count < 150 {
            let element = queue.removeFirst()
            found.append(element)
            queue += AX.children(element)
        }
        return found
    }

    private func isFocused(_ element: AXUIElement) -> Bool { focused.map { CFEqual($0, element) } ?? false }

    /// Puts text in one field of the dialog. Keys go out only while that very field has the focus.
    private func fill(_ field: AXUIElement, with text: String) throws {
        AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        if !AX.wait(0.5, until: { isFocused(field) }) { try press(Key.tab) }
        guard AX.wait(0.8, until: { isFocused(field) }) else { throw TargetError.bulkUnavailable }
        try press(Key.a, .maskCommand)
        Thread.sleep(forTimeInterval: 0.05)
        guard isFocused(field) else { throw TargetError.bulkUnavailable }
        if text.isEmpty { try press(Key.delete) } else { clipboard.put(text); try press(Key.v, .maskCommand) }
        guard AX.wait(1.5, until: { (AX.string(field, kAXValueAttribute) ?? "") == text }) else { throw TargetError.bulkUnavailable }
    }

    private func setCheckbox(_ box: AXUIElement, _ on: Bool) throws {
        func isOn() -> Bool { (AX.value(box, kAXValueAttribute) as? NSNumber)?.boolValue ?? false }
        guard isOn() != on else { return }
        AXUIElementPerformAction(box, kAXPressAction as CFString)
        guard AX.wait(0.8, until: { isOn() == on }) else { throw TargetError.bulkUnavailable }
    }

    /// Docs' 「検索と置換」 with 「大文字と小文字を区別」 on and the rest off, so that it matches the text literally.
    /// Throws bulkUnavailable before anything changes when the dialog is not the one measured (2026-11-06) or spans tabs.
    private func replaceAll(_ keyword: String, with replacement: String) throws {
        try press(Key.h, [.maskCommand, .maskShift])
        var dialog: AXUIElement?
        AX.wait(1.5) {
            var element = focused
            while let current = element {
                if AX.string(current, kAXSubroleAttribute) == "AXApplicationDialog" { dialog = current; return true }
                element = AX.element(current, kAXParentAttribute)
            }
            return false
        }
        guard let dialog else { throw TargetError.bulkUnavailable }
        let elements = descendants(of: dialog)
        func role(_ name: String) -> [AXUIElement] { elements.filter { AX.string($0, kAXRoleAttribute) == name } }
        let fields = role(kAXTextFieldRole), boxes = role(kAXCheckBoxRole), buttons = role(kAXButtonRole)
        // Close, Replace, Replace all, Previous, Next. A document with tabs adds a scope choice, which is left to the one-by-one way.
        guard fields.count == 2, boxes.count == 3, buttons.count == 5, role(kAXRadioButtonRole).isEmpty else {
            try? press(Key.escape)
            throw TargetError.bulkUnavailable
        }
        let saved = boxes.map { (AX.value($0, kAXValueAttribute) as? NSNumber)?.boolValue ?? false }
        defer {
            for (box, value) in zip(boxes, saved) { try? setCheckbox(box, value) }
            try? press(Key.escape)
        }
        try setCheckbox(boxes[0], true)
        try setCheckbox(boxes[1], false)
        try setCheckbox(boxes[2], false)
        try fill(fields[0], with: keyword)
        try fill(fields[1], with: replacement)
        guard AX.wait(1.5, until: { (AX.value(buttons[2], kAXEnabledAttribute) as? Bool) == true }), isInFront else { throw TargetError.bulkUnavailable }
        AXUIElementPerformAction(buttons[2], kAXPressAction as CFString)
        Thread.sleep(forTimeInterval: 0.7)
    }

    /// Runs 「すべて置換」 per keyword and reads the body back. False when it could not start and nothing changed.
    private func replaceInBulk(_ bulk: (order: [String], expected: String), plan: [Match], replacement: String, text: String, outcome: inout ReplaceOutcome) throws -> Bool {
        var current = text
        for (index, keyword) in bulk.order.enumerated() {
            // The count also covers other cases of the word and catches hits outside the body.
            let total = Matcher.ranges(of: keyword, in: current as NSString, caseSensitive: false).count
            _ = try openFindBar(keyword: keyword, total: total)
            try press(Key.escape)
            guard AX.wait(1, until: { focusedRole == kAXTextAreaRole }) else { throw TargetError.bodyNotFocused }
            do { try replaceAll(keyword, with: replacement) } catch TargetError.bulkUnavailable where index == 0 { return false }
            guard AX.wait(1.5, until: { focusedRole == kAXTextAreaRole }) else { outcome.isReliable = false; throw TargetError.bodyNotFocused }
            current = current.replacingOccurrences(of: keyword, with: replacement, options: .literal)
        }
        try press(Key.a, .maskCommand)
        Thread.sleep(forTimeInterval: 0.15)
        let copied = try? copySelection(timeout: 5)
        try press(Key.left)
        outcome.usedBulkReplace = true
        guard let copied else { outcome.isReliable = false; throw TargetError.copyFailed }
        outcome.text = copied
        if copied == bulk.expected { outcome.replaced = plan } else {
            outcome.isReliable = false
            outcome.stopReason = L("error.bulkDiffers")
        }
        return true
    }

    func replace(_ plan: [Match], keywords: [String], with replacement: String, in text: String,
                 progress: @escaping (Int) -> Void, isCancelled: @escaping () -> Bool) -> ReplaceOutcome {
        var outcome = ReplaceOutcome()
        let model = NSMutableString(string: text)
        do {
            try session {
                try focusBody()
                if let bulk = Self.bulkKeywords(plan, keywords: keywords, replacement: replacement, text: text),
                   try replaceInBulk(bulk, plan: plan, replacement: replacement, text: text, outcome: &outcome) { return }
                for (index, match) in plan.enumerated() {
                    if isCancelled() { outcome.stopReason = L("status.cancelled"); return }
                    progress(index)
                    let keyword = keywords[match.keywordIndex]
                    guard let position = Matcher.findBarPosition(of: match.range, keyword: keyword, in: model) else { outcome.skipped += 1; continue }
                    try select(keyword: keyword, index: position.index, total: position.total, expected: match.text)
                    do { try paste(replacement) } catch { outcome.isReliable = false; throw error }
                    model.replaceCharacters(in: match.range, with: replacement)
                    outcome.replaced.append(match)
                }
            }
        } catch {
            outcome.stopReason = error.localizedDescription
        }
        if !outcome.usedBulkReplace { outcome.text = model as String }
        return outcome
    }
}
