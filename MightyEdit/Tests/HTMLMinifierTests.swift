import Foundation
@main struct HTMLMinifierTests {
    static func main() {
        let cases: [(String, String)] = [
            ("<div>\n <p class=\"a\">Hello   world</p>\n</div>", "<div><p class=a>Hello world</div>"),
            ("<span>Hello</span> \n <a href=\"/\">world</a>", "<span>Hello</span> <a href=\"/\">world</a>"),
            ("Hello\nworld", "Hello world"),
            ("a <!-- comment --> b", "a b"),
            ("a<!-- comment -->b", "ab"),
            ("<!--[if IE]><p>A</p><![endif]-->", "<!--[if IE]><p>A</p><![endif]-->"),
            ("<!--! license -->", "<!--! license -->"),
            ("<input disabled=\"disabled\" checked=\"false\" aria-hidden=\"false\" title=\"a b\">", "<input disabled checked aria-hidden=false title=\"a b\">"),
            ("<div hidden=\"until-found\" contenteditable=\"false\" data-x=\"a&amp;b\"></div>", "<div hidden=until-found contenteditable=false data-x=\"a&amp;b\"></div>"),
            ("<img src=\"x\"/>", "<img src=x />"),
            ("<div title=\"a > b\" data-empty=\"\"></div>", "<div title=\"a > b\" data-empty=\"\"></div>"),
            ("<ul>\n<li>A</li>\n<li>B</li>\n</ul>", "<ul><li>A<li>B</ul>"),
            ("<p>A</p><span>B</span>", "<p>A</p><span>B</span>"),
            ("<a><p>A</p></a>", "<a><p>A</p></a>"),
            ("<table><tbody><tr><td>A</td><td>B</td></tr></tbody></table>", "<table><tbody><tr><td>A<td>B</table>"),
            ("<pre>\n a  <span>b  c</span> <!--keep-->\n</pre>", "<pre>\n a  <span>b  c</span> <!--keep-->\n</pre>"),
            ("<textarea> a\n  b </textarea>", "<textarea> a\n  b </textarea>"),
            ("<script defer=\"defer\">let a = '  ';\n// hi\na++;</script>", "<script defer>let a = '  ';\n// hi\na++;</script>"),
            ("<style>span { white-space: pre; }\n</style>", "<style>span { white-space: pre; }\n</style>"),
            ("<svg><svg><text> a  b </text></svg></svg>", "<svg><svg><text> a  b </text></svg></svg>"),
            ("<div title=\"unfinished", "<div title=\"unfinished"),
            ("<script>unterminated", "<script>unterminated"),
            ("<html><head><title>A</title></head><body><p>A</p></body></html>", "<html><head><title>A</title><body><p>A"),
            ("<body>A</body><!--[if IE]>x<![endif]-->", "<body>A</body><!--[if IE]>x<![endif]-->"),
            ("全角　　&nbsp;&nbsp;", "全角　　&nbsp;&nbsp;")
        ]
        for (input, expected) in cases {
            let actual = HTMLMinifier.minify(input)
            precondition(actual == expected, "Input: \(input)\nExpected: \(expected)\nActual: \(actual)")
            precondition(HTMLMinifier.minify(actual) == actual, "Not idempotent: \(actual)")
        }
        print("Passed \(cases.count) HTML minifier cases and idempotence checks")
    }
}
