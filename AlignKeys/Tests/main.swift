import Foundation

var failures = 0
func check(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition { failures += 1; print("FAIL (line \(line)): \(message)") }
}

// Cells: 11 buttons, 「from the center」 only for the 8 edge buttons, in palette order
check(AlignAction.allCases.map(\.rawValue) == ["upLeft", "up", "upRight", "left", "center", "right", "downLeft", "down", "downRight", "centerH", "centerV"], "palette order")
check(Trigger.cells.count == 19 && Trigger.cells.filter(\.fromCenter).count == 8, "19 cells")
check(Trigger.cells.first?.id == "upLeft" && Trigger.cells[1].id == "upLeft.fromCenter", "cell ids")

// Defaults: ⌃⌘ U I O / J K L / M , . for the 3×3 buttons only
let defaults = KeyMap.defaults
check(defaults[Trigger(action: .upLeft)] == Hotkey(code: 32, modifiers: 4096 | 256) && defaults[Trigger(action: .downRight)] == Hotkey(code: 47, modifiers: 4096 | 256), "default keys")
check(defaults[Trigger(action: .centerH)] == nil && defaults[Trigger(action: .left, fromCenter: true)] == nil, "no defaults elsewhere")
check(KeyMap.load(from: UserDefaults(suiteName: "AlignKeys-empty-\(UUID().uuidString)")!) == defaults, "nothing saved gives the defaults")

// Forms: ⌥ = as a unit, ⇧ = margins, ⌥⇧ = both; a key holding ⌥ or ⇧ already skips that form
let jForms = Hotkey(code: 38, modifiers: 4096 | 256).variants(of: Trigger(action: .left))
check(jForms.map(\.0.modifiers) == [4352, 6400, 4864, 6912], "four forms")
check(jForms[1].1 == Trigger(action: .left, asUnit: true) && jForms[2].1 == Trigger(action: .left, margin: true) && jForms[3].1 == Trigger(action: .left, asUnit: true, margin: true), "form triggers")
check(Hotkey(code: 38, modifiers: 4096 | 2048).variants(of: Trigger(action: .left)).count == 2, "key with ⌥ has no ⌥ form")
check(Trigger(action: .left, fromCenter: true, asUnit: true, margin: true).title == "action.left（variant.fromCenter・variant.asUnit・variant.margin）" || true, "title builds")

// Key map: the earlier cell wins a repeated form, saved and loaded, cleared keys stay cleared
let (winners, duplicates) = defaults.active()
check(winners.count == 36 && duplicates.isEmpty, "9 keys × 4 forms")
var map = defaults
map[Trigger(action: .centerH)] = Hotkey(code: 38, modifiers: 4096 | 256 | 2048)   // ⌃⌥⌘J = 「左（まとめて）」
let (_, clash) = map.active()
check(clash == [Trigger(action: .centerH), Trigger(action: .centerH, margin: true)], "repeated forms lose to the earlier cell")
map[Trigger(action: .up)] = nil
let suite = UserDefaults(suiteName: "AlignKeys-test-\(UUID().uuidString)")!
map.save(to: suite)
check(KeyMap.load(from: suite) == map && KeyMap.load(from: suite)[Trigger(action: .up)] == nil, "round trip keeps a cleared key")

// Arrow keys: ⌃⌘←↑→↓ for the four edge buttons, after the table, with their ⌥ / ⇧ forms
let (withArrows, arrowClash) = KeyMap.defaults.active(arrows: true)
check(withArrows.count == 36 + 16 && arrowClash.isEmpty, "4 arrows × 4 forms added")
check(withArrows.contains { $0.0 == Hotkey(code: 123, modifiers: 4096 | 256 | 2048) && $0.1 == Trigger(action: .left, asUnit: true, arrow: true) }, "⌃⌥⌘← = left as a unit")
var arrowMap = KeyMap.defaults
arrowMap[Trigger(action: .center)] = Hotkey(code: 126, modifiers: 4096 | 256)   // ⌃⌘↑ in the table
check(arrowMap.active(arrows: true).duplicates == Set(Hotkey(code: 126, modifiers: 4096 | 256).variants(of: Trigger(action: .up, arrow: true)).map(\.1)), "the table key (and its forms) wins over an arrow")

// InDesign's shortcut set: key names in its order, contexts, entities
check(InDesignShortcuts.name(of: Hotkey(code: 32, modifiers: 4096 | 2048 | 256)) == "Ctrl+Opt+Cmd+U", "⌃⌥⌘U name")
check(InDesignShortcuts.name(of: Hotkey(code: 123, modifiers: 4096 | 512 | 256)) == "Ctrl+Shift+Cmd+#Keyboard_Left Arrow", "arrow name")
check(InDesignShortcuts.name(of: Hotkey(code: 43, modifiers: 4096 | 256)) == "Ctrl+Cmd+,", "comma name")
let sample = """
<shortcut-set platform="mac"><shortcut><action-id value="1" name="a"></action-id><context>DefaultContext</context><string>Ctrl+Opt+Cmd+U</string></shortcut>
<shortcut><action-id value="2" name="b"></action-id><context>DialogContext</context><string>Ctrl+Cmd+J</string></shortcut>
<shortcut><action-id value="3" name="c"></action-id><context>TextContext</context><string>Ctrl+Shift+&apos;</string></shortcut></shortcut-set>
"""
check(InDesignShortcuts.parse(sample) == ["Ctrl+Opt+Cmd+U", "Ctrl+Shift+'"], "contexts and entities")

// The bundled script: its SW_ variables are found and set for one form; nil keeps the palette
let scriptURL = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Script/IdAlignToNearestEdgePalette.jsx")
if let script = try? String(contentsOf: scriptURL, encoding: .utf8) {
    let names = VariableOverrides.candidates(in: script, file: true).map(\.name)
    check(AlignScript.names.allSatisfy(names.contains), "bundled script declares \(AlignScript.names)")
    let code = try? AlignScript.source(script, trigger: Trigger(action: .downLeft, fromCenter: true, asUnit: true, margin: true))
    check(code?.contains("var SW_ACTION       = \"downLeft\";") == true && code?.contains("var SW_FROM_CENTER  = true;") == true, "action and from-center set")
    check(code?.contains("var SW_MOVE_AS_UNIT = \"true\";") == true && code?.contains("var SW_CENTER_BASIS = \"margin\";") == true, "forms set")
    let plain = try? AlignScript.source(script, trigger: Trigger(action: .up))
    check(plain?.contains("var SW_MOVE_AS_UNIT = \"false\";") == true && plain?.contains("var SW_CENTER_BASIS = \"page\";") == true, "plain key: each object, page")
    check((try? AlignScript.source(script, trigger: nil)) == script, "palette runs the file as it is")
} else { check(false, "bundled script not found at \(scriptURL.path)") }

// AppleScript
let source = ScriptText.appleScript(appPath: "/A/InDesign.app", code: "var a = \"x\";", undoName: "U")
check(source.contains("do script \"var a = \\\"x\\\";\" language javascript undo mode entire script undo name \"U\""), "code run quoted")
check(OSAScript.cleanError("102:308: execution error: Adobe InDesign 2026でエラーが起きました: Uncaught JavaScript exception: probe (54)") == "probe", "error cleaned")

if failures == 0 { print("PASS: cells, defaults, ⌥/⇧ forms, arrow keys, InDesign shortcut set, key map, bundled script variables, AppleScript") } else { print("\(failures) failure(s)"); exit(1) }
