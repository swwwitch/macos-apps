import Foundation
@main struct BulkTests {
    static func main() {
        let text = """
        ricoh-osaka-20261014

        - 素材
        ・ 原稿
        1. 入稿データ
        2) 校正/初校
          ricoh-osaka-20261014  
        .hidden
        a:b
        x//y
        """
        let e = BulkNames.parse(text)
        precondition(e.map(\.path) == ["ricoh-osaka-20261014", "素材", "原稿", "入稿データ", "校正/初校", nil, nil, nil], "\(e.map(\.path))")
        precondition(e[5].problem == .badCharacter && e[6].problem == .badCharacter && e[7].problem == .badCharacter)
        precondition(BulkNames.parse("\n  \n").isEmpty)
        // Heading + "-" lines: Project / -A / -B / -C → Project A, Project B, Project C (the heading itself is not made).
        precondition(BulkNames.parse("Project\n-A\n-B\n- C").map(\.path) == ["Project A", "Project B", "Project C"])
        // Blank line ends the group; a heading without items is a folder; a later heading starts a new group.
        precondition(BulkNames.parse("Project\n-A\n\n-B\nsolo\nWeb\n-top/img").map(\.path) == ["Project A", "B", "solo", "Web top/img"])
        // Ranges: Project / -A...C → Project A, B, C; numbers keep zero padding; "…" too; mixed kinds are left as typed.
        precondition(BulkNames.parse("Project\n-A...C").map(\.path) == ["Project A", "Project B", "Project C"])
        precondition(BulkNames.parse("ch01...03-draft").map(\.path) == ["ch01-draft", "ch02-draft", "ch03-draft"])
        precondition(BulkNames.parse("Day 3…1").map(\.path) == ["Day 3", "Day 2", "Day 1"])
        precondition(BulkNames.parse("x a...3").map(\.path) == ["x a...3"])
        precondition(BulkNames.parse("a...C").map(\.path) == ["a...C"])
        precondition(BulkNames.parse("abc...def").map(\.path) == ["abc...def"])
        // Case differences are the same folder on the default (case-insensitive) volume.
        precondition(BulkNames.parse("ABC\nabc").count == 1)
        print("PASS: bulk lines (bullets, numbering, blanks, duplicates, subfolders, bad names)")
    }
}
