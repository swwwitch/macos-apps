import Foundation

var count = 0
func check(_ condition: Bool, _ label: String, line: Int = #line) {
    precondition(condition, "line \(line): \(label)")
    count += 1
}
let control = Shortcut.control, option = Shortcut.option, command = Shortcut.command

// Duplicate rule: later enabled entries with the same key are flagged; disabled ones are ignored.
var a = LaunchEntry(bundleID: "a", name: "A", path: "", shortcut: Shortcut(code: 1, modifiers: control))
var b = LaunchEntry(bundleID: "b", name: "B", path: "", shortcut: Shortcut(code: 1, modifiers: control))
check(EntryRules.duplicates(in: [a, b]) == [b.id: a.id], "second is duplicate of the first")
a.enabled = false
check(EntryRules.duplicates(in: [a, b]).isEmpty, "disabled entry does not block")
b.shortcut = nil
check(EntryRules.duplicates(in: [b]).isEmpty, "no key")

// Search and display order (labels passed in, as the app does with the keyboard layout).
func label(_ s: Shortcut) -> String { s.modifierSymbols + ["0": "A", "34": "I", "2": "D"][String(s.code), default: "#"] }
let list = [
    LaunchEntry(bundleID: "com.adobe.InDesign", name: "InDesign", path: "", shortcut: Shortcut(code: 34, modifiers: control | option)),
    LaunchEntry(bundleID: "com.apple.Safari", name: "Safari", path: "", shortcut: nil),
    LaunchEntry(bundleID: "com.adobe.illustrator", name: "Adobe Illustrator", path: "", shortcut: Shortcut(code: 0, modifiers: control | option | command)),
    LaunchEntry(bundleID: "com.anthropic.claude", name: "Claude", path: "", shortcut: Shortcut(code: 2, modifiers: control | option))
]
func names(_ e: [LaunchEntry]) -> [String] { e.map(\.name) }
check(names(EntryRules.visible(list, query: "", order: .name, label: label)) == ["Adobe Illustrator", "Claude", "InDesign", "Safari"], "by name")
check(names(EntryRules.visible(list, query: "", order: .key, label: label)) == ["Claude", "InDesign", "Adobe Illustrator", "Safari"], "by key: ⌃⌥ D, I, then ⌃⌥⌘, unassigned last")
check(names(EntryRules.visible(list, query: "", order: .name, ascending: false, label: label)) == ["Safari", "InDesign", "Claude", "Adobe Illustrator"], "by name, descending")
check(names(EntryRules.visible(list, query: "", order: .key, ascending: false, label: label)) == ["Adobe Illustrator", "InDesign", "Claude", "Safari"], "by key, descending; unassigned still last")
var dbl = list[0]; dbl.id = UUID(); dbl.doubleTap = true; dbl.name = "InDesign"
check(EntryRules.visible([dbl, list[0]], query: "", order: .key, label: label).map(\.doubleTap) == [false, true], "same key: single before double")
check(names(EntryRules.visible([dbl, list[3]], query: "×2", order: .name, label: label)) == ["InDesign"], "search ×2")
check(names(EntryRules.visible(list, query: "adobe", order: .name, label: label)) == ["Adobe Illustrator", "InDesign"], "Bundle ID match")
check(names(EntryRules.visible(list, query: "⌃⌥I", order: .name, label: label)) == ["InDesign"], "key label match")
check(names(EntryRules.visible(list, query: "⌘", order: .name, label: label)) == ["Adobe Illustrator"], "modifier match")
check(names(EntryRules.visible(list, query: "d", order: .name, label: label)) == ["Adobe Illustrator", "Claude", "InDesign"], "case-insensitive: names and the bare key D")
check(names(EntryRules.visible(list, query: "⌃⌥d", order: .name, label: label)) == ["Claude"], "key with modifiers, lower case")
check(names(EntryRules.visible(list, query: "adobe ill", order: .name, label: label)) == ["Adobe Illustrator"], "all words must match")
check(EntryRules.visible(list, query: "zzz", order: .key, label: label).isEmpty, "no match")

