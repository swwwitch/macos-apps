import Foundation
@main struct BulkTests {
    static func main() {
        let text = """
        ricoh-osaka-20261014

        • 素材
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
        precondition(BulkNames.parse("Project\n+A\n+B\n+ C").map(\.path) == ["Project A", "Project B", "Project C"])
        // Blank line ends the group; a heading without items is a folder; a later heading starts a new group.
        precondition(BulkNames.parse("Project\n+A\n\n+B\nsolo\nWeb\n+top/img").map(\.path) == ["Project A", "B", "solo", "Web top/img"])
        // Ranges: Project / -A...C → Project A, B, C; numbers keep zero padding; "…" too; mixed kinds are left as typed.
        precondition(BulkNames.parse("Project\n+A...C").map(\.path) == ["Project A", "Project B", "Project C"])
        precondition(BulkNames.parse("ch01...03-draft").map(\.path) == ["ch01-draft", "ch02-draft", "ch03-draft"])
        precondition(BulkNames.parse("Day 3…1").map(\.path) == ["Day 3", "Day 2", "Day 1"])
        precondition(BulkNames.parse("x a...3").map(\.path) == ["x a...3"])
        precondition(BulkNames.parse("a...C").map(\.path) == ["a...C"])
        precondition(BulkNames.parse("abc...def").map(\.path) == ["abc...def"])
        // Files: extensions make files, "< template" picks one, a trailing "/" keeps a dotted folder.
        let files = BulkNames.parse("memo.txt\nsite/index.html < html5.html\nexample.com/\nv1.0\nnotes")
        precondition(files.map(\.path) == ["memo.txt", "site/index.html", "example.com", "v1.0", "notes"], "\(files.map(\.path))")
        precondition(files.map(\.isFile) == [true, true, false, false, false] && files[1].template == "html5.html")
        // "/" and indentation put a line inside the one above (the screenshot's case), as in projects.
        precondition(BulkNames.parse("takano\nmasahiro\n/marine").map(\.path) == ["takano", "masahiro", "masahiro/marine"])
        precondition(BulkNames.parse("a\n/b\n//c\n/d\ne").map(\.path) == ["a", "a/b", "a/b/c", "a/d", "e"])
        precondition(BulkNames.parse("site\n  css\n    style.css\n  index.html").map(\.path) == ["site", "site/css", "site/css/style.css", "site/index.html"])
        precondition(BulkNames.parse("site\n\timg").map(\.path) == ["site", "site/img"])
        // No line above, or under a file: unusable.
        precondition(BulkNames.parse("/orphan").map(\.path) == [nil])
        precondition(BulkNames.parse("memo.txt\n/inside").map(\.path) == ["memo.txt", nil])
        // Headings, ranges and "<" still work with levels.
        precondition(BulkNames.parse("Project\n+A...B\n/sub").map(\.path) == ["Project A", "Project B", "Project B/sub"])
        let tpl = BulkNames.parse("site\n/index.html < html5.html")
        precondition(tpl[1].path == "site/index.html" && tpl[1].template == "html5.html" && tpl[1].isFile)
        // Tree preview: own names, indented under the nearest listed parent.
        let tree = TreeRows.rows(["takano", "takano/marine", "x/y", "site", "site/css/a.css", nil], lines: ["", "", "", "", "", "bad:name"])
        precondition(tree == [.init(depth: 0, label: "takano"), .init(depth: 1, label: "marine"), .init(depth: 0, label: "x/y"),
                              .init(depth: 0, label: "site"), .init(depth: 1, label: "css/a.css"), .init(depth: 0, label: "bad:name")], "\(tree)")
        // "-" works like "/" ("--" deeper); a blank line ends the levels; "*" is a range too.
        precondition(BulkNames.parse("takano\n-marine").map(\.path) == ["takano", "takano/marine"])
        precondition(BulkNames.parse("a\n-b\n--c\n- d").map(\.path) == ["a", "a/b", "a/b/c", "a/d"])
        precondition(BulkNames.parse("a\n\n-b").map(\.path) == ["a", nil])
        precondition(BulkNames.parse("takano-1*3").map(\.path) == ["takano-1", "takano-2", "takano-3"])
        precondition(BulkNames.parse("ch01*03").map(\.path) == ["ch01", "ch02", "ch03"])
        precondition(BulkNames.parse("takano-*3").map(\.path) == ["takano-1", "takano-2", "takano-3"])
        precondition(BulkNames.parse("takano-4*3").map(\.path) == ["takano-4", "takano-5", "takano-6"])
        precondition(BulkNames.parse("p08*3").map(\.path) == ["p08", "p09", "p10"])
        precondition(BulkNames.parse("Room A*3").map(\.path) == ["Room A", "Room B", "Room C"])
        precondition(BulkNames.parse("ch*03").map(\.path) == ["ch*03"])
        precondition(BulkNames.parse("ch-*03").map(\.path) == ["ch-01", "ch-02", "ch-03"])
        precondition(BulkNames.parse("site\n-img-1*2").map(\.path) == ["site", "site/img-1", "site/img-2"])
        // Case differences are the same folder on the default (case-insensitive) volume.
        precondition(BulkNames.parse("ABC\nabc").count == 1)
        print("PASS: bulk lines (bullets, numbering, blanks, duplicates, subfolders, bad names)")
    }
}
