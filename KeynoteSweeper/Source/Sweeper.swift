import AppKit
@preconcurrency import ApplicationServices
import Foundation

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// What the front Keynote presentation contains, read through Apple Events.
struct KeynoteSnapshot: Equatable {
    var documentID: String
    var documentName: String
    var layouts: [String]
    var slideLayouts: [String]
    var skipped: [Bool]
    /// Per slide: has a transition effect.
    var transitions: [Bool] = []

    var hiddenCount: Int { skipped.filter { $0 }.count }
    /// Slides with a transition, leaving out hidden slides that are about to be deleted.
    func transitionCount(ignoringHidden: Bool) -> Int {
        zip(transitions, skipped).filter { $0.0 && !(ignoringHidden && $0.1) }.count
    }
    var allHidden: Bool { !skipped.isEmpty && skipped.allSatisfy { $0 } }
    /// Layouts no visible-or-hidden slide uses. Slides about to be deleted can be excluded first.
    func unusedLayoutIndexes(ignoringHidden: Bool) -> [Int] { SweepPlan.unusedLayoutIndexes(layouts: layouts, used: usedLayouts(ignoringHidden: ignoringHidden)) }
    func usedLayouts(ignoringHidden: Bool) -> Set<String> {
        Set(zip(slideLayouts, skipped).filter { !(ignoringHidden && $0.1) }.map(\.0))
    }
}

enum SweepPlan {
    /// 1-based indexes of unused layouts, last first so earlier indexes stay valid while deleting.
    /// Keynote refers to layouts by name, so a name that is used keeps every layout of that name.
    static func unusedLayoutIndexes(layouts: [String], used: Set<String>) -> [Int] {
        guard !layouts.isEmpty else { return [] }
        let unused = layouts.indices.filter { !used.contains(layouts[$0]) }.map { $0 + 1 }
        // Keynote needs at least one layout.
        return unused.count == layouts.count ? [] : unused.reversed()
    }
    /// Arrow presses to go from one navigator row to another (positive = down).
    static func steps(from: Int, to: Int) -> Int { to - from }
    /// "スライドレイアウトを編集: タイトル" → "タイトル".
    static func layoutName(fromInspectorTitle title: String) -> String? {
        guard let range = title.range(of: ": ") else { return nil }
        let name = String(title[range.upperBound...])
        return name.isEmpty ? nil : name
    }
}

enum SweepError: LocalizedError, Equatable {
    case keynoteMissing, noDocument, automationDenied, accessibilityDenied, allHidden
    case editorUnavailable, documentChanged, interrupted
    case keynote(String)
    var errorDescription: String? {
        switch self {
        case .keynoteMissing: return L("keynoteMissing")
        case .noDocument: return L("noDocument")
        case .automationDenied: return L("automationDenied")
        case .accessibilityDenied: return L("accessibilityDenied")
        case .allHidden: return L("allHidden")
        case .editorUnavailable: return L("editorUnavailable")
        case .documentChanged: return L("documentChanged")
        case .interrupted: return L("interrupted")
        case .keynote(let message): return L("keynoteError") + message
        }
    }
}

