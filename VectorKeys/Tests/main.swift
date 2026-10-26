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
check(winners.map(\.1) == [library.scripts[0].id] && duplicates == [library.scripts[1].id], "first in list wins")
library.scripts[0].enabled = false
(winners, duplicates) = library.activeHotkeys()
check(winners.map(\.1) == [library.scripts[1].id] && duplicates.isEmpty, "disabled script frees the key")

// Saving round trip
let file = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("VectorKeys-test-\(UUID().uuidString).json")
do { try library.save(to: file) } catch { check(false, "save: \(error)") }
check(Library.load(from: file) == library, "round trip")
try? FileManager.default.removeItem(at: file)
check(Library.load(from: file) == Library(), "missing file gives an empty list")

// AppleScript
let script = ScriptText.appleScript(appPath: "/Applications/Adobe Illustrator 2026/Adobe Illustrator.app", file: "/s/a \"q\".jsx")
check(script.contains("tell application \"/Applications/Adobe Illustrator 2026/Adobe Illustrator.app\""), "app by path")
check(script.contains("do javascript (POSIX file \"/s/a \\\"q\\\".jsx\" as alias)"), "file quoted")
check(OSAScript.cleanError("-: execution error: Adobe Illustratorでエラーが起きました：Error 21: undefined is not an object (-2700)") == "Error 21: undefined is not an object", "error cleaned")

if failures == 0 { print("PASS: entries, adding, hotkeys, saving, AppleScript") } else { print("\(failures) failure(s)"); exit(1) }
