import Foundation
@main struct NameTests {
    static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }
    static func main() {
        let today = date(2026, 10, 14)
        // The macro's year rule: before November this year, from November next year.
        precondition(FolderName.defaultYear(for: date(2026, 10, 31)) == 2026)
        precondition(FolderName.defaultYear(for: date(2026, 11, 1)) == 2027)
        precondition(FolderName.defaultYear(for: date(2026, 12, 31)) == 2027)
        // The screenshot's case: today on.
        var n = FolderName(client: "ricoh", region: "osaka", year: "2026", useToday: true)
        precondition(n.build(today: today) == .success("ricoh-osaka-20261014"))
        n.region = ""; n.memo = "下見"
        precondition(n.build(today: today) == .success("ricoh-20261014-下見"))
        // Given date, zero padded like the macro's 「00」 format; full-width digits accepted.
        n = FolderName(client: " ricoh ", region: "osaka", year: "2027", month: "3", day: "５", useToday: false)
        precondition(n.build(today: today) == .success("ricoh-osaka-20270305"))
        n.day = ""; precondition(n.build(today: today) == .success("ricoh-osaka-202703"))
        n.month = ""; precondition(n.build(today: today) == .success("ricoh-osaka-2027"))
        n.day = "5"; precondition(n.build(today: today) == .failure(.dayWithoutMonth))
        n.month = "2"; n.day = "30"; precondition(n.build(today: today) == .failure(.badDay))
        n.month = "13"; precondition(n.build(today: today) == .failure(.badMonth))
        n.month = "2"; n.day = "28"; n.year = "26"; precondition(n.build(today: today) == .failure(.badYear))
        n.year = "2028"; n.day = "29"; precondition(n.build(today: today) == .success("ricoh-osaka-20280229"))
        // クライアントも省略可: left out with its separator.
        n.client = ""; precondition(n.build(today: today) == .success("osaka-20280229"))
        n.client = "a/b"; precondition(n.build(today: today) == .failure(.badCharacter))
        n.client = ".x"; precondition(n.build(today: today) == .failure(.badCharacter))
        // Naming rule: order, separators, date styles; empty items drop with their separator.
        var r = FolderName(client: "ricoh", region: "", memo: "下見", useToday: true, pattern: "{date}_{client}_{region}_{memo}", dateStyle: .hyphen)
        precondition(r.build(today: today) == .success("2026-10-14_ricoh_下見"))
        r.pattern = "{region}-{client}"; precondition(r.build(today: today) == .success("ricoh"))
        r.pattern = "[{client}] {date}"; r.dateStyle = .short; precondition(r.build(today: today) == .success("[ricoh] 261014"))
        r.pattern = "{memo}"; r.memo = ""; precondition(r.build(today: today) == .failure(.emptyName))
        r.pattern = "{date} {unknown}"; r.dateStyle = .dot; precondition(r.build(today: today) == .success("2026.10.14 {unknown}"))
        r = FolderName(client: "x", year: "2027", month: "3", day: "", useToday: false, pattern: "{client}-{date}", dateStyle: .hyphen)
        precondition(r.build(today: today) == .success("x-2027-03"))
        precondition(FolderName.render(FolderName.defaultPattern, ["client": "a", "region": "", "date": "d", "memo": ""]) == "a-d")
        // Everything empty with 今日 on: the date alone.
        precondition(FolderName(useToday: true).build(today: today) == .success("20261014"))
        print("PASS: folder names match the KM macro (year rule, today, padding, optional parts) and reject bad input")
    }
}