/// Apple Events to Keynote. NSAppleScript is not thread-safe, so every call hops to the main thread.
enum KeynoteDOM {
    static let bundleID = "com.apple.Keynote"
    static var isInstalled: Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil }
    static var runningApp: NSRunningApplication? { NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first }

    /// The given presentation, or the front one when `documentID` is nil. Nil when it is not open.
    static func snapshot(documentID: String? = nil) throws -> KeynoteSnapshot? {
        let target = documentID.map { "document id \"\(escaped($0))\"" } ?? "front document"
        let result = try run("""
        tell application id "com.apple.Keynote"
            if (count documents) = 0 then return {}
            try
                tell \(target)
                    set effects to {}
                    repeat with i from 1 to count slides
                        set tp to transition properties of slide i
                        set end of effects to ((transition effect of tp) is not no transition effect)
                    end repeat
                    return {id, name, name of slide layouts, name of base layout of every slide, skipped of every slide, effects}
                end tell
            on error message number n
                -- Only "no such document" means closed; permission errors must reach the caller.
                if n is in {-1728, -1719} then return {}
                error message number n
            end try
        end tell
        """)
        guard result.numberOfItems == 6 else { return nil }
        func strings(_ index: Int) -> [String] { list(result.atIndex(index)).map { $0.stringValue ?? "" } }
        return KeynoteSnapshot(documentID: result.atIndex(1)?.stringValue ?? "", documentName: result.atIndex(2)?.stringValue ?? "",
                               layouts: strings(3), slideLayouts: strings(4), skipped: list(result.atIndex(5)).map(\.booleanValue),
                               transitions: list(result.atIndex(6)).map(\.booleanValue))
    }

    /// Sets every slide's transition effect to none and returns how many changed.
    /// Passing only the effect would reset duration, delay and auto-advance to Keynote's defaults, so they are written back.
    static func removeTransitions(documentID: String) throws -> Int {
        Int(try run("""
        tell application id "com.apple.Keynote"
            tell document id "\(escaped(documentID))"
                set changed to 0
                repeat with i from 1 to count slides
                    set tp to transition properties of slide i
                    if (transition effect of tp) is not no transition effect then
                        set transition properties of slide i to {transition effect:no transition effect, transition duration:(transition duration of tp), transition delay:(transition delay of tp), automatic transition:(automatic transition of tp)}
                        set changed to changed + 1
                    end if
                end repeat
                return changed
            end tell
        end tell
        """).int32Value)
    }

    /// Opens a presentation file in Keynote (launching it if needed) and returns its document id.
    static func open(_ url: URL) throws -> String {
        try run("""
        tell application id "com.apple.Keynote"
            activate
            return id of (open POSIX file "\(escaped(url.path))")
        end tell
        """).stringValue ?? ""
    }

    /// Position of the current slide. `slide number` is missing for hidden slides, but the
    /// returned reference is "slide N of document …", so N is read from the specifier.
    static func currentSlide(documentID: String) throws -> Int {
        let reference = try run("tell application id \"com.apple.Keynote\" to return current slide of document id \"\(escaped(documentID))\"")
        return Int(reference.forKeyword(AEKeyword(keyAEKeyData))?.int32Value ?? 0)
    }
    static func setCurrentSlide(documentID: String, _ number: Int) throws {
        try run("""
        tell application id "com.apple.Keynote"
            tell document id "\(escaped(documentID))" to set current slide to slide \(number)
        end tell
        """)
    }

    /// Brings the presentation's window to the front of Keynote. False when it has no window.
    static func bringToFront(documentID: String) throws -> Bool {
        try run("""
        tell application id "com.apple.Keynote"
            repeat with w in windows
                try
                    if id of document of w is "\(escaped(documentID))" then
                        set index of w to 1
                        return true
                    end if
                end try
            end repeat
            return false
        end tell
        """).booleanValue
    }

    static func deleteHiddenSlides(documentID: String) throws {
        try run("""
        tell application id "com.apple.Keynote"
            tell document id "\(escaped(documentID))" to delete (every slide whose skipped is true)
        end tell
        """)
    }

    /// Layout count and the front document's id, used to confirm each deletion on the right presentation.
    static func layoutCount() throws -> (documentID: String, count: Int) {
        let result = try run("""
        tell application id "com.apple.Keynote"
            if (count documents) = 0 then return {"", 0}
            tell front document to return {id, count slide layouts}
        end tell
        """)
        return (result.atIndex(1)?.stringValue ?? "", Int(result.atIndex(2)?.int32Value ?? 0))
    }

    @discardableResult
    static func run(_ source: String) throws -> NSAppleEventDescriptor {
        if !Thread.isMainThread { return try DispatchQueue.main.sync { try run(source) } }
        var info: NSDictionary?
        guard let script = NSAppleScript(source: source) else { throw SweepError.keynote("script") }
        let result = script.executeAndReturnError(&info)
        if let info {
            let number = info[NSAppleScript.errorNumber] as? Int ?? 0
            if number == -1743 || number == -1744 { throw SweepError.automationDenied }
            throw SweepError.keynote("\(info[NSAppleScript.errorMessage] as? String ?? "") (\(number))")
        }
        return result
    }

    private static func list(_ descriptor: NSAppleEventDescriptor?) -> [NSAppleEventDescriptor] {
        guard let descriptor, descriptor.numberOfItems > 0 else { return [] }
        return (1...descriptor.numberOfItems).compactMap { descriptor.atIndex($0) }
    }
    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    enum Permission { case allowed, denied, unknown }
    /// Never prompts unless `ask` is true. Unknown when Keynote is not running.
    static func permission(ask: Bool) -> Permission {
        var target = AEAddressDesc()
        let status: OSStatus = bundleID.withCString { pointer in
            guard AECreateDesc(typeApplicationBundleID, pointer, strlen(pointer), &target) == noErr else { return OSStatus(procNotFound) }
            defer { AEDisposeDesc(&target) }
            return AEDeterminePermissionToAutomateTarget(&target, typeWildCard, typeWildCard, ask)
        }
        switch status {
        case noErr: return .allowed
        case OSStatus(errAEEventNotPermitted): return .denied
        default: return .unknown
        }
    }
    static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") { NSWorkspace.shared.open(url) }
    }
}

