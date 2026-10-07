import AppKit

/// Official .ai → PDF: Illustrator exports the document as PDF with an Adobe PDF preset
/// (Resources/Illustrator/SaveAsPDF.jsx, after sttk3's exportPDF), driven through osascript `do javascript`.
enum IllustratorBridge {
    static let bundleID = "com.adobe.illustrator"

    struct Installation: Identifiable, Hashable {
        let url: URL
        let version: String
        var id: String { url.path }
        var name: String { url.deletingLastPathComponent().lastPathComponent }   // e.g. "Adobe Illustrator 2026"
        var isPrerelease: Bool { name.contains("Beta") || name.contains("Prerelease") }
    }

    /// Installed Illustrators, newest release first (Beta/Prerelease last).
    static func installations() -> [Installation] {
        let urls: [URL]
        if #available(macOS 12.0, *) { urls = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: bundleID) }
        else { urls = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { [$0] } ?? [] }
        let found = urls.compactMap { url -> Installation? in
            guard url.path.hasPrefix("/Applications/") else { return nil }
            let version = Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            return Installation(url: url, version: version)
        }
        return found.sorted { a, b in
            if a.isPrerelease != b.isPrerelease { return !a.isPrerelease }
            return a.version.compare(b.version, options: .numeric) == .orderedDescending
        }
    }

    static func defaultInstallation() -> Installation? { installations().first }

    /// Tests point this at Resources/Illustrator; the app reads the bundled copies.
    nonisolated(unsafe) static var scriptsDirectory: URL?

    private static func script(_ name: String) throws -> String {
        if let directory = scriptsDirectory { return try String(contentsOf: directory.appendingPathComponent(name + ".jsx"), encoding: .utf8) }
        guard let url = Bundle.main.url(forResource: name, withExtension: "jsx", subdirectory: "Illustrator")
                ?? Bundle.main.url(forResource: name, withExtension: "jsx") else { throw error("illustratorScriptMissing") }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func error(_ key: String, _ detail: String = "") -> NSError {
        NSError(domain: "PandocDesk.Illustrator", code: 1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(key, comment: "") + detail])
    }

    /// Runs JSX in the given Illustrator with arguments; returns the script's result text.
    static func run(_ jsx: String, arguments: [String], in app: URL, isCancelled: () -> Bool = { false }) throws -> String {
        let runner = """
        on run argv
            set appPath to item 1 of argv
            set jsx to item 2 of argv
            set args to {}
            if (count of argv) > 2 then set args to items 3 thru -1 of argv
            using terms from application id "com.adobe.illustrator"
                with timeout of 3600 seconds
                    tell application appPath
                        return do javascript jsx with arguments args
                    end tell
                end timeout
            end using terms from
        end run
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", runner, app.path, jsx] + arguments
        let output = Pipe(), errorPipe = Pipe()
        process.standardOutput = output; process.standardError = errorPipe
        try process.run()
        let outData = output.fileHandleForReading.readDataToEndOfFile()
        let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if isCancelled() { throw CancellationError() }
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errData, as: UTF8.self)
            if message.contains("(-1743)") || message.contains("(-1744)") { throw error("illustratorDenied") }
            if message.contains("(-1712)") { throw error("illustratorTimeout") }
            throw error("illustratorFailed", message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return String(decoding: outData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// PDF preset names from Illustrator (launches it if needed).
    static func presets(in app: URL) throws -> [String] {
        try run(script("ListPDFPresets"), arguments: [], in: app).components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    /// Notes from an export that become warnings (not failures).
    enum Note: String { case open, unsaved, links }

    /// Exports through Illustrator's exportForScreens into a fresh folder and moves the PDF to `output`.
    static func exportPDF(from input: URL, to output: URL, preset: String, app: URL, isCancelled: () -> Bool) throws -> [Note] {
        let fm = FileManager.default
        let folder = output.deletingLastPathComponent().appendingPathComponent("export-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: folder) }
        let result = try run(script("SaveAsPDF"), arguments: [input.path, folder.path, preset], in: app, isCancelled: isCancelled)
        if result == "ERROR:tooOld" { throw error("illustratorTooOld") }
        if result == "ERROR:presetMissing" { throw error("illustratorPresetMissing", " " + preset) }
        if result.hasPrefix("ERROR:") { throw error("illustratorFailed", String(result.dropFirst(6))) }
        let produced = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?
            .first { $0.pathExtension.lowercased() == "pdf" }
        guard let produced else { throw error("illustratorFailed") }
        try? fm.removeItem(at: output)
        try fm.moveItem(at: produced, to: output)
        return result.components(separatedBy: "\t").dropFirst().compactMap(Note.init(rawValue:))
    }
}
