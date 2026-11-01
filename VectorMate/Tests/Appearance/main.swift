import Foundation
import JavaScriptCore
func L(_ key: String) -> String { key }
let commands = Catalog.all
precondition(commands.count == 49 && Set(commands.map(\.id)).count == 49)
let context = JSContext()!
let action = try! String(contentsOfFile: "Resources/Actions/strokeRound1pt.aia", encoding: .utf8)
var scripts = 0
for command in commands {
    for dialog in [false, true] {
        guard let source = ScriptBuilder.source(for: command, values: [:], dialog: dialog,
                                                recorded: { _ in action }, resourceFile: { _ in "/tmp/openpath.ai" }) else { continue }
        context.exception = nil
        context.setObject(source, forKeyedSubscript: "src" as NSString)
        context.evaluateScript("new Function(src)")
        precondition(context.exception == nil, command.id)
        scripts += 1
    }
}
// The new sign-inversion key must not shadow an appearance command's default.
precondition(!commands.compactMap(\.defaultKey).contains { $0.code == 27 && $0.modifiers == DefaultKey.control })
print("Appearance: 49 unique commands, \(scripts) generated scripts parsed; Control-minus is free")
