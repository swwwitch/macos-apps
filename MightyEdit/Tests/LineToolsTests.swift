import Foundation
@main struct LineToolsTests {
    static func main() {
        precondition(LineTools.trim(" \ta　\r\n　b\t\r\n") == "a\nb\n")
        precondition(LineTools.trim("\t\n\n") == "\n\n")
        precondition(LineTools.affix("a\r\n\r\nb\r\n", prefix: "[", suffix: "]") == "[a]\n[]\n[b]\n")
        precondition(LineTools.affix("", prefix: "[", suffix: "]") == "")
        let source = "bbb\na\ncc\ndd\n👩‍💻\n"
        let ascending = "a\n👩‍💻\ncc\ndd\nbbb\n"
        let descending = "bbb\ncc\ndd\na\n👩‍💻\n"
        precondition(LineTools.sortByLength(source) == ascending)
        precondition(LineTools.sortByLength(ascending) == descending)
        precondition(LineTools.sortByLength(descending) == ascending)
        precondition(LineTools.sortByLength("aa\nbb") == "aa\nbb")
        precondition(LineTools.statistics("a 👩‍💻\r\ne\u{301}\n").contains("改行を除く）：4"))
        precondition(LineTools.statistics("a 👩‍💻\r\ne\u{301}\n").contains("行数：2"))
        precondition(LineTools.statistics("").contains("行数：0"))
        print("Passed line trim, stable length sorting, affixes and Unicode counts")
    }
}
