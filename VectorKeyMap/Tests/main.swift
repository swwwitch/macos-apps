import Foundation

var failures = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
    if !condition() { failures += 1; print("FAIL line \(line): \(message)") }
}
func load(_ path: String) -> KeySet { try! Kys.parse(Data(contentsOf: URL(fileURLWithPath: path))) }
let root = URL(fileURLWithPath: CommandLine.arguments[1])

// Parsing
let sample = "/Menus {\r\t/Adobe\\ New\\ Fill {\r\t\t/Context 0\r\t\t/Modifiers 64\r\t\t/Represent 47\r\t\t/Key 47\r\t}\r\t/zoomin {\r\t\t/Context 0\r\t\t/Modifiers 64\r\t\t/Represent 43\r\t\t/Key 61\r\t}\r\t/none {\r\t\t/Context 0\r\t\t/Modifiers 0\r\t\t/Represent 0\r\t\t/Key 0\r\t}\r\t/~textBold {\r\t\t/Context 1\r\t\t/Modifiers 96\r\t\t/Represent 98\r\t\t/Key 98\r\t}\r}\r/Tools {\r\t/Adobe\\ Select\\ Tool {\r\t\t/Context 0\r\t\t/Modifiers 0\r\t\t/Represent 86\r\t\t/Key 86\r\t}\r}\r/type {\r\t/raw \r}"
let set = try! Kys.parse(Data(sample.utf8))
check(set.entries.count == 5, "entry count")
check(set.assignedCount == 4, "assigned count")
check(set.entries[CommandKey(kind: .menu, id: "Adobe New Fill")]??.label == "⌘/", "escaped space")
check(set.entries[CommandKey(kind: .menu, id: "zoomin")]??.label == "⌘=", "Key, not Represent")
check(set.entries[CommandKey(kind: .menu, id: "~textBold")]??.label == "⇧⌘B", "lowercase key shows as a capital")
check(set.entries[CommandKey(kind: .menu, id: "~textBold")]??.context == 1, "context")
check(set.entries[CommandKey(kind: .tool, id: "Adobe Select Tool")]??.label == "V", "tool section")
check(set.entries[CommandKey(kind: .menu, id: "none")].map { $0 == nil } == true, "listed without a key")
check((try? Kys.parse(Data("not a key set".utf8))) == nil, "rejects other files")
check(Kys.unescape("a\\ b") == "a b", "unescape space")
check(Kys.unescape("\\743\\603\\651") == "ラ", "unescape sign-extended bytes")
check(Kys.unescape("\\343\\203\\251") == "ラ", "unescape plain octal")

// Labels and equality
check(Shortcut(modifiers: 224, key: 25, context: 0)!.label == "⌥⇧⌘F12", "modifier order and function key")
check(Shortcut(modifiers: 0, key: 14, context: 0)!.label == "F1", "F1")
check(Shortcut(modifiers: 32, key: 9, context: 0)!.label == "⇧Tab", "Tab")
check(Shortcut(modifiers: 0, key: 0, context: 0) == nil, "key 0 is no shortcut")
check(Shortcut(modifiers: 96, key: 117, context: 1) == Shortcut(modifiers: 96, key: 85, context: 1), "letter case does not matter")
check(Shortcut(modifiers: 64, key: 92, context: 0) == Shortcut(modifiers: 64, key: 165, context: 0), "\\ and ¥ are one key")
check(Shortcut(modifiers: 96, key: 85, context: 0) != Shortcut(modifiers: 96, key: 85, context: 1), "context matters")

// Comparing
func key(_ id: String) -> CommandKey { CommandKey(kind: .menu, id: id) }
func keySet(_ items: [(String, Shortcut?)]) -> KeySet {
    var result = KeySet()
    for (id, shortcut) in items { result.entries[key(id)] = .some(shortcut); result.order.append(key(id)) }
    return result
}
let a = Shortcut(modifiers: 64, key: 65, context: 0), b = Shortcut(modifiers: 64, key: 66, context: 0)
let base = keySet([("same", a), ("changed", a), ("removed", a), ("gone", b), ("empty", nil)])
let next = keySet([("same", a), ("changed", b), ("removed", nil), ("added", b), ("empty", nil)])
let rows = Compare.rows(baseline: base, target: next, names: [:], order: [:], japanese: true)
func status(_ id: String) -> DiffStatus? { rows.first { $0.key.id == id }?.status }
check(status("same") == .same, "same")
check(status("changed") == .changed, "changed")
check(status("removed") == .removed, "removed")
check(status("added") == .added, "added")
check(status("gone") == .unlisted, "in the baseline only")
check(status("empty") == .unassigned, "no key in either")
check(rows.first { $0.key.id == "changed" }?.conflicts == ["added"], "same key in the target")
check(rows.first { $0.key.id == "same" }?.conflicts == [], "baseline keys do not count as a conflict")

