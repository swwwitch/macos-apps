import Foundation
import JavaScriptCore

var failures = 0
func check(_ condition: Bool, _ message: String) {
    if condition { print("PASS:", message) } else { failures += 1; print("FAIL:", message) }
}

let ids = Catalog.all.map(\.id)
check(Set(ids).count == ids.count, "command ids are unique")
check(Catalog.all.count == 33, "33 commands from the original palette")
let keys = Catalog.all.compactMap(\.defaultKey).map { "\($0.code)-\($0.modifiers)" }
check(Set(keys).count == keys.count && keys.count == 17, "17 default keys, none twice")
check(PaletteSection.allCases.allSatisfy { !Catalog.commands(in: $0).isEmpty }, "every section has commands")
check(Catalog.command("removeItem")?.defaultKey == DefaultKey(code: 27, modifiers: 0), "Remove Item keeps the bare - key")

// Every built-in script compiles (ExtendScript is ES3; JavaScriptCore checks the syntax).
let context = JSContext()!
for command in Catalog.all {
    for dialog in [false, true] {
        guard let source = ScriptBuilder.source(for: command, values: [:], dialog: dialog) else {
            check(command.scriptPath != nil, "\(command.id): only script files have no built-in source"); continue
        }
        context.exception = nil
        context.setObject(source, forKeyedSubscript: "src" as NSString)
        context.evaluateScript("new Function(src)")
        check(context.exception == nil, "\(command.id)\(dialog ? " (dialog)" : ""): script compiles \(context.exception?.toString() ?? "")")
        check(source.contains("return \"OK\";") && source.contains("ERR:nosel"), "\(command.id): guarded and reports OK")
    }
}

let shadow = ScriptBuilder.source(for: Catalog.command("dropShadow")!, values: ["opacity": 30, "offsetX": 2, "offsetY": 2, "blur": 2])!
check(shadow.contains("R opac 0.3 ") && shadow.contains("U(2)") && shadow.contains("Adobe Drop Shadow"), "drop shadow: opacity 0–1, lengths in document units")
check(ScriptBuilder.source(for: Catalog.command("dropShadow")!, values: [:], dialog: true)!.contains("Live Adobe Drop Shadow"), "Option opens the Drop Shadow dialog box")
let zigzag = ScriptBuilder.source(for: Catalog.command("zigzagFlat")!, values: [:])!
check(zigzag.contains("R ridges 0 R roundness 0"), "Zig Zag 0-0 uses the defaults")
check(ScriptBuilder.source(for: Catalog.command("roughen")!, values: [:])!.contains("R dtal 9 R roundness 1"), "Roughen: detail 9, smooth")
check(ScriptBuilder.source(for: Catalog.command("offsetPath")!, values: ["join": 0])!.contains("I jntp 0"), "Offset Path join value")
check(ScriptBuilder.source(for: Catalog.command("pfCrop")!, values: [:])!.contains("app.executeMenuCommand(\"Live Pathfinder Crop\")"), "Pathfinder Crop menu command")
check(ScriptBuilder.source(for: Catalog.command("knockout")!, values: [:])!.contains("app.doScript(\"グループの抜き\", \"S2A\", false)"), "Knockout plays the user's action")
check(ScriptBuilder.number(0.3) == "0.3" && ScriptBuilder.number(2) == "2" && ScriptBuilder.number(-1.25) == "-1.25", "numbers without exponent")

// Temporary actions match Illustrator's .aia text.
let clear = TempAction.appearance(value: 6, name: "アピアランスを消去").source
check(clear.contains("/internalName (ai_plugin_appearance)") && clear.contains("/value 6") && clear.contains("e382a2e38394e382a2e383a9e383b3e382b9e38292e6b688e58ebb"), "Clear Appearance action")
check(clear.contains("/name [ 18\n\t5665637" ) || clear.hasPrefix("/version 3\n/name [ \(TempAction.setName.utf8.count)\n\t\(TempAction.hex(TempAction.setName))\n]"), "set name header")
check(TempAction.makeCompoundShape.source.contains("/key 1835101029") && TempAction.releaseCompoundShape.source.contains("/internalName (ai_release_compound_shape)"), "compound shape actions")
check(TempAction.hex("項目を削除") == "e9a085e79baee38292e5898ae999a4", "UTF-8 hex like the Actions panel")

check(CommandRunner.outcome("OK") == .success && CommandRunner.outcome("ERR:nosel\n") == .refused(.nosel) && CommandRunner.outcome("") == .success, "results from Illustrator")
check(OSAScript.cleanError("-: execution error: Adobe Illustratorでエラーが起きました：Error 21: undefined is not an object (-2700)") == "Error 21: undefined is not an object", "error text trimmed")

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
