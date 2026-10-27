import AppKit

@main struct RunnerTests {
    static func main() {
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
