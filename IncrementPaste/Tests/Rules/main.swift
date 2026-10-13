import Foundation

var failures = 0
func check(_ input: String, _ expected: String, _ kind: IncrementKind, step: Int = 1, dates: Bool = true, letters: Bool = true, year: Int = 2026) {
    let result = Incrementer.increment(input, options: .init(step: step, dates: dates, letters: letters), currentYear: year)
    if result != IncrementResult(text: expected, kind: kind) {
        print("FAIL: \(input) → \(result.text) (\(result.kind)), expected \(expected) (\(kind))"); failures += 1
    }
}
// The KM macro's sample text.
check("1-2-3", "1-2-4", .number)
check("5-6", "5-7", .number)
check("7-8-9", "7-8-10", .number)
check("第1章", "第2章", .number)
check("001", "002", .number)
check("09", "10", .number)
check("000123", "000124", .number)
check("（1）", "（2）", .number)
check("［A］", "［B］", .letter)
check("A-1", "A-2", .number)
check("Chapter 1", "Chapter 2", .number)
check("Chapter 1-1", "Chapter 1-2", .number)
check("Section 001", "Section 002", .number)
check("1月25日", "1月26日", .date)
// Dots, carries, widths.
check("1.2.3", "1.2.4", .number)
check("1.9", "1.10", .number)
check("99", "100", .number)
check("９", "１０", .number)
check("No.０９", "No.１０", .number)
check("123456789012345678901234567899", "123456789012345678901234567900", .number)
check("①", "②", .circled)
check("⑳", "㉑", .circled)
check("㉟", "㊱", .circled)
check("㊿", "㊿", .none)
// Letters.
check("A", "B", .letter)
check("a", "b", .letter)
check("Z", "AA", .letter)
check("az", "ba", .letter)
check("Item A.", "Item B.", .letter)
check("Ｂ", "Ｃ", .letter)
check("A", "A", .none, letters: false)
check("あいう", "あいう", .none)
check("", "", .none)
// Dates.
check("10月13日火曜日", "10月14日水曜日", .date)
check("10月13日（火）", "10月14日（水）", .date)
check("10月13日(火曜)", "10月14日(水曜)", .date)
check("１０月１３日", "１０月１４日", .date)
check("01月09日", "01月10日", .date)
check("12月31日", "1月1日", .date)
check("2026年12月31日（木）", "2027年1月1日（金）", .date)
check("2028年2月28日", "2028年2月29日", .date)
check("2月28日", "3月1日", .date, year: 2027)
check("10月13日〜10月14日", "10月14日〜10月15日", .date)
check("1月2日日本", "1月3日日本", .date)
check("2024/02/28", "2024/02/29", .date)
check("2025-12-31", "2026-01-01", .date)
check("13月1日", "13月2日", .number)
check("10月13日", "10月14日", .number, dates: false)
check("2025-12-31", "2025-12-32", .number, dates: false)
// Step.
check("1", "3", .number, step: 2)
check("Y", "AA", .letter, step: 2)
check("10月13日", "10月20日", .date, step: 7)
check("1", "2", .number, step: 0)
if failures > 0 { print("\(failures) failure(s)"); exit(1) }
print("PASS: KM sample text, dots/hyphens/zeros/full-width/circled, letters, dates (weekday, month end, leap year), step")
