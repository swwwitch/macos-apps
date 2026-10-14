import Foundation
// Run with test.sh: compiled together with Sources/MarkdownKitchen/HeadingParser.swift.
var failures = 0
func expect(_ source: String, _ expected: [String], _ note: String) {
    let got = HeadingParser.headings(in: source).map { String(repeating: "#", count: $0.level) + " " + $0.title }
    if got != expected { failures += 1; print("FAIL \(note): \(got) != \(expected)") }
}
expect("# A\n## B\n### C ###\n#### D#", ["# A", "## B", "### C", "#### D#"], "ATX and closing hashes")
expect("#NoSpace\n####### seven\n    # indented code\n   # three spaces", ["# three spaces"], "non-headings")
expect("```\n# in code\n```\n~~~~\n# tilde\n~~~\n# still code\n~~~~\n# after", ["# after"], "fences")
expect("---\ntitle: x\n# not heading\n---\n# Real", ["# Real"], "front matter")
expect("Title\n=====\n\nSub\n---\n\n- item\n---\n\n***\n---", ["# Title", "## Sub"], "setext")
expect("<!--\n# hidden\n-->\n# shown", ["# shown"], "html comment")
expect("# 日本語の見出し\r\n本文\r\n## 二つ目", ["# 日本語の見出し", "## 二つ目"], "CRLF and Japanese")
let text = "x\n## 😀 B"
let h = HeadingParser.headings(in: text)[0]
if (text as NSString).substring(with: h.range) != "## 😀 B" { failures += 1; print("FAIL range") }
let rendered = HeadingParser.render(HeadingParser.headings(in: "# A\n### C"), format: .indented)
if rendered != "A\n\t\tC" { failures += 1; print("FAIL render: \(rendered.debugDescription)") }
func shifted(_ source: String, _ delta: Int, levels: Set<Int> = Set(1...6)) -> String? {
    let targets = HeadingParser.headings(in: source).filter { levels.contains($0.level) }
    guard let edits = HeadingParser.shiftEdits(targets, by: delta, in: source) else { return nil }
    let string = NSMutableString(string: source)
    for edit in edits { string.replaceCharacters(in: edit.range, with: edit.text) }
    return string as String
}
func expectShift(_ source: String, _ delta: Int, _ expected: String?, levels: Set<Int> = Set(1...6), _ note: String) {
    let got = shifted(source, delta, levels: levels)
    if got != expected { failures += 1; print("FAIL \(note): \(String(describing: got).debugDescription)") }
}
expectShift("## A\n本文 #\n  ### B ###\n```\n## code\n```", -1, "# A\n本文 #\n  ## B ###\n```\n## code\n```", "raise keeps indent, closing and code")
expectShift("# A\n## B", 1, "## A\n### B", "lower")
expectShift("# A\n## B", -1, nil, "cannot raise H1")
expectShift("###### F", 1, nil, "cannot lower H6")
expectShift("Title\n=====\n\nSub\n---", 1, "## Title\n\n### Sub", "setext becomes ATX")
expectShift("# A\n### C", 1, "# A\n#### C", levels: [3], "only checked levels")
let spaced = HeadingParser.render(HeadingParser.headings(in: "## A\n### B\n### C\n## D\n### E"), format: .markdownSpaced)
if spaced != "## A\n\n### B\n### C\n\n## D\n\n### E" { failures += 1; print("FAIL spaced: \(spaced.debugDescription)") }
let tree = HeadingParser.render(HeadingParser.headings(in: "## A\n### B\n#### C\n### D"), format: .tree)
if tree != "A\n└ B\n\u{3000}└ C\n└ D" { failures += 1; print("FAIL tree: \(tree.debugDescription)") }
let html = "<h2 style=\"margin-top: 2em; color:#fff;\">リマインダー（開催当日のお知らせ）</h2>\n本文\n<H3 class=\"x\">A &amp; <b>B</b></H3>\n<div><h3>中</h3></div>\n<h4>複数\n行</h4>\n<h2>閉じない\n\n</h2>"
expect(html, ["## リマインダー（開催当日のお知らせ）", "### A & B", "#### 複数 行"], "html headings")
expectShift(html, 1, "<h3 style=\"margin-top: 2em; color:#fff;\">リマインダー（開催当日のお知らせ）</h3>\n本文\n<H4 class=\"x\">A &amp; <b>B</b></H4>\n<div><h3>中</h3></div>\n<h5>複数\n行</h5>\n<h2>閉じない\n\n</h2>", "html shift")
expect("<hr>\n<header>x</header>\n<h7>x</h7>", [], "not headings")
func expectHTML(_ source: String, _ expected: String, _ note: String) {
    let got = HTMLToMarkdown.convert(source)
    if got != expected { failures += 1; print("FAIL html2md \(note):\n\(got)\n--- expected ---\n\(expected)") }
}
expectHTML("<h2 style=\"color:#fff;\">リマインダー（<span>当日</span>）</h2>\n本文", "## リマインダー（当日）\n\n本文", "heading with style and span")
expectHTML("# そのまま\n\n- [a](b)", "# そのまま\n\n- [a](b)", "plain markdown untouched")
expectHTML("<p>一行目<br>二行目 <strong>太字</strong> と <a href=\"https://x.jp/\">リンク</a></p><p>次 &amp; 後</p>", "一行目\n二行目 **太字** と [リンク](https://x.jp/)\n\n次 & 後", "paragraphs and inline")
expectHTML("<ul><li>A</li><li><b>B</b></li></ul>\n<ol><li>一</li><li>二</li></ol>", "- A\n- **B**\n\n1. 一\n2. 二", "lists")
expectHTML("<img src=\"a.jpg\" alt=\"写真\" class=\"right\" />", "![写真](a.jpg)", "image")
expectHTML("```html\n<h2>コード</h2>\n```\n<h3>外</h3>", "```html\n<h2>コード</h2>\n```\n### 外", "fenced code untouched")
expectHTML("<pre><code>&lt;b&gt;x</code></pre>", "```\n<b>x\n```", "pre")
expectHTML("<https://example.com> と <em>斜体</em>", "<https://example.com> と *斜体*", "autolink kept")
let dkSource = "## タイトル\n本文 ## ではない\n### 小見出し\n#### そのまま\n```\n## コード\n```\n<h2 style=\"x\">既存</h2>"
let dk = DoorkeeperHTML.convert(dkSource, styles: DoorkeeperHTML.styles(for: DoorkeeperPreset.defaults[0])!)
let dkExpected = "<h2 style=\"margin-top: 2em; border-bottom: none; font-size: 1.5em;background-color:#0AF; color:#fff; padding: 10px 20px; border-radius: 5px;\">タイトル</h2>\n本文 ## ではない\n<h3 style=\"color:#0AF; background-color:rgba(0, 170, 255, 0.3); font-size: 1.2em; line-height: 1.2; margin-top: 2.2em; padding: .5em 1em; border-left: 2px solid #0AF; border-bottom: 2px solid #0AF; border-bottom-left-radius: 6px;\">小見出し</h3>\n#### そのまま\n```\n## コード\n```\n<h2 style=\"x\">既存</h2>"
if dk != dkExpected { failures += 1; print("FAIL doorkeeper:\n\(dk)") }
let dtp = DoorkeeperHTML.convert("## 誰もが不安になる「センス」の話〜センスは才能か、それとも技術か〜\n### 聞き手、MC（進行）", styles: DoorkeeperHTML.styles(for: DoorkeeperPreset.defaults[1])!)
if dtp != "<h2 style=\"margin-top: 2em; border-bottom: none; font-size: 1.5em;background-color:#993366; color:#fff; padding: 10px 20px; border-radius: 5px;\">誰もが不安になる「センス」の話〜センスは才能か、それとも技術か〜</h2>\n<h3 style=\"color:#993366; background-color:rgba(153, 51, 102, 0.2); font-size: 1.2em; line-height: 1.2; margin-top: 2.2em; padding: .5em 1em; border-left: 2px solid #993366; border-bottom: 2px solid #993366; border-bottom-left-radius: 6px;\">聞き手、MC（進行）</h3>" { failures += 1; print("FAIL dtp: \(dtp)") }
// Round trip: Markdown→HTML→Markdown gives the Markdown back.
if HTMLToMarkdown.convert(dk) != "## タイトル\n\n本文 ## ではない\n\n### 小見出し\n\n#### そのまま\n```\n## コード\n```\n## 既存" { failures += 1; print("FAIL roundtrip:\n\(HTMLToMarkdown.convert(dk))") }
if DoorkeeperHTML.rgb("#0AF")! != (0, 170, 255) || DoorkeeperHTML.rgb("12") != nil { failures += 1; print("FAIL rgb") }
let withDiv = "<h2>外</h2>\n<div style=\"a\"><h3>中</h3><div><b>入れ子</b></div><p>x</p></div>\n<p>後</p>"
if HTMLToMarkdown.convert(withDiv, keep: ["div"]) != "## 外\n\n<div style=\"a\"><h3>中</h3><div><b>入れ子</b></div><p>x</p></div>\n\n後" { failures += 1; print("FAIL skipDivs:\n\(HTMLToMarkdown.convert(withDiv, keep: ["div"]))") }
if HTMLToMarkdown.convert(withDiv).contains("<div") { failures += 1; print("FAIL divs converted when not skipped") }
func expectPreview(_ source: String, _ expected: String, _ note: String) {
    let got = MarkdownHTML.render(source)
    if got != expected { failures += 1; print("FAIL preview \(note):\n\(got)\n--- expected ---\n\(expected)") }
}
expectPreview("# 見出し\n\n本文 **太字** と *斜体* と `a<b`\n2行目", "<h1>見出し</h1>\n<p>本文 <strong>太字</strong> と <em>斜体</em> と <code>a&lt;b</code>\n2行目</p>", "heading and inline")
expectPreview("- A\n- [B](https://x.jp/)\n  - C\n\n1. 一\n2. 二", "<ul><li>A\n</li><li><a href=\"https://x.jp/\">B</a>\n<ul><li>C\n</li></ul></li></ul><ol><li>一\n</li><li>二\n</li></ol>", "lists")
expectPreview("<h2 style=\"color:#fff\">そのまま</h2>\n\n> 引用", "<h2 style=\"color:#fff\">そのまま</h2>\n<blockquote><p>引用</p></blockquote>", "raw html and quote")
expectPreview("```\n<b>x</b>\n```\n---\n![写真](a.jpg)", "<pre><code>&lt;b&gt;x&lt;/b&gt;</code></pre>\n<hr>\n<p><img src=\"a.jpg\" alt=\"写真\"></p>", "code, hr, image")
func expectTidy(_ rules: [MarkdownTidy.Rule], _ source: String, _ expected: String, _ note: String) {
    let got = MarkdownTidy.apply(rules, to: source)
    if got != expected { failures += 1; print("FAIL tidy \(note): \(got.debugDescription)") }
}
expectTidy([.trailingSpaces], "a   \nb  \n\nc\t\n```\nx  \n```", "a  \nb\n\nc\n```\nx  \n```", "trailing spaces keep hard break and code")
expectTidy([.blankLines], "a\n\n\n\nb\n```\n\n\n\n```", "a\n\nb\n```\n\n\n\n```", "blank lines")
expectTidy([.listMarkers], "* a\n  + b\n* * *\n*強調*", "- a\n  - b\n* * *\n*強調*", "list markers")
expectTidy([.halfwidthAlphanumerics], "ＡＢＣ１２３ａｂｃ　カタカナ（）", "ABC123abc　カタカナ（）", "halfwidth")
func moved(_ text: String, _ from: String, before: String?) -> String? {
    let all = HeadingParser.headings(in: text)
    guard let source = all.first(where: { $0.title == from }) else { return nil }
    let target = before.flatMap { name in all.first { $0.title == name } }
    guard let edit = SectionMover.moveEdit(in: text, all: all, moving: source, before: target) else { return nil }
    return (text as NSString).replacingCharacters(in: edit.range, with: edit.text)
}
let doc = "前書き\n\n## A\nA本文\n### A1\nA1本文\n\n## B\nB本文\n\n## C\nC本文"
if moved(doc, "C", before: "A") != "前書き\n\n## C\nC本文\n\n## A\nA本文\n### A1\nA1本文\n\n## B\nB本文" { failures += 1; print("FAIL move up last: \(String(describing: moved(doc, "C", before: "A")).debugDescription)") }
if moved(doc, "A", before: nil) != "前書き\n\n## B\nB本文\n\n## C\nC本文\n\n## A\nA本文\n### A1\nA1本文" { failures += 1; print("FAIL move to end: \(String(describing: moved(doc, "A", before: nil)).debugDescription)") }
if moved(doc, "A", before: "A1") != nil { failures += 1; print("FAIL move into itself") }
if moved(doc, "A1", before: "C") != "前書き\n\n## A\nA本文\n## B\nB本文\n\n### A1\nA1本文\n\n## C\nC本文" { failures += 1; print("FAIL move child: \(String(describing: moved(doc, "A1", before: "C")).debugDescription)") }
if TableOfContents.make(HeadingParser.headings(in: "## A\n### B\n## C")) != "- A\n  - B\n- C" { failures += 1; print("FAIL toc") }
let anchored = MarkdownHTML.render("---\nt: 1\n---\n# A\n\n本文\n\n- x\n- y", lineAnchors: true)
if anchored != "<span data-line=\"3\"></span>\n<h1>A</h1>\n<span data-line=\"5\"></span>\n<p>本文</p>\n<span data-line=\"7\"></span>\n<ul><li>x\n</li><li>y\n</li></ul>" { failures += 1; print("FAIL anchors:\n\(anchored)") }
let withTable = "<table><tr><td><b>x</b></td></tr></table>\n<p><b>y</b></p>"
if HTMLToMarkdown.convert(withTable, keep: ["table"]) != "<table><tr><td><b>x</b></td></tr></table>\n\n**y**" { failures += 1; print("FAIL keep table:\n\(HTMLToMarkdown.convert(withTable, keep: ["table"]))") }
expectTidy([.japaneseLatinSpaces], "Photoshop と Illustrator の 2 部構成。`a b` と CSS Nite\n## 見出し A\n- 項目 1", "PhotoshopとIllustratorの2部構成。`a b` とCSS Nite\n## 見出しA\n- 項目1", "japanese-latin spaces")
// Re-theme: CSS Nite headings (including the older rgb() form) switch to DTP Transit in place.
let nite = "<h2 style=\"margin-top: 2em; border-bottom: none; font-size: 1.5em;background-color:#0AF; color:#fff; padding: 10px 20px; border-radius: 5px;\">A <b>x</b></h2>\n本文\n<h3 style=\"color:#0AF; background-color:rgb(0, 170, 255, 0.3); font-size: 1.2em; line-height: 1.2; margin-top: 2.2em; padding: .5em 1em; border-left: 2px solid #0AF; border-bottom: 2px solid #0AF; border-bottom-left-radius: 6px;\">B</h3>\n<h2 style=\"color:red\">別の装飾</h2>\n## C"
let dtpStyles = DoorkeeperHTML.styles(for: DoorkeeperPreset.defaults[1])!
let rethemed = DoorkeeperHTML.convert(nite, styles: dtpStyles)
let rethemeExpected = "<h2 style=\"\(dtpStyles[2]!)\">A <b>x</b></h2>\n本文\n<h3 style=\"\(dtpStyles[3]!)\">B</h3>\n<h2 style=\"color:red\">別の装飾</h2>\n<h2 style=\"\(dtpStyles[2]!)\">C</h2>"
if rethemed != rethemeExpected { failures += 1; print("FAIL retheme:\n\(rethemed)") }
if DoorkeeperHTML.convert(rethemed, styles: dtpStyles) != rethemed { failures += 1; print("FAIL retheme idempotent") }
expectTidy([.minifyHTML], "本文\n\n<div style=\"padding: 1px 20px;  margin: 0;\">\n  <h3 style=\"color: #0AF;\">谷口\n  正樹</h3>\n  <p>a</p>\n</div>\n\n## 見出し\n<pre>\n x\n</pre>", "本文\n\n<div style=\"padding:1px 20px;margin:0;\"><h3 style=\"color:#0AF;\">谷口 正樹</h3><p>a</p></div>\n\n## 見出し\n<pre>\n x\n</pre>", "minify html")
if MarkdownTidy.Rule.standard.contains(.minifyHTML) { failures += 1; print("FAIL minify in standard") }
print(failures == 0 ? "HeadingParser: all passed" : "HeadingParser: \(failures) failed")
exit(failures == 0 ? 0 : 1)
