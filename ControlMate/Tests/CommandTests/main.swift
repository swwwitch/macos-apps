import Foundation

var failures = 0
func check(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition { failures += 1; print("FAIL line \(line): \(message)") }
}

// Matching: exact modifiers, ⇧ carried only where allowed, ⌘ variants kept apart.
let all = CommandTable.all
check(CommandTable.match(code: 3, mods: [], in: all)?.id == "forward", "⌃F")
check(CommandTable.match(code: 3, mods: .shift, in: all)?.id == "forward", "⌃⇧F selects")
check(CommandTable.match(code: 3, mods: .option, in: all) == nil, "⌃⌥F is left alone")
check(CommandTable.match(code: 40, mods: [], in: all)?.id == "killLine", "⌃K")
check(CommandTable.match(code: 40, mods: .command, in: all)?.id == "copyToLineEnd", "⌃⌘K")
check(CommandTable.match(code: 7, mods: [], in: all)?.id == "killToLineStart", "⌃X")
check(CommandTable.match(code: 7, mods: .command, in: all)?.id == "copyToLineStart", "⌃⌘X")
check(CommandTable.match(code: 40, mods: .shift, in: all) == nil, "⌃⇧K is left alone")
check(CommandTable.match(code: 126, mods: [], in: all) == nil, "⌃↑ stays with Mission Control")
check(CommandTable.match(code: 126, mods: .shift, in: all)?.id == "moveParagraphUp", "⌃⇧↑")
// No two commands on the same key and modifiers.
var seen = Set<String>()
for command in all { check(seen.insert("\(command.key)-\(command.mods.rawValue)").inserted, "duplicate \(command.label)") }
// Arrows carry the Fn and keypad flags, letters do not.
check(CommandTable.right.flags.contains(.maskNumericPad) && CommandTable.right.flags.contains(.maskSecondaryFn), "arrow flags")
check(Stroke(code: 8, mods: .command, label: "").flags == .maskCommand, "⌘C flags")

// Per-app resolution: pass-through groups dropped, VS Code's own keys swapped in, case-insensitive IDs.
let chrome = CommandTable.resolved(bundleID: "com.google.Chrome", passthrough: CommandTable.initialPassthrough, disabled: [])
check(!chrome.contains { $0.group == .basic && !$0.ignoresPassthrough } && !chrome.contains { $0.group == .paragraph }, "Chrome passes basic and paragraph keys")
check(chrome.contains { $0.id == "enter" }, "Chrome still gets the typing helpers")
check(chrome.contains { $0.id == "killLine" } && chrome.contains { $0.id == "yank" }, "⌃K and ⌃Y are handled even where the basic keys pass through")
check(CommandTable.match(code: 7, mods: [.option, .command], in: all)?.id == "copyToTextEnd", "⌃⌥⌘X")
check(CommandTable.match(code: 7, mods: .option, in: all) == nil, "⌃⌥X is left alone")
let code = CommandTable.resolved(bundleID: "com.microsoft.vscode", passthrough: [:], disabled: ["tab"])
check(code.first { $0.id == "moveParagraphUp" }?.action == .keys([Stroke(code: 126, mods: .option, label: "⌥↑")]), "VS Code ⌥↑")
check(!code.contains { $0.id == "tab" }, "disabled command left out")
check(CommandTable.resolved(bundleID: nil, passthrough: CommandTable.initialPassthrough, disabled: []).count == all.count, "unknown app gets all")

// Triggers.
check(TriggerKey.capsLock.pressed(control: false, capsLock: true) && !TriggerKey.capsLock.pressed(control: true, capsLock: false), "Caps Lock trigger")
check(TriggerKey.both.pressed(control: true, capsLock: false) && TriggerKey.both.pressed(control: false, capsLock: true), "both")

// Paragraphs, as the JXA scripts split them.
let text = "one\ntwo\r\nthree\u{2029}" as NSString
let list = TextRanges.paragraphs(text)
check(list == [Paragraph(start: 0, contentEnd: 3, end: 4), Paragraph(start: 4, contentEnd: 7, end: 9),
               Paragraph(start: 9, contentEnd: 14, end: 15), Paragraph(start: 15, contentEnd: 15, end: 15)], "split \(list)")
