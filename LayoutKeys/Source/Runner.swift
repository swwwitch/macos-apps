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
    case fileMissing
    case failed(String)
}

/// Runs scripts in InDesign one at a time (a serial queue).
final class ScriptRunner {
    private let queue = DispatchQueue(label: "jp.dtp-transit.layoutkeys.runner")
    private let lock = NSLock()
    private var pending = 0
    /// Presses beyond this many waiting runs are dropped (a held key would otherwise pile up).
    static let maxPending = 3

    /// Runs on the background queue and calls back on the main queue. Returns false when the queue is full.
    @discardableResult
    func run(_ script: ScriptEntry, key: VariableKey? = nil, completion: @escaping (RunOutcome) -> Void) -> Bool {
        lock.lock()
        guard pending < Self.maxPending else { lock.unlock(); return false }
        pending += 1
        lock.unlock()
        queue.async { [self] in
            let outcome = execute(script, key: key)
            lock.lock(); pending -= 1; lock.unlock()
            DispatchQueue.main.async { completion(outcome) }
        }
        return true
    }

    private func execute(_ script: ScriptEntry, key: VariableKey?) -> RunOutcome {
        guard script.fileExists else { return .fileMissing }
        guard let path = InDesign.running?.bundleURL?.path else { return .noInDesign }
        let source: String
        do { source = try Self.prepare(script, key: key, appPath: path) } catch { return .failed(error.localizedDescription) }
        switch OSAScript.run(source) {
        case .output: return .success
        case .automationDenied: return .automationDenied
        case .failed(let message): return .failed(message)
        }
    }

    /// The file as it is, or a copy with the changed SW_ variables (read now, so edits to the file are picked up).
    static func prepare(_ script: ScriptEntry, key: VariableKey? = nil, appPath: String) throws -> String {
        let overrides = script.overrides(with: key), undoName = script.title(for: key)
        if overrides.isEmpty { return ScriptText.appleScript(appPath: appPath, file: script.path, undoName: undoName) }
        guard URL(fileURLWithPath: script.path).pathExtension.lowercased() != "jsxbin",
              let source = try? String(contentsOfFile: script.path, encoding: .utf8) else { throw VariableOverrides.Failure(key: "override.fileText", name: (script.path as NSString).lastPathComponent) }
        let changed = try VariableOverrides.apply(to: source, names: overrides.map(\.name), values: overrides.map(\.value), file: true)
        return ScriptText.appleScript(appPath: appPath, code: changed, undoName: undoName)
    }
}