// Path Finder preference: only Finder entries, only while Path Finder runs, options kept.
var finder = LaunchEntry(bundleID: "com.apple.finder", name: "Finder", path: "/System/Library/CoreServices/Finder.app", shortcut: Shortcut(code: 50, modifiers: control | option))
finder.hideOthers = true
let pf = ("com.cocoatech.PathFinder-setapp", "Path Finder", "/Applications/Setapp/Path Finder.app")
let swapped = EntryRules.resolved(finder, preferPathFinder: true, running: [("com.apple.Safari", "Safari", "/x"), pf])
check(swapped.bundleID == pf.0 && swapped.name == "Path Finder" && swapped.hideOthers && swapped.id == finder.id, "Finder → running Path Finder (Setapp)")
check(EntryRules.resolved(finder, preferPathFinder: false, running: [pf]) == finder, "setting off")
check(EntryRules.resolved(finder, preferPathFinder: true, running: [("com.apple.Safari", "Safari", "/x")]) == finder, "Path Finder not running")
check(EntryRules.resolved(list[0], preferPathFinder: true, running: [pf]) == list[0], "other apps untouched")
check(EntryRules.resolved(finder, preferPathFinder: true, running: [("com.cocoatech.PathFinder", "Path Finder", "/Applications/Path Finder.app")]).bundleID == "com.cocoatech.PathFinder", "regular copy")

// Data saved by 1.1.0 (no switchToABC) still loads, with the new option off.
let old = #"[{"id":"2C1E9A5E-7B3F-4C1A-9D2E-1F0A3B4C5D6E","bundleID":"com.hnc.Discord","name":"Discord","path":"/Applications/Discord.app","shortcut":{"code":16,"modifiers":6144},"enabled":true,"allWindows":true,"reopen":false,"hideOthers":false}]"#
let loaded = try! JSONDecoder().decode([LaunchEntry].self, from: Data(old.utf8))
check(loaded.count == 1 && loaded[0].name == "Discord" && !loaded[0].switchToABC && !loaded[0].doubleTap && loaded[0].openPath == nil && loaded[0].shortcut?.code == 16, "old saved data loads")
var abc = loaded[0]; abc.switchToABC = true
check(try! JSONDecoder().decode(LaunchEntry.self, from: JSONEncoder().encode(abc)).switchToABC, "new option persists")

// Double tap: single and double on the same key are different triggers and app slots, and are not duplicates.
var single = LaunchEntry(bundleID: "com.cocoatech.PathFinder-setapp", name: "Path Finder", path: "", shortcut: Shortcut(code: 15, modifiers: control))
var double = single; double.id = UUID(); double.doubleTap = true; double.openPath = "~/sw Dropbox/takano masahiro/Dropbox-shared"
check(single.trigger != double.trigger && EntryRules.slot(single) != EntryRules.slot(double), "single vs double")
check(EntryRules.duplicates(in: [single, double]).isEmpty, "single + double on one key is allowed")
var double2 = double; double2.id = UUID()
check(EntryRules.duplicates(in: [single, double, double2]) == [double2.id: double.id], "two double taps on one key clash")

// Export file: round trip, format check, add vs replace.
let file = SettingsFile(entries: [single, double], excluded: ["com.google.Chrome"], preferPathFinder: false)
let decoded = try! SettingsFile.decode(file.encoded())
check(decoded == file, "export round trip")
check((try? SettingsFile.decode(Data("{}".utf8))) == nil, "not a settings file")
let legacy = #"{"format":"AppLauncher","version":1,"entries":[],"excluded":["com.google.Chrome"],"preferPathFinder":true}"#
check((try? SettingsFile.decode(Data(legacy.utf8)))?.excluded == ["com.google.Chrome"], "file from before the rename (AppLauncher) still imports")
check(file.format == "DocklessLauncher" && SettingsFile.fileExtension == "docklesslauncher", "new format name and extension")
let foreign = #"{"format":"Other","version":1,"entries":[],"excluded":[],"preferPathFinder":true}"#
do { _ = try SettingsFile.decode(Data(foreign.utf8)); check(false, "format check") } catch { check(error as? SettingsFile.Failure == .notOurs, "other format refused") }
var current = LaunchEntry(bundleID: "com.cocoatech.PathFinder-setapp", name: "PF", path: "", shortcut: Shortcut(code: 3, modifiers: control | option))
let added = file.applied(to: [current], excluded: ["com.apple.Terminal"], replace: false)
check(added.added == 1 && added.entries.count == 2 && added.entries[0] == current, "add keeps the registered single slot, adds the double slot")
check(added.entries[1].doubleTap && added.entries[1].id != double.id, "added rows get new ids")
check(added.excluded == ["com.apple.Terminal", "com.google.Chrome"], "excluded combined and sorted")
let replaced = file.applied(to: [current], excluded: ["com.apple.Terminal"], replace: true)
check(replaced.entries == file.entries && replaced.excluded == file.excluded && replaced.added == 2, "replace")

