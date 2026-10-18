import AppKit
import ApplicationServices
import os

/// Diagnostics (Console / `log show --predicate 'subsystem == "jp.dtp-transit.vectormate"'`). No text content is logged.
let diagnostics = Logger(subsystem: "jp.dtp-transit.vectormate", category: "metrics")

/// Illustrator (the release build and its Beta / Prerelease, whose IDs start the same).
enum Illustrator {
    static let bundlePrefix = "com.adobe.illustrator"
    static func isIllustrator(_ app: NSRunningApplication?) -> Bool {
        app?.bundleIdentifier?.lowercased().hasPrefix(bundlePrefix) ?? false
    }
    static var running: NSRunningApplication? {
        if let front = NSWorkspace.shared.frontmostApplication, isIllustrator(front) { return front }
        return NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundlePrefix && !$0.isTerminated }
    }

    enum ScriptResult {
        case output(String)
        /// Error -1743: the Automation permission for Illustrator was refused.
        case automationDenied
        case timedOut
        case failed(String)
    }

    /// Runs `do javascript` through osascript (off the main thread; a busy Illustrator only delays this queue).
    /// The app is addressed by its path, so the Illustrator in front is used even when several versions are open.
    static func run(javascript: String, in app: NSRunningApplication, timeout: Int = 5) -> ScriptResult {
        guard let path = app.bundleURL?.path else { return .failed("no bundle") }
        return run(appleScript: MetricsScript.appleScript(appPath: path, javascript: javascript, timeout: timeout), timeout: timeout)
    }

    /// Runs an AppleScript source through osascript (off the main thread).
    static func run(appleScript source: String, timeout: Int = 5) -> ScriptResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-"]
        let input = Pipe(), output = Pipe(), error = Pipe()
        process.standardInput = input; process.standardOutput = output; process.standardError = error
        do { try process.run() } catch { return .failed(error.localizedDescription) }
        input.fileHandleForWriting.write(source.data(using: .utf8)!)
        try? input.fileHandleForWriting.close()
        let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(timeout + 3), execute: killer)
        let out = output.fileHandleForReading.readDataToEndOfFile()
        let err = error.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        killer.cancel()
        let message = String(data: err, encoding: .utf8) ?? ""
        if process.terminationReason == .uncaughtSignal { return .timedOut }
        guard process.terminationStatus == 0 else {
            if message.contains("-1743") { return .automationDenied }
            if message.contains("-1712") { return .timedOut }
            return .failed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .output(String(data: out, encoding: .utf8) ?? "")
    }
}

/// 自動カーニング「メトリクス」→ プロポーショナルメトリクス ON.
/// Event-driven (B13): a check runs shortly after a click, Return / Enter / Tab, or a ⌘ key in Illustrator,
/// and when Illustrator comes to the front. Nothing runs while another app is in front.
@MainActor
final class MetricsWatcher {
    enum Event: Equatable {
        case applied(on: Int, off: Int)
        case automationDenied
        case failed(String)
    }

    var isActive = false { didSet { isActive ? start() : stop() } }
    /// Also turn it off when Metrics becomes another method.
    var turnOff = true
    var onEvent: ((Event) -> Void)?
    private var monitors: [Any] = []
    private var activation: NSObjectProtocol?
    private var pending: DispatchWorkItem?
    private var running = false
    private var again = false
    private var previous: MetricsScript.Snapshot?
    private var previousPID: pid_t = 0
    private let queue = DispatchQueue(label: "VectorMate.metrics")
    /// Wait after the event, so Illustrator has applied the panel change before it is read.
    static let delay: TimeInterval = 0.35

    private func start() {
        guard monitors.isEmpty else { return }
        if let mouse = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.schedule() }
        }) { monitors.append(mouse) }
        // Key events reach a global monitor only with the Accessibility permission.
        if let keys = NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: { [weak self] event in
            let commit: Set<UInt16> = [36, 76, 48]   // Return, Enter, Tab (typing a method name in the panel)
            guard commit.contains(event.keyCode) || event.modifierFlags.contains(.command) else { return }
            MainActor.assumeIsolated { self?.schedule() }
        }) { monitors.append(keys) }
        activation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { if Illustrator.isIllustrator(app) { self?.schedule() } }
        }
    }

    private func stop() {
        monitors.forEach(NSEvent.removeMonitor); monitors = []
        if let activation { NSWorkspace.shared.notificationCenter.removeObserver(activation) }
        activation = nil
        pending?.cancel(); pending = nil
        previous = nil
    }

    /// Restarts the monitors (after the Accessibility permission changed, so the key monitor can be added).
    func restart() { guard isActive else { return }; stop(); start() }

    private func schedule() {
        guard isActive, Illustrator.isIllustrator(NSWorkspace.shared.frontmostApplication) else { return }
        diagnostics.notice("event")
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.check() } }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.delay, execute: work)
    }

    private func check() {
        guard isActive else { return }
        if running { again = true; return }
        // Checked again just before running (B21): only the Illustrator in front.
        guard let app = NSWorkspace.shared.frontmostApplication, Illustrator.isIllustrator(app) else { return }
        if app.processIdentifier != previousPID { previous = nil; previousPID = app.processIdentifier }
        running = true
        let source = MetricsScript.source(previous: previous, turnOff: turnOff)
        queue.async { [weak self] in
            let result = Illustrator.run(javascript: source, in: app)
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.finish(result) } }
        }
    }

    private func finish(_ result: Illustrator.ScriptResult) {
        running = false
        switch result {
        case .output(let text):
            var same = "-"
            if case .checked(let snapshot, _, _) = MetricsScript.parse(text) { same = String(previous?.signature == snapshot.signature) }
            diagnostics.notice("answer: \(text.split(separator: "\n").dropFirst(2).joined(separator: " "), privacy: .public) sameSelection=\(same, privacy: .public)")
        default: diagnostics.notice("failed: \(String(describing: result), privacy: .public)")
        }
        switch result {
        case .output(let text):
            switch MetricsScript.parse(text) {
            case .noText: previous = nil
            case .checked(let snapshot, let on, let off):
                previous = snapshot
                if on + off > 0 { onEvent?(.applied(on: on, off: off)) }
            case .unreadable(let text): previous = nil; onEvent?(.failed(text))
            }
        case .automationDenied: previous = nil; onEvent?(.automationDenied)
        // Illustrator was busy (a dialog box, a long operation): try with the next event.
        case .timedOut: previous = nil
        case .failed(let message): previous = nil; onEvent?(.failed(message))
        }
        if again { again = false; schedule() }
    }
}
