import AppKit

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

/// How a run ended.
enum RunOutcome: Equatable {
    case success
    case noIllustrator
    case automationDenied
    case fileMissing
    case failed(String)
}

/// Runs scripts in Illustrator one at a time (a serial queue).
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
        guard script.fileExists else { return .fileMissing }
        guard let path = Illustrator.running?.bundleURL?.path else { return .noIllustrator }
        switch OSAScript.run(ScriptText.appleScript(appPath: path, file: script.path)) {
        case .output: return .success
        case .automationDenied: return .automationDenied
        case .failed(let message): return .failed(message)
        }
    }
}
