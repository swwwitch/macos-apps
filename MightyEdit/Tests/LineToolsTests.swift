import Foundation
@main struct LineToolsTests {
    static func main() {
        precondition(LineTools.trim(" \ta　\r\n　b\t\r\n") == "a\nb\n")
        precondition(LineTools.trim("\t\n\n") == "\n\n")
        precondition(LineTools.affix("a\r\n\r\nb\r\n", prefix: "[", suffix: "]") == "[a]\n[]\n[b]\n")
        precondition(LineTools.affix("", prefix: "[", suffix: "]") == "")
        precondition(LineTools.split("BrowserSwitcher、BundleIDInspector、CarmaChameleon", at: "、", keepSeparator: false) == "BrowserSwitcher\nBundleIDInspector\nCarmaChameleon")
        precondition(LineTools.split("a, b ,c\r\nd", at: ",", keepSeparator: false) == "a\nb\nc\nd")
        precondition(LineTools.split("一。二。", at: "。", keepSeparator: true) == "一。\n二。\n")
        precondition(LineTools.split("abc", at: "", keepSeparator: false) == "abc")
        precondition(LineTools.split("Mac macOS アプリ開発", at: " ", keepSeparator: false, prefix: "#") == "#Mac\n#macOS\n#アプリ開発")
        precondition(LineTools.split("a\n\nb", at: "", keepSeparator: false, prefix: "- ") == "- a\n\n- b")
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
        print("Passed line trim, stable length sorting, affixes, splits and Unicode counts")
    }
}
