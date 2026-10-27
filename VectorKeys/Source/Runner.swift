import AppKit
import ApplicationServices

/// Illustrator (the release build and its Beta / Prerelease, whose IDs start the same).
enum Illustrator {
    static let bundlePrefix = "com.adobe.illustrator"
    static func isIllustrator(_ app: NSRunningApplication?) -> Bool {
        app?.bundleIdentifier?.lowercased().hasPrefix(bundlePrefix) ?? false
    }
    static var front: NSRunningApplication? {
        let app = NSWorkspace.shared.frontmostApplication
        return isIllustrator(app) ? app : nil
    }
    static var running: NSRunningApplication? {
        front ?? NSWorkspace.shared.runningApplications.first { isIllustrator($0) && !$0.isTerminated }
    }
}

/// How a run ended. step: the 1-based number of the step that stopped it.
enum RunOutcome: Equatable {
    case success
    case noIllustrator
    case automationDenied
    case accessibilityDenied
    case fileMissing(step: Int)
    case menuMissing(step: Int, title: String)
    case menuDisabled(step: Int, title: String)
    case failed(step: Int, message: String)
}

/// Runs items in Illustrator one at a time (a serial queue), their steps in order.
final class ScriptRunner {
    private let queue = DispatchQueue(label: "jp.dtp-transit.vectorkeys.runner")
    private let lock = NSLock()
    private var pending = 0
    /// Presses beyond this many waiting runs are dropped (a held key would otherwise pile up).
    static let maxPending = 3

    /// Runs on the background queue and calls back on the main queue. Returns false when the queue is full.
    @discardableResult
    func run(_ script: ScriptEntry, completion: @escaping (RunOutcome) -> Void) -> Bool {
        lock.lock()
        guard pending < Self.maxPending else { lock.unlock(); return false }
        pending += 1
        lock.unlock()
        queue.async { [self] in
            let outcome = execute(script)
            lock.lock(); pending -= 1; lock.unlock()
            DispatchQueue.main.async { completion(outcome) }
        }
        return true
    }

    private func execute(_ script: ScriptEntry) -> RunOutcome {
        guard let app = Illustrator.running, let appPath = app.bundleURL?.path else { return .noIllustrator }
        for (index, step) in script.actions.enumerated() {
            let number = index + 1
            switch step {
            case .script(let path):
                guard FileManager.default.fileExists(atPath: path) else { return .fileMissing(step: number) }
                if let stop = osascript(ScriptText.appleScript(appPath: appPath, file: path), step: number) { return stop }
            case .menuCommand(let id, _):
                if let stop = osascript(ScriptText.appleScript(appPath: appPath, code: ScriptText.menuCommandJS(id)), step: number) { return stop }
            case .menuItem(let path):
                guard AXIsProcessTrusted() else { return .accessibilityDenied }
                let title = path.joined(separator: " › ")
                guard let item = MenuAX.item(pid: app.processIdentifier, path: path) else { return .menuMissing(step: number, title: title) }
                guard MenuAX.isEnabled(item) else { return .menuDisabled(step: number, title: title) }
                MenuAX.press(item)
                // Let Illustrator take the command before the next step.
                Thread.sleep(forTimeInterval: 0.15)
            }
        }
        return .success
    }

    private func osascript(_ source: String, step: Int) -> RunOutcome? {
        switch OSAScript.run(source) {
        case .output: return nil
        case .automationDenied: return .automationDenied
        case .failed(let message): return .failed(step: step, message: message)
        }
    }
}

/// The menu bar of an app through Accessibility.
enum MenuAX {
    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }
    static func title(_ element: AXUIElement) -> String { attribute(element, kAXTitleAttribute) as? String ?? "" }

    /// Walks the titles from the menu bar. Right after a script Illustrator can be too busy to answer; an unreadable
    /// menu is read again for up to a second, while a menu that was read without the item answers at once.
    static func item(pid: pid_t, path: [String]) -> AXUIElement? {
        for attempt in 0..<8 {
            switch lookup(pid: pid, path: path) {
            case .found(let item): return item
            case .absent: return nil
            case .unreadable: if attempt < 7 { Thread.sleep(forTimeInterval: 0.15) }
            }
        }
        return nil
    }
    private enum Lookup { case found(AXUIElement), absent, unreadable }
    private static func lookup(pid: pid_t, path: [String]) -> Lookup {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 2)
        guard let bar = attribute(app, kAXMenuBarAttribute) else { return .unreadable }
        var container = bar as! AXUIElement
        var found: AXUIElement?
        for (index, wanted) in path.enumerated() {
            if index > 0 {
                guard let menu = children(container).first(where: { (attribute($0, kAXRoleAttribute) as? String) == kAXMenuRole }) else { return .unreadable }
                container = menu
            }
            let items = children(container)
            if items.isEmpty { return .unreadable }
            guard let match = items.first(where: { MenuTitles.matches(wanted, title($0)) }) else { return .absent }
            found = match; container = match
        }
        return found.map { .found($0) } ?? .absent
    }
    static func isEnabled(_ item: AXUIElement) -> Bool { (attribute(item, kAXEnabledAttribute) as? Bool) ?? false }
    /// AXPress waits while a menu command shows a dialog box; a short timeout lets the run go on.
    static func press(_ item: AXUIElement) {
        AXUIElementSetMessagingTimeout(item, 0.5)
        AXUIElementPerformAction(item, kAXPressAction as CFString)
    }
}
