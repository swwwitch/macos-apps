import Foundation
@main struct OpeningTests {
    @MainActor static func main() {
        var calls: [String] = []
        func run(_ required: Bool, _ trusted: Bool, _ opens: Bool) -> Bool {
            calls = []
            return AccessibilitySettingsOpening.open(required: required, openPane: { calls.append("open"); return opens },
                isTrusted: { calls.append("check-without-prompt"); return trusted }, assist: { calls.append("select-without-toggle") })
        }
        precondition(run(true, false, true) && calls == ["open", "check-without-prompt"])
        precondition(run(true, true, true) && calls == ["open", "check-without-prompt", "select-without-toggle"])
        precondition(run(false, true, true) && calls == ["open"])
        precondition(!run(true, true, false) && calls == ["open"])
        print("PASS: pane opens before assistance; denied/unneeded permissions skip assistance; opening failure never selects; no permission requests")
    }
}
