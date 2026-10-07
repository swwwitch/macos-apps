import Foundation
@main struct HTMLBeautifierTests {
    static func main() {
        let cases: [(String, String)] = [
            ("<div><p>Hello <a href=\"x\">world</a> !</p><p>B</p></div>", "<div>\n  <p>Hello <a href=\"x\">world</a> !</p>\n  <p>B</p>\n</div>"),
            ("<ul><li>A<li>B</ul>", "<ul>\n  <li>A\n  <li>B\n</ul>"),
            ("<div><pre>\n a  <span>x</span>\n</pre><p>B</p></div>", "<div>\n  <pre>\n a  <span>x</span>\n</pre>\n  <p>B</p>\n</div>"),
            ("<span>A</span> <a>B</a>", "<span>A</span> <a>B</a>"),
            ("<script>let x = '  ';\n x++;</script><div>A</div>", "<script>let x = '  ';\n x++;</script>\n<div>A</div>"),
            ("<div><p>A</p>\n   <p>B</p></div>", "<div>\n  <p>A</p>\n  <p>B</p>\n</div>"),
            ("<div title=\"unfinished", "<div title=\"unfinished"),
            ("", "")
        ]
        for (input, expected) in cases {
            let result = HTMLMinifier.beautify(input)
            precondition(result == expected, "Expected: \(expected)\nActual: \(result)")
            precondition(HTMLMinifier.beautify(result) == result)
        }
        precondition(TextTransform.minify.rawValue == 15)
        print("Passed \(cases.count) Beautify cases; legacy Minify ID preserved")
    }
}
