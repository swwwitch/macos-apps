import Foundation

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// A hotkey in Carbon terms (kVK_* key code; ⌘256 ⇧512 ⌥2048 ⌃4096).
struct Hotkey: Codable, Hashable {
    var code: UInt32
    var modifiers: UInt32
}

/// The palette's buttons in its order (the 3×3 cross, then the two single-axis centers). Raw values are the script's SW_ACTION names.
enum AlignAction: String, CaseIterable, Identifiable {
    case upLeft, up, upRight, left, center, right, downLeft, down, downRight, centerH, centerV
    var id: String { rawValue }
    var title: String { L("action." + rawValue) }
    /// The center buttons have no 「from the center」 form: starting from the center changes nothing for them.
    var hasFromCenter: Bool { ![.center, .centerH, .centerV].contains(self) }
    var symbol: String {
        switch self {
        case .upLeft: return "arrow.up.left"
        case .up: return "arrow.up"
        case .upRight: return "arrow.up.right"
        case .left: return "arrow.left"
        case .center: return "plus"
        case .right: return "arrow.right"
        case .downLeft: return "arrow.down.left"
        case .down: return "arrow.down"
        case .downRight: return "arrow.down.right"
        case .centerH: return "align.horizontal.center"
        case .centerV: return "align.vertical.center"
        }
    }
}

/// One thing a hotkey runs: a button, optionally after centering first (Option-click on the palette),
/// moving the selection as a unit (⌥ added to the key) and centering on the margins instead of the page (⇧ added).
struct Trigger: Hashable, Identifiable {
    let action: AlignAction
    var fromCenter = false
    var asUnit = false
    var margin = false
    /// Registered through 「上下左右は矢印キーでも」 rather than the cell's own key (kept apart so their problems show separately).
    var arrow = false
    /// The table cell the key is set in: the button, or its 「from the center」 form. The ⌥ / ⇧ forms come from that key.
    var id: String { action.rawValue + (fromCenter ? ".fromCenter" : "") }
    var base: Trigger { Trigger(action: action, fromCenter: fromCenter) }
    var centerBasis: CenterBasis { margin ? .margin : .page }
    /// 「左」「左（中央から・まとめて・マージン）」.
    var title: String {
        let parts = [fromCenter ? L("variant.fromCenter") : nil, asUnit ? L("variant.asUnit") : nil, margin ? L("variant.margin") : nil].compactMap { $0 }
        return parts.isEmpty ? action.title : String(format: L("variant.title"), action.title, parts.joined(separator: L("variant.separator")))
    }
    /// The table cells in order; a repeated key goes to the first one.
    static let cells: [Trigger] = AlignAction.allCases.flatMap { action in
        action.hasFromCenter ? [Trigger(action: action), Trigger(action: action, fromCenter: true)] : [Trigger(action: action)]
    }
}

extension Hotkey {
    static let option: UInt32 = 2048, shift: UInt32 = 512, command: UInt32 = 256, control: UInt32 = 4096
    /// The forms a cell's key registers: as set, with ⌥ (as a unit), with ⇧ (margins) and with both.
    /// A key that already holds ⌥ or ⇧ does not get that form.
    func variants(of cell: Trigger) -> [(Hotkey, Trigger)] {
        var result: [(Hotkey, Trigger)] = []
        for (asUnit, margin) in [(false, false), (true, false), (false, true), (true, true)] {
            if asUnit && modifiers & Self.option != 0 { continue }
            if margin && modifiers & Self.shift != 0 { continue }
            let extra = (asUnit ? Self.option : 0) | (margin ? Self.shift : 0)
            result.append((Hotkey(code: code, modifiers: modifiers | extra), Trigger(action: cell.action, fromCenter: cell.fromCenter, asUnit: asUnit, margin: margin, arrow: cell.arrow)))
        }
        return result
    }
}

