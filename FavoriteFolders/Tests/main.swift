import AppKit
import Carbon

var failures = 0
func check(_ condition: Bool, _ message: String) {
    if condition { print("PASS:", message) } else { failures += 1; print("FAIL:", message) }
}

func folder(_ name: String, _ path: String, days: Double, hotkey: [String: Any]? = nil) -> FavoriteItem {
    var raw: [String: Any] = ["bookmark": Data("book".utf8), "date": Date(timeIntervalSinceReferenceDate: days * 86400), "itemType": 2, "name": name,
                              "url": URL(fileURLWithPath: path, isDirectory: true).absoluteString]
    if let hotkey { raw["hotkey"] = hotkey }
    return FavoriteItem(raw: raw)
}
let separatorA = FavoriteItem.separator(date: Date(timeIntervalSinceReferenceDate: 1000))
let separatorB = FavoriteItem.separator(date: Date(timeIntervalSinceReferenceDate: 2000))
let items = [folder("b", "/tmp/b", days: 3), folder("A", "/tmp/a", days: 1), separatorA,
             folder("item10", "/z", days: 5), folder("item2", "/y", days: 2), folder("item1", "/x", days: 9), separatorB, folder("only", "/o", days: 0)]
let names = { (list: [FavoriteItem]) in list.map { $0.isSeparator ? "|" : $0.name } }

// Categories
let categories = Favorites.categories(items)
check(categories.map(\.key) == ["top", "1000", "2000"], "categories are keyed top + separator dates")
check(categories.map(\.range) == [0..<2, 3..<6, 7..<8] && categories.map(\.separatorIndex) == [nil, 2, 6], "category ranges and separator indices")
check(Favorites.categories([]).count == 1 && Favorites.categories([separatorA]).map(\.range) == [0..<0, 1..<1], "empty list and separator-only list")

// Sorting keeps separators in place and sorts inside each category
check(names(Favorites.sorted(items, by: .name)) == ["A", "b", "|", "item1", "item2", "item10", "|", "only"], "name sort is localized-standard (item2 before item10) and per category")
check(names(Favorites.sorted(items, by: .nameDescending)) == ["b", "A", "|", "item10", "item2", "item1", "|", "only"], "descending name sort")
check(names(Favorites.sorted(items, by: .path)) == ["A", "b", "|", "item1", "item2", "item10", "|", "only"], "path sort")
check(names(Favorites.sorted(items, by: .newest)) == ["b", "A", "|", "item1", "item10", "item2", "|", "only"], "newest first")
check(names(Favorites.sorted(items, by: .oldest)) == ["A", "b", "|", "item2", "item10", "item1", "|", "only"], "oldest first")
check(names(Favorites.sorted(items, by: .name, only: ["1000"])) == ["b", "A", "|", "item1", "item2", "item10", "|", "only"], "sort limited to one category")
let ties = [folder("x", "/1", days: 1), folder("x", "/2", days: 1), folder("x", "/3", days: 1)]
check(Favorites.sorted(ties, by: .name).map(\.path) == ["/1", "/2", "/3"], "sort is stable for equal names")

// Moving items and categories
let moved = Favorites.moving([items[0].id, items[5].id, separatorA.id], to: "2000", in: items)
check(names(moved) == ["A", "|", "item10", "item2", "|", "only", "b", "item1"], "moving to a category appends in order and ignores separators")
check(names(Favorites.moving([items[7].id], to: "top", in: items)) == ["b", "A", "only", "|", "item10", "item2", "item1", "|"], "moving to the first category")
check(names(Favorites.movingCategory("2000", by: -1, in: items)) == ["b", "A", "|", "only", "|", "item10", "item2", "item1"], "category up")
check(names(Favorites.movingCategory("1000", by: 1, in: items)) == ["b", "A", "|", "only", "|", "item10", "item2", "item1"], "category down")
check(names(Favorites.movingCategory("1000", by: -1, in: items)) == names(items), "a category does not move above the first")
check(names(Favorites.movingCategory("2000", by: 1, in: items)) == names(items), "the last category does not move down")
check(Favorites.movingCategory("1000", by: 1, in: items).count == items.count, "moving a category keeps every item")

// Separator format (measured in Default Folder X 6.3.3)
check(separatorA.raw["itemType"] as? Int == 4 && separatorA.raw["url"] as? String == "DXMenuSeparator" && separatorA.raw["bookmark"] == nil, "separator is itemType 4, url DXMenuSeparator, no bookmark")
check(separatorA.fileURL == nil && separatorA.path.isEmpty && separatorA.exists, "separator has no file")

