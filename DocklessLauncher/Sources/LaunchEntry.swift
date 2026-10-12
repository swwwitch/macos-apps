import Foundation

// Pure data and list rules, with no AppKit so Tests/Rules can compile them alone.

/// A key combination in Carbon terms (⌘256 ⇧512 ⌥2048 ⌃4096).
struct Shortcut: Codable, Equatable, Hashable {
    var code: UInt32
    var modifiers: UInt32
    static let command: UInt32 = 256, shift: UInt32 = 512, option: UInt32 = 2048, control: UInt32 = 4096
    var signature: String { "\(code):\(modifiers)" }
    /// Modifier symbols in the standard Mac order ⌃⌥⇧⌘.
    var modifierSymbols: String {
        (modifiers & Shortcut.control != 0 ? "⌃" : "") + (modifiers & Shortcut.option != 0 ? "⌥" : "")
            + (modifiers & Shortcut.shift != 0 ? "⇧" : "") + (modifiers & Shortcut.command != 0 ? "⌘" : "")
    }
    /// A global launcher key needs ⌘, ⌥ or ⌃ (⇧ alone would take a typed character).
    var hasRequiredModifier: Bool { modifiers & (Shortcut.command | Shortcut.option | Shortcut.control) != 0 }
}

/// Which copy to use when several apps share a Bundle ID (Adobe apps keep one ID across yearly versions).
enum VersionMode: String, Codable, CaseIterable {
    /// Launch Services decides (the default).
    case system
    /// The highest version among the copies found.
    case newest
    /// Always the app at `LaunchEntry.path`.
    case path
}

/// Whether a row's key depends on the app in front.
enum FrontRule: String, Codable, CaseIterable {
    case none
    /// Not while one of `frontApps` is in front (the key goes to that app).
    case except
    /// Only while one of `frontApps` is in front.
    case only
}

/// One registered app.
struct LaunchEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var bundleID: String
    var name: String
    /// Last known location; used only when Launch Services no longer knows the Bundle ID.
    var path: String
    var shortcut: Shortcut?
    var enabled = true
    /// Bring every window of the app to the front.
    var allWindows = true
    /// Ask the app to open a window when it has none, as clicking its Dock icon does.
    var reopen = false
    /// Hide the other apps after the switch.
    var hideOthers = false
    /// Select the "ABC" input source after the switch.
    var switchToABC = false
    /// Fire on a double tap of `shortcut` instead of a single press. The same key can have one single and one double entry.
    var doubleTap = false
    /// A folder or file to open with the app; "~" is allowed.
    var openPath: String?
    var versionMode: VersionMode = .system
    var frontRule: FrontRule = .none
    /// Bundle IDs for `frontRule`.
    var frontApps: [String] = []
    /// Not while a browser in front shows a page starting with one of these (e.g. "https://docs.google.com/").
    /// Checked when the key is pressed (needs Accessibility); the key then goes to the browser.
    var skipURLs: [String] = []

    /// Key + tap count: what must be unique among enabled entries.
    var trigger: String? { shortcut.map { $0.signature + (doubleTap ? "×2" : "") } }

    init(id: UUID = UUID(), bundleID: String, name: String, path: String, shortcut: Shortcut? = nil) {
        self.id = id; self.bundleID = bundleID; self.name = name; self.path = path; self.shortcut = shortcut
    }
    /// Options added later are optional in saved data, so entries saved by an older version still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        bundleID = try c.decode(String.self, forKey: .bundleID)
        name = try c.decode(String.self, forKey: .name)
        path = try c.decodeIfPresent(String.self, forKey: .path) ?? ""
        shortcut = try c.decodeIfPresent(Shortcut.self, forKey: .shortcut)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        allWindows = try c.decodeIfPresent(Bool.self, forKey: .allWindows) ?? true
        reopen = try c.decodeIfPresent(Bool.self, forKey: .reopen) ?? false
        hideOthers = try c.decodeIfPresent(Bool.self, forKey: .hideOthers) ?? false
        switchToABC = try c.decodeIfPresent(Bool.self, forKey: .switchToABC) ?? false
        doubleTap = try c.decodeIfPresent(Bool.self, forKey: .doubleTap) ?? false
        openPath = try c.decodeIfPresent(String.self, forKey: .openPath)
        versionMode = try c.decodeIfPresent(VersionMode.self, forKey: .versionMode) ?? .system
        frontRule = try c.decodeIfPresent(FrontRule.self, forKey: .frontRule) ?? .none
        frontApps = try c.decodeIfPresent([String].self, forKey: .frontApps) ?? []
        skipURLs = try c.decodeIfPresent([String].self, forKey: .skipURLs) ?? []
    }
}

