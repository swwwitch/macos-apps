import Foundation

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// A hotkey in Carbon terms (kVK_* key code; ⌘256 ⇧512 ⌥2048 ⌃4096).
struct Hotkey: Codable, Hashable {
    var code: UInt32
    var modifiers: UInt32
}

/// A hotkey that runs the script with other values for some of its SW_ variables (「SW_ACTION = left」に ⌃⌥← など).
struct VariableKey: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    /// Values by variable name; a name left out keeps the entry's value (or the file's).
    var values: [String: String] = [:]
    var hotkey: Hotkey?
    /// 「left · true」: the values in name order, for the list, the run record and the undo name.
    var label: String { values.sorted { $0.key < $1.key }.map(\.value).joined(separator: " · ") }
}

/// What a hotkey runs: the script as set, or one of its variable keys.
struct Trigger: Hashable {
    let script: String
    var key: String? = nil
}

/// One registered script file.
struct ScriptEntry: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var path: String
    var hotkey: Hotkey?
    var enabled: Bool
    /// Successful runs (hotkey or Run button) and the last one. Optional so lists saved by 1.0.0 still load.
    var runCount: Int?
    var lastRun: Date?
    var uses: Int { runCount ?? 0 }
    /// New initial values of the script's `var SW_… = …;` declarations, by name (only the changed ones).
    /// The file stays as it is; a changed copy runs instead. Optional so lists saved without it still load.
    var variables: [String: String]?
    /// Hotkeys that run the script with other variable values. Optional so older lists load.
    var variableKeys: [VariableKey]?
    var keys: [VariableKey] { variableKeys ?? [] }
    /// The changed variables in name order: the entry's own, then those of the variable key on top.
    func overrides(with key: VariableKey? = nil) -> [(name: String, value: String)] {
        (variables ?? [:]).merging(key?.values ?? [:]) { _, new in new }.sorted { $0.key < $1.key }.map { (name: $0.key, value: $0.value) }
    }
    /// 「IdAlign（left · true）」 for a variable key, the name alone otherwise.
    func title(for key: VariableKey?) -> String {
        guard let key, !key.label.isEmpty else { return name }
        return "\(name)（\(key.label)）"
    }

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
    mutating func recordRun(at date: Date = Date()) { runCount = uses + 1; lastRun = date }
}

/// The registered scripts, kept in Application Support/LayoutKeys/Scripts.json.
struct Library: Codable, Equatable {
    var version = 1
    var scripts: [ScriptEntry] = []

    static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LayoutKeys", isDirectory: true)
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

    /// Hotkeys that would react: of enabled scripts, the script's own key and then its variable keys,
    /// the first one in the list winning a repeated key. Returns the winners and the triggers that lose to an earlier one.
    func activeHotkeys() -> (winners: [(Hotkey, Trigger)], duplicates: Set<Trigger>) {
        var seen: Set<Hotkey> = [], winners: [(Hotkey, Trigger)] = [], duplicates: Set<Trigger> = []
        func take(_ hotkey: Hotkey?, _ trigger: Trigger) {
            guard let hotkey else { return }
            if seen.contains(hotkey) { duplicates.insert(trigger); return }
            seen.insert(hotkey); winners.append((hotkey, trigger))
        }
        for script in scripts where script.enabled {
            take(script.hotkey, Trigger(script: script.id))
            for key in script.keys { take(key.hotkey, Trigger(script: script.id, key: key.id)) }
        }
        return (winners, duplicates)
    }
}

enum ScriptText {
    static func quote(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
    /// Runs the file with `do script … language javascript`, addressing InDesign by its path so the one in front is used when several versions are open.
    /// One undo step named after the script (`undo mode entire script`), as InDesign's own scripts usually do with `app.doScript`.
    /// A long timeout: scripts that open a dialog box keep `do script` waiting until it is closed.
    /// The same, with the script's text instead of its file (used when SW_ variables are changed). `#targetengine` still applies.
    static func appleScript(appPath: String, code: String, undoName: String) -> String {
        "with timeout of 3600 seconds\ntell application \(quote(appPath))\ndo script \(quote(code)) language javascript undo mode entire script undo name \(quote(undoName))\nend tell\nend timeout"
    }
    static func appleScript(appPath: String, file: String, undoName: String) -> String {
        """
        with timeout of 3600 seconds
        tell application \(quote(appPath))
        do script (POSIX file \(quote(file)) as alias) language javascript undo mode entire script undo name \(quote(undoName))
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
    /// "102:308: execution error: Adobe InDesign 2026でエラーが起きました: Uncaught JavaScript exception: probe (54)" → "probe".
    static func cleanError(_ message: String) -> String {
        var text = message
        if let range = text.range(of: "execution error: ") { text = String(text[range.upperBound...]) }
        if let range = text.range(of: "：") ?? text.range(of: ": ") { text = String(text[range.upperBound...]) }
        if let range = text.range(of: " (", options: .backwards), text.hasSuffix(")") { text = String(text[..<range.lowerBound]) }
        if text.hasPrefix("Uncaught JavaScript exception: ") { text = String(text.dropFirst("Uncaught JavaScript exception: ".count)) }
        text = text.replacingOccurrences(of: "\r", with: " ")
        return text.isEmpty ? message : text
    }
}
