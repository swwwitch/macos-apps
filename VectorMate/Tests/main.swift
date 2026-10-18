import Foundation

var failures = 0
func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition { failures += 1; print("FAIL (line \(line)): \(message)") }
}

// Parsing the script's answer.
expect(MetricsScript.parse("none\n") == .noText, "none")
expect(MetricsScript.parse("ok\nabc%7Cf1%2C2\nAO\n1\n0\n") == .checked(.init(signature: "abc%7Cf1%2C2", kinds: "AO"), turnedOn: 1, turnedOff: 0), "ok")
if case .unreadable = MetricsScript.parse("ok\nsig\nAX\n0\n0") {} else { expect(false, "bad kinds rejected") }
if case .unreadable = MetricsScript.parse("Error 21: undefined") {} else { expect(false, "error text rejected") }

// The previous state is embedded as JavaScript literals that cannot break out of the string.
let tricky = MetricsScript.Snapshot(signature: "a\"b\\c\nd\u{2028}", kinds: "OA")
let source = MetricsScript.source(previous: tricky, turnOff: true)
expect(source.contains(#"})("a\"b\\c\nd\u2028", "OA", true)"#), "escaped literal: \(source.suffix(60))")
expect(MetricsScript.source(previous: nil, turnOff: false).hasSuffix(#"})("", "", false)"#), "no previous state")
// Only a change of method on the same selection: other → Metrics turns it on, Metrics → other turns it off.
expect(source.contains(#"if (sig !== prevSig) continue;"#), "same selection")
expect(source.contains(#"metrics && prevKinds.charAt(j) === "O""#), "on rule")
expect(source.contains(#"turnOff && !metrics && prevKinds.charAt(j) === "A""#), "off rule")

// AppleScript quoting of path and JavaScript.
let script = MetricsScript.appleScript(appPath: "/Applications/Adobe \"Ai\".app", javascript: #"a("\n")"#, timeout: 5)
expect(script.contains(#"tell application "/Applications/Adobe \"Ai\".app" to do javascript "a(\"\\n\")""#), "AppleScript quoting: \(script)")

if failures > 0 { print("\(failures) failure(s)"); exit(1) }
print("All tests passed")
