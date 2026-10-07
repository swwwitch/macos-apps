import AppKit

/// Official .ai → PDF: Illustrator exports the document as PDF with an Adobe PDF preset
/// (Resources/Illustrator/SaveAsPDF.jsx, after sttk3's exportPDF), driven through osascript `do javascript`.
/// .ai → PNG / SVG goes through ExportImages.jsx the same way. PhotoshopBridge shares the plumbing.
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
    static func installations(bundleID: String = bundleID) -> [Installation] {
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

    static func script(_ name: String, subdirectory: String = "Illustrator") throws -> String {
        if let directory = scriptsDirectory { return try String(contentsOf: directory.appendingPathComponent(subdirectory).appendingPathComponent(name + ".jsx"), encoding: .utf8) }
        guard let url = Bundle.main.url(forResource: name, withExtension: "jsx", subdirectory: subdirectory)
                ?? Bundle.main.url(forResource: name, withExtension: "jsx") else { throw error("illustratorScriptMissing") }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func error(_ key: String, _ detail: String = "") -> NSError {
        NSError(domain: "PandocDesk.Illustrator", code: 1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(key, comment: "") + detail])
    }

    /// Runs JSX in the given Illustrator (or Photoshop, with its `terms` ID) with arguments; returns the script's result text.
    static func run(_ jsx: String, arguments: [String], in app: URL, terms: String = bundleID, isCancelled: () -> Bool = { false }) throws -> String {
        let runner = """
        on run argv
            set appPath to item 1 of argv
            set jsx to item 2 of argv
            set args to {}
            if (count of argv) > 2 then set args to items 3 thru -1 of argv
            using terms from application id "\(terms)"
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
            let prefix = terms == bundleID ? "illustrator" : "photoshop"
            if message.contains("(-1743)") || message.contains("(-1744)") { throw error(prefix + "Denied") }
            if message.contains("(-1712)") { throw error(prefix + "Timeout") }
            throw error(prefix + "Failed", message.trimmingCharacters(in: .whitespacesAndNewlines))
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

    /// One exported artboard: its 1-based number, name, and the file Illustrator wrote.
    struct ExportedArtboard { let number: Int; let name: String; let file: URL; let total: Int }

    /// .ai → PNG (at `ppi`) or SVG, one file per artboard in `range`, all inside `folder` (a scratch folder).
    static func exportImages(from input: URL, into folder: URL, kind: String, range: String, ppi: Int, transparent: Bool,
                             svg: SVGOptions, app: URL, isCancelled: () -> Bool) throws -> (artboards: [ExportedArtboard], notes: [Note]) {
        let arguments = [input.path, folder.path, kind, range, String(ppi), transparent ? "1" : "0",
                         svg.css, svg.font, svg.images, String(svg.precision), svg.idType, svg.minify ? "1" : "0", svg.responsive ? "1" : "0"]
        let result = try run(script("ExportImages"), arguments: arguments, in: app, isCancelled: isCancelled)
        if result == "ERROR:tooOld" { throw error("illustratorTooOld") }
        if result == "ERROR:range" { throw PageRange.invalid(range) }
        if result.hasPrefix("ERROR:rangeOut") { throw PageRange.outOfRange(range, Int(result.components(separatedBy: "\t").last ?? "") ?? 0) }
        if result.hasPrefix("ERROR:") { throw error("illustratorFailed", String(result.dropFirst(6))) }
        let lines = result.components(separatedBy: "\n")
        let notes = (lines.first ?? "").components(separatedBy: "\t").dropFirst().compactMap(Note.init(rawValue:))
        let rows = lines.dropFirst().map { $0.components(separatedBy: "\t") }.filter { $0.count >= 3 && $0[0] == "AB" }
        // Numbers stay as in Illustrator even with a range; `total` is the document's artboard count.
        let total = lines.first { $0.hasPrefix("COUNT\t") }.flatMap { Int($0.dropFirst(6)) } ?? rows.count
        let ext = kind == "svg" ? "svg" : "png"
        let artboards = try rows.map { row -> ExportedArtboard in
            let number = Int(row[1]) ?? 0
            let sub = folder.appendingPathComponent("ab\(number)", isDirectory: true)
            guard let file = (try? FileManager.default.contentsOfDirectory(at: sub, includingPropertiesForKeys: nil))?.first(where: { $0.pathExtension.lowercased() == ext })
            else { throw error("illustratorFailed") }
            return ExportedArtboard(number: number, name: row[2...].joined(separator: "\t"), file: file, total: total)
        }
        guard !artboards.isEmpty else { throw error("illustratorFailed") }
        return (artboards, Array(notes))
    }
}

/// .psd → PNG / PDF through Photoshop (Resources/Photoshop/SaveCopy.jsx), the same way as IllustratorBridge.
enum PhotoshopBridge {
    static let bundleID = "com.adobe.Photoshop"
    static func installations() -> [IllustratorBridge.Installation] { IllustratorBridge.installations(bundleID: bundleID) }
    static func defaultInstallation() -> IllustratorBridge.Installation? { installations().first }

    /// Saves a copy as PNG (`kind` "png") or PDF ("pdf") at `output`.
    static func saveCopy(from input: URL, to output: URL, kind: String, app: URL, isCancelled: () -> Bool) throws -> [IllustratorBridge.Note] {
        let result = try IllustratorBridge.run(IllustratorBridge.script("SaveCopy", subdirectory: "Photoshop"), arguments: [input.path, output.path, kind],
                                               in: app, terms: bundleID, isCancelled: isCancelled)
        if result.hasPrefix("ERROR:") { throw IllustratorBridge.error("photoshopFailed", String(result.dropFirst(6))) }
        guard FileManager.default.fileExists(atPath: output.path) else { throw IllustratorBridge.error("photoshopFailed") }
        return result.components(separatedBy: "\t").dropFirst().compactMap(IllustratorBridge.Note.init(rawValue:))
    }
}