// Search
let found = rows.first { $0.key.id == "changed" }!
check(Compare.matches(found, query: "cmd+b"), "cmd+ finds ⌘")
check(Compare.matches(found, query: "⌘B CHANGED"), "several words")
check(!Compare.matches(found, query: "⌘C"), "no match")

// Export
check(Report.csvField("a,b") == "\"a,b\"", "csv comma")
check(Report.csvField("say \"hi\"") == "\"say \"\"hi\"\"\"", "csv quote")
check(Report.csv([["a", "b"], ["1", "2"]]) == "a,b\r\n1,2\r\n", "csv rows")
check(Report.markdown([["a"], ["x|y"]]) == "| a |\n| --- |\n| x\\|y |\n", "markdown escapes the bar")

// Bundled data
let text = try! String(contentsOf: root.appendingPathComponent("Data/Commands.tsv"), encoding: .utf8)
let table = CommandTable.parse(text)
let defaults = load(root.appendingPathComponent("Data/IllustratorDefault.kys").path)
check(defaults.entries.count == 936, "bundled default has every command")
check(table.names.count == 936, "name table has every command")
check(defaults.order.allSatisfy { table.names[$0] != nil }, "every default ID has a name")
check(table.names[CommandKey(kind: .menu, id: "Adobe PathfinderUI")]?.japanese == "パスファインダー", "current ID of the panel")
check(table.names[CommandKey(kind: .tool, id: "Adobe Select Tool")]?.japanese == "選択", "tool name")
check(defaults.entries[CommandKey(kind: .menu, id: "Adobe PathfinderUI")]??.label == "⇧⌘F9", "default key of the panel")
let same = Compare.rows(baseline: defaults, target: defaults, names: table.names, order: table.order, japanese: true)
check(same.allSatisfy { $0.status == .same || $0.status == .unassigned }, "a set against itself has no difference")
check(same.allSatisfy { $0.groupRank < Compare.groups.count }, "every bundled command has a known group")

// Active set
check(SetScanner.activeSet("x /KBSCShortcutFile {\r\t\t/IsPreset 0\r\t\t/FileName [ 7\r\t\t\t73772d32303230\r\t\t]\r\t}") == ActiveSet(name: "sw-2020", isPreset: false), "custom set in the preferences")
check(SetScanner.activeSet("/KBSCShortcutFile { /IsPreset 1 }")?.isPreset == true, "preset in the preferences")
check(SetScanner.activeSet("nothing") == nil, "no entry in the preferences")

// Scanning a settings folder: one file linked from two versions is listed once, under the release version
let folder = FileManager.default.temporaryDirectory.appendingPathComponent("VectorKeyMapTest-\(UUID().uuidString)")
let release = folder.appendingPathComponent("Adobe Illustrator 30 Settings/ja_JP"), beta = folder.appendingPathComponent("Adobe Illustrator 31.0.0 Beta Settings/ja_JP")
try! FileManager.default.createDirectory(at: release, withIntermediateDirectories: true)
try! FileManager.default.createDirectory(at: beta, withIntermediateDirectories: true)
try! Data(sample.utf8).write(to: release.appendingPathComponent("mine.kys"))
try! FileManager.default.createSymbolicLink(at: beta.appendingPathComponent("mine.kys"), withDestinationURL: release.appendingPathComponent("mine.kys"))
try! Data(sample.utf8).write(to: beta.appendingPathComponent("beta.kys"))
try! Data("/KBSCShortcutFile { /IsPreset 0 /FileName [ 4 6d696e65 ] }".utf8).write(to: release.appendingPathComponent("Adobe Illustrator Prefs"))
let scan = SetScanner.scan(preferences: folder)
check(scan.sources.map(\.name) == ["mine", "beta"], "release first, each file once")
check(scan.sources.first?.origin == .detected(version: "30"), "listed under the release version")
check(scan.sources.first?.isActive == true && scan.sources.last?.isActive == false, "active set marked")
try? FileManager.default.removeItem(at: folder)

