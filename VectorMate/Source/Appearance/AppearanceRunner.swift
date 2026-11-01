import AppKit

extension Illustrator {
    /// Illustrator when it is the frontmost app.
    static var front: NSRunningApplication? {
        let app = NSWorkspace.shared.frontmostApplication
        return isIllustrator(app) ? app : nil
    }
}

/// How a run ended.
enum RunOutcome: Equatable {
    case success
    /// A script file finished; what it did is up to the script.
    case scriptFinished
    case noIllustrator
    case automationDenied
    case fileMissing(String)
    case refused(ScriptBuilder.Failure)
    case failed(String)
}

/// Runs commands in Illustrator one at a time (a serial queue).
final class CommandRunner {
    private let queue = DispatchQueue(label: "jp.dtp-transit.vectormate.appearance")
    private let lock = NSLock()
    private var pending = 0
    /// Presses beyond this many waiting runs are dropped (a held key would otherwise pile up).
    static let maxPending = 3

    /// Calls back on the main queue. Returns false when the queue is full.
    @discardableResult
    func run(source: String?, file: String?, completion: @escaping (RunOutcome) -> Void) -> Bool {
        lock.lock()
        guard pending < Self.maxPending else { lock.unlock(); return false }
        pending += 1
        lock.unlock()
        queue.async { [self] in
            let outcome = execute(source: source, file: file)
            lock.lock(); pending -= 1; lock.unlock()
            DispatchQueue.main.async { completion(outcome) }
        }
        return true
    }

    private func execute(source: String?, file: String?) -> RunOutcome {
        guard let app = Illustrator.running, let appPath = app.bundleURL?.path else { return .noIllustrator }
        if let file {
            guard FileManager.default.fileExists(atPath: file) else { return .fileMissing(file) }
            switch OSAScript.run(AppleScriptText.run(appPath: appPath, file: file)) {
            case .output: return .scriptFinished
            case .automationDenied: return .automationDenied
            case .failed(let message): return .failed(message)
            }
        }
        guard let source else { return .failed("") }
        switch OSAScript.run(AppleScriptText.run(appPath: appPath, code: source)) {
        case .output(let text): return Self.outcome(text)
        case .automationDenied: return .automationDenied
        case .failed(let message): return .failed(message)
        }
    }

    static func outcome(_ output: String) -> RunOutcome {
        let text = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("ERR:"), let failure = ScriptBuilder.Failure(rawValue: String(text.dropFirst(4))) { return .refused(failure) }
        return .success
    }
}

enum AppleScriptText {
    static func quote(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
    /// Addresses Illustrator by its path so the one in front is used when several versions are open.
    /// A long timeout: commands that open a dialog box keep `do javascript` waiting until it is closed.
    static func run(appPath: String, code: String) -> String {
        "with timeout of 3600 seconds\ntell application \(quote(appPath))\ndo javascript \(quote(code))\nend tell\nend timeout"
    }
    static func run(appPath: String, file: String) -> String {
        "with timeout of 3600 seconds\ntell application \(quote(appPath))\ndo javascript (POSIX file \(quote(file)) as alias)\nend tell\nend timeout"
    }
}

/// osascript, so a hung script can be stopped without blocking the app.
enum OSAScript {
    enum Result: Equatable { case output(String), automationDenied, failed(String) }
    static func run(_ source: String) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-"]
        let input = Pipe(), output = Pipe(), error = Pipe()
        process.standardInput = input; process.standardOutput = output; process.standardError = error
        do { try process.run() } catch { return .failed(error.localizedDescription) }
        input.fileHandleForWriting.write(Data(source.utf8))
        try? input.fileHandleForWriting.close()
        var errorData = Data()
        let group = DispatchGroup(); group.enter()
        DispatchQueue.global().async { errorData = error.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        let out = output.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()
        let message = (String(data: errorData, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            if message.contains("-1743") { return .automationDenied }
            return .failed(cleanError(message))
        }
        return .output((String(data: out, encoding: .utf8) ?? "").trimmingCharacters(in: .newlines))
    }
    /// "-: execution error: Adobe Illustratorでエラーが起きました：Error 21: undefined is not an object (-2700)" → the message part.
    static func cleanError(_ message: String) -> String {
        var text = message
        if let range = text.range(of: "execution error: ") { text = String(text[range.upperBound...]) }
        if let range = text.range(of: "：") ?? text.range(of: ": ") { text = String(text[range.upperBound...]) }
        if let range = text.range(of: " (", options: .backwards), text.hasSuffix(")") { text = String(text[..<range.lowerBound]) }
        text = text.replacingOccurrences(of: "\r", with: " ")
        return text.isEmpty ? message : text
    }
}