// Hotkey text: ⌃⇧ + key (modifierFlags 393216 = shift | control, keyCode 17 = T)
let hotkeyItem = folder("h", "/h", days: 0, hotkey: ["characters": "", "charactersIgnoringModifiers": "T", "keyCode": 17, "modifierFlags": 393216])
check(hotkeyItem.hotkeyText == "⌃⇧T", "hotkey shows ⌃⇧T (got \(hotkeyItem.hotkeyText))")
check(folder("n", "/n", days: 0).hotkeyText.isEmpty, "no hotkey, no text")
check(folder("f", "/f", days: 0, hotkey: ["keyCode": 122, "modifierFlags": 1048576]).hotkeyText == "⌘F1", "function key name")

// Round trip through a temporary file keeps unknown keys, bookmarks and hotkeys
let temp = FileManager.default.temporaryDirectory.appendingPathComponent("FavoriteFoldersTest-\(UUID().uuidString).plist")
var withExtra = items; withExtra[0].raw["somethingNew"] = ["kept": true]; withExtra[1] = hotkeyItem
try! Favorites.data(withExtra).write(to: temp)
let back = try! Favorites.read(temp)
check(Favorites.fingerprint(back) == Favorites.fingerprint(withExtra), "round trip keeps order, names, urls and hotkeys")
check((back[0].raw["somethingNew"] as? [String: Bool])?["kept"] == true && back[0].raw["bookmark"] as? Data == Data("book".utf8), "round trip keeps unknown keys and bookmark data")
check(String(data: try! Data(contentsOf: temp), encoding: .utf8)?.hasPrefix("<?xml") == true, "written as an XML plist like Default Folder X")
try? FileManager.default.removeItem(at: temp)
check(Favorites.fingerprint(Favorites.sorted(items, by: .name)) != Favorites.fingerprint(items), "fingerprint changes with order")

// The real file, read only (skipped when Default Folder X is not set up on this Mac)
let sets = DFX.folderSets()
// Localized default set names must resolve to DFX's canonical storage folder.
let setRoot = FileManager.default.temporaryDirectory.appendingPathComponent("DFXSetTests-" + UUID().uuidString)
let canonical = setRoot.appendingPathComponent("Default Set/Favorites.plist")
try! FileManager.default.createDirectory(at: canonical.deletingLastPathComponent(), withIntermediateDirectories: true)
try! Favorites.data(items).write(to: canonical)
let defaultNames: Set<String> = ["Default Set", "デフォルト設定", "Jeu par défaut"]
check(DFX.favoritesURL(set: "デフォルト設定", root: setRoot, defaultNames: defaultNames) == canonical, "Japanese default set resolves to Default Set")
check(DFX.favoritesURL(set: "Jeu par défaut", root: setRoot, defaultNames: defaultNames) == canonical, "other DFX translations resolve to Default Set")
check(DFX.favoritesURL(set: "Work", root: setRoot, defaultNames: defaultNames).path == setRoot.appendingPathComponent("Work/Favorites.plist").path, "missing custom set never uses the default favorites")
let exact = setRoot.appendingPathComponent("デフォルト設定/Favorites.plist")
try! FileManager.default.createDirectory(at: exact.deletingLastPathComponent(), withIntermediateDirectories: true)
try! Favorites.data([]).write(to: exact)
check(DFX.favoritesURL(set: "デフォルト設定", root: setRoot, defaultNames: defaultNames) == exact, "existing exact set takes priority over a translated default name")
try! FileManager.default.removeItem(at: setRoot)
check(DFX.favoritesURL(set: "デフォルト設定", root: setRoot, defaultNames: defaultNames) == exact, "missing default file is not invented")

// Backups keep the newest 30 (regression: 1.0.0–1.2.0 deleted every backup right after making it)
let stamps = (1...35).map { URL(fileURLWithPath: "/b/Favorites-\($0 % 2 == 0 ? "デフォルト設定" : "x")-202610\(String(format: "%02d", $0))-120000.plist") }
let removed = Backups.pruned(stamps + [URL(fileURLWithPath: "/b/notes.txt")])
check(removed.count == 5 && Set(removed.map(\.lastPathComponent)) == Set(stamps.prefix(5).map(\.lastPathComponent)), "pruning removes only the 5 oldest of 35, across set names")
check(Backups.pruned(Array(stamps.prefix(1))).isEmpty, "a single backup is kept")
// Use counting from successive looks at Default Folder X
var counter = UsageCounter()
check(counter.step(dialogOpen: false, currentFolder: nil, recentTop: "/a").isEmpty, "the first look counts nothing")
check(counter.step(dialogOpen: false, currentFolder: nil, recentTop: "/a").isEmpty, "the same top of Recent Folders counts nothing")
check(counter.step(dialogOpen: false, currentFolder: nil, recentTop: "/b") == ["/b"], "a new top of Recent Folders counts once")
check(counter.step(dialogOpen: true, currentFolder: "/c", recentTop: "/b").isEmpty, "an open dialog counts nothing yet")
check(counter.step(dialogOpen: true, currentFolder: "/d", recentTop: "/d").isEmpty, "navigating in the dialog counts nothing yet")
check(counter.step(dialogOpen: false, currentFolder: nil, recentTop: "/d") == ["/d"], "closing the dialog counts its last folder once")
check(counter.step(dialogOpen: false, currentFolder: nil, recentTop: "/d").isEmpty, "the dialog's folder at the top of Recent Folders is not counted again")
check(counter.step(dialogOpen: false, currentFolder: nil, recentTop: nil).isEmpty, "no Recent Folders counts nothing")