// Keyboard
let jis = KeyboardLayout.rows(.jis).flatMap { $0 }.filter { $0.id >= 0 }
let ansi = KeyboardLayout.rows(.ansi).flatMap { $0 }.filter { $0.id >= 0 }
check(Set(jis.map(\.id)).count == jis.count && Set(ansi.map(\.id)).count == ansi.count, "key codes are unique")
for kind in KeyboardKind.allCases {
    for row in KeyboardLayout.rows(kind) {
        check(abs(row.map(\.width).reduce(0, +) - KeyboardLayout.unitsPerRow) < 0.001, "\(kind) row width \(row.map(\.label))")
    }
}
func placed(_ modifiers: Int, _ key: Int, _ keys: [KeySpec]) -> Slot? { KeyboardLayout.slot(Shortcut(modifiers: modifiers, key: key, context: 0)!, keys: keys) }
check(placed(64, 75, jis) == Slot(keyCode: 40, modifiers: 64), "⌘K")
check(placed(64, 43, jis) == Slot(keyCode: 41, modifiers: 96), "⌘+ on JIS is ⇧⌘;")
check(placed(64, 61, jis) == Slot(keyCode: 27, modifiers: 96), "⌘= on JIS is ⇧⌘-")
check(placed(64, 61, ansi) == Slot(keyCode: 24, modifiers: 64), "⌘= on US is its own key")
check(placed(32, 125, jis) == Slot(keyCode: 42, modifiers: 32), "⇧} keeps one Shift")
check(placed(64, 165, jis) == Slot(keyCode: 93, modifiers: 64), "⌘¥ on JIS")
check(placed(64, 92, ansi) == Slot(keyCode: 42, modifiers: 64), "⌘\\ on US")
check(placed(0, 19, jis) == Slot(keyCode: 97, modifiers: 0), "F6")
check(placed(32, 9, jis) == Slot(keyCode: 48, modifiers: 32), "⇧Tab")
check(KeyboardLayout.systemSlot(code: 48, carbonFlags: 0x100) == Slot(keyCode: 48, modifiers: 64), "⌘Tab from macOS")
check(KeyboardLayout.systemSlot(code: 20, carbonFlags: 0x300) == Slot(keyCode: 20, modifiers: 96), "⇧⌘3 from macOS")
check(KeyboardLayout.systemSlot(code: 0, carbonFlags: 0x20000) == nil, "Globe+A is not a bare A")
check(KeyboardLayout.systemSlot(code: 0, carbonFlags: 0x20200) == nil, "Globe+Shift+A is not ⇧A")
check(KeyboardLayout.systemSlot(code: 49, carbonFlags: 0x1000) == nil, "⌃ never meets Illustrator")
let assigned: [(name: String, shortcut: Shortcut)] = [("A", Shortcut(modifiers: 64, key: 75, context: 0)!), ("B", Shortcut(modifiers: 96, key: 75, context: 1)!)]
let map = KeyMap(kind: .jis, assignments: assigned, system: [Slot(keyCode: 49, modifiers: 64), Slot(keyCode: 0, modifiers: 64)])
let keyK = jis.first { $0.id == 40 }!, keyA = jis.first { $0.id == 0 }!, keySpace = jis.first { $0.id == 49 }!, keyL = jis.first { $0.id == 37 }!
check(map.state(keyK, 64) == .used, "used")
check(map.state(keyK, 96) == .textOnly, "text only")
check(map.state(keyA, 64) == .system, "macOS")
check(map.state(keySpace, 64) == .system && map.state(keySpace, 0) == .unavailable, "Space is not a free key")
check(map.state(keyL, 64) == .free, "free")
check(!map.freeKeys(64).contains(keyK) && map.freeKeys(64).contains(keyL), "free list")
let defaultsOnJIS = KeyMap(kind: .jis, assignments: same.compactMap { row in row.target.map { (row.displayName, $0) } })
check(defaultsOnJIS.unplaced.isEmpty, "every default key sits on the JIS keyboard: \(defaultsOnJIS.unplaced)")

if failures > 0 { print("\(failures) failed"); exit(1) }
print("PASS: all checks")
