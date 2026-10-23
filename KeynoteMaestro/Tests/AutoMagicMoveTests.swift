import AppKit

/// Execute the exact production AppleScript helpers without Apple events or a Keynote document.
func verifyAutoMagicMove() {
    func evaluate(_ expression: String) -> NSAppleEventDescriptor {
        let source = "return " + expression + "\n" + AutoMagicMoveScript.matchingHandlers
        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error), error == nil else {
            preconditionFailure("Auto Magic Move helper failed: \(String(describing: error))")
        }
        return result
    }
    func record(_ index: Int, _ signatures: [String], skipped: Bool = false) -> String {
        let values = signatures.map { "\"" + $0 + "\"" }.joined(separator: ",")
        return "{slideOrdinal:\(index), slideIsSkipped:\(skipped ? "true" : "false"), slideObjectSignatures:{\(values)}}"
    }
    func matches(_ records: [String], _ expected: [Int]) {
        let result = evaluate("my matchingSlideOrdinals({" + records.joined(separator: ",") + "})")
        let actual = result.numberOfItems == 0 ? [] : (1...result.numberOfItems).map { Int(result.atIndex($0)!.int32Value) }
        precondition(actual == expected, "Matching ordinals \(actual) != \(expected)")
    }
    matches([], [])
    matches([record(1, ["A"])], [])
    matches([record(1, ["A"]), record(2, ["A"])], [1])
    matches([record(1, ["A"]), record(2, ["A"]), record(3, ["A"])], [1, 2])
    matches([record(1, ["A"]), record(2, ["A"], skipped: true), record(3, ["A"])], [1])
    matches([record(1, ["A"], skipped: true), record(2, ["A"]), record(3, ["A"])], [2])
    matches([record(1, ["A"]), record(2, ["A"]), record(3, ["A"], skipped: true)], [1])
    matches([record(1, ["A"], skipped: true), record(2, ["A"], skipped: true)], [])
    matches([record(1, ["A"]), record(2, ["B"], skipped: true), record(3, ["C"], skipped: true), record(4, ["A"])], [1])
    matches([record(1, ["A"]), record(2, ["B"]), record(3, ["A"])], [])
    matches([record(1, ["A"]), record(2, ["B"]), record(3, ["B"]), record(4, ["A"])], [2])
    matches([record(1, []), record(2, [])], [])
    matches([record(1, ["A", "A"]), record(2, ["X", "A"])], [1])
    matches([record(1, ["A"]), record(2, ["a"])], [])
    matches([record(1, ["image|file|a.png"]), record(2, ["movie|file|a.png"])], [])
    for kind in ["image", "movie", "audio"] {
        let signature = evaluate("my signatureFromProperties(\"\(kind)\", \"same.dat\", \"ignored\", 10, 20)").stringValue
        precondition(signature == "\(kind)|file|same.dat")
    }
    precondition(evaluate("my signatureFromProperties(\"shape\", \"\", \"caption\", 10, 20)").stringValue == "shape|text|caption")
    precondition(evaluate("my signatureFromProperties(\"text\", \"\", \"caption\", 100, 200)").stringValue == "text|text|caption")
    precondition(evaluate("my signatureFromProperties(\"shape\", \"\", \"\", 99.6, 49.6)").stringValue == "shape|size|100x50")
    precondition(evaluate("my signatureFromProperties(\"shape\", \"\", \"\", 100.4, 50.4)").stringValue == "shape|size|100x50")
    precondition(evaluate("(my signatureFromProperties(\"text\", \"\", \"\", 100, 50)) is missing value").booleanValue)
    precondition(evaluate("(my signatureFromProperties(\"group\", \"\", \"caption\", 100, 50)) is missing value").booleanValue)
    precondition(evaluate("(my signatureFromProperties(\"shape\", \"\", \"100x50\", 100, 50)) is not (my signatureFromProperties(\"shape\", \"\", \"\", 100, 50))").booleanValue)

    precondition(AutoMagicMoveResult(output: "OK|0\n") == .completed(0))
    precondition(AutoMagicMoveResult(output: "OK|12") == .completed(12))
    precondition(AutoMagicMoveResult(output: "PARTIAL|3|-1743") == .partial(changed: 3, error: -1743))
    for output in ["", "0", "OK", "OK|", "OK|-1", "OK|one", "OK|1|2", "PARTIAL|3", "PARTIAL|3|0", "PARTIAL|-1|-1743", "OTHER|3"] {
        precondition(AutoMagicMoveResult(output: output) == nil, output)
    }
    precondition(!KeynoteCommand.autoMagicMove.enabledByDefault)
    precondition(!KeynoteCommand.autoMagicMove.isStandard)
    precondition(KeynoteCommand.autoMagicMove.shortcutSection == .transition)
    precondition(KeynoteCommand.autoMagicMove.steps == [.script(.autoMagicMove)])
    if case .success(let output) = CommandRunner.runScriptProcess("return \"OK|2\"") {
        precondition(AutoMagicMoveResult(output: output) == .completed(2))
    } else { preconditionFailure("Out-of-process result protocol failed") }
    if case .failure(let error) = CommandRunner.runScriptProcess("error number -1743") {
        precondition(error.code == -1743)
    } else { preconditionFailure("Out-of-process AppleScript errors were lost") }
    print("PASS: Auto Magic Move production matching/signature helpers, skip/last/nonmatching preservation, zero/partial results and subprocess errors")
}