/// Keynote's window driven through the Accessibility API: the "Edit Slide Layouts" mode and the Build Order panel.
/// Layouts cannot be deleted with Apple Events (error -10000), and the navigator thumbnails
/// are not exposed to AX, so rows are selected with arrow keys and read back from the inspector title.
final class KeynoteUI {
    static let up: CGKeyCode = 126, down: CGKeyCode = 125, delete: CGKeyCode = 51
    let pid: pid_t
    private let app: AXUIElement
    var pollInterval: TimeInterval = 0.03
    var timeout: TimeInterval = 3

    init(pid: pid_t) { self.pid = pid; app = AXUIElementCreateApplication(pid) }

    // MARK: AX helpers
    private func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
    private func children(_ element: AXUIElement) -> [AXUIElement] { attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] }
    private func role(_ element: AXUIElement) -> String { attribute(element, kAXRoleAttribute) as? String ?? "" }
    private func title(_ element: AXUIElement) -> String { attribute(element, kAXTitleAttribute) as? String ?? "" }
    private func text(_ element: AXUIElement) -> String { (attribute(element, kAXValueAttribute) as? String) ?? title(element) }

    private var splitGroup: AXUIElement? {
        guard let window = attribute(app, kAXMainWindowAttribute) ?? attribute(app, kAXFocusedWindowAttribute) else { return nil }
        return children(window as! AXUIElement).first { role($0) == kAXSplitGroupRole }
    }
    /// Selected layout name, or nil when the editor is not showing.
    var currentLayoutName: String? {
        guard let group = splitGroup, let label = children(group).first(where: { role($0) == kAXStaticTextRole }) else { return nil }
        return SweepPlan.layoutName(fromInspectorTitle: text(label))
    }
    var isEditing: Bool { currentLayoutName != nil }
    /// Read live from AX; NSWorkspace.frontmostApplication lags behind without a run loop turn.
    var isFrontmost: Bool { (attribute(app, kAXFrontmostAttribute) as? Bool) ?? false }
    func activate() -> Bool {
        AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        return wait { self.isFrontmost }
    }

    private func pressViewMenuItem(_ titles: [String]) -> Bool {
        guard let bar = attribute(app, kAXMenuBarAttribute) else { return false }
        for item in children(bar as! AXUIElement) where ["表示", "View", "显示", "보기"].contains(title(item)) {
            for menu in children(item) {
                if let target = children(menu).first(where: { titles.contains(title($0)) }) {
                    return AXUIElementPerformAction(target, kAXPressAction as CFString) == .success
                }
            }
        }
        return false
    }

    func enter() throws {
        if isEditing { return }
        _ = pressViewMenuItem(["ナビゲータ", "Navigator", "导航器", "탐색기"])
        guard pressViewMenuItem(["スライドレイアウトを編集", "Edit Slide Layouts", "编辑幻灯片布局", "슬라이드 레이아웃 편집"]),
              wait({ self.isEditing }) else { throw SweepError.editorUnavailable }
    }
    func exit() {
        guard let group = splitGroup else { return }
        if let done = children(group).first(where: { role($0) == kAXButtonRole && ["終了", "Done", "完成", "완료"].contains(title($0)) }) {
            AXUIElementPerformAction(done, kAXPressAction as CFString)
        }
    }
    func focusNavigator() throws {
        guard let group = splitGroup, let navigator = children(group).first(where: { role($0) == kAXScrollAreaRole }),
              AXUIElementSetAttributeValue(navigator, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success else { throw SweepError.editorUnavailable }
    }

    // MARK: Build Order panel
    private static let buildOrderTitles = ["ビルドの順番", "Build Order", "构件顺序", "빌드 순서"]
    private var buildOrderWindow: AXUIElement? {
        (attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []).first { Self.buildOrderTitles.contains(title($0)) }
    }
    private var buildTable: AXUIElement? {
        guard let window = buildOrderWindow, let scroll = children(window).first(where: { role($0) == kAXScrollAreaRole }) else { return nil }
        return children(scroll).first { role($0) == kAXTableRole }
    }
    /// Builds listed for the current slide, or nil when the panel is not showing.
    var buildRows: [AXUIElement]? { buildTable.map { attribute($0, kAXRowsAttribute) as? [AXUIElement] ?? [] } }
    var isBuildOrderShowing: Bool { buildOrderWindow != nil }
    /// Toggles the panel with View › Show/Hide Build Order.
    func toggleBuildOrder() -> Bool {
        guard let bar = attribute(app, kAXMenuBarAttribute) else { return false }
        for item in children(bar as! AXUIElement) where ["表示", "View", "显示", "보기"].contains(title(item)) {
            for menu in children(item) {
                if let target = children(menu).first(where: { t in Self.buildOrderTitles.contains { title(t).contains($0) } }) {
                    return AXUIElementPerformAction(target, kAXPressAction as CFString) == .success
                }
            }
        }
        return false
    }
    /// Selects every build of the current slide and deletes them. Returns how many were removed.
    func deleteAllBuilds() throws -> Int {
        guard let table = buildTable, let rows = buildRows, !rows.isEmpty else { return 0 }
        AXUIElementSetAttributeValue(table, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        guard AXUIElementSetAttributeValue(table, kAXSelectedRowsAttribute as CFString, rows as CFArray) == .success,
              wait({ (self.attribute(table, kAXSelectedRowsAttribute) as? [AXUIElement])?.count == rows.count }) else { throw SweepError.editorUnavailable }
        press(Self.delete)
        return wait({ self.buildRows?.isEmpty == true }) ? rows.count : rows.count - (buildRows?.count ?? rows.count)
    }
    /// Reads the list until two reads agree, so a list still showing the previous slide is not used.
    func settledBuildCount() -> Int? {
        var last = buildRows?.count
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.06)
            let now = buildRows?.count
            if now == last { return now }
            last = now
        }
        return last
    }

    // MARK: Keys
    func press(_ key: CGKeyCode, times: Int = 1) {
        guard times > 0 else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        for _ in 0..<times {
            CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)?.postToPid(pid)
            CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)?.postToPid(pid)
        }
    }
    func move(_ steps: Int) { press(steps < 0 ? Self.up : Self.down, times: abs(steps)) }

    @discardableResult
    func wait(_ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: pollInterval)
        } while Date() < deadline
        return false
    }
}

