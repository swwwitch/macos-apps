import Foundation

var count = 0
func check(_ actual: String, _ expected: String, _ label: String, line: Int = #line) {
    precondition(actual == expected, "line \(line) \(label): got \(actual.debugDescription), expected \(expected.debugDescription)")
    count += 1
}

// The exact code points taken from the KM macro.
precondition(Array(CleanRules.excelPattern.unicodeScalars).map(\.value) == [0x28, 0x3F, 0x6D, 0x29, 0x5E, 0x2011, 0x5F, 0x2B, 0x5C, 0x73])
precondition(CleanRules.spreadsheetSteps.map(\.pattern) == ["(?m)^\"", "(?m)\"$", "\"+"])
precondition(CleanRules.spreadsheetSteps.map(\.template) == ["", "", "\""])
precondition(CleanRules.apostrophe.unicodeScalars.first!.value == 0x27 && CleanRules.doubleQuote.unicodeScalars.first!.value == 0x22)
count += 4

// Excel
let nbh = "\u{2011}"
check(CleanRules.cleanExcel(nbh + "___ memo"), "memo", "excel line start")
check(CleanRules.cleanExcel("A1\n" + nbh + "_\tB2\n" + nbh + "__\nC3"), "A1\nB2\nC3", "excel multiline, tab and newline count as \\s")
check(CleanRules.cleanExcel("-___ memo"), "-___ memo", "ASCII hyphen-minus is not matched")
check(CleanRules.cleanExcel("x" + nbh + "__ y"), "x" + nbh + "__ y", "not at line start")
check(CleanRules.cleanExcel(nbh + "___memo"), nbh + "___memo", "needs one whitespace")
check(CleanRules.cleanExcel(nbh + "_  two"), " two", "only one whitespace is removed")
check(CleanRules.cleanExcel("\"a\nb\""), "a\nb", "Excel: in-cell line break loses the outer quotes")
check(CleanRules.cleanExcel("\"a\nb\"\tc\r\nd\t\"e\nf\"\r\n"), "a\nb\tc\r\nd\te\nf\r\n", "Excel: quoted cells among tab/row separators")
check(CleanRules.cleanExcel("\"He said \"\"hi\"\"\nok\""), "He said \"hi\"\nok", "Excel: doubled quotes inside a quoted cell")
check(CleanRules.cleanExcel("\"\"\"x\"\"\""), "\"x\"", "Excel: a cell that is just \"x\"")
check(CleanRules.cleanExcel("say \"hi\""), "say \"hi\"", "Excel: quotes not at the cell start are kept")
check(CleanRules.cleanExcel("\"open\tb"), "\"open\tb", "Excel: unclosed quote is kept as is")
check(CleanRules.cleanExcel("\"a\"b\tc"), "\"a\"b\tc", "Excel: quote closing mid-cell is not Excel quoting")
check(CleanRules.cleanExcel("\"" + nbh + "_ a\nb\""), "a\nb", "Excel: unquote first, then the U+2011 rule at the line start")
check(CleanRules.cleanExcel("\"😀\n日本語\""), "😀\n日本語", "Excel: non-ASCII")
check(CleanRules.cleanExcel("r1\r" + nbh + "_ r2"), "r1\rr2", "CR line ending")
check(CleanRules.cleanExcel(""), "", "empty")

// Google Sheets in a browser
check(CleanRules.cleanSpreadsheet("\"a\nb\""), "a\nb", "cell with an in-cell line break")
check(CleanRules.cleanSpreadsheet("a\"\"b"), "a\"b", "doubled quote inside a cell")
check(CleanRules.cleanSpreadsheet("\"He said \"\"hi\"\"\""), "He said \"hi\"", "escaped quotes in a multi-line cell")
check(CleanRules.cleanSpreadsheet("\"\""), "", "a cell that is just \"\" loses both quotes (steps a and b)")
check(CleanRules.cleanSpreadsheet("\"\"\"\""), "\"", "four quotes: a, b, then c collapses the rest")
check(CleanRules.cleanSpreadsheet("plain\tcell"), "plain\tcell", "unchanged")
check(CleanRules.cleanSpreadsheet("\"x\ny\"\tz\n\"p\nq\""), "x\ny\"\tz\np\nq", "macro only trims quotes at line edges, not at tab-separated cell edges")
check(CleanRules.cleanSpreadsheet("don't"), "don\"t", "step d: apostrophe becomes a double quote (as in the macro)")
check(CleanRules.cleanSpreadsheet("don't", replaceApostrophe: false), "don't", "step d off")
check(CleanRules.cleanSpreadsheet("''"), "\"\"", "step d runs after c, so quotes made from apostrophes are not collapsed")
check(CleanRules.cleanSpreadsheet("\"a\r\nb\""), "a\r\nb", "CRLF")
check(CleanRules.cleanSpreadsheet("’‘“”"), "’‘“”", "curly quotes are not touched")
check(CleanRules.cleanSpreadsheet("\"😀\n日本語\""), "😀\n日本語", "non-ASCII")

// Browser: only a Google Sheets window
precondition(CleanRules.isGoogleSheetsTitle("無題のスプレッドシート - Google スプレッドシート"))
precondition(CleanRules.isGoogleSheetsTitle("Budget - Google Sheets — Mozilla Firefox"))
precondition(CleanRules.isGoogleSheetsTitle("예산 - Google 스프레드시트") && CleanRules.isGoogleSheetsTitle("预算 - Google 表格"))
precondition(!CleanRules.isGoogleSheetsTitle("Google ドキュメント") && !CleanRules.isGoogleSheetsTitle("Gmail") && !CleanRules.isGoogleSheetsTitle(nil))
count += 4

// Dispatch by Bundle ID
precondition(CleanRules.target(for: "com.microsoft.Excel")?.profile == .excel)
precondition(CleanRules.target(for: "com.google.Chrome")?.profile == .spreadsheet)
precondition(CleanRules.target(for: "com.apple.Safari")?.profile == .spreadsheet)
precondition(CleanRules.target(for: "org.mozilla.firefox")?.profile == .spreadsheet)
precondition(CleanRules.target(for: "com.apple.TextEdit") == nil && CleanRules.target(for: nil) == nil)
count += 5
check(CleanRules.clean("\"a\nb\"", profile: .spreadsheet), "a\nb", "clean() spreadsheet")
check(CleanRules.clean(nbh + "_ a", profile: .excel), "a", "clean() excel")

print("PASS: \(count) rule checks (Excel unquote + regex U+2011, browser steps a–d, Sheets title, Bundle ID dispatch)")