check(TextRanges.index(at: 3, in: list) == 0 && TextRanges.index(at: 4, in: list) == 1 && TextRanges.index(at: 15, in: list) == 3, "index")
// ⌃K: to the end of the paragraph, then the break; a selection as it is.
check(TextRanges.killToLineEnd(text, selection: NSRange(location: 5, length: 0)) == NSRange(location: 5, length: 2), "⌃K mid")
check(TextRanges.killToLineEnd(text, selection: NSRange(location: 7, length: 0)) == NSRange(location: 7, length: 2), "⌃K at end takes \\r\\n")
check(TextRanges.killToLineEnd(text, selection: NSRange(location: 15, length: 0)).length == 0, "⌃K at the very end")
check(TextRanges.killToLineEnd(text, selection: NSRange(location: 1, length: 5)) == NSRange(location: 1, length: 5), "⌃K selection")
// ⌃X: from the paragraph start to the caret / selection end.
check(TextRanges.killToLineStart(text, selection: NSRange(location: 6, length: 0)) == NSRange(location: 4, length: 2), "⌃X")
check(TextRanges.killToLineStart(text, selection: NSRange(location: 4, length: 0)).length == 0, "⌃X at start")
// ⌃S: whole paragraphs with the break; a selection ending right after a break stays in its paragraph.
check(TextRanges.paragraphSelection(text, selection: NSRange(location: 5, length: 0)) == NSRange(location: 4, length: 5), "⌃S")
check(TextRanges.paragraphSelection(text, selection: NSRange(location: 0, length: 4)) == NSRange(location: 0, length: 4), "⌃S selected line")
check(TextRanges.paragraphSelection(text, selection: NSRange(location: 1, length: 5)) == NSRange(location: 0, length: 9), "⌃S two")
// Swap pairs.
check(TextRanges.swapPair(text, selection: NSRange(location: 0, length: 0), up: true) == nil, "top cannot go up")
if let pair = TextRanges.swapPair(text, selection: NSRange(location: 5, length: 0), up: true) {
    check(pair.upper.start == 0 && pair.lower.start == 4 && !pair.movingIsUpper, "up pair")
} else { check(false, "up pair missing") }
if let pair = TextRanges.swapPair(text, selection: NSRange(location: 5, length: 0), up: false) {
    check(pair.upper.start == 4 && pair.lower.start == 9 && pair.movingIsUpper, "down pair")
} else { check(false, "down pair missing") }

// The 「キー」 table: four categories, every command in exactly one row, ⌃Y and ⌃Z on one row.
var listed: [String] = []
for category in KeyCategory.allCases {
    for row in CommandTable.rows(in: category) {
        if let command = row.standard { check(command.standard, "standard column \(command.id)"); listed.append(command.id) }
        if let command = row.extended { check(!command.standard, "extended column \(command.id)"); listed.append(command.id) }
    }
}
check(listed.sorted() == all.map(\.id).sorted(), "every command once in the table")
check(CommandTable.rows(in: .killYank).map(\.id) == ["killLine", "killToLineStart", "yank"], "Kill/Yank rows: ⌃K, ⌃X, ⌃Y (no ⌃Z)")
check(CommandTable.match(code: 6, mods: [], in: all) == nil, "⌃Z is not used")
check(all.filter(\.standard).map(\.keyLabel).sorted() == ["A", "B", "D", "E", "F", "K", "N", "P", "Y"], "macOS's own Emacs keys")

// ⌃A / ⌃E: paragraph start / end; ⇧ keeps the other end.
check(TextRanges.paragraphEdge(text, selection: NSRange(location: 5, length: 0), end: true, extend: false) == NSRange(location: 7, length: 0), "⌃E")
check(TextRanges.paragraphEdge(text, selection: NSRange(location: 5, length: 0), end: false, extend: false) == NSRange(location: 4, length: 0), "⌃A")
check(TextRanges.paragraphEdge(text, selection: NSRange(location: 5, length: 0), end: true, extend: true) == NSRange(location: 5, length: 2), "⌃⇧E")
check(TextRanges.paragraphEdge(text, selection: NSRange(location: 6, length: 0), end: false, extend: true) == NSRange(location: 4, length: 2), "⌃⇧A")
check(TextRanges.paragraphEdge(text, selection: NSRange(location: 7, length: 0), end: true, extend: false) == NSRange(location: 7, length: 0), "⌃E at the end stays")

if failures > 0 { print("\(failures) failure(s)"); exit(1) }
print("PASS: command table, per-app resolution, triggers and paragraph ranges")
