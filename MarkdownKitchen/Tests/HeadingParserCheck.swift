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
expectTidy([.markerSpaces], "##見出し\n# ok\n-箇条書き\n  +項目\n*項目\n*斜体*\n**太字**\n---\n-5度\n1.項目\n2)項目\n1.5倍\n2026.10.15\n####### 7\n```\n#!x\n```", "## 見出し\n# ok\n- 箇条書き\n  + 項目\n* 項目\n*斜体*\n**太字**\n---\n-5度\n1. 項目\n2) 項目\n1.5倍\n2026.10.15\n####### 7\n```\n#!x\n```", "marker spaces")
expectTidy([.removeUTM], "[a](https://ex.com/p?utm_source=x&utm_medium=y) https://ex.com/?id=3&UTM_campaign=z#top\n<a href=\"https://ex.com/?a=1&amp;utm_source=n&amp;b=2\">x</a> https://ex.com/?utm_term=a&q=1\nhttps://ex.com/?q=utm_x", "[a](https://ex.com/p) https://ex.com/?id=3#top\n<a href=\"https://ex.com/?a=1&amp;b=2\">x</a> https://ex.com/?q=1\nhttps://ex.com/?q=utm_x", "remove utm")
expectTidy([.twitterToX], "https://twitter.com/a\n[X](https://www.Twitter.com/b) mobile.twitter.com/c\napi.twitter.com nottwitter.com twitter.community\n```\ntwitter.com\n```", "https://x.com/a\n[X](https://x.com/b) x.com/c\napi.twitter.com nottwitter.com twitter.community\n```\ntwitter.com\n```", "twitter to x")
expectTidy([.leadingSpaces], "\u{3000}段落\n  続き\n- a\n  - 子\n  続き\n\n    code\n    code2\n\n本文\n<pre>\n  x\n</pre>\n\u{3000}後", "段落\n続き\n- a\n- 子\n続き\n\ncode\ncode2\n\n本文\n<pre>\n  x\n</pre>\n後", "leading spaces remove indentation and keep pre")
expectTidy([.leadingSpaces], "  a\n\tb\n\u{3000}c\n```\n  x\n```", "a\nb\nc\n```\n  x\n```", "leading spaces")
expectTidy([.removeBlankLines], "a\n\n \nb\n```\nx\n\ny\n```\n\nc", "a\nb\n```\nx\n\ny\n```\nc", "remove blank lines")
expectTidy([.whitespaceLines], "a\n  \n\t\n\u{3000}\n b \n```\n  \n```", "a\n\n\n\n b \n```\n  \n```", "whitespace-only lines")
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
func applied(_ text: String, _ edit: TextEdit) -> (String, String) {
    let result = (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
    return (result, (result as NSString).substring(with: edit.selection))
}
func expectFormat(_ got: (String, String), _ text: String, _ selected: String, _ note: String) {
    if got.0 != text || got.1 != selected { failures += 1; print("FAIL format \(note): \(got.0.debugDescription) sel=\(got.1.debugDescription)") }
}
let s1 = "abc 太字 def"
expectFormat(applied(s1, MarkdownFormat.toggleWrap(s1, selection: NSRange(location: 4, length: 2), marker: "**")), "abc **太字** def", "太字", "bold on")
let s2 = "abc **太字** def"
expectFormat(applied(s2, MarkdownFormat.toggleWrap(s2, selection: NSRange(location: 6, length: 2), marker: "**")), "abc 太字 def", "太字", "bold off (outside)")
expectFormat(applied(s2, MarkdownFormat.toggleWrap(s2, selection: NSRange(location: 4, length: 6), marker: "**")), "abc 太字 def", "太字", "bold off (inside)")
expectFormat(applied(s2, MarkdownFormat.toggleWrap(s2, selection: NSRange(location: 6, length: 2), marker: "*")), "abc ***太字*** def", "太字", "italic inside bold")
expectFormat(applied("ab", MarkdownFormat.toggleWrap("ab", selection: NSRange(location: 1, length: 0), marker: "`")), "a``b", "", "empty selection")
expectFormat(applied("x", MarkdownFormat.toggleComment("x", selection: NSRange(location: 0, length: 1))), "<!-- x -->", "x", "comment")
expectFormat(applied("見る", MarkdownFormat.link("見る", selection: NSRange(location: 0, length: 2), image: false)), "[見る](https://)", "https://", "link")
let url = "https://x.jp/"
expectFormat(applied(url, MarkdownFormat.link(url, selection: NSRange(location: 0, length: 13), image: true)), "![](https://x.jp/)", "", "image from url")
let doc2 = "前\n## 古い見出し\n後"
expectFormat(applied(doc2, MarkdownFormat.setBlock(doc2, selection: NSRange(location: 4, length: 0), to: .heading(3))), "前\n### 古い見出し\n後", "### 古い見出し", "heading 3")
expectFormat(applied(doc2, MarkdownFormat.setBlock(doc2, selection: NSRange(location: 4, length: 0), to: .paragraph)), "前\n古い見出し\n後", "古い見出し", "paragraph")
let lst = "a\nb\n\nc"
expectFormat(applied(lst, MarkdownFormat.setBlock(lst, selection: NSRange(location: 0, length: 6), to: .orderedList)), "1. a\n2. b\n\n3. c", "1. a\n2. b\n\n3. c", "ordered")
let ul = "- a\n- b"
expectFormat(applied(ul, MarkdownFormat.setBlock(ul, selection: NSRange(location: 0, length: 7), to: .unorderedList)), "a\nb", "a\nb", "unordered off")
expectFormat(applied(ul, MarkdownFormat.setBlock(ul, selection: NSRange(location: 0, length: 7), to: .orderedList)), "1. a\n2. b", "1. a\n2. b", "unordered to ordered")
expectFormat(applied("a\nb\n", MarkdownFormat.setBlock("a\nb\n", selection: NSRange(location: 0, length: 4), to: .quote)), "> a\n> b\n", "> a\n> b", "quote on")
expectFormat(applied("> a\n> b", MarkdownFormat.setBlock("> a\n> b", selection: NSRange(location: 2, length: 0), to: .quote)), "> a\n> b".replacingOccurrences(of: "> a", with: "a"), "a", "quote off one line")
expectFormat(applied("- a\n- b", MarkdownFormat.indent("- a\n- b", selection: NSRange(location: 4, length: 1), outdent: false)), "- a\n  - b", "  - b", "indent")
expectFormat(applied("  - b", MarkdownFormat.indent("  - b", selection: NSRange(location: 3, length: 0), outdent: true)), "- b", "- b", "outdent")
expectFormat(applied("ab\ncd", MarkdownFormat.newParagraph("ab\ncd", selection: NSRange(location: 1, length: 0))), "ab\n\n\ncd", "", "new paragraph")
func typed(_ text: String, _ caret: Int, _ edit: TextEdit?) -> String? {
    guard let edit else { return nil }
    let result = (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement) as NSString
    return result.substring(to: edit.selection.location) + "|" + result.substring(from: edit.selection.location)
}
func expectTyped(_ got: String?, _ expected: String?, _ note: String) {
    if got != expected { failures += 1; print("FAIL typing \(note): \(String(describing: got).debugDescription)") }
}
expectTyped(typed("- a", 3, MarkdownFormat.continueList("- a", selection: NSRange(location: 3, length: 0))), "- a\n- |", "bullet")
expectTyped(typed("  3. a", 6, MarkdownFormat.continueList("  3. a", selection: NSRange(location: 6, length: 0))), "  3. a\n  4. |", "ordered")
expectTyped(typed("- [x] a", 7, MarkdownFormat.continueList("- [x] a", selection: NSRange(location: 7, length: 0))), "- [x] a\n- [ ] |", "task")
expectTyped(typed("> a", 3, MarkdownFormat.continueList("> a", selection: NSRange(location: 3, length: 0))), "> a\n> |", "quote")
expectTyped(typed("- a\n- ", 6, MarkdownFormat.continueList("- a\n- ", selection: NSRange(location: 6, length: 0))), "- a\n|", "empty item ends list")
expectTyped(typed("text", 4, MarkdownFormat.continueList("text", selection: NSRange(location: 4, length: 0))), nil, "plain line")
expectTyped(typed("```\n- a", 7, MarkdownFormat.continueList("```\n- a", selection: NSRange(location: 7, length: 0))), nil, "in code")
expectTyped(typed("- a\n- b", 7, MarkdownFormat.tab("- a\n- b", selection: NSRange(location: 7, length: 0), outdent: false)), "- a\n  - b|", "tab indents list")
expectTyped(typed("  - b", 5, MarkdownFormat.tab("  - b", selection: NSRange(location: 5, length: 0), outdent: true)), "- b|", "backtab outdents")
expectTyped(typed("text", 2, MarkdownFormat.tab("text", selection: NSRange(location: 2, length: 0), outdent: false)), nil, "plain tab")
expectTyped(typed("    code", 8, MarkdownFormat.continueList("    code", selection: NSRange(location: 8, length: 0))), "    code\n    |", "indented line keeps indent")
expectTyped(typed("    ", 4, MarkdownFormat.continueList("    ", selection: NSRange(location: 4, length: 0))), nil, "blank indented line")
let paras = "# A\n\nB1\nB2\n\n\nC\n"
// Caret in B ("B2", offset 1) moves up: the caret stays on the same character.
expectTyped(typed(paras, 0, MarkdownFormat.moveParagraph(paras, selection: NSRange(location: 7, length: 0), up: true)), "B1|\nB2\n\n# A\n\n\nC\n", "move paragraph up")
expectTyped(typed(paras, 0, MarkdownFormat.moveParagraph(paras, selection: NSRange(location: 7, length: 0), up: false)), "# A\n\nC\n\n\nB1|\nB2\n", "move paragraph down")
expectTyped(typed(paras, 0, MarkdownFormat.moveParagraph(paras, selection: NSRange(location: 1, length: 0), up: true)), nil, "first paragraph cannot go up")
expectTyped(typed(paras, 0, MarkdownFormat.moveParagraph(paras, selection: NSRange(location: 0, length: 9), up: false)), "C\n\n\n|# A\n\nB1\nB2\n", "move two selected paragraphs down")
let toc2 = HeadingParser.render(HeadingParser.headings(in: "## 書体名の由来\n### イタリック\n#### 細目\n### Futura\n## 記号のトリビア\n### セリフ"), format: .simpleTOC)
if toc2 != "1. 書体名の由来\n\u{3000}イタリック\n\u{3000}\u{3000}細目\n\u{3000}Futura\n2. 記号のトリビア\n\u{3000}セリフ" { failures += 1; print("FAIL simple toc: \(toc2.debugDescription)") }
if LineTools.removeDuplicates("a\nb\na\n\n\nb\nc\n") != "a\nb\n\n\nc\n" { failures += 1; print("FAIL dedupe") }
if LineTools.sort("item10\nitem2\nB\na\n", descending: false) != "a\nB\nitem2\nitem10\n" { failures += 1; print("FAIL sort: \(LineTools.sort("item10\nitem2\nB\na\n", descending: false).debugDescription)") }
if LineTools.sort("1\n3\n2", descending: true) != "3\n2\n1" { failures += 1; print("FAIL sort desc") }
expectTyped(typed("a\nb", 0, MarkdownFormat.horizontalRule("a\nb", selection: NSRange(location: 1, length: 0))), "a\n\n---|\n\nb", "hr after line")
expectTyped(typed("a\n\nb", 0, MarkdownFormat.horizontalRule("a\n\nb", selection: NSRange(location: 2, length: 0))), "a\n\n---|\n\nb", "hr on blank line")
expectTyped(typed("a", 0, MarkdownFormat.horizontalRule("a", selection: NSRange(location: 1, length: 0))), "a\n\n---|", "hr at end")
if MarkdownHTML.render("```swift\nlet a = 1\n```\n~~~\nx\n~~~") != "<pre><code class=\"language-swift\">let a = 1</code></pre>\n<pre><code>x</code></pre>" { failures += 1; print("FAIL code language: \(MarkdownHTML.render("```swift\nlet a = 1\n```\n~~~\nx\n~~~"))") }
func styles(_ text: String) -> [(String, MarkdownSyntax.Style)] {
    MarkdownSyntax.spans(in: text, headings: HeadingParser.headings(in: text)).map { ((text as NSString).substring(with: $0.range), $0.style) }
}
let syn = styles("## 見出し\n- **太字** と `code` と [リンク](https://x.jp/)\n<h2 style=\"a\">HTML見出し</h2>\n<div><b>**中**</b></div>\n> 引用")
func has(_ s: String, _ st: MarkdownSyntax.Style) -> Bool { syn.contains { $0.0 == s && $0.1 == st } }
if !(has("## 見出し", .heading) && has("##", .markup) && has("-", .listMarker) && has("**太字**", .strong) && has("`code`", .code)
     && has("[リンク](https://x.jp/)", .link) && has("https://x.jp/", .linkTarget) && has("<h2 style=\"a\">", .markup) && has("</h2>", .markup)
     && has("> 引用", .quote)) { failures += 1; print("FAIL syntax spans: \(syn)") }
if syn.contains(where: { $0.0.contains("中") }) { failures += 1; print("FAIL syntax inside div colored") }
if syn.contains(where: { $0.0 == "<b>" }) { failures += 1; print("FAIL plain html tag colored") }
let gfm = MarkdownHTML.render("| Tool | 説明 | 数 |\n|------|:---:|---:|\n| **A** | `a|b` と x\\|y | 1 |\n| B |\n\n後")
if gfm != "<table><thead><tr><th>Tool</th><th style=\"text-align: center\">説明</th><th style=\"text-align: right\">数</th></tr></thead><tbody><tr><td><strong>A</strong></td><td style=\"text-align: center\"><code>a|b</code> と x|y</td><td style=\"text-align: right\">1</td></tr><tr><td>B</td><td style=\"text-align: center\"></td><td style=\"text-align: right\"></td></tr></tbody></table>\n<p>後</p>" { failures += 1; print("FAIL gfm table:\n\(gfm)") }
if MarkdownHTML.render("a | b\nc") != "<p>a | b\nc</p>" { failures += 1; print("FAIL not a table") }
// A blank line made of a lone CR (classic Mac) still separates blocks.
if MarkdownHTML.render("前の段落\n\r## 見出し\r\n本文") != "<p>前の段落</p>\n<h2>見出し</h2>\n<p>本文</p>" { failures += 1; print("FAIL CR line breaks: \(MarkdownHTML.render("前の段落\n\r## 見出し\r\n本文"))") }
if MarkdownTidy.apply([.blankLines], to: "a\r\r\r\rb") != "a\n\nb" { failures += 1; print("FAIL CR tidy") }
expectFormat(applied("ab", MarkdownFormat.toggleStrikethrough("ab", selection: NSRange(location: 0, length: 2))), "<s>ab</s>", "ab", "strike on")
expectFormat(applied("<s>ab</s>", MarkdownFormat.toggleStrikethrough("<s>ab</s>", selection: NSRange(location: 3, length: 2))), "ab", "ab", "strike off")
expectFormat(applied("a\nb\nc", MarkdownFormat.toggleCodeBlock("a\nb\nc", selection: NSRange(location: 0, length: 3))), "```\na\nb\n```\nc", "a\nb", "code block on")
expectFormat(applied("```\na\n```", MarkdownFormat.toggleCodeBlock("```\na\n```", selection: NSRange(location: 0, length: 9))), "a", "a", "code block off")
expectTyped(typed("x\n\ny", 0, MarkdownFormat.toggleCodeBlock("x\n\ny", selection: NSRange(location: 2, length: 0))), "x\n```\n|\n```\ny", "code block on blank line")
if LineTools.joinLines("This is\na pen.\n日本語の\n文章と\nEnglish\n\n次の段落\n```\na\nb\n```\n") != "This is a pen.日本語の文章とEnglish\n\n次の段落\n```\na\nb\n```\n" { failures += 1; print("FAIL join lines: \(LineTools.joinLines("This is\na pen.\n日本語の\n文章と\nEnglish\n\n次の段落\n```\na\nb\n```\n").debugDescription)") }
let blocksIn = "# A\n## B\n本文1\n本文2\n- a\n  続き\n- b\n> 引用\n> 2\n| x |\n|---|\n```\nc\n\nd\n```\n段落\n---\nタイトル\n===\n<div>x</div>\n後"
let blocksOut = "# A\n\n## B\n\n本文1\n本文2\n\n- a\n  続き\n- b\n\n> 引用\n> 2\n\n| x |\n|---|\n\n```\nc\n\nd\n```\n\n段落\n---\n\nタイトル\n===\n\n<div>x</div>\n\n後"
if LineTools.separateBlocks(blocksIn) != blocksOut { failures += 1; print("FAIL separate blocks:\n\(LineTools.separateBlocks(blocksIn))") }
if LineTools.separateBlocks(blocksOut) != blocksOut { failures += 1; print("FAIL separate blocks idempotent") }
let hb = LineTools.hardBreaksToParagraphs("一行目  \n二行目\\\nC<br>D<BR />E\n<div>a<br>b</div>\n```\nx  \ny\n```\n")
if hb != "一行目\n\n二行目\n\nC\n\nD\n\nE\n<div>a<br>b</div>\n```\nx  \ny\n```\n" { failures += 1; print("FAIL hard breaks: \(hb.debugDescription)") }
let plain = LineTools.hardBreaksToParagraphs("『入門ガイド』の出版から約2年。\nこの2年の間に、進化し。\n- a\n- b\n> q1\n> q2\nタイトル\n===\n本文")
if plain != "『入門ガイド』の出版から約2年。\n\nこの2年の間に、進化し。\n- a\n- b\n> q1\n> q2\nタイトル\n===\n本文" { failures += 1; print("FAIL plain breaks: \(plain.debugDescription)") }
let divWrapped = LineTools.wrapInDiv("## 見出し\n\n本文の**太字**\n\n- a\n- b\n")
if divWrapped != LineTools.divOpen + "<h2>見出し</h2><p>本文の<strong>太字</strong></p><ul><li>a</li><li>b</li></ul></div>\n" { failures += 1; print("FAIL div wrap: \(divWrapped.debugDescription)") }
let statsSource = "## 見出し\n\n**太字**と`code`\n\n<h2 style=\"color: red\">HTML見出し</h2>\n\n- a &amp; b\n\n| x | y |\n|---|---|\n| 1 | 2 |\n"
let statsPlain = TextStats.plainText(statsSource).components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
if statsPlain != ["見出し", "太字とcode", "HTML見出し", "a & b", "x y", "1 2"] { failures += 1; print("FAIL plain text: \(statsPlain)") }
let statsCount = TextStats.content(statsSource)
if statsCount.lines != 6 || statsCount.characters != 3 + 7 + 7 + 5 + 3 + 3 { failures += 1; print("FAIL content stats: \(statsCount)") }
if TextStats.raw("a\n\nb").lines != 3 || TextStats.raw("").lines != 0 { failures += 1; print("FAIL raw stats") }
let autolinkCases: [(String, String)] = [
    ("詳細は https://example.com/a_b_c です。", "詳細は <a href=\"https://example.com/a_b_c\">https://example.com/a_b_c</a> です。"),
    ("https://example.com/です", "<a href=\"https://example.com/\">https://example.com/</a>です"),
    ("(see www.example.com).", "(see <a href=\"http://www.example.com\">www.example.com</a>)."),
    ("https://ja.wikipedia.org/wiki/A_(B)", "<a href=\"https://ja.wikipedia.org/wiki/A_(B)\">https://ja.wikipedia.org/wiki/A_(B)</a>"),
    ("[文字](https://example.com) と <https://a.jp>", "<a href=\"https://example.com\">文字</a> と <a href=\"https://a.jp\">https://a.jp</a>"),
    ("**https://example.com**", "<strong><a href=\"https://example.com\">https://example.com</a></strong>"),
    ("~~古い~~ 新しい", "<del>古い</del> 新しい"),
    ("`https://example.com`", "<code>https://example.com</code>"),
    ("https://a.com/?x=1&y=2", "<a href=\"https://a.com/?x=1&amp;y=2\">https://a.com/?x=1&amp;y=2</a>"),
]
for (source, expected) in autolinkCases where MarkdownHTML.inline(source) != expected {
    failures += 1; print("FAIL autolink: \(MarkdownHTML.inline(source))")
}
expectTidy([.leadingSpaces], "    text\n\ttext\n　text\n    ", "text\ntext\ntext\n", "four spaces and whitespace-only line")
for (block, expected) in [(MarkdownFormat.Block.unorderedList, "- a\n- b\n- c"), (.orderedList, "1. a\n2. b\n3. c")] {
    let source = "    a\n\tb\n　c"
    expectFormat(applied(source, MarkdownFormat.setBlock(source, selection: NSRange(location: 0, length: (source as NSString).length), to: block)), expected, expected, "list strips leading whitespace")
}
print(failures == 0 ? "HeadingParser: all passed" : "HeadingParser: \(failures) failed")
exit(failures == 0 ? 0 : 1)
