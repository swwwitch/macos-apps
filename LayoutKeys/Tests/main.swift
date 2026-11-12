import Foundation

var failures = 0
func check(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition { failures += 1; print("FAIL (line \(line)): \(message)") }
}

// Entries
check(ScriptEntry.defaultName(for: "/a/b/AlignToArtboard.jsx") == "AlignToArtboard", "name from file")
check(ScriptEntry.accepts(URL(fileURLWithPath: "/a/x.JSX")) && ScriptEntry.accepts(URL(fileURLWithPath: "/a/x.jsxbin")), "script extensions")
check(!ScriptEntry.accepts(URL(fileURLWithPath: "/a/x.ai")), "non-script refused")

// Adding: same path once, non-scripts skipped, order kept
var library = Library()
let added = library.add(paths: ["/s/B.jsx", "/s/A.jsx", "/s/B.jsx", "/s/readme.txt"])
check(added.map(\.name) == ["B", "A"], "added in order without duplicates")
check(library.add(paths: ["/s/A.jsx"]).isEmpty && library.scripts.count == 2, "already registered path ignored")

// Hotkeys: disabled and unassigned skipped, the earlier script wins a repeated key
let key = Hotkey(code: 0, modifiers: 256 | 2048)
library.scripts[0].hotkey = key
library.scripts[1].hotkey = key
var (winners, duplicates) = library.activeHotkeys()
check(winners.map(\.1.script) == [library.scripts[0].id] && duplicates == [Trigger(script: library.scripts[1].id)], "first in list wins")
library.scripts[0].enabled = false
(winners, duplicates) = library.activeHotkeys()
check(winners.map(\.1.script) == [library.scripts[1].id] && duplicates.isEmpty, "disabled script frees the key")

// Run count: old lists without the fields load as 0
let old = #"{"version":1,"scripts":[{"id":"x","name":"A","path":"/s/A.jsx","enabled":true}]}"#
var loaded = (try? JSONDecoder().decode(Library.self, from: Data(old.utf8)))?.scripts.first
check(loaded?.uses == 0 && loaded?.lastRun == nil, "1.0.0 list loads with no runs")
loaded?.recordRun(); loaded?.recordRun(at: Date(timeIntervalSince1970: 100))
check(loaded?.uses == 2 && loaded?.lastRun == Date(timeIntervalSince1970: 100), "runs counted")

// Saving round trip
let file = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("LayoutKeys-test-\(UUID().uuidString).json")
do { try library.save(to: file) } catch { check(false, "save: \(error)") }
check(Library.load(from: file) == library, "round trip")
try? FileManager.default.removeItem(at: file)
check(Library.load(from: file) == Library(), "missing file gives an empty list")

// AppleScript
let script = ScriptText.appleScript(appPath: "/Applications/Adobe InDesign 2026/Adobe InDesign 2026.app", file: "/s/a \"q\".jsx", undoName: "Align \"L\"")
check(script.contains("tell application \"/Applications/Adobe InDesign 2026/Adobe InDesign 2026.app\""), "app by path")
check(script.contains("do script (POSIX file \"/s/a \\\"q\\\".jsx\" as alias) language javascript undo mode entire script undo name \"Align \\\"L\\\"\""), "file and undo name quoted")
// Measured on InDesign 2026 (21.6) with `throw new Error("probe")`.
check(OSAScript.cleanError("102:308: execution error: Adobe InDesign 2026でエラーが起きました: Uncaught JavaScript exception: probe (54)") == "probe", "error cleaned")

// SW_ variables: discovery with the line's comment, a changed copy, the file untouched
let source = """
#targetengine "Probe"
(function () {
    var SW_ACTION      = "";     /* ボタン（空ならパレット） */
    var SW_FROM_CENTER = false;  // 中央から
    var SW_STEP = 2;
    var NOT_SW = 1;
})();
"""
let found = VariableOverrides.candidates(in: source, file: true)
check(found.map(\.name) == ["SW_ACTION", "SW_FROM_CENTER", "SW_STEP"], "SW_ variables found")
check(found.first?.note == "ボタン（空ならパレット）" && found.dropFirst().first?.note == "中央から" && found.last?.note == "", "trailing comments as notes")
check(found.dropFirst().first?.isBoolean == true && found.first?.isBoolean == false, "boolean detection")
let changed = try? VariableOverrides.apply(to: source, names: ["SW_ACTION", "SW_FROM_CENTER"], values: ["left", "true"], file: true)
check(changed?.contains("var SW_ACTION      = \"left\";") == true && changed?.contains("var SW_FROM_CENTER = true;") == true, "values replaced")
check((try? VariableOverrides.apply(to: source, names: ["SW_FROM_CENTER"], values: ["yes"], file: true)) == nil, "non-boolean refused")
check((try? VariableOverrides.apply(to: "var SW_A = 1;\n$.evalFile(x);", names: ["SW_A"], values: ["2"], file: true)) == nil, "file-location scripts refused")

// Variable keys: registered after the script's own key, values layered over the entry's
var keyed = Library()
keyed.add(paths: ["/s/Align.jsx"])
keyed.scripts[0].hotkey = key
keyed.scripts[0].variables = ["SW_ACTION": "up", "SW_FROM_CENTER": "true"]
let leftKey = VariableKey(values: ["SW_ACTION": "left"], hotkey: Hotkey(code: 123, modifiers: 4096 | 2048))
let sameKey = VariableKey(values: ["SW_ACTION": "right"], hotkey: key)
keyed.scripts[0].variableKeys = [leftKey, sameKey, VariableKey(values: ["SW_ACTION": "down"])]
let (keyWinners, keyDuplicates) = keyed.activeHotkeys()
let entryID = keyed.scripts[0].id
check(keyWinners.map(\.1) == [Trigger(script: entryID), Trigger(script: entryID, key: leftKey.id)], "own key, then variable keys; unassigned skipped")
check(keyDuplicates == [Trigger(script: entryID, key: sameKey.id)], "a variable key repeating the script's key loses")
check(keyed.scripts[0].overrides(with: leftKey).map { "\($0.name)=\($0.value)" } == ["SW_ACTION=left", "SW_FROM_CENTER=true"], "key values over the entry's")
check(keyed.scripts[0].title(for: leftKey) == "Align（left）" && keyed.scripts[0].title(for: nil) == "Align", "titles")
let oldEntry = #"{"version":1,"scripts":[{"id":"x","name":"A","path":"/s/A.jsx","enabled":true}]}"#
check((try? JSONDecoder().decode(Library.self, from: Data(oldEntry.utf8)))?.scripts.first?.keys.isEmpty == true, "lists without variable keys load")
let choice = VariableOverrides.candidates(in: "var SW_ACTION = \"\";  /* 空ならパレット [upLeft|up | left] / empty */\nvar SW_X = false;", file: true)
check(choice.first?.choices == ["upLeft", "up", "left"] && choice.first?.explanation == "空ならパレット / empty", "choices from the comment")
check(choice.last?.choices == ["true", "false"], "boolean choices")

check(ScriptText.appleScript(appPath: "/A/InDesign.app", code: "var a = \"x\";", undoName: "U").contains("do script \"var a = \\\"x\\\";\" language javascript undo mode entire script undo name \"U\""), "code run quoted")

if failures == 0 { print("PASS: entries, adding, hotkeys, saving, AppleScript, SW_ variables, variable keys") } else { print("\(failures) failure(s)"); exit(1) }
