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

/// How a run ended. step: the 1-based number of the step that stopped it.
enum RunOutcome: Equatable {
    case success
    case noIllustrator
    case automationDenied
    case unsupportedSteps
    case fileMissing(step: Int)
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
        guard script.scriptsOnly else { return .unsupportedSteps }
        guard let app = Illustrator.running, let appPath = app.bundleURL?.path else { return .noIllustrator }
        for (index, step) in script.actions.enumerated() {
            let number = index + 1
            switch step {
            case .script(let path):
                guard FileManager.default.fileExists(atPath: path) else { return .fileMissing(step: number) }
                if let stop = osascript(ScriptText.appleScript(appPath: appPath, file: path), step: number) { return stop }
            case .code(let source):
                guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .failed(step: number, message: L("code.empty")) }
                if let stop = osascript(ScriptText.appleScript(appPath: appPath, code: source), step: number) { return stop }
            case .menuCommand, .menuItem:
                return .unsupportedSteps
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
