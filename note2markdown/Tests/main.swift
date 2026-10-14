import Foundation

var failures = 0
var count = 0
func check(_ name: String, _ actual: String, _ expected: String) {
    count += 1
    if actual != expected {
        failures += 1
        print("FAIL \(name)\n--- expected\n\(expected)\n--- actual\n\(actual)")
    }
}
func md(_ html: String, title: String = "", titles: [String: String] = [:]) -> String {
    var converter = NoteMarkdown()
    converter.embedTitles = titles
    return converter.convert(title: title, html: html)
}

// URL → key
check("key note.com", NoteArticle.key(from: "https://note.com/dtp_tranist/n/n22872a3cbb8d") ?? "nil", "n22872a3cbb8d")
check("key query", NoteArticle.key(from: " https://note.com/dtp_tranist/n/n22872a3cbb8d?magazine_key=m1#x \n") ?? "nil", "n22872a3cbb8d")
check("key custom domain", NoteArticle.key(from: "https://example.jp/n/n0123456789ab") ?? "nil", "n0123456789ab")
check("key bare", NoteArticle.key(from: "n0123456789ab") ?? "nil", "n0123456789ab")
check("key profile", NoteArticle.key(from: "https://note.com/dtp_tranist") ?? "nil", "nil")
check("key magazine", NoteArticle.key(from: "https://note.com/swwwitch/m/m057948d2fbeb") ?? "nil", "nil")
check("key not url", NoteArticle.key(from: "note.com/a/n/n0123456789ab") ?? "nil", "nil")

// File names
check("filename", NoteArticle.fileName(for: "A/B: C?", key: "n1"), "A_B_ C_.md")
check("filename empty", NoteArticle.fileName(for: "  ", key: "n0123456789ab"), "n0123456789ab.md")
check("filename dot", NoteArticle.fileName(for: ".hidden", key: "n1"), "hidden.md")