// Version choice: numeric comparison, newest pick, old data defaults to standard.
check(VersionRules.isNewer("21.6.0.57", than: "20.5.5.119") && !VersionRules.isNewer("20.5.5.119", than: "21.6.0.57"), "InDesign 2026 > 2025")
check(VersionRules.isNewer("30.1", than: "30.0.2") && VersionRules.isNewer("10", than: "9.9") && !VersionRules.isNewer("1.0", than: "1"), "numeric parts, missing parts are 0")
check(VersionRules.newest([("/A/2025.app", "20.5.5.119"), ("/A/2026.app", "21.6.0.57"), ("/A/2024.app", "19.0")]) == "/A/2026.app", "newest copy")
check(VersionRules.newest([("/first", "1.0"), ("/second", "1.0")]) == "/first" && VersionRules.newest([]) == nil, "tie keeps the first; empty")
check(loaded[0].versionMode == .system, "old data: standard version mode")
var pinned = single; pinned.versionMode = .path
check(try! JSONDecoder().decode(LaunchEntry.self, from: JSONEncoder().encode(pinned)).versionMode == .path, "version mode persists")

// Front-app condition: except / only, alternatives on one key, registration duplicates per front app.
var inDesign = LaunchEntry(bundleID: "com.adobe.InDesign", name: "InDesign", path: "", shortcut: Shortcut(code: 34, modifiers: control | option))
inDesign.frontRule = .except; inDesign.frontApps = ["com.google.Chrome"]
check(!EntryRules.applies(inDesign, front: "com.google.Chrome") && EntryRules.applies(inDesign, front: "com.apple.finder") && EntryRules.applies(inDesign, front: nil), "except Chrome")
var chromeOnly = LaunchEntry(bundleID: "com.example.tool", name: "Tool", path: "", shortcut: inDesign.shortcut)
chromeOnly.frontRule = .only; chromeOnly.frontApps = ["com.google.Chrome"]
check(EntryRules.applies(chromeOnly, front: "com.google.Chrome") && !EntryRules.applies(chromeOnly, front: "com.apple.finder") && !EntryRules.applies(chromeOnly, front: nil), "only Chrome")
var emptyOnly = chromeOnly; emptyOnly.frontApps = []
check(!EntryRules.applies(emptyOnly, front: "com.google.Chrome"), "only with no apps never applies")
check(EntryRules.duplicates(in: [inDesign, chromeOnly]).isEmpty, "conditioned rows on one key are not flagged in the list")
check(EntryRules.duplicates(in: [inDesign, chromeOnly], front: .some("com.google.Chrome")).isEmpty, "in Chrome only Tool is live")
var plain = LaunchEntry(bundleID: "com.example.other", name: "Other", path: "", shortcut: inDesign.shortcut)
check(EntryRules.duplicates(in: [inDesign, plain], front: .some("com.apple.finder")) == [plain.id: inDesign.id], "outside Chrome InDesign wins (registered first)")
check(EntryRules.duplicates(in: [inDesign, plain], front: .some("com.google.Chrome")).isEmpty, "in Chrome the plain row is live")
check(loaded[0].frontRule == .none && loaded[0].frontApps.isEmpty, "old data: no condition")

