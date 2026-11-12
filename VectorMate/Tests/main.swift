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

// 環境設定セット: what the read script answers is parsed back to the same values; snapping and inverted keys.
let flagLines = PrefPresets.flags.map { flag -> String in
    let on = PrefPreset.preset1Values[keyPath: flag.path]
    return flag.inverted ? (on ? "0" : "1") : String(on != flag.negated)
}
let otherLines = ["7", "0.65", "0.65", "0.65", "1", "15", "50", "1", "0.29", "0.52", "1", "0", "0", "1", "0"]
// File Handling is not read from JavaScript: it comes back as ［デフォルト］ and is left out of the comparison.
let roundTrip = PrefPresets.parse((flagLines + otherLines).joined(separator: "\n"))
expect(roundTrip.map { PrefPreset.preset1Values.matches($0, ignoring: PrefValues.fileHandlingPaths + [\.lockGuides]) } == true, "preset 1 round trip")
expect(roundTrip.map { PrefPreset.preset1Values.matches($0) } == false, "File Handling compared when known")
expect(roundTrip?.uiBrightness == 3 && roundTrip?.shapeSwatches == false, "brightness and Shape Builder color")
var brightnessLines = otherLines; brightnessLines[13] = "0.51"; brightnessLines[14] = "1"
let mediumLight = PrefPresets.parse((flagLines + brightnessLines).joined(separator: "\n"))
expect(mediumLight?.uiBrightness == 2 && mediumLight?.shapeSwatches == true, "0.51 is やや明るめ")
expect(!PrefPresets.writeScript(PrefPreset.defaultValues).contains(#"setRealPreference("uiBrightness""#), "brightness not written from JavaScript")
var snapped = otherLines; snapped[0] = "6"; snapped[1] = "0.66"; snapped[4] = "2.4"; snapped[5] = "0"; snapped[6] = "0"
let parsed = PrefPresets.parse((flagLines + snapped).joined(separator: "\n"))
expect(parsed?.anchorSize == 5 && parsed?.artboardColor == 7 && parsed?.artboardStrokeWidth == 2, "snapped: \(String(describing: parsed))")
expect(parsed?.recentFontsEnabled == false && parsed?.historyStates == 100, "recent fonts off, history 0 means unset")
expect(parsed.map { $0.matches(PrefPreset.preset1Values) } == false, "different values do not match")
var hidden = PrefPreset.defaultValues; hidden.recentFontsEnabled = false
var hiddenOther = hidden; hiddenOther.recentFontsCount = 25
expect(hidden.matches(hiddenOther), "count ignored while the list is off")
expect(PrefPresets.parse("true\nfalse") == nil, "wrong line count rejected")
expect(PrefPresets.writeScript(PrefPreset.defaultValues).contains(#"p.setIntegerPreference("hitShapeOnPreview", 1);"#), "inverted write")
expect(PrefPresets.writeScript(PrefPreset.preset1Values).contains(#"p.setBooleanPreference("ShowExternalJSXWarning", false);"#), "scripts allowed: no warning")
expect(PrefPresets.writeScript(PrefPreset.defaultValues).contains(#"p.setBooleanPreference("ShowExternalJSXWarning", true);"#), "scripts not allowed: warning")

// カスタム: paths relative to the synced folder, and the 2.13 keyboard shortcut source.
let base = "/tmp/sync"
expect(SyncFolder.resolve("合成フォント", base: base).path == "/tmp/sync/合成フォント", "relative resolves against the synced folder")
expect(SyncFolder.resolve("/a/b", base: base).path == "/a/b", "absolute kept")
expect(SyncFolder.base("  ").path == SyncFolder.expand(SyncFolder.defaultPath).path, "empty synced folder means the default")
let decomposed = "/tmp/sync/キーボードショートカット".decomposedStringWithCanonicalMapping
expect(SyncFolder.relative(URL(fileURLWithPath: decomposed), base: base) == "キーボードショートカット", "NFD path made relative and precomposed")
expect(SyncFolder.relative(URL(fileURLWithPath: "/tmp/syncother/x"), base: base) == "/tmp/syncother/x", "a sibling with the same prefix is not inside")
expect(SyncFolder.normalize("/tmp/sync/New Document Profiles", base: base) == "New Document Profiles", "2.13 absolute path made relative")
let migrated = SyncFolder.migrateShortcutSource(stored: "/tmp/sync/キーボードショートカット/sw-2020.kys", name: nil, base: base, defaultSource: "K", legacyDefault: "L")
expect(migrated.source == "キーボードショートカット" && migrated.name == "sw-2020", "2.13 .kys becomes folder and set: \(migrated)")
expect(SyncFolder.migrateShortcutSource(stored: "L", name: nil, base: base, defaultSource: "K", legacyDefault: "L") == ("K", ""), "legacy default replaced")
expect(SyncFolder.migrateShortcutSource(stored: "K", name: "x", base: base, defaultSource: "K", legacyDefault: "L") == ("K", "x"), "current value kept")

// Symbolic links: created, kept, replaced, real files moved aside, folders skipped, and the same folder refused.
let fm = FileManager.default
let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("VectorMateLinks-\(UUID().uuidString)")
let src = root.appendingPathComponent("src"), dst = root.appendingPathComponent("dst"), bk = root.appendingPathComponent("bk")
try! fm.createDirectory(at: src.appendingPathComponent("sub"), withIntermediateDirectories: true)
try! fm.createDirectory(at: dst, withIntermediateDirectories: true)
for name in ["a", "b", "c", "d"] { try! name.write(to: src.appendingPathComponent(name), atomically: true, encoding: .utf8) }
try! "old".write(to: dst.appendingPathComponent("b"), atomically: true, encoding: .utf8)
try! fm.createSymbolicLink(at: dst.appendingPathComponent("c"), withDestinationURL: root.appendingPathComponent("elsewhere"))
try! fm.createSymbolicLink(at: dst.appendingPathComponent("d"), withDestinationURL: src.appendingPathComponent("d"))
try! "keep".write(to: dst.appendingPathComponent("onlyHere"), atomically: true, encoding: .utf8)
let summary = try? SymbolicLinks.linkAll(from: src, into: dst, backups: bk)
expect(summary.map { [$0.created, $0.replaced, $0.existing, $0.moved] } == [1, 2, 1, 1], "summary: \(String(describing: summary))")
expect((try? String(contentsOf: dst.appendingPathComponent("b"), encoding: .utf8)) == "b", "b now links to the source")
expect((try? String(contentsOf: bk.appendingPathComponent("b"), encoding: .utf8)) == "old", "the real b was moved aside")
expect((try? String(contentsOf: src.appendingPathComponent("b"), encoding: .utf8)) == "b", "the source is untouched")
expect(fm.fileExists(atPath: dst.appendingPathComponent("onlyHere").path), "files only Illustrator has stay")
expect((try? fm.destinationOfSymbolicLink(atPath: dst.appendingPathComponent("sub").path)) == nil, "folders are not linked")
expect(!((try? fm.contentsOfDirectory(atPath: dst.path)) ?? []).contains { $0.hasPrefix(".") }, "no temporary link left")
do { _ = try SymbolicLinks.linkAll(from: dst, into: dst, backups: bk); expect(false, "same folder refused") }
catch { expect(error as? SymbolicLinks.LinkError == .sameFolder(dst.path), "same folder: \(error)") }
// A source folder of links back into Illustrator's folder (the reverse set-up) would move the only copies away.
let reverse = root.appendingPathComponent("reverse")
try! fm.createDirectory(at: reverse, withIntermediateDirectories: true)
try! fm.createSymbolicLink(at: reverse.appendingPathComponent("onlyHere"), withDestinationURL: dst.appendingPathComponent("onlyHere"))
do { _ = try SymbolicLinks.linkAll(from: reverse, into: dst, backups: bk); expect(false, "links back into the folder refused") }
catch { expect(error as? SymbolicLinks.LinkError == .sameFolder(reverse.path), "reverse links: \(error)") }
expect((try? String(contentsOf: dst.appendingPathComponent("onlyHere"), encoding: .utf8)) == "keep", "the real file stays where it was")
do { _ = try SymbolicLinks.linkAll(from: src.appendingPathComponent("sub"), into: dst, backups: bk); expect(false, "empty source refused") }
catch { expect(error is SymbolicLinks.LinkError, "no files: \(error)") }
try? fm.removeItem(at: root)

// Sign inversion preserves formatting and rejects nonnumeric expressions / multiline input.
for (input, output) in [("12.5 mm", "-12.5 mm"), ("-12.5 mm", "12.5 mm"), ("  +001.20pt  ", "  -001.20pt  "), (".5°", "-.5°"), ("-3%", "3%"), ("10級", "-10級")] {
    expect(SignInversion.flip(input) == output, "sign: \(input)")
}
for input in ["text", "1+2", "1,000", "1\n2", "--2", "", "12 mm\n"] {
    expect(SignInversion.flip(input) == nil, "sign unchanged: \(input)")
}
for input in ["0", "0.0 mm", "-0pt"] { expect(SignInversion.flip(input) == input, "zero preserved: \(input)") }
let partial = SignInversion.replacement(value: "12.5 mm", selection: NSRange(location: 0, length: 4))
expect(partial?.value == "-12.5 mm" && partial?.selection == NSRange(location: 0, length: 5), "selected number retains unit")
expect(SignInversion.replacement(value: "-12 pt", selection: NSRange(location: 3, length: 0))?.value == "12 pt", "no selection uses whole field")
expect(SignInversion.replacement(value: "12 mm", selection: NSRange(location: 0, length: 999)) == nil, "invalid range unchanged")

// ドラッグでパン: click vs drag, waiting for the typing check, typing, and presses that are not ours.
do {
    let a = CGPoint(x: 100, y: 100), near = CGPoint(x: 102, y: 101), far = CGPoint(x: 110, y: 100), farther = CGPoint(x: 120, y: 105)
    var m = DragPanMachine()
    expect(m.down(at: a, eligible: true) == .swallow, "pan: press held back")
    expect(m.dragged(to: near) == .swallow, "pan: small move stays a click")
    expect(m.typingAnswered(false) == nil, "pan: answer before moving does nothing")
    expect(m.up(at: near) == .click(a), "pan: release without moving clicks where it was pressed")
    expect(m.phase == .idle, "pan: idle after click")

    m = DragPanMachine()
    _ = m.down(at: a, eligible: true); _ = m.typingAnswered(false)
    expect(m.dragged(to: far) == .startPan(from: a, to: far), "pan: drag past threshold starts the pan")
    expect(m.dragged(to: farther) == .drag(farther), "pan: later drags follow")
    expect(m.up(at: farther) == .endPan(farther), "pan: release ends the pan")

    m = DragPanMachine()
    _ = m.down(at: a, eligible: true)
    expect(m.dragged(to: far) == .swallow, "pan: drag waits for the typing check")
    expect(m.dragged(to: farther) == .swallow, "pan: still waiting")
    expect(m.typingAnswered(false) == .startPan(from: a, to: farther), "pan: answer starts the pan at the latest point")

    m = DragPanMachine()
    _ = m.down(at: a, eligible: true); _ = m.typingAnswered(true)
    expect(m.dragged(to: far) == .replay(at: a, to: far), "pan: typing replays the press")
    expect(m.dragged(to: farther) == .pass && m.up(at: farther) == .pass, "pan: typing drag passes")

    m = DragPanMachine()
    expect(m.down(at: a, eligible: false) == .pass && m.dragged(to: far) == .pass && m.up(at: far) == .pass, "pan: not ours passes")

    m = DragPanMachine()
    _ = m.down(at: a, eligible: true); _ = m.typingAnswered(false); _ = m.dragged(to: far)
    expect(m.abort() == .endPan(far) && m.phase == .idle, "pan: abort releases a pan in progress")
    expect(m.abort() == nil, "pan: abort when idle does nothing")
    expect(m.up(at: far) == .pass, "pan: stray release passes")
}

if failures > 0 { print("\(failures) failure(s)"); exit(1) }
print("All tests passed")