// Most used first, NFC/NFD keys, notes in search
let nfd = "/x/スクリプト".decomposedStringWithCanonicalMapping, nfc = "/x/スクリプト/".precomposedStringWithCanonicalMapping
check(FolderKey.of(nfd) == FolderKey.of(nfc) && !FolderKey.of(nfc).hasSuffix("/"), "folder keys match across NFC/NFD and trailing slashes")
let used = [folder("a", "/u/a", days: 0), folder("b", "/u/b", days: 0), folder("c", "/u/c", days: 0)]
check(Favorites.sorted(used, by: .mostUsed, usage: ["/u/b": 5, "/u/c": 2]).map(\.name) == ["b", "c", "a"], "most used first, unused last")
check(Favorites.sorted(used, by: .mostUsed).map(\.name) == ["a", "b", "c"], "without counts the order stays")
check(used[0].matches("請求書", note: "請求書の控え") && !used[0].matches("請求書"), "search finds words in the note")

// Files and size of a folder
let statsDir = FileManager.default.temporaryDirectory.appendingPathComponent("FavoriteFoldersStats-\(UUID().uuidString)")
try! FileManager.default.createDirectory(at: statsDir.appendingPathComponent("sub/My.app/Contents"), withIntermediateDirectories: true)
try! Data(count: 1000).write(to: statsDir.appendingPathComponent("a.txt"))
try! Data(count: 2000).write(to: statsDir.appendingPathComponent("sub/b.txt"))
try! Data(count: 500).write(to: statsDir.appendingPathComponent(".hidden"))
try! Data(count: 3000).write(to: statsDir.appendingPathComponent("sub/My.app/Contents/x"))
let measured = FolderStats.measure(statsDir)
check(measured?.files == 3 && (measured?.bytes ?? 0) >= 6000, "files and size include subfolders, skip hidden files, count a package once with its contents (\(String(describing: measured)))")
check(FolderStats.measure(statsDir, isCancelled: { true }) == nil, "a cancelled count gives nothing")
try? FileManager.default.removeItem(at: statsDir)

// Shortened Dropbox paths (uses this Mac's Dropbox folder when there is one)
if let dropbox = Dropbox.roots.first {
    let inside = folder("in", dropbox + "/Dropbox-shared/setup2026", days: 0)
    check(inside.shownPath(shortDropbox: true) == "Dropbox-shared/setup2026" && inside.shownPath(shortDropbox: false) == dropbox + "/Dropbox-shared/setup2026", "Dropbox paths shorten only when asked")
}
check(folder("out", "/tmp/x", days: 0).shownPath(shortDropbox: true) == "/tmp/x", "paths outside Dropbox stay full")

// Keyboard map of hotkeys
let k1 = folder("k1", "/k1", days: 0, hotkey: ["keyCode": 17, "modifierFlags": 0x60000])
let k2 = folder("k2", "/k2", days: 0, hotkey: ["keyCode": 17, "modifierFlags": 0x60000])
let k3 = folder("k3", "/k3", days: 0, hotkey: ["keyCode": 1, "modifierFlags": 0x100000])
let k4 = folder("k4", "/k4", days: 0, hotkey: ["keyCode": 2, "modifierFlags": 0x60000])
check(KeyUsage.modifierSets([k1, k3, k4]) == [[.control, .shift], [.command]], "modifier sets, most used first")
let keyMap = KeyUsage.map([k1, k2, k3, k4], flags: [.control, .shift])
check(keyMap[17]?.map(\.name) == ["k1", "k2"] && keyMap[2]?.map(\.name) == ["k4"] && keyMap[1] == nil, "keys per modifier set, clashes kept together")
check(KeyboardRows.rows.joined().contains(kVK_ANSI_T) && KeyboardRows.rows.count == 5, "the keyboard has a function row and four key rows")

