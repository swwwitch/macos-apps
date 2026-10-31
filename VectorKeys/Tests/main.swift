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

// Run count: old lists without the fields load as 0
let old = #"{"version":1,"scripts":[{"id":"x","name":"A","path":"/s/A.jsx","enabled":true}]}"#
var loaded = (try? JSONDecoder().decode(Library.self, from: Data(old.utf8)))?.scripts.first
check(loaded?.uses == 0 && loaded?.lastRun == nil, "1.0.0 list loads with no runs")
loaded?.recordRun(); loaded?.recordRun(at: Date(timeIntervalSince1970: 100))
check(loaded?.uses == 2 && loaded?.lastRun == Date(timeIntervalSince1970: 100), "runs counted")

// Saving round trip
library.reconcileComponents()
let file = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("VectorKeys-test-\(UUID().uuidString).json")
do { try library.save(to: file) } catch { check(false, "save: \(error)") }
check(Library.load(from: file) == library, "round trip")
try? FileManager.default.removeItem(at: file)
check(Library.load(from: file) == Library(), "missing file gives an empty list")

// Single and double press of one key are different hotkeys, registered as one key
var keys = Library()
keys.add(paths: ["/k/One.jsx", "/k/Two.jsx", "/k/Other.jsx"])
keys.scripts[0].hotkey = Hotkey(code: 17, modifiers: 2048)
keys.scripts[1].hotkey = Hotkey(code: 17, modifiers: 2048, taps: 2)
keys.scripts[2].hotkey = Hotkey(code: 17, modifiers: 2048, taps: 2)
let targets = keys.keyTargets()
check(targets.count == 1 && targets[0].single == keys.scripts[0].id && targets[0].double == keys.scripts[1].id, "one key, single and double")
check(keys.activeHotkeys().duplicates == [keys.scripts[2].id], "second double press is the duplicate")

// KM numbering
check(Library.strippingNumbering("11)1 同じフォントを選択") == "同じフォントを選択", "number and sub-number")
check(Library.strippingNumbering("21）【テキスト】入力") == "【テキスト】入力", "full-width bracket")
check(Library.strippingNumbering("12) テキスト入力 (エリア内文字)") == "テキスト入力 (エリア内文字)", "space after bracket")
check(Library.strippingNumbering("12)3Dにする") == "3Dにする", "digit in the name kept")
check(Library.strippingNumbering("テーブル風に加工") == "テーブル風に加工", "no numbering")