// URL condition: prefix match ignoring scheme / case / www, pattern parsing.
let sheets = "https://docs.google.com/spreadsheets/d/1abc/edit#gid=0"
check(EntryRules.urlMatches(sheets, patterns: ["https://docs.google.com/"]), "docs.google.com prefix")
check(EntryRules.urlMatches(sheets, patterns: ["docs.google.com/spreadsheets"]) && EntryRules.urlMatches(sheets, patterns: ["HTTP://DOCS.GOOGLE.COM/"]), "scheme and case ignored")
check(!EntryRules.urlMatches("https://docs.google.com/document/d/1", patterns: ["https://docs.google.com/spreadsheets/"]), "Docs is not Sheets")
check(!EntryRules.urlMatches("https://www.google.com/search?q=docs.google.com", patterns: ["docs.google.com"]), "only the start counts")
check(EntryRules.urlMatches("https://www.example.com/a", patterns: ["example.com/a"]) && !EntryRules.urlMatches(sheets, patterns: ["", "  "]), "www ignored; blank patterns never match")
check(EntryRules.urlPatterns(from: "https://docs.google.com/\n\n  sheets.new \nHTTPS://DOCS.GOOGLE.COM/") == ["https://docs.google.com/", "sheets.new"], "lines trimmed, blanks and duplicates dropped")
check(EntryRules.browsers.isSuperset(of: ["com.google.Chrome", "com.apple.Safari", "org.mozilla.firefox"]), "three browsers")
check(loaded[0].skipURLs.isEmpty, "old data: no URL condition")

// Keyboard layouts: no key code twice, letters and digits present, rows of similar width.
for layout in KeyboardLayout.allCases {
    let codes = layout.rows.flatMap { $0.compactMap(\.code) }
    check(codes.count == Set(codes).count, "\(layout): unique key codes")
    let letters: Set<UInt32> = [0, 11, 8, 2, 14, 3, 5, 4, 34, 38, 40, 37, 46, 45, 31, 35, 12, 15, 1, 17, 32, 9, 13, 7, 16, 6]
    check(letters.isSubset(of: Set(codes)) && Set<UInt32>([18, 19, 20, 21, 23, 22, 26, 28, 25, 29]).isSubset(of: Set(codes)), "\(layout): A–Z and 0–9")
    let widths = layout.rows.dropFirst().map { $0.reduce(0) { $0 + $1.width } }
    check((widths.max()! - widths.min()!) <= 1.5, "\(layout): rows line up \(widths)")
    check(layout.rows[2].first?.caption == "tab" && layout.rows[2].dropFirst().first?.code == 12, "\(layout): Q follows tab")
}
check(KeyboardLayout.jis.rows.flatMap { $0 }.contains { $0.code == 102 } && !KeyboardLayout.ansi.rows.flatMap { $0 }.contains { $0.code == 102 }, "英数 only on JIS")
check(!KeySpec(code: nil, caption: "⇧").assignable && KeySpec(code: 34).assignable && KeySpec(code: 49, caption: "space").assignable, "assignable keys")

// Keyboard drag: swap or move all rows of a key for one modifier set; other sets untouched; swapping twice restores.
let co = control | option
var ka = LaunchEntry(bundleID: "a", name: "A", path: "", shortcut: Shortcut(code: 0, modifiers: co))
var kaDouble = ka; kaDouble.id = UUID(); kaDouble.doubleTap = true
let ks = LaunchEntry(bundleID: "s", name: "S", path: "", shortcut: Shortcut(code: 1, modifiers: co))
let kOther = LaunchEntry(bundleID: "o", name: "O", path: "", shortcut: Shortcut(code: 0, modifiers: co | command))
let before = [ka, kaDouble, ks, kOther]
let swapped2 = EntryRules.swappingKeys(before, 0, 1, modifiers: co)
check(swapped2.map { $0.shortcut!.code } == [1, 1, 0, 0] && swapped2[1].doubleTap, "A (single + double) ↔ S, ⌃⌥⌘A untouched")
check(EntryRules.swappingKeys(swapped2, 0, 1, modifiers: co) == before, "swapping again restores (undo)")
check(EntryRules.swappingKeys(before, 0, 2, modifiers: co).map { $0.shortcut!.code } == [2, 2, 1, 0], "move to an empty key")

// Persistence round trip
let json = try! JSONEncoder().encode([single, double])
check(try! JSONDecoder().decode([LaunchEntry].self, from: json) == [single, double], "Codable round trip")

print("PASS: \(count) rule checks (duplicates, double tap, search, sort, Path Finder, old data, export file)")