// API response
let json = #"{"data":{"name":"題名","body":"<p>本文</p>","note_url":"https://note.com/u/n/n0123456789ab","price":300}}"#
if let article = try? NoteArticle.parse(Data(json.utf8), key: "n0123456789ab") {
    check("parse", "\(article.title)|\(article.body)|\(article.url)|\(article.price)", "題名|<p>本文</p>|https://note.com/u/n/n0123456789ab|300")
} else { failures += 1; print("FAIL parse") }
count += 1
do { _ = try NoteArticle.parse(Data(#"{"data":{"name":"x","body":null}}"#.utf8), key: "n1"); failures += 1; print("FAIL no body") }
catch { if error as? NoteArticle.Failure != .noBody { failures += 1; print("FAIL no body type") } }

// Title and paragraphs
check("title h1", md("<p name=\"a\" id=\"a\">本文です。</p>", title: "タイトル"), "# タイトル\n\n本文です。\n")
check("br hard break", md("<p>一行目<br>二行目<br></p><p><br></p><p>次</p>"), "一行目  \n二行目\n\n次\n")
check("headings", md("<h2 style=\"text-align: start;\">大見出し</h2><h3>小見出し</h3>"), "## 大見出し\n\n### 小見出し\n")
check("inline", md("<p><strong>太字</strong>と<em>斜体</em>と<s>消し</s>と<code>x</code></p>"), "**太字**と*斜体*と~~消し~~と`x`\n")
check("link", md("<p><a href=\"https://a.jp/x\" target=\"_blank\" rel=\"nofollow noopener\"><strong>リンク</strong></a></p>"), "[リンク](https://a.jp/x)\n")
check("autolink", md("<p><a href=\"https://a.jp/\">https://a.jp/</a></p>"), "<https://a.jp/>\n")
check("entities", md("<p>&lt;tag&gt; &amp; &quot;q&quot; &#x3042;&#12354;</p>"), "\\<tag> & \"q\" ああ\n")
check("escape", md("<p>a * b * c と file_name と _x_ と `code_x*` と ¥&lt;Price&gt;</p>"), "a \\* b \\* c と file_name と \\_x\\_ と `code_x*` と ¥\\<Price>\n")
check("line start", md("<p># 見出しではない</p><p>1. 番号ではない</p><p>- 箇条ではない</p>"), "\\# 見出しではない\n\n1\\. 番号ではない\n\n\\- 箇条ではない\n")

// Lists
check("ul", md("<ul><li><p>一</p></li><li><p>二</p></li></ul>"), "- 一\n- 二\n")
check("ol nested", md("<ol><li><p>手順</p><ul><li><p>補足</p></li></ul></li><li><p>次</p></li></ol>"), "1. 手順\n   - 補足\n2. 次\n")

// Quote, code, rule, table of contents
check("blockquote", md("<blockquote><p>引用<br>二行</p></blockquote>"), "> 引用  \n> 二行\n")
check("pre", md("<pre name=\"x\"><code>if (a &lt; b) {\n  go();\n}</code></pre>"), "```\nif (a < b) {\n  go();\n}\n```\n")
check("pre fence", md("<pre><code>```\nx\n```</code></pre>"), "````\n```\nx\n```\n````\n")
check("hr toc", md("<table-of-contents><br></table-of-contents><p>a</p><hr><p>b</p>"), "a\n\n---\n\nb\n")

// Images
check("image", md("<figure><img src=\"https://assets.st-note.com/img/1-a.png?width=1200\" alt=\"\" width=\"620\"><figcaption></figcaption></figure>"), "![画像](https://assets.st-note.com/img/1-a.png)\n")
check("image caption", md("<figure><img src=\"https://assets.st-note.com/img/1-a.png\"><figcaption>説明</figcaption></figure>"), "![説明](https://assets.st-note.com/img/1-a.png)\n")
check("quote figure", md("<figure><blockquote><p>文</p></blockquote><figcaption>出典</figcaption></figure>"), "> 文\n\n出典\n")

// Embeds
let noteEmbed = "<figure data-src=\"https://note.com/u/n/n0123456789ab\" embedded-service=\"note\"></figure>"
check("note embed", md(noteEmbed), "- [note記事へのリンク](https://note.com/u/n/n0123456789ab)\n")
check("note embed title", md(noteEmbed, titles: ["https://note.com/u/n/n0123456789ab": "別の[記事]"]), "- [別の\\[記事\\]](https://note.com/u/n/n0123456789ab)\n")
check("note embed urls", NoteMarkdown.noteEmbedURLs(in: noteEmbed + noteEmbed).joined(separator: ","), "https://note.com/u/n/n0123456789ab")
check("twitter", md("<figure data-src=\"https://x.com/a/status/1\" embedded-service=\"twitter\"><blockquote class=\"twitter-tweet\"><p>本文</p></blockquote></figure>"), "- [Twitter（現「X」）リンク](https://x.com/a/status/1)\n")
check("youtube", md("<figure data-src=\"https://www.youtube.com/watch?v=abc\" embedded-service=\"youtube\">  </figure>"), "https://www.youtube.com/watch?v=abc\n")
check("external", md("<figure data-src=\"https://fonts.adobe.com/\" embedded-service=\"external-article\"><a href=\"https://fonts.adobe.com/\"><strong>\nAdobe Fonts\n</strong><em>説明</em></a></figure>"), "- [Adobe Fonts](https://fonts.adobe.com/)\n")
check("attachment", md("<figure embedded-service=\"attachment\"><a href=\"https://note.com/api/v2/attachments/download/x\"><strong>A.dmg</strong> 4.67 MB ファイルダウンロードについて ダウンロード</a></figure>"), "- [A.dmg](https://note.com/api/v2/attachments/download/x)\n")
check("gist", md("<figure data-src=\"https://gist.github.com/a/b\" embedded-service=\"gist\"><a href=\"https://gist.github.com/a/b\"></a></figure>"), "- <https://gist.github.com/a/b>\n")

// Paid line and blank-line collapsing
check("paid line", md("<p>無料</p><p>このラインより上のエリアが無料で表示されます。</p><p>有料</p>"), "無料\n\n有料\n")

print(failures == 0 ? "OK: \(count) checks" : "\(failures) of \(count) checks failed")
exit(failures == 0 ? 0 : 1)