/// The hotkeys by table cell, kept in UserDefaults (and shared between Macs with the settings).
struct KeyMap: Codable, Equatable {
    static let defaultsKey = "actionHotkeys"
    var keys: [String: Hotkey] = [:]
    subscript(cell: Trigger) -> Hotkey? {
        get { keys[cell.id] }
        set { keys[cell.id] = newValue }
    }
    /// ⌃⌘ with the keys laid out like the 3×3 buttons: U I O / J K L / M , . (kVK codes). The others start unassigned.
    static let defaultKeys: [AlignAction: UInt32] = [.upLeft: 32, .up: 34, .upRight: 31, .left: 38, .center: 40, .right: 37, .downLeft: 46, .down: 43, .downRight: 47]
    static func defaultHotkey(for cell: Trigger) -> Hotkey? {
        guard !cell.fromCenter, let code = defaultKeys[cell.action] else { return nil }
        return Hotkey(code: code, modifiers: Hotkey.control | Hotkey.command)
    }
    static var defaults: KeyMap {
        var map = KeyMap()
        for cell in Trigger.cells { map[cell] = defaultHotkey(for: cell) }
        return map
    }
    /// ⌃⌘ with ←↑→↓ for the four edge buttons (kVK codes), registered after the table's keys when the option is on.
    static let arrowKeys: [(AlignAction, UInt32)] = [(.up, 126), (.left, 123), (.right, 124), (.down, 125)]
    static var arrowCells: [(Hotkey, Trigger)] {
        arrowKeys.map { (Hotkey(code: $0.1, modifiers: Hotkey.control | Hotkey.command), Trigger(action: $0.0, arrow: true)) }
    }
    /// Every registered form in table order (then the arrow keys), and the forms whose key repeats an earlier one.
    func active(arrows: Bool = false) -> (winners: [(Hotkey, Trigger)], duplicates: Set<Trigger>) {
        var seen: Set<Hotkey> = [], winners: [(Hotkey, Trigger)] = [], duplicates: Set<Trigger> = []
        var cells = Trigger.cells.compactMap { cell in self[cell].map { ($0, cell) } }
        if arrows { cells += Self.arrowCells }
        for (hotkey, cell) in cells {
            for (key, trigger) in hotkey.variants(of: cell) {
                if seen.contains(key) { duplicates.insert(trigger); continue }
                seen.insert(key); winners.append((key, trigger))
            }
        }
        return (winners, duplicates)
    }
    /// Nothing saved yet gives the default keys; a saved map keeps the keys the user cleared.
    static func load(from defaults: UserDefaults = .standard) -> KeyMap {
        guard let data = defaults.data(forKey: defaultsKey), let map = try? JSONDecoder().decode(KeyMap.self, from: data) else { return Self.defaults }
        return map
    }
    func save(to defaults: UserDefaults = .standard) {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(self) { defaults.set(data, forKey: Self.defaultsKey) }
    }
}

/// 「中央揃えの基準」: the script's SW_CENTER_BASIS values.
enum CenterBasis: String {
    case page, margin
}

/// The bundled IdAlignToNearestEdgePalette.jsx with its SW_ variables set for one run.
enum AlignScript {
    static let names = ["SW_ACTION", "SW_FROM_CENTER", "SW_MOVE_AS_UNIT", "SW_CENTER_BASIS"]
    /// The palette when `trigger` is nil (the file as it is), otherwise one button.
    static func source(_ script: String, trigger: Trigger?) throws -> String {
        guard let trigger else { return script }
        return try VariableOverrides.apply(to: script, names: names,
                                           values: [trigger.action.rawValue, trigger.fromCenter ? "true" : "false", trigger.asUnit ? "true" : "false", trigger.centerBasis.rawValue], file: true)
    }
}

