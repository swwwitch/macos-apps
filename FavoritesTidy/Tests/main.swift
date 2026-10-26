import AppKit

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
let temp = FileManager.default.temporaryDirectory.appendingPathComponent("FavoritesTidyTest-\(UUID().uuidString).plist")
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

print(failures == 0 ? "All tests passed" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
