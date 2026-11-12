import AppKit

/// InDesign (the release build and its Beta / Prerelease, whose IDs start the same).
enum InDesign {
    static let bundlePrefix = "com.adobe.indesign"
    static func isInDesign(_ app: NSRunningApplication?) -> Bool {
        app?.bundleIdentifier?.lowercased().hasPrefix(bundlePrefix) ?? false
    }
    static var front: NSRunningApplication? {
        let app = NSWorkspace.shared.frontmostApplication
        return isInDesign(app) ? app : nil
    }
    static var running: NSRunningApplication? {
        front ?? NSWorkspace.shared.runningApplications.first { isInDesign($0) && !$0.isTerminated }
    }
}

/// How a run ended.
enum RunOutcome: Equatable {
    case success
    case noInDesign
    case automationDenied
    case failed(String)
}

/// Runs the script in InDesign one press at a time (a serial queue).
final class ScriptRunner {
    private let queue = DispatchQueue(label: "jp.dtp-transit.alignkeys.runner")
    private let lock = NSLock()
    private var pending = 0
    /// Presses beyond this many waiting runs are dropped (a held key would otherwise pile up).
    static let maxPending = 3

    /// Runs on the background queue and calls back on the main queue. Returns false when the queue is full.
    @discardableResult
    func run(_ code: String, undoName: String, completion: @escaping (RunOutcome) -> Void) -> Bool {
        lock.lock()
        guard pending < Self.maxPending else { lock.unlock(); return false }
        pending += 1
        lock.unlock()
        queue.async { [self] in
            let outcome = execute(code, undoName: undoName)
            lock.lock(); pending -= 1; lock.unlock()
            DispatchQueue.main.async { completion(outcome) }
        }
        return true
    }

    private func execute(_ code: String, undoName: String) -> RunOutcome {
        guard let path = InDesign.running?.bundleURL?.path else { return .noInDesign }
        switch OSAScript.run(ScriptText.appleScript(appPath: path, code: code, undoName: undoName)) {
        case .output: return .success
        case .automationDenied: return .automationDenied
        case .failed(let message): return .failed(message)
        }
    }
}
