import Foundation
var count = 0
func test(_ source: String, _ offset: Int, _ replacement: String, _ location: Int, _ length: Int,
          action: String = "round", force: Bool = false, trim: Bool = false) {
    let edit = BracketEdit.make(source, at: offset, action: action, force: force, trimSpaces: trim)
    precondition(edit.replacement == replacement, "Wrong replacement (\(action)): \(source) -> \(edit.replacement), expected \(replacement)")
    precondition(edit.selection == NSRange(location: location, length: length), "Wrong range: \(source)")
    count += 1
}
test("文字列", 4, "（文字列）", 5, 3)
test("", 10, "（）", 11, 0)
test("［文字列］", 2, "（文字列）", 2, 5)
test("前［内］後", 3, "前（内）後", 3, 5)
test("［a］［b］", 0, "（a）（b）", 0, 6)
test("［片側", 0, "（片側", 0, 3)
test("片側］", 0, "片側）", 0, 3)
test("[abc]", 0, "（abc）", 0, 5)
test("a\nb", 6, "（a\nb）", 7, 3)
test("😀", 2, "（😀）", 3, 2)
test("👩‍💻e\u{301}", 1, "（👩‍💻e\u{301}）", 2, 7)
test("［😀］", 0, "（😀）", 0, 4)
test("（）", 0, "（）", 0, 2)
test("（外「内」）", 0, "【外「内」】", 0, 6, action: "lenticular")
test("［外［内］］", 0, "（外［内］）", 0, 6)
test("「a］", 0, "（a）", 0, 3)
test("”abc“", 0, "（abc）", 0, 5)
test("’abc‘", 0, "‘abc’", 0, 5, action: "smartSingle")
test("don't", 0, "（don't）", 1, 5)
test("don’t", 0, "（don’t）", 1, 5)
test("\"a\" and \"b\"", 0, "「a」 and 「b」", 0, 11, action: "corner")
test("（a）", 0, "「（a）」", 1, 3, action: "corner", force: true)
test("（外「内」）", 0, "外「内」", 0, 4, action: "removeOuter")
test("（外「内」）", 0, "外内", 0, 2, action: "removeAll")
test("x(a)y[b]z", 0, "xaybz", 0, 5, action: "removeOuter")
test("don't", 0, "don't", 0, 5, action: "removeAll")
test("", 0, "", 0, 0, action: "removeOuter")
test("😀", 4, " 😀 ", 5, 2, action: "spaces")
test("", 0, "  ", 1, 0, action: "spaces")
test(" a ", 0, "（ a ）", 1, 3)
test(" a ", 0, "（a）", 1, 1, trim: true)
test("前 ［ a ］ 後", 0, "前（a）後", 0, 5, trim: true)
test("［\na\t］", 0, "（\na\t）", 0, 5, trim: true)
test("<div>x</div>", 0, "<!-- <div>x</div> -->", 5, 12, action: "html")
test("a{b:c}", 0, "/* a{b:c} */", 3, 6, action: "css")
for pair in BracketAction.pairs {
    test("", 3, pair.opening + pair.closing, 3 + pair.opening.utf16.count, 0, action: pair.id)
    test("日本😀", 7, pair.opening + "日本😀" + pair.closing, 7 + pair.opening.utf16.count, 4, action: pair.id)
    if pair.id != "html" && pair.id != "css" {
        let result = pair.opening + "外「内」" + pair.closing
        test("［外「内」］", 2, result, 2, result.utf16.count, action: pair.id)
    }
}
print("PASS: \(count) bracket, nested, force, deletion, whitespace, comment and UTF-16 cases")
for id in BracketAction.forceIDs {
    let pair = BracketAction.pair(String(id.dropFirst(6)))!
    let result = pair.opening + "［a］" + pair.closing
    test("［a］", 2, result, 2 + pair.opening.utf16.count, 3, action: id)
}
print("PASS: 5 independent force hotkey operations")
