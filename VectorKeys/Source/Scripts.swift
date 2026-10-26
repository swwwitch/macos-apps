import Foundation

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// A hotkey in Carbon terms (kVK_* key code; ⌘256 ⇧512 ⌥2048 ⌃4096).
struct Hotkey: Codable, Hashable {
    var code: UInt32
    var modifiers: UInt32
}

/// One registered script file.
struct ScriptEntry: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var path: String
    var hotkey: Hotkey?
    var enabled: Bool

    static let extensions: Set<String> = ["jsx", "js", "jsxbin"]
    static func accepts(_ url: URL) -> Bool { extensions.contains(url.pathExtension.lowercased()) }
    /// The file name without its extension: 「AlignToArtboard.jsx」 → 「AlignToArtboard」.
    static func defaultName(for path: String) -> String {
        ((path as NSString).lastPathComponent as NSString).deletingPathExtension
    }
    init(id: String = UUID().uuidString, path: String, name: String? = nil, hotkey: Hotkey? = nil, enabled: Bool = true) {
        self.id = id; self.path = path; self.name = name ?? Self.defaultName(for: path); self.hotkey = hotkey; self.enabled = enabled
    }
    var fileExists: Bool { FileManager.default.fileExists(atPath: path) }
}

/// The registered scripts, kept in Application Support/VectorKeys/Scripts.json.
struct Library: Codable, Equatable {
    var version = 1
    var scripts: [ScriptEntry] = []

    static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("VectorKeys", isDirectory: true)
    }
    static var file: URL { folder.appendingPathComponent("Scripts.json") }

    static func load(from url: URL = file) -> Library {
        guard let data = try? Data(contentsOf: url) else { return Library() }
        return (try? JSONDecoder().decode(Library.self, from: data)) ?? Library()
    }
    func save(to url: URL = file) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    /// Adds files not registered yet (same path = same script). Returns the new entries in the given order.
    @discardableResult
    mutating func add(paths: [String]) -> [ScriptEntry] {
        var known = Set(scripts.map(\.path))
        var added: [ScriptEntry] = []
        for path in paths where !known.contains(path) && ScriptEntry.accepts(URL(fileURLWithPath: path)) {
            known.insert(path)
            added.append(ScriptEntry(path: path))
        }
        scripts.append(contentsOf: added)
        return added
    }

    /// Scripts that would react to a hotkey: enabled and with a key, the first one in the list winning a repeated key.
    /// Returns the winners and the ids that lose to an earlier script.
    func activeHotkeys() -> (winners: [(Hotkey, String)], duplicates: Set<String>) {
        var seen: Set<Hotkey> = [], winners: [(Hotkey, String)] = [], duplicates: Set<String> = []
        for script in scripts where script.enabled {
            guard let hotkey = script.hotkey else { continue }
            if seen.contains(hotkey) { duplicates.insert(script.id); continue }
            seen.insert(hotkey); winners.append((hotkey, script.id))
        }
        return (winners, duplicates)
    }
}

enum ScriptText {
    static func quote(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
    /// Runs the file with `do javascript`, addressing Illustrator by its path so the one in front is used when several versions are open.
    /// A long timeout: scripts that open a dialog box keep `do javascript` waiting until it is closed.
    static func appleScript(appPath: String, file: String) -> String {
        """
        with timeout of 3600 seconds
        tell application \(quote(appPath))
        do javascript (POSIX file \(quote(file)) as alias)
        end tell
        end timeout
        """
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
        input.fileHandleForWriting.write(source.data(using: .utf8)!)
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
