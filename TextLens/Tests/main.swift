import Foundation
func check(_ condition: @autoclosure () -> Bool, _ message: String) { if !condition() { fatalError(message) } }
check(OCRText.clean("日 本 語\nHello world (test)", join: true, parens: true) == "日本語\nHello world （test）", "Japanese spacing, Latin words and line breaks")
check(OCRText.clean("日 本 (A)", join: false, parens: false) == "日 本 (A)", "disabled rules preserve original")
check(OCRText.clean("日\t本　語", join: true, parens: false) == "日本語", "horizontal Japanese spacing")
check(OCRText.clean("", join: true, parens: true).isEmpty, "empty input")
print("PASS: formatting preserves lines and Latin spaces; preferences disable rules")