// Dropbox marks and search
check(Dropbox.root(containing: "/Users/a/sw Dropbox/me/x", roots: ["/Users/a/sw Dropbox/me"]) == "/Users/a/sw Dropbox/me", "path inside a Dropbox root")
check(Dropbox.root(containing: "/Users/a/sw Dropbox/meX/x", roots: ["/Users/a/sw Dropbox/me"]) == nil, "a sibling with the same prefix is not inside")
check(Dropbox.root(containing: "/Users/a/Dropbox", roots: ["/Users/a/Dropbox"]) != nil, "the Dropbox folder itself")
let named = folder("setup2026", "/tmp/Projects/setup2026", days: 0)
check(named.matches("setup") && named.matches("SETUP projects") && !named.matches("setup zzz") && !separatorA.matches(""), "search matches name or path, every word, case-insensitive; never separators")
check(!Dropbox.roots.isEmpty || true, "Dropbox roots on this Mac: \(Dropbox.roots)")
if let current = sets.current, let real = try? Favorites.read(DFX.favoritesURL(set: current)) {
    check(!real.isEmpty, "reads the current folder set (\(current)): \(real.filter { !$0.isSeparator }.count) favorites, \(real.filter(\.isSeparator).count) separators")
    check(try! PropertyListSerialization.propertyList(from: Favorites.data(real), format: nil) as? NSArray
          == (try! PropertyListSerialization.propertyList(from: Data(contentsOf: DFX.favoritesURL(set: current)), format: nil) as? NSArray),
          "the real file survives a read/write round trip unchanged (in memory only)")
    // Hotkeys written by Default Folder X itself: rebuilding them from keyCode + modifiers must give the same dictionary.
    let keyed = real.filter { $0.hotkey != nil }
    let mismatches = keyed.filter { item in
        let stored = item.raw["hotkey"] as! [String: Any], hotkey = item.hotkey!
        let built = FavoriteItem.hotkeyDictionary(code: hotkey.code, flags: hotkey.flags)
        return (built as NSDictionary).isEqual(to: stored) == false
    }
    check(mismatches.isEmpty, "\(keyed.count) real hotkeys rebuild exactly" + (mismatches.isEmpty ? "" : " (differ: \(mismatches.map(\.name)))"))
} else {
    print("SKIP: no Default Folder X favorites on this Mac")
}
var edited = folder("e", "/e", days: 0)
edited.setHotkey(code: 17, flags: [.control, .shift])
check(edited.hotkeyText == "⌃⇧T" && (edited.raw["hotkey"] as? [String: Any])?["modifierFlags"] as? Int == 0x60000, "setHotkey writes ⌃⇧T as 0x60000")
edited.setHotkey(code: 123, flags: [.command, .shift])
check((edited.raw["hotkey"] as? [String: Any])?["modifierFlags"] as? Int == 0x920000 && (edited.raw["hotkey"] as? [String: Any])?["characters"] as? String == "\u{F702}", "arrow keys get the function flag and U+F702")
edited.clearHotkey()
check(edited.raw["hotkey"] == nil && edited.hotkeyText.isEmpty, "clearHotkey removes the hotkey")

check(NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: nil) != nil, "menu bar SF Symbol exists")

// A complete manual settings file must restore order, separators, hotkeys and opaque DFX data.
let snapshot = try! FavoritesTransfer.export(set: "Main", items: withExtra)
let wire = try! PropertyListSerialization.data(fromPropertyList: ["values": snapshot], format: .xml, options: 0)
let record = try! PropertyListSerialization.propertyList(from: wire, format: nil) as! NSDictionary
let restored = try! FavoritesTransfer.decode(record["values"] as! NSDictionary)!
check(restored.set == "Main" && Favorites.fingerprint(restored.items) == Favorites.fingerprint(withExtra), "settings file restores the selected set, order, separators and hotkeys")
check(NSDictionary(dictionary: restored.items[0].raw) == NSDictionary(dictionary: withExtra[0].raw), "settings transfer preserves bookmark and unknown DFX fields")
check(try! FavoritesTransfer.decode(["categoryNames": ["Main|top": "Work"]]) == nil, "legacy preferences never replace favorites with an empty list")
let empty = try! FavoritesTransfer.decode(FavoritesTransfer.export(set: "Main", items: []))!
check(empty.items.isEmpty, "an explicitly exported empty favorites list can be restored")
for bad: NSDictionary in [
    [FavoritesTransfer.key: "broken"],
    [FavoritesTransfer.key: ["version": 2, "set": "Main", "favorites": Data()]],
    [FavoritesTransfer.key: ["version": 1, "set": "Main", "favorites": try! PropertyListSerialization.data(fromPropertyList: [["name": "bad"]], format: .xml, options: 0)]]
] {
    do { _ = try FavoritesTransfer.decode(bad); check(false, "invalid snapshot rejected") }
    catch { check(true, "invalid snapshot rejected before changing favorites") }
}

print(failures == 0 ? "All tests passed" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