enum VersionRules {
    /// "21.6.0.57" > "20.5.5.119" > "20.5"; compared number by number, missing parts count as 0.
    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }
    private static func parts(_ version: String) -> [Int] {
        version.split(whereSeparator: { !$0.isNumber }).map { Int($0) ?? 0 }
    }
    /// The newest of (path, version) copies; on equal versions the first one found wins.
    static func newest(_ copies: [(path: String, version: String)]) -> String? {
        var best: (path: String, version: String)?
        for copy in copies where best == nil || isNewer(copy.version, than: best!.version) { best = copy }
        return best?.path
    }
}

enum EntryRules {
    /// An app's single-press entry and its double-tap entry are separate rows.
    static func slot(_ entry: LaunchEntry) -> String { entry.bundleID + (entry.doubleTap ? "×2" : "") }

    /// Browsers whose page URL is checked for `skipURLs`.
    static let browsers: Set<String> = ["com.google.Chrome", "com.apple.Safari", "org.mozilla.firefox",
                                        "com.microsoft.edgemac", "company.thebrowser.Browser", "com.brave.Browser"]

    /// Prefix match, ignoring case and the scheme, so "docs.google.com/spreadsheets" also matches https URLs.
    static func urlMatches(_ url: String, patterns: [String]) -> Bool {
        func bare(_ text: String) -> String {
            var t = text.trimmingCharacters(in: .whitespaces).lowercased()
            for scheme in ["https://", "http://"] where t.hasPrefix(scheme) { t.removeFirst(scheme.count) }
            if t.hasPrefix("www.") { t.removeFirst(4) }
            return t
        }
        let target = bare(url)
        return patterns.map(bare).contains { !$0.isEmpty && target.hasPrefix($0) }
    }
    /// One pattern per line from the editor; blank lines dropped, order kept, duplicates removed.
    static func urlPatterns(from text: String) -> [String] {
        var seen = Set<String>()
        return text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    /// Keyboard view drag: every row on key `a` with `modifiers` moves to key `b` and every row on `b` moves to `a`
    /// (a move when `b` is empty). Tap count, conditions and other options stay with the rows.
    static func swappingKeys(_ entries: [LaunchEntry], _ a: UInt32, _ b: UInt32, modifiers: UInt32) -> [LaunchEntry] {
        entries.map { entry in
            guard var shortcut = entry.shortcut, shortcut.modifiers == modifiers, shortcut.code == a || shortcut.code == b else { return entry }
            shortcut.code = shortcut.code == a ? b : a
            var moved = entry
            moved.shortcut = shortcut
            return moved
        }
    }

    /// Whether the row's key is usable with `front` (a Bundle ID) in front. An "only" row with no apps never applies.
    static func applies(_ entry: LaunchEntry, front: String?) -> Bool {
        switch entry.frontRule {
        case .none: return true
        case .except: return !(front.map(entry.frontApps.contains) ?? false)
        case .only: return front.map(entry.frontApps.contains) ?? false
        }
    }

    /// Entries whose key is also used by an earlier enabled entry (registration order), mapped to that earlier entry.
    /// Only the earlier one is used, whatever order the list is shown in.
    /// With `front`, only the rows usable for that app are compared (what is registered right now).
    /// Without it (the list's warning), rows with a front-app condition are not flagged: they are meant as alternatives.
    static func duplicates(in entries: [LaunchEntry], front: String?? = nil) -> [UUID: UUID] {
        var owner: [String: UUID] = [:]
        var result: [UUID: UUID] = [:]
        for entry in entries where entry.enabled {
            guard let key = entry.trigger else { continue }
            if let front {
                guard applies(entry, front: front) else { continue }
            } else if entry.frontRule != .none {
                continue
            }
            if let first = owner[key] { result[entry.id] = first } else { owner[key] = entry.id }
        }
        return result
    }

    static let finderID = "com.apple.finder"
    /// Path Finder, the regular and the Setapp copy (com.cocoatech.PathFinder-setapp).
    static let pathFinderPrefix = "com.cocoatech.PathFinder"

    /// With "prefer Path Finder" on, a Finder entry targets a running Path Finder instead, keeping the row's options.
    /// `running` is (Bundle ID, name, path) of the running apps.
    static func resolved(_ entry: LaunchEntry, preferPathFinder: Bool, running: [(String, String, String)]) -> LaunchEntry {
        guard preferPathFinder, entry.bundleID == finderID,
              let pathFinder = running.first(where: { $0.0.hasPrefix(pathFinderPrefix) }) else { return entry }
        var result = entry
        result.bundleID = pathFinder.0; result.name = pathFinder.1; result.path = pathFinder.2
        return result
    }

    enum Order: String, CaseIterable { case name, key }

    /// The rows to show: filtered by app name, Bundle ID or key label, then sorted for display only
    /// (which entry keeps a shared key is decided by registration order, not by this).
    /// `label` gives the key's display text (it depends on the keyboard layout, so it is passed in).
    static func visible(_ entries: [LaunchEntry], query: String, order: Order, ascending: Bool = true, label: (Shortcut) -> String) -> [LaunchEntry] {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        let filtered = words.isEmpty ? entries : entries.filter { entry in
            let key = entry.shortcut.map { label($0) + (entry.doubleTap ? " ×2" : "") } ?? ""
            let haystack = [entry.name, entry.bundleID, key, keyWithoutSymbols(key)].joined(separator: "\n").lowercased()
            return words.allSatisfy { haystack.contains($0) }
        }
        switch order {
        case .name:
            let sorted = filtered.enumerated().sorted { a, b in
                let result = a.element.name.localizedStandardCompare(b.element.name)
                if result != .orderedSame { return result == .orderedAscending }
                return a.element.doubleTap != b.element.doubleTap ? !a.element.doubleTap : a.offset < b.offset
            }.map(\.element)
            return ascending ? sorted : sorted.reversed()
        case .key:
            // Modifier set (⌃⌥ before ⌃⌥⌘ …), then the key's name, then single press before double tap.
            // Rows without a key stay at the end in both directions.
            let assigned = filtered.enumerated().filter { $0.element.shortcut != nil }.sorted { a, b in
                let x = a.element.shortcut!, y = b.element.shortcut!
                if x.modifiers != y.modifiers { return modifierRank(x.modifiers) < modifierRank(y.modifiers) }
                let result = keyWithoutSymbols(label(x)).localizedStandardCompare(keyWithoutSymbols(label(y)))
                if result != .orderedSame { return result == .orderedAscending }
                return a.element.doubleTap != b.element.doubleTap ? !a.element.doubleTap : a.offset < b.offset
            }.map(\.element)
            let unassigned = filtered.filter { $0.shortcut == nil }
            return (ascending ? assigned : assigned.reversed()) + unassigned
        }
    }

    /// "⌃⌥I" → "I", so a search for "i" or a sort by key ignores the modifier symbols.
    static func keyWithoutSymbols(_ label: String) -> String {
        String(label.drop { "⌃⌥⇧⌘".contains($0) })
    }
    /// Fewer modifiers first; among equal counts, the ⌃⌥⇧⌘ order.
    static func modifierRank(_ modifiers: UInt32) -> Int {
        let bits = [Shortcut.control, Shortcut.option, Shortcut.shift, Shortcut.command]
        return bits.filter { modifiers & $0 != 0 }.count * 100 + bits.enumerated().reduce(0) { $0 + (modifiers & $1.element != 0 ? 1 << (3 - $1.offset) : 0) }
    }
}

/// The file written by「書き出す…」: the list and the settings that belong with it. JSON, extension .docklesslauncher.
struct SettingsFile: Codable, Equatable {
    static let format = "DocklessLauncher"
    static let fileExtension = "docklesslauncher"
    /// Files written before the rename (AppLauncher 1.5.0 and earlier) are still accepted.
    static let legacyFormats: Set<String> = ["AppLauncher"]
    static let legacyExtension = "applauncher"
    var format = SettingsFile.format
    var version = 1
    var entries: [LaunchEntry]
    var excluded: [String]
    var preferPathFinder: Bool

    enum Failure: Error, Equatable { case unreadable, notOurs }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    static func decode(_ data: Data) throws -> SettingsFile {
        guard let file = try? JSONDecoder().decode(SettingsFile.self, from: data) else { throw Failure.unreadable }
        guard file.format == format || legacyFormats.contains(file.format) else { throw Failure.notOurs }
        return file
    }

    /// Replace: the file's list and settings as they are. Add: rows for app slots not yet registered are appended
    /// with new ids (a single and a double-tap row are separate slots); excluded apps are combined; the rest is kept.
    func applied(to entries: [LaunchEntry], excluded: [String], replace: Bool) -> (entries: [LaunchEntry], excluded: [String], added: Int) {
        if replace { return (self.entries, self.excluded, self.entries.count) }
        var result = entries
        var slots = Set(entries.map(EntryRules.slot))
        for var entry in self.entries where slots.insert(EntryRules.slot(entry)).inserted {
            entry.id = UUID()
            result.append(entry)
        }
        return (result, Array(Set(excluded + self.excluded)).sorted(), result.count - entries.count)
    }
}
