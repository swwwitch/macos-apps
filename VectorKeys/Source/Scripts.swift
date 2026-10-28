import Foundation

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// A hotkey in Carbon terms (kVK_* key code; ⌘256 ⇧512 ⌥2048 ⌃4096).
/// taps: nil = press once, 2 = press twice in a row (Keyboard Maestro's "tapped twice").
struct Hotkey: Codable, Hashable {
    var code: UInt32
    var modifiers: UInt32
    var taps: Int?
    var isDouble: Bool { taps == 2 }
    /// The key itself, shared by its single and double press.
    struct Key: Hashable { var code: UInt32; var modifiers: UInt32 }
    var key: Key { Key(code: code, modifiers: modifiers) }
}

/// A saved step. Legacy menu cases remain decodable so existing libraries round-trip without data loss.
enum Step: Codable, Hashable {
    /// A script file run with do javascript.
    case script(path: String)
    case code(source: String)
    /// Legacy command record, retained for decoding only; never executed.
    case menuCommand(id: String, title: String?)
    /// Legacy menu-title record, retained for decoding only; never executed.
    case menuItem(path: [String])

    var scriptPath: String? { if case .script(let path) = self { return path }; return nil }
    var isSupported: Bool {
        switch self { case .script, .code: return true; case .menuCommand, .menuItem: return false }
    }
    var exists: Bool {
        if case .code(let source) = self { return !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return scriptPath.map { FileManager.default.fileExists(atPath: $0) } ?? true
    }
    var identity: String {
        switch self {
        case .script(let path): return path
        case .code(let source): return "code:" + source
        case .menuCommand(let id, _): return "command:" + id
        case .menuItem(let path): return "menu:" + path.joined(separator: " > ")
        }
    }
}

/// Finder's standard tag palette; these are app item labels, never filesystem tags.
enum ItemTag: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, gray
}

/// One registered script item; script files run in order by one hotkey.
struct ScriptEntry: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var path: String
    var hotkey: Hotkey?
    var enabled: Bool
    /// nil = uncategorized.
    var category: String?
    /// The Keyboard Maestro macro it was imported from (turned off / on from Tools).
    var kmUID: String?
    /// The steps. nil in lists saved before 1.4.0: those items are their one script (path).
    var steps: [Step]?
    /// The steps to run. Setting them keeps path on the first script, which older code and the import use.
    var actions: [Step] {
        get { steps ?? (path.isEmpty ? [] : [.script(path: path)]) }
        set { steps = newValue; path = newValue.compactMap(\.scriptPath).first ?? "" }
    }
    /// What makes two items the same: the one step of a single-step item; a multi-step item is only itself.
    var identity: String { actions.count == 1 ? actions[0].identity : "item:" + id }
    init(id: String = UUID().uuidString, steps: [Step], name: String, hotkey: Hotkey? = nil, enabled: Bool = true) {
        self.init(id: id, path: "", name: name, hotkey: hotkey, enabled: enabled)
        actions = steps
    }
    /// Successful runs (hotkey or Run button) and the last one. Optional so lists saved by 1.0.0 still load.
    var tagColor: ItemTag?
    var notes: String?
    var runCount: Int?
    var lastRun: Date?
    var uses: Int { runCount ?? 0 }

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
    /// Never execute only the script portion of a legacy mixed item. Keep its data for explicit editing.
    var hasUnsupportedSteps: Bool { actions.contains { !$0.isSupported } }
    var scriptsOnly: Bool { !actions.isEmpty && !hasUnsupportedSteps }
    var isAvailable: Bool { scriptsOnly && actions.allSatisfy(\.exists) }
    mutating func recordRun(at date: Date = Date()) { runCount = uses + 1; lastRun = date }
}