struct SweepOptions {
    var deleteUnusedLayouts: Bool
    var deleteHiddenSlides: Bool
    var removeTransitions = false
    var removeBuilds = false
    var isEmpty: Bool { !deleteUnusedLayouts && !deleteHiddenSlides && !removeTransitions && !removeBuilds }
}

struct SweepResult: Equatable {
    var documentName = ""
    var deletedSlides = 0
    var removedTransitions = 0
    var removedBuilds = 0
    var buildSlides = 0
    var deletedLayouts: [String] = []
    var skippedLayouts: [String] = []
    var error: SweepError?
}

/// Runs the chosen clean-ups on the front presentation. Call off the main thread.
final class Sweeper: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }

    func run(_ options: SweepOptions, documentID: String, progress: @escaping (Int, Int) -> Void) -> SweepResult {
        var result = SweepResult()
        do {
            guard let snapshot = try KeynoteDOM.snapshot(documentID: documentID) else { throw SweepError.noDocument }
            result.documentName = snapshot.documentName
            var current = snapshot
            if options.deleteHiddenSlides, snapshot.hiddenCount > 0 {
                guard !snapshot.allHidden else { throw SweepError.allHidden }
                try KeynoteDOM.deleteHiddenSlides(documentID: snapshot.documentID)
                guard let after = try KeynoteDOM.snapshot(documentID: snapshot.documentID) else { throw SweepError.documentChanged }
                result.deletedSlides = snapshot.skipped.count - after.skipped.count
                current = after
            }
            if options.removeTransitions {
                result.removedTransitions = try KeynoteDOM.removeTransitions(documentID: current.documentID)
            }
            if options.removeBuilds {
                try deleteBuilds(current, into: &result, progress: progress)
            }
            if options.deleteUnusedLayouts {
                try deleteLayouts(current, into: &result, progress: progress)
            }
        } catch let error as SweepError {
            result.error = error
        } catch {
            result.error = .keynote(error.localizedDescription)
        }
        return result
    }

    /// Puts the presentation in Keynote's front window with Keynote active, for the AX steps.
    private func frontUI(_ snapshot: KeynoteSnapshot) throws -> KeynoteUI {
        guard AXIsProcessTrusted() else { throw SweepError.accessibilityDenied }
        guard let keynote = KeynoteDOM.runningApp else { throw SweepError.noDocument }
        let editor = KeynoteUI(pid: keynote.processIdentifier)
        guard try KeynoteDOM.bringToFront(documentID: snapshot.documentID) else { throw SweepError.noDocument }
        guard editor.activate() else { throw SweepError.interrupted }
        guard editor.wait({ (try? KeynoteDOM.layoutCount().documentID) == snapshot.documentID }) else { throw SweepError.documentChanged }
        return editor
    }

    /// Object animations are not in Keynote's dictionary: each slide's Build Order list is emptied with select-all and Delete.
    private func deleteBuilds(_ snapshot: KeynoteSnapshot, into result: inout SweepResult, progress: @escaping (Int, Int) -> Void) throws {
        let editor = try frontUI(snapshot)
        let id = snapshot.documentID
        let original = (try? KeynoteDOM.currentSlide(documentID: id)) ?? 1
        let opened = !editor.isBuildOrderShowing
        if opened { guard editor.toggleBuildOrder(), editor.wait({ editor.isBuildOrderShowing }) else { throw SweepError.editorUnavailable } }
        defer {
            try? KeynoteDOM.setCurrentSlide(documentID: id, original)
            if opened { _ = editor.toggleBuildOrder() }
        }
        let total = snapshot.skipped.count
        guard total > 0 else { return }
        for number in 1...total {
            if isCancelled { throw SweepError.interrupted }
            guard editor.isFrontmost else { throw SweepError.interrupted }
            guard (try? KeynoteDOM.layoutCount().documentID) == id else { throw SweepError.documentChanged }
            try KeynoteDOM.setCurrentSlide(documentID: id, number)
            guard editor.wait({ (try? KeynoteDOM.currentSlide(documentID: id)) == number }) else { throw SweepError.editorUnavailable }
            if let count = editor.settledBuildCount(), count > 0 {
                let removed = try editor.deleteAllBuilds()
                result.removedBuilds += removed
                if removed > 0 { result.buildSlides += 1 }
            }
            progress(number, total)
        }
    }

    private func deleteLayouts(_ snapshot: KeynoteSnapshot, into result: inout SweepResult, progress: @escaping (Int, Int) -> Void) throws {
        let targets = snapshot.unusedLayoutIndexes(ignoringHidden: false)
        guard !targets.isEmpty else { return }
        // The editor works on Keynote's front window, so put this presentation there first.
        let editor = try frontUI(snapshot)
        try editor.enter()
        defer { editor.exit() }
        try editor.focusNavigator()

        // Go to the last row once, then walk upward: deleting from the end keeps earlier rows in place.
        var total = snapshot.layouts.count
        editor.press(KeynoteUI.down, times: total)
        var position = total
        for (done, index) in targets.enumerated() {
            if isCancelled { throw SweepError.interrupted }
            // Stop if someone switched apps meanwhile.
            guard editor.isFrontmost else { throw SweepError.interrupted }
            let expected = snapshot.layouts[index - 1]
            editor.move(SweepPlan.steps(from: position, to: index))
            position = index
            if !editor.wait({ editor.currentLayoutName == expected }) {
                // Lost track of the selection: count again from the top.
                editor.press(KeynoteUI.up, times: total)
                editor.press(KeynoteUI.down, times: index - 1)
            }
            guard editor.wait({ editor.currentLayoutName == expected }) else { result.skippedLayouts.append(expected); continue }
            editor.press(KeynoteUI.delete)
            var state = (documentID: snapshot.documentID, count: total)
            let removed = editor.wait {
                state = (try? KeynoteDOM.layoutCount()) ?? state
                return state.count == total - 1 || state.documentID != snapshot.documentID
            }
            guard state.documentID == snapshot.documentID else { throw SweepError.documentChanged }
            if removed {
                total -= 1
                result.deletedLayouts.append(expected)
                // Keynote selects the next row, or the previous one after deleting the last.
                position = min(position, total)
            } else {
                result.skippedLayouts.append(expected)
            }
            progress(done + 1, targets.count)
        }
    }
}
