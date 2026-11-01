import AppKit

@main struct RunnerTests {
    static func main() {
        // Validate AppleScript argument-list serialization without controlling Illustrator.
        let values = ["quotes \" and \\ and 日本語\nnext", "", "third, value"]
        let list = "{" + values.map(ScriptText.quote).joined(separator: ", ") + "}"
        let probe = "set v to " + list + "\nif (count v) is not 3 then error \"count\"\nif item 2 of v is not \"\" then error \"position\"\nif item 1 of v is not " + ScriptText.quote(values[0]) + " then error \"literal\"\nreturn \"OK\""
        precondition(OSAScript.run(probe) == .output("OK"), "argument text must remain literal and empty positions must survive")
        let runner = ScriptRunner()
        let cases: [[Step]] = [
            [.script(path: "/does-not-exist.jsx"), .menuCommand(id: "group", title: nil)],
            [.menuItem(path: ["File", "Close"]), .script(path: "/does-not-exist.jsx")],
            []
        ]
        func next(_ index: Int) {
            guard index < cases.count else { print("PASS: legacy mixed, menu and empty items stop before Illustrator or any script execution"); exit(0) }
            let entry = ScriptEntry(steps: cases[index], name: "Legacy test")
            precondition(runner.run(entry) { outcome in
                guard outcome == .unsupportedSteps else { print("FAIL: unsupported item reached execution: \(outcome)"); exit(1) }
                next(index + 1)
            })
        }
        next(0)
        dispatchMain()
    }
}
