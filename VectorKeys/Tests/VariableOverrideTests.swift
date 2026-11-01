import Foundation
import JavaScriptCore

@main struct VariableOverrideTests {
    static func main() throws {
        let settings = #"""
        // var SW_COMMENT = 99;
        var text = "var SW_TEXT = 99;";
        var SW_STEP_SIGN = 1;
        var SW_STEP_MULTIPLIER = 10;
        var SW_LABEL = '日本語\n\x41\u0042';
        var SW_ENABLED = false;
        var SW_EMPTY = "";
        var INTERNAL = 1;
        var SW_EXPRESSION = 1 + 2;
        var SW_DUPLICATE = 1;
        var SW_DUPLICATE = 2;
        var SW_MULTI = 1, OTHER = 2;
        """#
        let settingsFound = VariableOverrides.candidates(in: settings)
        precondition(settingsFound.map(\.name) == ["SW_STEP_SIGN", "SW_STEP_MULTIPLIER", "SW_LABEL", "SW_ENABLED", "SW_EMPTY"])
        precondition(settingsFound.map(\.value) == ["1", "10", "日本語\nAB", "false", ""])
        precondition(VariableOverrides.candidates(in: "#include 'a.jsx'\nvar SW_X = 1;", file: true).isEmpty)
        precondition(VariableOverrides.candidates(for: .code(source: settings)) == settingsFound)
        let source = """
        // var STEP_SIGN = 90;
        var mention = "var STEP_MULTIPLIER = 90;";
        var pattern = /var STEP_SIGN = 90;/;
        (function () {
            var STEP_SIGN = 1; /* keep comment */
            var STEP_MULTIPLIER = 1;
            return STEP_SIGN * STEP_MULTIPLIER;
        })();
        """
        let changed = try VariableOverrides.apply(to: source, names: ["STEP_SIGN", "STEP_MULTIPLIER"], values: ["-1", "10"])
        precondition(changed.contains("var STEP_SIGN = -1; /* keep comment */"))
        precondition(changed.contains("var STEP_MULTIPLIER = 10;"))
        precondition(changed.contains("// var STEP_SIGN = 90;") && changed.contains("/var STEP_SIGN = 90;/"))
        let context = JSContext()!
        precondition(context.evaluateScript(changed)!.toInt32() == -10 && context.exception == nil)
        func reject(_ code: String, _ names: [String] = ["X"], _ values: [String] = ["2"]) {
            do { _ = try VariableOverrides.apply(to: code, names: names, values: values); preconditionFailure("accepted unsupported source") }
            catch is VariableOverrides.Failure {} catch { preconditionFailure("unexpected error") }
        }
        reject("// var X = 1;")
        reject("var text = 'var X = 1;';")
        reject("var X = 1;\nvar X = 2;")
        reject("var X = 1;", ["X", "X"], ["2", "3"])
        reject("var X = 1;", ["X;alert(1)"], ["2"])
        reject("var X = 1;", ["X"], ["2;alert(1)"])
        reject("var X = 1;", ["X"], ["NaN"])
        reject("var X = 1;", ["X"], ["010"])
        reject("var X = 1;", ["X"], ["1e999"])
        reject("var X = 1 + 2;")
        reject("var X = readValue();")
        reject("var X = 1, Y = 2;")
        reject("var X = 1", ["X"], ["2"])
        reject("const X = 1;")
        reject("var X = true;", ["X"], ["1"])
        reject("var X = 1;", ["X"], [""])
        let bool = try VariableOverrides.apply(to: "var X = true;\nX;", names: ["X"], values: ["false"])
        precondition(context.evaluateScript(bool)!.toBool() == false)
        let rawString = "日本語\n\"; throw Error('injected'); //\\🙂\u{2028}"
        let string = try VariableOverrides.apply(to: "var X = 'old';\nX;", names: ["X"], values: [rawString])
        precondition(context.evaluateScript(string)!.toString() == rawString && context.exception == nil)
        let noChanges = try VariableOverrides.apply(to: source, names: ["", "", ""], values: ["a", "b", "c"])
        precondition(noChanges == source)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let file = temp.appendingPathComponent("sample.jsx")
        let original = Data(source.utf8); try original.write(to: file)
        var entry = ScriptEntry(steps: [.script(path: file.path), .code(source: source)], name: "Named")
        for index in 0..<2 {
            entry.setArgument("-1", at: index, slot: 0); entry.setVariableName("STEP_SIGN", at: index, slot: 0)
            entry.setArgument("10", at: index, slot: 1); entry.setVariableName("STEP_MULTIPLIER", at: index, slot: 1)
            entry.setArgument("positional", at: index, slot: 2)
            let prepared = try ScriptRunner.prepare(entry, at: index, appPath: "/Illustrator.app")
            precondition(prepared.contains(ScriptText.quote("-1")) == false) // Named numeric values are code, not positional strings.
            precondition(prepared.contains(ScriptText.argumentClause(["", "", "positional"])))
            precondition(prepared.contains(ScriptText.quote(changed)))
        }
        let after = try Data(contentsOf: file)
        precondition(after == original, "original file is never modified")
        for dependent in ["#include 'helper.jsx'\nvar X = 1;", "var X = 1;\n$.fileName;", "var X = 1;\n$.evalFile('a.jsx');"] {
            do { _ = try VariableOverrides.apply(to: dependent, names: ["X"], values: ["2"], file: true); preconditionFailure("file context ignored") }
            catch is VariableOverrides.Failure {}
        }
        var library = Library(); library.components = [Component(name: "One", step: .code(source: source))]; library.componentCategories = []
        entry.componentIDs = [library.components![0].id, library.components![0].id]
        library.scripts = [entry]; library.reconcileComponents()
        library.scripts[0].setVariableName("STEP_MULTIPLIER", at: 1, slot: 0)
        library.moveComponentReference(actionID: entry.id, from: 1, by: -1)
        precondition(library.scripts[0].variableNames(at: 0)[0] == "STEP_MULTIPLIER")
        library.removeComponentReference(actionID: entry.id, at: 0)
        precondition(library.scripts[0].variableNames(at: 0)[0] == "STEP_SIGN")
        library.reconcileComponents() // Production LibraryStore resolves cached steps after a reference edit.
        let saved = temp.appendingPathComponent("Scripts.json")
        try library.save(to: saved)
        precondition(Library.load(from: saved) == library)
        print("PASS: named overrides: literals, scopes, comments/strings/regex, invalid inputs, independent invocations, order/remove/save, file preservation and both runner paths")
    }
}
