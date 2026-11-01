import Foundation
import JavaScriptCore

var failures = 0
func check(_ condition: Bool, _ message: String) {
    if condition { print("PASS:", message) } else { failures += 1; print("FAIL:", message) }
}

let ids = Catalog.all.map(\.id)
check(Set(ids).count == ids.count, "command ids are unique")
check(Catalog.all.count == 49, "49 commands from the original palette")
let keys = Catalog.all.compactMap(\.defaultKey).map { "\($0.code)-\($0.modifiers)" }
check(Set(keys).count == keys.count && keys.count == 21, "21 default keys, none twice")
check(PaletteSection.allCases.allSatisfy { !Catalog.commands(in: $0).isEmpty }, "every section has commands")
check(Catalog.command("removeItem")?.defaultKey == DefaultKey(code: 27, modifiers: 0), "Remove Item keeps the bare - key")

func recorded(_ name: String) -> String? { try? String(contentsOfFile: "Resources/Actions/\(name).aia", encoding: .utf8) }
for name in ["strokeRound1pt"] { check(recorded(name) != nil, "bundled action \(name)") }

// Every built-in script compiles (ExtendScript is ES3; JavaScriptCore checks the syntax).
let context = JSContext()!
for command in Catalog.all {
    for dialog in [false, true] {
        guard let source = ScriptBuilder.source(for: command, values: [:], dialog: dialog, recorded: recorded) else {
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
let stroke = TempAction.renamed(recorded("strokeRound1pt")!)
check(stroke.hasPrefix("/version 3\n/name [ \(TempAction.setName.utf8.count)\n\t\(TempAction.hex(TempAction.setName))\n]") && stroke.contains("\t/name [ 8\n\t\t\(TempAction.hex(TempAction.actionName))\n\t]") && !stroke.contains("e4b8b8e59e8be7b79ae7abafe381ab") && stroke.contains("/eventCount 1"), "recorded action renamed to VectorFX's set, events kept")
let open = ScriptBuilder.source(for: Catalog.command("openPath")!, values: [:], recorded: recorded)!
check(open.contains("I Command 6") && open.contains("B ExtractUnpainted 0") && !open.contains("Live Pathfinder Outline") && open.contains("ai_plugin_setStroke"), "Open path: Outline effect keeps unpainted artwork, 1 pt round stroke")
check(open.range(of: "Adobe Transform")!.lowerBound < open.range(of: "Adobe Pathfinder")!.lowerBound, "Transform is applied before Outline (stays above it)")
check(ScriptBuilder.source(for: Catalog.command("roundedRectangle")!, values: [:])!.contains("I Shape 1") && ScriptBuilder.source(for: Catalog.command("ellipse")!, values: [:])!.contains("I Shape 2"), "rounded rectangle and ellipse shapes")
check(TempAction.hex("項目を削除") == "e9a085e79baee38292e5898ae999a4", "UTF-8 hex like the Actions panel")

check(CommandRunner.outcome("OK") == .success && CommandRunner.outcome("ERR:nosel\n") == .refused(.nosel) && CommandRunner.outcome("") == .success, "results from Illustrator")
check(OSAScript.cleanError("-: execution error: Adobe Illustratorでエラーが起きました：Error 21: undefined is not an object (-2700)") == "Error 21: undefined is not an object", "error text trimmed")

// 「しくみ」 steps.
let shadowSteps = Logic.steps(for: Catalog.command("dropShadow")!, values: [:], recorded: recorded)
check(shadowSteps.count == 5 && EffectKind.dropShadow.liveEffectName == "Adobe Drop Shadow", "drop shadow: check, units, effect, Option, send")
check(Logic.events(in: recorded("strokeRound1pt")!) == ["線を設定"] && Logic.events(in: TempAction.appearance(value: 6, name: "アピアランスを消去").source) == ["アピアランス：アピアランスを消去"], "action events are listed by name")
check(Catalog.all.allSatisfy { !Logic.steps(for: $0, values: [:], recorded: recorded).isEmpty }, "every command has steps")
check(Catalog.command("roundCorners")!.opensDialog && Catalog.command("freeDistortScript")!.opensDialog && !Catalog.command("pfAdd")!.opensDialog && !Catalog.command("dropShadow")!.opensDialog, "… only for commands that open a dialog box")

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