// Find and replace in names
check(Library.replacing(in: "Text Input", find: "text", with: "文字", regex: false, caseSensitive: false) == "文字 Input", "literal, any case")
check(Library.replacing(in: "Text Input", find: "text", with: "文字", regex: false, caseSensitive: true) == "Text Input", "match case")
check(Library.replacing(in: "a.b", find: ".", with: "$1", regex: false, caseSensitive: true) == "a$1b", "literal keeps . and $1")
check(Library.replacing(in: "11) 長方形", find: #"^(\d+)\) (.+)$"#, with: "$2（$1）", regex: true, caseSensitive: true) == "長方形（11）", "regex groups")
check(Library.replacing(in: "x", find: "(", with: "", regex: true, caseSensitive: true) == nil, "bad pattern")
check(Library.replacing(in: "abc", find: "abc", with: "", regex: false, caseSensitive: true) == "abc", "empty result keeps the name")

// Statistics order
var used = Library()
used.add(paths: ["/u/A.jsx", "/u/B.jsx", "/u/C.jsx"])
used.scripts[1].recordRun(at: Date(timeIntervalSince1970: 10)); used.scripts[1].recordRun(at: Date(timeIntervalSince1970: 20))
used.scripts[2].recordRun(at: Date(timeIntervalSince1970: 30))
check(used.byUse.map(\.name) == ["B", "C", "A"], "most used first, never run last")

// Categories
var cats = Library()
cats.add(paths: ["/c/A.jsx", "/c/B.jsx", "/c/C.jsx"])
cats.setCategory("Text", for: [cats.scripts[0].id, cats.scripts[2].id])
check(cats.categoryList == ["Text"] && cats.scripts.map(\.category) == ["Text", nil, "Text"], "set category")
cats.renameCategory("Text", to: "文字")
check(cats.categoryList == ["文字"] && cats.scripts[0].category == "文字", "rename moves scripts")
cats.addCategory("Path"); cats.renameCategory("Path", to: "文字")
check(cats.categoryList == ["文字"], "rename onto an existing name merges")
cats.deleteCategory("文字")
check(cats.categoryList.isEmpty && cats.scripts.allSatisfy { $0.category == nil } && cats.scripts.count == 3, "delete keeps scripts")
check(cats.addCategory("  ") == nil, "empty name refused")

// Moving inside one category keeps the others in place
var order = Library()
order.add(paths: ["/o/1.jsx", "/o/2.jsx", "/o/3.jsx", "/o/4.jsx"])
let subset = [order.scripts[0].id, order.scripts[2].id, order.scripts[3].id]
order.move(ids: subset, from: [2], to: 0)
check(order.scripts.map(\.name) == ["4", "2", "1", "3"], "subset move: \(order.scripts.map(\.name))")

// Sorting for display
var sortable = Library()
sortable.add(paths: ["/s/b.jsx", "/s/a.jsx", "/s/c.jsx"])
sortable.scripts[0].hotkey = Hotkey(code: 1, modifiers: 256)
sortable.scripts[2].hotkey = Hotkey(code: 0, modifiers: 256)
check(SortOrder.name.sorted(sortable.scripts) { _ in "" }.map(\.name) == ["a", "b", "c"], "by name")
check(SortOrder.hotkey.sorted(sortable.scripts) { $0.code == 0 ? "A" : "S" }.map(\.name) == ["c", "b", "a"], "by hotkey, none last")

// Keyboard Maestro export
func macro(_ name: String, _ actions: [[String: Any]], key: Int? = nil, active: Bool = true) -> [String: Any] {
    var m: [String: Any] = ["Name": name, "Actions": actions, "IsActive": active]
    if let key { m["Triggers"] = [["MacroTriggerType": "HotKey", "KeyCode": key, "Modifiers": 256 | 2048 | 4096]] }
    return m
}
let comment: [String: Any] = ["MacroActionType": "Comment", "Title": "memo"]
let export: [[String: Any]] = [["Name": "G", "Targeting": ["Targeting": "Included", "TargetingApps": [["BundleIdentifier": "com.adobe.illustrator"]]], "Macros": [
    macro("File", [comment, ["MacroActionType": "PlugIn", "PlugInFolderName": "Ai Execute Script File", "PlugInParameters": ["Script path": "~/s/A.jsx"]]], key: 17),
    macro("Code", [["MacroActionType": "PlugIn", "PlugInFolderName": "Ai Execute Jsx Text", "PlugInParameters": ["Jsx code": "alert(1); // 50%"]]], active: false),
    macro("Open", [["MacroActionType": "Open1File", "Path": "/s/B.jsx", "Application": ["BundleIdentifier": "com.adobe.illustrator"]]]),
    macro("Two", [["MacroActionType": "PlugIn", "PlugInFolderName": "Ai Execute Script File", "PlugInParameters": ["Script path": "/s/C.jsx"]], ["MacroActionType": "Pause", "Time": "0.1"]]),
    macro("Var", [["MacroActionType": "PlugIn", "PlugInFolderName": "Ai Execute Script File", "PlugInParameters": ["Script path": "%Variable%dir%/D.jsx"]]]),
    macro("Menu", [["MacroActionType": "SelectMenuItem", "Menu": ["File", "Close"], "TargetingType": "Front"]]),
    macro("Keys", [["MacroActionType": "SimulateKeystroke", "KeyCode": 0]]),
    macro("Off", [["MacroActionType": "PlugIn", "PlugInFolderName": "Ai Execute Script File", "PlugInParameters": ["Script path": "/s/E.jsx"]], ["MacroActionType": "Pause", "IsActive": false]]),
]]]
let tapped: [String: Any] = ["Name": "T", "Actions": [["MacroActionType": "PlugIn", "PlugInFolderName": "Ai Execute Script File", "PlugInParameters": ["Script path": "/s/T.jsx"]]],
    "Triggers": [["MacroTriggerType": "HotKey", "KeyCode": 17, "Modifiers": 2048, "FireType": "Tapped", "TapCount": 2]]]
check(KMImport.hotkey(of: tapped) == Hotkey(code: 17, modifiers: 2048, taps: 2), "tapped twice is a double press")
var thrice = tapped; thrice["Triggers"] = [["MacroTriggerType": "HotKey", "KeyCode": 17, "Modifiers": 2048, "FireType": "TappedOnly", "TapCount": 3]]
check(KMImport.hotkey(of: thrice) == nil, "three taps left out")
let kmData = try! PropertyListSerialization.data(fromPropertyList: export, format: .xml, options: 0)
let parsed = KMImport.parse(kmData)!
check(parsed.items.map(\.name) == ["File", "Code", "Open", "Off"], "importable macros: \(parsed.items.map(\.name))")
check(parsed.items.allSatisfy { $0.group == "G" }, "group kept for the category")
check(parsed.items[0].parts == [.file(("~/s/A.jsx" as NSString).expandingTildeInPath)] && parsed.items[0].hotkey == Hotkey(code: 17, modifiers: 256 | 2048 | 4096), "path expanded, hotkey kept")
check(parsed.items[1].parts == [.code("alert(1); // 50%")] && !parsed.items[1].enabled, "code kept, off state kept")
check(parsed.skipped.map(\.reason) == [.severalSteps, .variable, .notScript, .notScript], "skip reasons: \(parsed.skipped.map(\.reason))")
check(KMImport.parse(Data("not a plist".utf8)) == nil, "unreadable file")
let finder: [[String: Any]] = [["Name": "Finder", "Macros": [macro("Close", [["MacroActionType": "SelectMenuItem", "Menu": ["File", "Close"], "TargetingType": "Front"]])]]]
check(KMImport.parse(try! PropertyListSerialization.data(fromPropertyList: finder, format: .xml, options: 0))!.items.isEmpty, "front-app menu outside Illustrator groups left out")
check(KMImport.fileName(for: "a/b:c", taken: ["a／b：c.jsx"]) == "a／b：c 2.jsx", "file name made safe and unique")

// Legacy menu entries remain decodable but never run, register a key, or enter a new library.
var stepped = ScriptEntry(steps: [.menuCommand(id: "selectall", title: nil), .script(path: "/s/T.jsx")], name: "Mixed", hotkey: Hotkey(code: 2, modifiers: 256))
stepped.category = "Saved"; stepped.kmUID = "Original"; stepped.runCount = 8
let savedMixed = try! JSONEncoder().encode(stepped)
let decodedMixed = try! JSONDecoder().decode(ScriptEntry.self, from: savedMixed)
check(decodedMixed == stepped && decodedMixed.category == "Saved" && decodedMixed.uses == 8, "legacy mixed item round-trips without lost data")
check(stepped.hasUnsupportedSteps && !stepped.scriptsOnly && !stepped.isAvailable, "mixed item is blocked in full, not partially run")
var blocked = Library(); blocked.scripts = [stepped]
check(blocked.activeHotkeys().winners.isEmpty && blocked.keyTargets().isEmpty, "legacy menu keys are not intercepted")
var additions = Library()
check(additions.add(entries: [stepped]).isEmpty, "cannot create a menu item")
stepped.actions = [.menuItem(path: ["File", "Close"])]
check(!stepped.isAvailable && !stepped.scriptsOnly, "legacy AX menu item is blocked")
stepped.actions = []
check(!stepped.isAvailable && !stepped.scriptsOnly, "empty item is not runnable")
let legacy = #"{"id":"L","name":"A","path":"/s/A.jsx","enabled":true}"#
check((try? JSONDecoder().decode(ScriptEntry.self, from: Data(legacy.utf8)))?.actions == [.script(path: "/s/A.jsx")], "1.3 item is one script step")
let menuMacro = macro("Menu plus script", [["MacroActionType": "SelectMenuItem", "Menu": ["File", "Close"], "TargetingType": "Front"], ["MacroActionType": "PlugIn", "PlugInFolderName": "Ai Execute Script File", "PlugInParameters": ["Script path": "/s/T.jsx"]]])
let mixedKM = try! PropertyListSerialization.data(fromPropertyList: [["Name":"Illustrator", "Macros":[menuMacro]]], format: .xml, options: 0)
let mixedResult = KMImport.parse(mixedKM)!
check(mixedResult.items.isEmpty && mixedResult.skipped.count == 1, "KM menu plus script is skipped as a whole")
let appleMenu = macro("Menu by code", [["MacroActionType":"ExecuteAppleScript", "Text":"app.executeMenuCommand('group')"]])
let menuData = try! PropertyListSerialization.data(fromPropertyList: [["Name":"Illustrator", "Macros":[appleMenu]]], format:.xml, options:0)
check(KMImport.parse(menuData)!.items.isEmpty, "KM menu AppleScript is not converted to a script")
let scriptsMacro = macro("Two scripts", [["MacroActionType":"PlugIn", "PlugInFolderName":"Ai Execute Script File", "PlugInParameters":["Script path":"/s/First.jsx"]], ["MacroActionType":"PlugIn", "PlugInFolderName":"Ai Execute Jsx Text", "PlugInParameters":["Jsx code":"alert(2);"]]])
let scriptsData = try! PropertyListSerialization.data(fromPropertyList: [["Name":"Scripts", "Macros":[scriptsMacro]]], format:.xml, options:0)
check(KMImport.parse(scriptsData)!.items.first?.parts == [.file("/s/First.jsx"), .code("alert(2);")], "multiple script steps keep their order")

// AppleScript
let script = ScriptText.appleScript(appPath: "/Applications/Adobe Illustrator 2026/Adobe Illustrator.app", file: "/s/a \"q\".jsx")
check(script.contains("tell application \"/Applications/Adobe Illustrator 2026/Adobe Illustrator.app\""), "app by path")
check(script.contains("do javascript (POSIX file \"/s/a \\\"q\\\".jsx\" as alias)"), "file quoted")
check(OSAScript.cleanError("-: execution error: Adobe Illustratorでエラーが起きました：Error 21: undefined is not an object (-2700)") == "Error 21: undefined is not an object", "error cleaned")

// Inline code retains exact Unicode, newlines, quotes and backslashes through JSON.
let inlineSource = "// 日本語\nalert(\"C:\\\\test\");\n'quoted';"
let inlineEntry = ScriptEntry(steps: [.code(source: inlineSource)], name: "Inline", hotkey: key)
check(inlineEntry.scriptsOnly && inlineEntry.isAvailable, "inline code is executable without a file")
check(inlineEntry.path.isEmpty, "inline code has no external file")
let inlineData = try JSONEncoder().encode(inlineEntry)
check(try JSONDecoder().decode(ScriptEntry.self, from: inlineData) == inlineEntry, "inline code JSON round trip")
check(!ScriptEntry(steps: [.code(source: " \n\t")], name: "Empty").isAvailable, "blank code is unavailable")
let mixedCode = ScriptEntry(steps: [.code(source: inlineSource), .menuItem(path: ["File"])], name: "Legacy")
check(!mixedCode.scriptsOnly, "legacy steps remain blocked with inline code")
var inlineLibrary = Library()
inlineLibrary.scripts = [inlineEntry]
check(inlineLibrary.activeHotkeys().winners.count == 1, "inline code supports hotkeys")
let inlineAppleScript = ScriptText.appleScript(appPath: "/Applications/Illustrator.app", code: inlineSource)
check(inlineAppleScript.contains("do javascript " + ScriptText.quote(inlineSource)), "code is quoted as text instead of a file")

// SCRIPTMETA: only a closed local block with Script-ID; description content is not metadata.
let metaSource = "/*\nSCRIPTMETA-BEGIN\nScript-ID=test.example\nVersion=1.2.3\nDescription-BEGIN\nVersion=999\nDescription-END\nSCRIPTMETA-END\n*/"
check(ScriptMetadata.version(in: metaSource) == "1.2.3", "metadata ignores version inside description")
check(ScriptMetadata.version(in: metaSource.replacingOccurrences(of: "\n", with: "\r\n")) == "1.2.3", "metadata CRLF")
check(ScriptMetadata.version(in: metaSource.replacingOccurrences(of: "SCRIPTMETA-END", with: "")) == nil, "unterminated metadata ignored")
check(ScriptMetadata.version(in: "// Version=2.0\nvar VERSION = '3.0';") == nil, "no guessed version")
check(ScriptMetadata.version(in: metaSource.replacingOccurrences(of: "Script-ID=test.example", with: "")) == nil, "metadata requires identifier")
check(ScriptMetadata.version(in: metaSource.replacingOccurrences(of: "SCRIPTMETA-BEGIN", with: "SCRIPTMETA-DIST-BEGIN")) == nil, "distribution block is not local version")
let metaFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jsx")
try metaSource.write(to: metaFile, atomically: true, encoding: .utf8)
check(ScriptMetadata.version(at: metaFile.path) == "1.2.3", "metadata file read")
try FileManager.default.removeItem(at: metaFile)
var paletteLibrary = Library()
paletteLibrary.categories = ["Demo"]
paletteLibrary.paletteHotkeys = ["Demo": key]
check(try JSONDecoder().decode(Library.self, from: JSONEncoder().encode(paletteLibrary)) == paletteLibrary, "palette keys JSON round trip")
paletteLibrary.renameCategory("Demo", to: "Renamed")
check(paletteLibrary.paletteHotkeys?["Demo"] == nil && paletteLibrary.paletteHotkeys?["Renamed"] == key, "category rename migrates key")
paletteLibrary.deleteCategory("Renamed")
check(paletteLibrary.paletteHotkeys?["Renamed"] == nil, "category deletion removes key")

let infoSource = "SCRIPTMETA-BEGIN\nScript-ID=example.info\nAuthor=Test Author\nMeta-URL=https://example.com/script?a=b\nDescription-BEGIN\nFirst line\n\nSecond line\nVersion=not metadata\nDescription-END\nSCRIPTMETA-END"
let parsedInfo = ScriptMetadata.parse(infoSource)
check(parsedInfo?.fields["Author"] == "Test Author", "author parsed without version")
check(parsedInfo?.summary == "First line\n\nSecond line\nVersion=not metadata", "overview preserves paragraphs")
check(parsedInfo?.url?.absoluteString == "https://example.com/script?a=b", "URL first equals separator")
check(ScriptMetadata.parse(infoSource.replacingOccurrences(of: "https://example.com/script?a=b", with: "javascript:alert(1)"))?.url == nil, "only web links permitted")
var noteEntry = ScriptEntry(path: "/test.jsx")
noteEntry.notes = "Personal memo\n日本語"
check(try JSONDecoder().decode(ScriptEntry.self, from: JSONEncoder().encode(noteEntry)).notes == noteEntry.notes, "memo JSON persistence")
let readmeDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: readmeDir, withIntermediateDirectories: true)
try "shared".write(to: readmeDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
let specificReadme = readmeDir.appendingPathComponent("Example.md")
try "specific".write(to: specificReadme, atomically: true, encoding: .utf8)
check(ScriptMetadata.readme(for: readmeDir.appendingPathComponent("Example.jsx").path) == specificReadme, "script README preferred over folder README")
try FileManager.default.removeItem(at: readmeDir)

let variableSource = #"""
var SCRIPT_NAME = "InsertNewTextJ"; /* スクリプト名 */
var SCRIPT_VERSION = "v1.1.1";
var SCRIPT_AUTHOR = "Masahiro Takano (@swwwitch)";
var SCRIPT_RELEASED = "2025-04-01";
var SCRIPT_UPDATED = "2026-10-04";
var SCRIPT_README_JA = "https://github.com/swwwitch/illustrator-scripts/blob/master/readme-ja/InsertNewTextJ.md";
var SCRIPT_README_EN = "https://github.com/swwwitch/illustrator-scripts/blob/master/readme-en/InsertNewTextJ.md";
var SCRIPT_ARTICLE_URL = "https://note.com/dtp_tranist/n/n509eb6aa0a19";
"""#
let variableInfo = ScriptMetadata.parse(variableSource)
check(variableInfo?.fields["Name"] == "InsertNewTextJ" && variableInfo?.version == "v1.1.1", "SCRIPT_NAME/VERSION literals parsed")
check(variableInfo?.fields["Author"] == "Masahiro Takano (@swwwitch)", "SCRIPT_AUTHOR literal parsed")
check(variableInfo?.fields["First-Release-Date"] == "2025-04-01" && variableInfo?.fields["Updated-Date"] == "2026-10-04", "initial release and updated date are distinct")
check(variableInfo?.readmeURL(language: "ja-JP")?.path.contains("readme-ja") == true, "Japanese README selected")
check(variableInfo?.readmeURL(language: "en-US")?.path.contains("readme-en") == true, "English README selected")
check(variableInfo?.url?.host == "note.com", "article URL parsed")
check(ScriptMetadata.parse(metaSource + "\n" + variableSource)?.version == "1.2.3", "SCRIPTMETA takes priority")
check(ScriptMetadata.parse(#"/* var SCRIPT_VERSION = "9"; */"#) == nil, "commented assignments ignored")
check(ScriptMetadata.parse(#"var sample = 'var SCRIPT_VERSION = "9";';"#) == nil, "quoted assignments ignored")
check(ScriptMetadata.parse(#"var SCRIPT_VERSION = computeVersion();"#) == nil, "computed metadata never evaluated")
check(ScriptMetadata.parse(#"var SCRIPT_VERSION = "v" + version;"#) == nil, "expressions not mistaken for literal version")
check(ScriptMetadata.parse(#"const SCRIPT_AUTHOR = 'Takano\u0020Masahiro';"#)?.fields["Author"] == "Takano Masahiro", "single quotes and Unicode escape")
check(ScriptMetadata.parse(#"let SCRIPT_AUTHOR = "Takano\"M";"#)?.fields["Author"] == "Takano\"M", "escaped quote decoded")

// Selected sorting keeps unselected slots and category membership, and persists palette settings.
var selectionSort = Library()
_ = selectionSort.add(paths: ["/s/Z.jsx", "/s/Keep.jsx", "/s/A.jsx"])
let selectedIDs = Set([selectionSort.scripts[0].id, selectionSort.scripts[2].id])
selectionSort.sortSelected(selectedIDs, by: .name) { _ in "A" }
check(selectionSort.scripts.map(\.name) == ["A", "Keep", "Z"], "selected sort preserves unselected position")
for _ in 0..<9 { selectionSort.scripts[2].recordRun() }
selectionSort.sortSelected(selectedIDs, by: .uses) { _ in "A" }
check(selectionSort.scripts.map(\.name) == ["Z", "Keep", "A"], "usage sort is descending")
selectionSort.paletteEnabled = ["Demo": false]
selectionSort.paletteModes = ["Demo": 2]
selectionSort.addCategory("Demo")
selectionSort.renameCategory("Demo", to: "Renamed")
check(selectionSort.paletteModes?["Renamed"] == 2 && !selectionSort.allowsPalette("Renamed"), "palette options follow rename")
let restoredOptions = try JSONDecoder().decode(Library.self, from: JSONEncoder().encode(selectionSort))
check(restoredOptions == selectionSort, "palette settings persist")
selectionSort.deleteCategory("Renamed")
check(selectionSort.paletteModes?["Renamed"] == nil, "palette options removed with category")


// Code links must refer to this exact script, with no ambiguous candidate.
let codeReadme = "[source](https://github.com/example/scripts/blob/main/Foo.jsx) [other](https://github.com/example/scripts/blob/main/Other.jsx)"
check(ScriptMetadata.codeURL(in: codeReadme, scriptFilename: "Foo.jsx")?.path == "/example/scripts/blob/main/Foo.jsx", "README exact script")
check(ScriptMetadata.codeURL(in: codeReadme, scriptFilename: "Missing.jsx") == nil, "unrelated links never guessed")
check(ScriptMetadata.codeURL(in: codeReadme + " https://github.com/other/repo/blob/main/Foo.jsx", scriptFilename: "Foo.jsx") == nil, "ambiguous links rejected")
let readmeBase = URL(string: "https://github.com/example/scripts/blob/main/docs/README.md")!
check(ScriptMetadata.codeURL(in: "[code](../Foo.jsx)", scriptFilename: "Foo.jsx", relativeTo: readmeBase)?.path == "/example/scripts/blob/main/Foo.jsx", "relative code link")
check(ScriptMetadata.codeURL(in: "[unsafe](javascript:Foo.jsx)", scriptFilename: "Foo.jsx") == nil, "non-web link rejected")
check(ScriptMetadata.codeURL(in: codeReadme + " https://raw.githubusercontent.com/example/scripts/main/Foo.jsx", scriptFilename: "Foo.jsx") != nil, "raw and blob deduplicated")
check(ScriptMetadata.readmeRequestURL(readmeBase)?.host == "raw.githubusercontent.com", "raw README text")
check(ScriptMetadata.parse(#"var SCRIPT_CODE_URL = "https://github.com/example/scripts/blob/main/Foo.jsx";"#)?.codeURL?.host == "github.com", "code constant")
check(ScriptMetadata.Info(fields: ["Code-URL": "javascript:alert(1)"]).codeURL == nil, "unsafe field refused")
var coloredEntry = ScriptEntry(path: "/s/Foo.jsx")
coloredEntry.tagColor = .purple
let coloredRestored = try JSONDecoder().decode(ScriptEntry.self, from: JSONEncoder().encode(coloredEntry))
check(coloredRestored.tagColor == .purple && coloredRestored.id == coloredEntry.id, "color persistence preserves identity")
let legacyColorLibrary = try JSONDecoder().decode(Library.self, from: Data(old.utf8))
check(legacyColorLibrary.scripts.first?.tagColor == nil, "legacy has no color")


let watchRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
let nested = watchRoot.appendingPathComponent("One/Two", isDirectory: true)
try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
let watchedFile = nested.appendingPathComponent("Watched.jsx")
try "// test".write(to: watchedFile, atomically: true, encoding: .utf8)
try "// skip".write(to: nested.appendingPathComponent(".Hidden.jsx"), atomically: true, encoding: .utf8)
try FileManager.default.createSymbolicLink(at: watchRoot.appendingPathComponent("Loop"), withDestinationURL: watchRoot)
let scan = WatchedScripts.scan([watchRoot.path, watchRoot.path])
check(scan.files.count == 1 && scan.files[watchedFile.path] == ["One", "Two"], "recursive folder tags, hidden and symlink skipped")
var watchedLibrary = Library()
check(WatchedScripts.merge(scan, into: &watchedLibrary) == 1, "initial import")
watchedLibrary.scripts[0].name = "Custom"
watchedLibrary.scripts[0].tags = ["Manual"]
watchedLibrary.scripts[0].hotkey = key
check(WatchedScripts.merge(scan, into: &watchedLibrary) == 0 && watchedLibrary.scripts[0].name == "Custom" && watchedLibrary.scripts[0].hotkey == key, "repeat import preserves edits and avoids duplicates")
check(Set(watchedLibrary.scripts[0].allTags) == ["Manual", "One", "Two"], "manual and folder tags combined")
let restoredWatch = try JSONDecoder().decode(Library.self, from: JSONEncoder().encode(watchedLibrary))
check(restoredWatch == watchedLibrary, "tag persistence")
var ignoredLibrary = Library()
check(WatchedScripts.merge(scan, into: &ignoredLibrary, ignoring: [watchedFile.path]) == 0, "deleted items not reimported")

let excludedFolder = nested.appendingPathComponent("BACKUP", isDirectory: true)
try FileManager.default.createDirectory(at: excludedFolder, withIntermediateDirectories: true)
try "// excluded".write(to: excludedFolder.appendingPathComponent("Ignored.jsx"), atomically: true, encoding: .utf8)
let excludedScan = WatchedScripts.scan([watchRoot.path], excluding: ["backup", "single-function"])
check(excludedScan.files.count == 1 && !excludedScan.groups.contains("One/Two/BACKUP"), "excludes folder subtree at any depth without case sensitivity")
var groupedLibrary = Library()
WatchedScripts.merge(excludedScan, into: &groupedLibrary, autoGroup: true)
check(groupedLibrary.scripts.first?.category == "One/Two" && groupedLibrary.categoryList.contains("One"), "hierarchy groups and script assignment")
groupedLibrary.scripts[0].category = "Manual"
WatchedScripts.merge(excludedScan, into: &groupedLibrary, autoGroup: true)
check(groupedLibrary.scripts[0].category == "Manual", "manual classification preserved")
var ungroupedLibrary = Library()
WatchedScripts.merge(excludedScan, into: &ungroupedLibrary)
check(ungroupedLibrary.categoryList.isEmpty && ungroupedLibrary.scripts.first?.category == nil, "default grouping remains off")
try FileManager.default.removeItem(at: excludedFolder)

try FileManager.default.removeItem(at: watchedFile)
WatchedScripts.merge(WatchedScripts.scan([watchRoot.path]), into: &watchedLibrary)
check(watchedLibrary.scripts.count == 1, "missing original keeps item and metadata")
try FileManager.default.removeItem(at: watchRoot)


let namedFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jsx")
try #"var SCRIPT_DESCRIPTION_JA = "Japanese item";"#.write(to: namedFile, atomically: true, encoding: .utf8)
var autoEntry = ScriptEntry(path: namedFile.path)
check(autoEntry.name == "Japanese item", "description constant supplies item name")
try #"var SCRIPT_DESCRIPTION_JA = "Updated description";"#.write(to: namedFile, atomically: true, encoding: .utf8)
autoEntry.refreshAutomaticName()
check(autoEntry.name == "Updated description", "automatic name refresh")
autoEntry.name = "User custom name"
autoEntry.refreshAutomaticName()
check(autoEntry.name == "User custom name", "manual name survives metadata refresh")
var legacyName = ScriptEntry(path: namedFile.path, name: "Legacy custom")
legacyName.refreshAutomaticName()
check(legacyName.name == "Legacy custom", "legacy custom name preserved")
try FileManager.default.removeItem(at: namedFile)
var boundary = ScriptEntry(steps: [], name: "Section", enabled: false); boundary.divider = true
let z = ScriptEntry(path: "/test/Z.jsx"), a = ScriptEntry(path: "/test/A.jsx")
check(SortOrder.name.sorted([z, boundary, a]) { _ in "" }.map(\.name) == ["Z", "Section", "A"], "divider blocks display sorting across sections")
var dividedLibrary = Library(); dividedLibrary.scripts = [z, boundary, a]
dividedLibrary.sortSelected(Set([z.id, a.id]), by: .name) { _ in "" }
check(dividedLibrary.scripts.map(\.name) == ["Z", "Section", "A"], "divider blocks selected sorting across sections")
check(dividedLibrary.byUse.count == 2 && !boundary.isAvailable, "divider excluded from stats and execution")
let sr1 = StatisticsRow(rank: 1, id: "a", name: "Z", category: "B", scriptName: "B.jsx", path: "/b", uses: 12, last: nil, key: "T")
let sr2 = StatisticsRow(rank: 2, id: "b", name: "A", category: "A", scriptName: "A.jsx", path: "/a", uses: 2, last: nil, key: "A")
check(StatisticsRow.sorted([sr1, sr2], by: .uses, ascending: true).map(\.id) == ["b", "a"], "statistics numeric sorting")
check(StatisticsRow.sorted([sr1, sr2], by: .category, ascending: false).map(\.id) == ["a", "b"], "statistics descending category sorting")


let migrationFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jsx")
try #"var SCRIPT_DESCRIPTION_JA = "Description for existing item";"#.write(to: migrationFile, atomically: true, encoding: .utf8)
let basename = migrationFile.deletingPathExtension().lastPathComponent
var migrated = ScriptEntry(path: migrationFile.path, name: basename)
migrated.userRenamed = nil; migrated.automaticName = nil
migrated.refreshAutomaticName()
check(migrated.name == "Description for existing item", "legacy filename migrates to description")
var explicitFilename = ScriptEntry(path: migrationFile.path, name: basename)
explicitFilename.refreshAutomaticName()
check(explicitFilename.name == basename, "explicit user name equal to filename remains")
var legacyCustom = ScriptEntry(path: migrationFile.path, name: "Custom display")
legacyCustom.userRenamed = nil; legacyCustom.refreshAutomaticName()
check(legacyCustom.name == "Custom display", "legacy custom name never overwritten")
var scoped = Library()
var targetEntry = ScriptEntry(path: migrationFile.path, name: basename)
targetEntry.userRenamed = nil
var outsideEntry = targetEntry; outsideEntry.id = "outside"
scoped.scripts = [targetEntry, outsideEntry]
scoped.refreshAutomaticNames(ids: [targetEntry.id])
check(scoped.scripts[0].name == "Description for existing item" && scoped.scripts[1].name == basename, "scope limits name updates")
let nameRoundTrip = try JSONDecoder().decode(ScriptEntry.self, from: JSONEncoder().encode(explicitFilename))
check(nameRoundTrip.userRenamed == true, "manual-name marker persists")
try FileManager.default.removeItem(at: migrationFile)


let searchable = ScriptEntry(path: "/s/InvoiceFromClipboard.jsx", name: "Japanese display")
var searchDivider = ScriptEntry(steps: [], name: "Invoice section", enabled: false); searchDivider.divider = true
let directSearch = ScriptEntry(steps: [.code(source: "alert(1)")], name: "Other")
check(PaletteSearch.filter([searchable, searchDivider, directSearch], query: "invoice").map(\.id) == [searchable.id], "palette searches filename and excludes divider")
check(PaletteSearch.filter([searchable], query: "JAPANESE").count == 1, "palette name search ignores case")
check(PaletteSearch.filter([searchable, searchDivider], query: "  ").count == 2, "empty search restores divider")
check(PaletteSearch.filter([directSearch], query: "missing").isEmpty, "no invented filename for inline code")

// Components: migration preserves action identity/settings, shares definitions and order.
var componentMigration = try! JSONDecoder().decode(Library.self, from: Data(old.utf8))
let preserved = componentMigration.scripts[0]
componentMigration.scripts.append(ScriptEntry(steps: [.script(path: "/s/A.jsx"), .code(source: "alert(1)")], name: "combo"))
componentMigration.reconcileComponents()
check(componentMigration.components?.count == 2 && componentMigration.scripts[0].id == preserved.id && componentMigration.scripts[0].name == preserved.name, "migration preserves action and shares component")
check(componentMigration.scripts[0].componentIDs?.first == componentMigration.scripts[1].componentIDs?.first, "shared references")
let previous = componentMigration
componentMigration.components![0].step = .script(path: "/new/A.jsx")
componentMigration.reconcileComponents(previous: previous)
check(componentMigration.scripts.allSatisfy { $0.actions.first == .script(path: "/new/A.jsx") }, "shared edit propagates to every action")
let beforeMove = componentMigration
componentMigration.scripts[1].actions.reverse()
componentMigration.reconcileComponents(previous: beforeMove)
check(componentMigration.scripts[1].actions.first == .code(source: "alert(1)") && componentMigration.components?.count == 2, "order edit reuses components")
var round = try! JSONDecoder().decode(Library.self, from: JSONEncoder().encode(componentMigration))
round.reconcileComponents()
check(round == componentMigration, "component migration idempotent and JSON round trip")
round.scripts[0].componentIDs = ["absent"]
round.reconcileComponents()
check(!round.scripts[0].scriptsOnly, "missing reference blocks whole action")
var recent = Library()
for i in 0..<12 { var entry = ScriptEntry(path: "/\(i).jsx"); entry.recordRun(at: Date(timeIntervalSince1970: Double(i))); recent.scripts.append(entry) }
check(recent.recentlyUsed.count == 10 && recent.recentlyUsed.first?.path == "/11.jsx", "latest ten distinct actions")
recent.scripts[0].recordRun(at: Date(timeIntervalSince1970: 20))
check(recent.recentlyUsed.first?.path == "/0.jsx" && Set(recent.recentlyUsed.map(\.id)).count == 10, "reuse moves to top without duplicate")
let legacyFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".json")
try! Data(old.utf8).write(to: legacyFile)
let migrationResult = Library.load(from: legacyFile)
let backupFile = legacyFile.deletingPathExtension().appendingPathExtension("pre-components.json")
check((try? Data(contentsOf: backupFile)) == Data(old.utf8) && migrationResult.version == 2, "migration backs up exact original bytes")
try? FileManager.default.removeItem(at: legacyFile); try? FileManager.default.removeItem(at: backupFile)

// Exercise the same writeback observer as AppModel, including attaching an identical step twice.
struct ObservedLibrary {
    var library: Library { didSet { library.reconcileComponents(previous: oldValue) } }
}
var observed = ObservedLibrary(library: componentMigration)
let sharedID = observed.library.scripts[0].componentIDs![0]
observed.library.scripts[0].componentIDs!.append(sharedID)
check(observed.library.scripts[0].actions.count == 2, "observer resolves repeated component reference")
let sharedIndex = observed.library.components!.firstIndex { $0.id == sharedID }!
observed.library.components![sharedIndex].step = .code(source: "changed")
check(observed.library.scripts[0].actions == [.code(source: "changed"), .code(source: "changed")], "observer propagates shared component mutation")
observed.library.scripts[0].actions.removeLast()
check(observed.library.scripts[0].componentIDs?.count == 1, "observer detaches without deleting component")
if failures == 0 { print("PASS: entries, adding, hotkeys, saving, AppleScript") } else { print("\(failures) failure(s)"); exit(1) }