enum ScriptText {
    static func quote(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
    /// Runs the script's text with `do script … language javascript`, addressing InDesign by its path so the one in front is used
    /// when several versions are open. One undo step named after the button. `#targetengine` in the text still applies (measured 2026-11-03).
    static func appleScript(appPath: String, code: String, undoName: String) -> String {
        "with timeout of 3600 seconds\ntell application \(quote(appPath))\ndo script \(quote(code)) language javascript undo mode entire script undo name \(quote(undoName))\nend tell\nend timeout"
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

/// The keys InDesign's own shortcut set uses, read from its .indk file (XML), so this app can leave them to InDesign.
enum InDesignShortcuts {
    /// Contexts that apply while laying out or editing text and tables (not dialogs, full screen or the XML structure).
    static let contexts: Set<String> = ["DefaultContext", "TextContext", "TableContext"]
    /// kVK codes → the key names InDesign writes (unshifted characters; arrows as 「#Keyboard_Left Arrow」).
    static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 50: "`", 123: "#Keyboard_Left Arrow", 124: "#Keyboard_Right Arrow", 125: "#Keyboard_Down Arrow", 126: "#Keyboard_Up Arrow",
    ]
    /// 「Ctrl+Opt+Shift+Cmd+M」, in InDesign's order of modifiers. Nil for a key this table does not know.
    static func name(of hotkey: Hotkey) -> String? {
        guard let key = keyNames[hotkey.code] else { return nil }
        let m = hotkey.modifiers
        let parts = [(Hotkey.control, "Ctrl"), (Hotkey.option, "Opt"), (Hotkey.shift, "Shift"), (Hotkey.command, "Cmd")].filter { m & $0.0 != 0 }.map(\.1)
        return (parts + [key]).joined(separator: "+")
    }
    /// The key strings of the shortcuts in those contexts.
    static func parse(_ xml: String) -> Set<String> {
        var result: Set<String> = []
        for block in xml.components(separatedBy: "<shortcut>").dropFirst() {
            guard let context = value(of: "context", in: block), contexts.contains(context), let key = value(of: "string", in: block) else { continue }
            result.insert(key)
        }
        return result
    }
    private static func value(of tag: String, in block: String) -> String? {
        guard let start = block.range(of: "<\(tag)>"), let end = block.range(of: "</\(tag)>", range: start.upperBound..<block.endIndex) else { return nil }
        return String(block[start.upperBound..<end.lowerBound])
            .replacingOccurrences(of: "&apos;", with: "'").replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&amp;", with: "&")
    }
    /// The set InDesign uses: the newest .indk among the user's sets for this version (InDesign writes a set when it is edited),
    /// else the default set in the app's Presets. `appURL` is the running InDesign, `major` its version (21 for 2026).
    static func activeSetFile(appURL: URL, major: Int, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL? {
        let fm = FileManager.default
        let prefs = home.appendingPathComponent("Library/Preferences/Adobe InDesign")
        var userSets: [URL] = []
        for version in (try? fm.contentsOfDirectory(atPath: prefs.path)) ?? [] where version.hasPrefix("Version \(major).") {
            let versionURL = prefs.appendingPathComponent(version)
            for locale in (try? fm.contentsOfDirectory(atPath: versionURL.path)) ?? [] {
                let folder = versionURL.appendingPathComponent(locale).appendingPathComponent("InDesign Shortcut Sets")
                for file in (try? fm.contentsOfDirectory(atPath: folder.path)) ?? [] where file.lowercased().hasSuffix(".indk") {
                    userSets.append(folder.appendingPathComponent(file))
                }
            }
        }
        func modified(_ url: URL) -> Date { (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast }
        if let newest = userSets.max(by: { modified($0) < modified($1) }) { return newest }
        let presets = appURL.deletingLastPathComponent().appendingPathComponent("Presets/InDesign Shortcut Sets")
        for locale in [Locale.current.identifier, "ja_JP", "en_US"] {
            let folder = presets.appendingPathComponent(locale)
            for name in ["デフォルト.indk", "Default.indk"] where fm.fileExists(atPath: folder.appendingPathComponent(name).path) {
                return folder.appendingPathComponent(name)
            }
        }
        return nil
    }
}