/// The registered scripts, kept in Application Support/VectorKeys/Scripts.json.
struct Library: Codable, Equatable {
    var version = 1
    var scripts: [ScriptEntry] = []
    /// Category names in the sidebar order. Optional so lists saved before 1.3.0 still load.
    var categories: [String]?
    var paletteHotkeys: [String: Hotkey]?
    var paletteEnabled: [String: Bool]?
    var paletteModes: [String: Int]?
    func allowsPalette(_ category: String) -> Bool { paletteEnabled?[category] ?? true }
    func paletteMode(_ category: String) -> Int { paletteModes?[category] ?? 0 }
    mutating func sortSelected(_ ids: Set<String>, by order: SortOrder, keyName: (Hotkey) -> String) {
        // Replace only selected slots in each category, preserving every unselected row.
        for category in Set(scripts.filter { ids.contains($0.id) }.map { $0.category ?? "" }) {
            let slots = scripts.indices.filter { ids.contains(scripts[$0].id) && (scripts[$0].category ?? "") == category }
            let sorted = order.sorted(slots.map { scripts[$0] }, keyName: keyName)
            for (slot, entry) in zip(slots, sorted) { scripts[slot] = entry }
        }
    }

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
        add(entries: paths.map { ScriptEntry(path: $0) })
    }
    /// Adds entries not registered yet (the same file, command ID or menu path counts once), keeping their name, hotkey and on/off.
    @discardableResult
    mutating func add(entries: [ScriptEntry]) -> [ScriptEntry] {
        var known = Set(scripts.map(\.identity))
        var added: [ScriptEntry] = []
        for entry in entries where entry.scriptsOnly && !known.contains(entry.identity) && entry.actions.allSatisfy({ $0.scriptPath.map { ScriptEntry.accepts(URL(fileURLWithPath: $0)) } ?? true }) {
            known.insert(entry.identity)
            added.append(entry)
        }
        scripts.append(contentsOf: added)
        return added
    }

    // MARK: Categories

    /// The sidebar categories: the saved order, then any name a script uses that the list lacks.
    var categoryList: [String] {
        var list = categories ?? []
        for name in scripts.compactMap(\.category) where !list.contains(name) { list.append(name) }
        return list
    }
    /// Adds a category (a name already there is kept once). Returns the trimmed name, or nil when empty.
    @discardableResult
    mutating func addCategory(_ name: String) -> String? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        var list = categoryList
        if !list.contains(name) { list.append(name) }
        categories = list
        return name
    }
    /// Renames a category and moves its scripts along. Renaming onto an existing name merges the two.
    mutating func renameCategory(_ old: String, to new: String) {
        let new = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !new.isEmpty, new != old else { return }
        var list = categoryList
        if list.contains(new) { list.removeAll { $0 == old } } else if let index = list.firstIndex(of: old) { list[index] = new }
        categories = list
        if let key = paletteHotkeys?.removeValue(forKey: old), paletteHotkeys?[new] == nil { paletteHotkeys?[new] = key }
        if let value = paletteEnabled?.removeValue(forKey: old), paletteEnabled?[new] == nil { paletteEnabled?[new] = value }
        if let value = paletteModes?.removeValue(forKey: old), paletteModes?[new] == nil { paletteModes?[new] = value }
        for index in scripts.indices where scripts[index].category == old { scripts[index].category = new }
    }
    /// Removes a category; its scripts become uncategorized (nothing is deleted).
    mutating func deleteCategory(_ name: String) {
        categories = categoryList.filter { $0 != name }
        paletteHotkeys?.removeValue(forKey: name)
        paletteEnabled?.removeValue(forKey: name)
        paletteModes?.removeValue(forKey: name)
        for index in scripts.indices where scripts[index].category == name { scripts[index].category = nil }
    }
    mutating func setCategory(_ name: String?, for ids: Set<String>) {
        if let name { addCategory(name) }
        for index in scripts.indices where ids.contains(scripts[index].id) { scripts[index].category = name }
    }
    /// Moves within a shown subset (one category, in list order) and writes the new order back into the full list.
    mutating func move(ids: [String], from source: IndexSet, to destination: Int) {
        // Array.move(fromOffsets:toOffset:) lives in SwiftUI; this file stays Foundation-only for the tests.
        let picked = source.map { ids[$0] }
        var moved = ids.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertAt = destination - source.filter { $0 < destination }.count
        moved.insert(contentsOf: picked, at: max(0, min(insertAt, moved.count)))
        let members = Set(ids)
        var next = moved.makeIterator()
        let byID = Dictionary(uniqueKeysWithValues: scripts.map { ($0.id, $0) })
        for index in scripts.indices where members.contains(scripts[index].id) {
            if let id = next.next(), let script = byID[id] { scripts[index] = script }
        }
    }

    /// Removes Keyboard Maestro numbering from the start of the names: 「11)」「21）」「11)1 」 (a digit right after
    /// the bracket stays when it is part of the name, as in 「12)3Dにする」). Returns how many names changed.
    @discardableResult
    mutating func stripNumbering(ids: Set<String>) -> Int {
        var changed = 0
        for index in scripts.indices where ids.contains(scripts[index].id) {
            let stripped = Self.strippingNumbering(scripts[index].name)
            if stripped != scripts[index].name && !stripped.isEmpty { scripts[index].name = stripped; changed += 1 }
        }
        return changed
    }
    static func strippingNumbering(_ name: String) -> String {
        name.replacingOccurrences(of: #"^\s*\d+\s*[)）]\s*(\d+\s+)?"#, with: "", options: .regularExpression)
    }

    /// Find and replace in a name. nil when the regular expression is invalid; an empty result keeps the old name.
    static func replacing(in name: String, find: String, with replacement: String, regex: Bool, caseSensitive: Bool) -> String? {
        guard !find.isEmpty else { return name }
        var options: String.CompareOptions = regex ? [.regularExpression] : []
        if !caseSensitive { options.insert(.caseInsensitive) }
        if regex {
            guard (try? NSRegularExpression(pattern: find, options: caseSensitive ? [] : [.caseInsensitive])) != nil else { return nil }
        }
        // A literal replacement must not read $1 or \ as template characters.
        let template = regex ? replacement : NSRegularExpression.escapedTemplate(for: replacement)
        let pattern = regex ? find : NSRegularExpression.escapedPattern(for: find)
        let result = name.replacingOccurrences(of: pattern, with: template, options: options.union(.regularExpression))
        let trimmed = result.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? name : trimmed
    }
    /// Applies replacing(in:…) to the names of the given scripts. Returns how many changed (0 for an invalid pattern).
    @discardableResult
    mutating func replaceNames(ids: Set<String>, find: String, with replacement: String, regex: Bool, caseSensitive: Bool) -> Int {
        var changed = 0
        for index in scripts.indices where ids.contains(scripts[index].id) {
            guard let new = Self.replacing(in: scripts[index].name, find: find, with: replacement, regex: regex, caseSensitive: caseSensitive) else { return 0 }
            if new != scripts[index].name { scripts[index].name = new; changed += 1 }
        }
        return changed
    }

    /// Every script by use: most runs first, then the latest run, then name (scripts never run come last).
    var byUse: [ScriptEntry] {
        scripts.sorted { a, b in
            if a.uses != b.uses { return a.uses > b.uses }
            if a.lastRun != b.lastRun { return (a.lastRun ?? .distantPast) > (b.lastRun ?? .distantPast) }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    // MARK: Hotkeys

    /// Scripts that would react to a hotkey: enabled and with a key, the first one in the list winning a repeated key
    /// (a single and a double press of the same key are different hotkeys).
    /// Returns the winners and the ids that lose to an earlier script.
    func activeHotkeys() -> (winners: [(Hotkey, String)], duplicates: Set<String>) {
        var seen: Set<Hotkey> = [], winners: [(Hotkey, String)] = [], duplicates: Set<String> = []
        for script in scripts where script.enabled && script.scriptsOnly {
            guard let hotkey = script.hotkey else { continue }
            if seen.contains(hotkey) { duplicates.insert(script.id); continue }
            seen.insert(hotkey); winners.append((hotkey, script.id))
        }
        return (winners, duplicates)
    }
    /// One registration per key: the script for a single press and the one for a double press.
    func keyTargets() -> [(key: Hotkey.Key, single: String?, double: String?)] {
        var order: [Hotkey.Key] = [], single: [Hotkey.Key: String] = [:], double: [Hotkey.Key: String] = [:]
        for (hotkey, id) in activeHotkeys().winners {
            if single[hotkey.key] == nil && double[hotkey.key] == nil { order.append(hotkey.key) }
            if hotkey.isDouble { double[hotkey.key] = id } else { single[hotkey.key] = id }
        }
        return order.map { ($0, single[$0], double[$0]) }
    }
}

/// How the list is shown (the saved order stays as it is).
enum SortOrder: String, CaseIterable {
    case manual, name, uses, hotkey
    func sorted(_ scripts: [ScriptEntry], keyName: (Hotkey) -> String) -> [ScriptEntry] {
        switch self {
        case .manual: return scripts
        case .name: return scripts.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .uses: return scripts.sorted { $0.uses > $1.uses }
        case .hotkey:
            // Scripts with a key first, by the key's name, then fewer modifiers, then single before double press.
            return scripts.sorted { a, b in
                switch (a.hotkey, b.hotkey) {
                case (nil, nil): return a.name.localizedStandardCompare(b.name) == .orderedAscending
                case (nil, _): return false
                case (_, nil): return true
                case let (x?, y?):
                    let nx = keyName(x), ny = keyName(y)
                    if nx != ny { return nx.localizedStandardCompare(ny) == .orderedAscending }
                    return false // Equal letter: keep the existing order, ignoring modifiers and tap count.
                }
            }
        }
    }
}

enum ScriptText {
    static func quote(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
    /// Runs the file with `do javascript`, addressing Illustrator by its path so the one in front is used when several versions are open.
    /// A long timeout: scripts that open a dialog box keep `do javascript` waiting until it is closed.
    static func appleScript(appPath: String, code: String) -> String {
        "with timeout of 3600 seconds\ntell application \(quote(appPath))\ndo javascript \(quote(code))\nend tell\nend timeout"
    }
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

/// Read local metadata as text; never execute scripts or follow metadata URLs automatically.
enum ScriptMetadata {
    struct Info: Equatable {
        var fields: [String: String] = [:]
        var summary = ""
        var version: String? {
            guard let value = fields["Version"], !value.isEmpty, value.count <= 64 else { return nil }
            return value
        }
        var codeURL: URL? { Self.webURL(fields["Code-URL"]) ?? Self.webURL(fields["Source-URL"]) }
        var url: URL? {
            Self.webURL(fields["Article-URL"]) ?? Self.webURL(fields["Meta-URL"])
        }
        func readmeURL(language: String) -> URL? {
            let preferred = language.lowercased().hasPrefix("ja") ? "README-JA" : "README-EN"
            let fallback = preferred == "README-JA" ? "README-EN" : "README-JA"
            return Self.webURL(fields[preferred]) ?? Self.webURL(fields[fallback])
        }
        private static func webURL(_ text: String?) -> URL? {
            guard let text, let url = URL(string: text), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
            return url
        }
    }
    static func parse(_ source: String) -> Info? {
        var fields = variables(in: source)
        let tags = parseTags(source)
        if let tags { fields.merge(tags.fields) { _, tagged in tagged } }
        guard !fields.isEmpty || tags != nil else { return nil }
        return Info(fields: fields, summary: tags?.summary ?? "")
    }
    private static func parseTags(_ source: String) -> Info? {
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        var inside = false, description = false
        var info = Info(), summary: [String] = []
        for raw in lines {
            var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("//") { line = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
            else if line.hasPrefix("*") { line = String(line.dropFirst()).trimmingCharacters(in: .whitespaces) }
            if !inside {
                if line == "SCRIPTMETA-BEGIN" { inside = true; info = Info(); summary = [] }
                continue
            }
            if description {
                if line == "Description-END" { description = false }
                else { summary.append(line) }
                continue
            }
            if line == "Description-BEGIN" { description = true; continue }
            if line == "SCRIPTMETA-END" {
                if let id = info.fields["Script-ID"], !id.isEmpty {
                    info.summary = summary.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    return info
                }
                inside = false
                continue
            }
            let pair = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { continue }
            let key = pair[0].trimmingCharacters(in: .whitespaces)
            let value = pair[1].trimmingCharacters(in: .whitespaces)
            info.fields[key] = value
        }
        return nil
    }
    static func read(at path: String) -> Info? {
        guard (path as NSString).pathExtension.lowercased() != "jsxbin", let file = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? file.close() }
        guard let data = try? file.read(upToCount: 262144), let text = String(data: data, encoding: .utf8) else { return nil }
        return parse(text)
    }
    static func version(in source: String) -> String? { parse(source)?.version }
    static func version(at path: String) -> String? { read(at: path)?.version }
    static func readme(for path: String) -> URL? {
        let script = URL(fileURLWithPath: path)
        let folder = script.deletingLastPathComponent()
        let candidates = [script.deletingPathExtension().appendingPathExtension("md"),
                          folder.appendingPathComponent("README.md"), folder.appendingPathComponent("README.txt")]
        return candidates.first { url in
            var directory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &directory) && !directory.boolValue
        }
    }
}

extension ScriptMetadata {
    static func variables(in source: String) -> [String: String] {
        let names = ["SCRIPT_CODE_URL": "Code-URL", "SCRIPT_GITHUB_URL": "Code-URL", "SCRIPT_NAME": "Name", "SCRIPT_VERSION": "Version", "SCRIPT_AUTHOR": "Author",
                     "SCRIPT_RELEASED": "First-Release-Date", "SCRIPT_UPDATED": "Updated-Date",
                     "SCRIPT_README_JA": "README-JA", "SCRIPT_README_EN": "README-EN", "SCRIPT_ARTICLE_URL": "Article-URL"]
        let pattern = #"//[^\r\n]*|/\*[\s\S]*?\*/|"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*'|`(?:\\[\s\S]|[^`\\])*`|[A-Za-z_$][A-Za-z0-9_$]*|[^\s]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }
        let text = source as NSString
        let tokens = regex.matches(in: source, range: NSRange(location: 0, length: text.length)).map { text.substring(with: $0.range) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("/*") }
        guard tokens.count >= 4 else { return [:] }
        var result: [String: String] = [:]
        for i in 0...(tokens.count - 4) {
            guard ["var", "let", "const"].contains(tokens[i]), let field = names[tokens[i + 1]], tokens[i + 2] == "=" else { continue }
            guard i + 4 == tokens.count || [";", ","].contains(tokens[i + 4]), let value = literal(tokens[i + 3]), !value.isEmpty else { continue }
            result[field] = value
        }
        return result
    }
    private static func literal(_ token: String) -> String? {
        guard let quote = token.first, ["\"", "'"].contains(quote), token.last == quote else { return nil }
        let chars = Array(token.dropFirst().dropLast())
        var result = "", i = 0
        while i < chars.count {
            let char = chars[i]; i += 1
            if char != "\\" { result.append(char); continue }
            guard i < chars.count else { return nil }
            let escaped = chars[i]; i += 1
            switch escaped {
            case "\\", "\"", "'", "/": result.append(escaped)
            case "n": result.append("\n")
            case "r": result.append("\r")
            case "t": result.append("\t")
            case "b": result.append("\u{8}")
            case "f": result.append("\u{c}")
            case "u", "x":
                let count = escaped == "u" ? 4 : 2
                guard i + count <= chars.count, let number = UInt32(String(chars[i..<(i + count)]), radix: 16), let scalar = UnicodeScalar(number) else { return nil }
                result.unicodeScalars.append(scalar); i += count
            default: return nil
            }
        }
        return result
    }
}


extension ScriptMetadata {
    /// Select only links to this exact script. A repository/homepage alone is not proof.
    static func codeURL(in readme: String, scriptFilename: String, relativeTo base: URL? = nil) -> URL? {
        guard !scriptFilename.isEmpty,
              let regex = try? NSRegularExpression(pattern: #"https?://[^\s<>"\)\]]+|(?<=\]\()[^\s\)]+"#) else { return nil }
        let text = readme as NSString
        var candidates: [String: URL] = [:]
        for match in regex.matches(in: readme, range: NSRange(location: 0, length: text.length)) {
            let token = text.substring(with: match.range).replacingOccurrences(of: "&amp;", with: "&")
            guard let url = URL(string: token, relativeTo: base)?.absoluteURL,
                  ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil,
                  url.lastPathComponent.removingPercentEncoding?.caseInsensitiveCompare(scriptFilename) == .orderedSame else { continue }
            var normalized = URLComponents(url: url, resolvingAgainstBaseURL: true)
            normalized?.query = nil; normalized?.fragment = nil
            if url.host?.lowercased() == "raw.githubusercontent.com" {
                let parts = url.pathComponents.filter { $0 != "/" }
                if parts.count >= 4 {
                    normalized?.host = "github.com"
                    normalized?.path = "/" + (Array(parts.prefix(2)) + ["blob"] + Array(parts.dropFirst(2))).joined(separator: "/")
                }
            }
            if let canonical = normalized?.url { candidates[canonical.absoluteString] = canonical }
        }
        return candidates.count == 1 ? candidates.values.first : nil
    }
    static func readText(at url: URL) -> String? {
        guard url.isFileURL, let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }
        guard let data = try? file.read(upToCount: 524288) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func readmeRequestURL(_ url: URL) -> URL? {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        if url.host?.lowercased() == "github.com" {
            var parts = url.pathComponents.filter { $0 != "/" }
            guard parts.count >= 5, parts[2] == "blob" else { return nil }
            parts.remove(at: 2)
            var components = URLComponents()
            components.scheme = "https"; components.host = "raw.githubusercontent.com"
            components.path = "/" + parts.joined(separator: "/")
            return components.url
        }
        return url
    }
}
