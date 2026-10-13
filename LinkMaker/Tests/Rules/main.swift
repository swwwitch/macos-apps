import Foundation

func expect(_ actual: String, _ expected: String, _ note: String = "", line: Int = #line) {
    if actual != expected { print("FAIL line \(line) \(note)\n  got:      \(actual)\n  expected: \(expected)"); exit(1) }
}
func expect(_ ok: Bool, _ note: String, line: Int = #line) { if !ok { print("FAIL line \(line) \(note)"); exit(1) } }

// Titles: unread counts, browser suffixes (window-title fallback).
expect(LinkRules.cleanTitle("(3) Inbox"), "Inbox")
expect(LinkRules.cleanTitle("Example Domain - Google Chrome - DTP"), "Example Domain")
expect(LinkRules.cleanTitle("A - B - Google Chrome"), "A - B")
expect(LinkRules.cleanTitle("Page — Mozilla Firefox"), "Page")
expect(LinkRules.cleanTitle("Keep - dash title"), "Keep - dash title")
expect(LinkRules.isEmptyPage(title: "新しいタブ", url: "chrome://newtab/"), "new tab")
expect(LinkRules.isEmptyPage(title: "スタートページ", url: "favorites://"), "start page")
expect(!LinkRules.isEmptyPage(title: "", url: "https://example.com/"), "untitled page is a page")

// URLs.
expect(LinkRules.cleanURL("https://www.amazon.co.jp/%E6%9C%AC/dp/4297123456/ref=sr_1_1?keywords=x", simplify: false), "https://www.amazon.co.jp/dp/4297123456")
expect(LinkRules.cleanURL("https://www.amazon.co.jp/gp/product/B0ABCDEFGH?psc=1", simplify: true), "https://www.amazon.co.jp/dp/B0ABCDEFGH")
expect(LinkRules.cleanURL("https://example.com/a?utm_source=x&b=1", simplify: false), "https://example.com/a?b=1")
expect(LinkRules.cleanURL("https://example.com/a?utm_source=x&b=1", simplify: true), "https://example.com/a")
expect(LinkRules.cleanURL("https://example.com/a?fbclid=abc", simplify: false), "https://example.com/a")
expect(LinkRules.cleanURL("https://example.com/item?id=12&ref=x", simplify: true), "https://example.com/item?id=12&ref=x")
expect(LinkRules.cleanURL("https://www.youtube.com/watch?v=abc&utm_medium=x", simplify: true), "https://www.youtube.com/watch?v=abc")
expect(LinkRules.cleanURL("https://www.google.com/search?q=make+link", simplify: true), "https://www.google.com/search?q=make+link")
expect(LinkRules.cleanURL("https://example.com/dir/index.html", simplify: true), "https://example.com/dir/")
expect(LinkRules.cleanURL("https://example.com/#section", simplify: true), "https://example.com/#section")

// Amazon links.
expect(LinkRules.amazonASIN("https://www.amazon.co.jp/dp/b0abcdefgh") ?? "", "B0ABCDEFGH")
expect(LinkRules.amazonASIN("https://example.com/dp/B0ABCDEFGH") == nil, "not amazon")
expect(LinkRules.amazonLink(asin: "4297123456", associateID: ""), "https://www.amazon.co.jp/dp/4297123456")
expect(LinkRules.amazonLink(asin: "4297123456", associateID: "myid"), "https://www.amazon.co.jp/exec/obidos/ASIN/4297123456/myid-22/ref=nosim")
expect(LinkRules.amazonLink(asin: "4297123456", associateID: "myid-22"), "https://www.amazon.co.jp/exec/obidos/ASIN/4297123456/myid-22/ref=nosim")

// Formats (the copy macros).
expect(LinkRules.format(.titleLine, title: "T", url: "https://e.com"), "T\nhttps://e.com")
expect(LinkRules.format(.titleSpace, title: "T", url: "https://e.com"), "T https://e.com")
expect(LinkRules.format(.markdown, title: "A [b]", url: "https://e.com/x_(y)"), "- [A \\[b\\]](https://e.com/x_(y%29)")
expect(LinkRules.format(.html, title: "A & <B>", url: "https://e.com/?a=1&b=2"), "<a href=\"https://e.com/?a=1&amp;b=2\">A &amp; &lt;B&gt;</a>")
let tabs = [(title: "One", url: "https://one.example/"), (title: "新しいタブ", url: "chrome://newtab/"), (title: "Two", url: "https://two.example/")]
expect(LinkRules.tabList(tabs, format: .urls), "https://one.example/\nhttps://two.example/")
expect(LinkRules.tabList(tabs, format: .titled), "One\nhttps://one.example/\n\nTwo\nhttps://two.example/")
expect(LinkRules.tabList(tabs, format: .markdown), "- [One](https://one.example/)\n- [Two](https://two.example/)")

// Edit mode (note / Tally / Doorkeeper), as in 「note編集（+tally編集）」.
expect(LinkRules.editURL(for: "https://note.com/swwwitch/n/n1234abcd#heading") == .url("https://editor.note.com/notes/n1234abcd/edit/"), "note")
expect(LinkRules.editURL(for: "https://editor.note.com/notes/n1234abcd/edit/") == .alreadyEditing, "note editing")
expect(LinkRules.editURL(for: "https://tally.so/forms/w2XYz9/submissions") == .url("https://tally.so/forms/w2XYz9/edit"), "tally")
expect(LinkRules.editURL(for: "https://tally.so/forms/w2XYz9/edit") == .alreadyEditing, "tally editing")
expect(LinkRules.editURL(for: "https://cssnite.doorkeeper.jp/events/123456") == .url("https://manage.doorkeeper.jp/groups/cssnite/events/123456/edit"), "doorkeeper")
expect(LinkRules.editURL(for: "https://example.com/") == .unsupported, "other")

// Clipboard helpers.
expect(LinkRules.extractURLs("see https://a.example/x). and http://b.example/?q=1, https://a.example/x").joined(separator: " "), "https://a.example/x http://b.example/?q=1")
expect(LinkRules.searchTerms("- apple\n・りんご\n\n  banana ").joined(separator: "|"), "apple|りんご|banana")
expect(LinkRules.searchURL("make link"), "https://www.google.com/search?q=make%20link")
expect(LinkRules.translateURL("https://e.com/?a=1", target: "ja"), "https://translate.google.com/translate?sl=auto&tl=ja&u=https%3A%2F%2Fe.com%2F%3Fa%3D1")
expect(LinkRules.fileName("a/b: c", fallback: "x"), "ab c")
expect(LinkRules.fileName(" .. ", fallback: "x"), "x")

// 「Make Link (misc)」: selected text.
expect(LinkRules.jinaLines(["https://a.example/", "https://b.example/x"]), "https://r.jina.ai/https://a.example/\nhttps://r.jina.ai/https://b.example/x")
expect(LinkRules.dictionaryURL(" 文字 "), "mkdictionaries:///?text=%E6%96%87%E5%AD%97")
var parts = DateComponents(); parts.year = 2026; parts.month = 10; parts.day = 13; parts.hour = 9; parts.minute = 5; parts.second = 7
expect(LinkRules.urlListFileName(Calendar.current.date(from: parts)!), "url-20261013-090507")
expect(LinkRules.urlList(["a", "b"]), "a\nb\n")
expect(LinkRules.suggestedName(for: "https://www.example.com/x"), "example.com")
expect(LinkRules.webSources(["https://dl.example/f.zip", "https://example.com/page", "https://dl.example/f.zip", "/local"]).joined(separator: " "), "https://dl.example/f.zip https://example.com/page")
expect(LinkAction.allCases.filter(\.isGlobal).count == 11 && !LinkAction.copyURL.isGlobal, "selection group is global")
expect(LinkAction.from(number: 27) == .searchClipboardLines && LinkAction.from(number: 38) == .fileWhereFrom, "existing numbers unchanged")
expect(LinkAction.listed(.copy) == [.copyAsk] + LinkAction.copyFormats, "combined copy first, affiliate follows the Amazon link")

// Action table: unique numbers, KM default keys unique.
let numbers = LinkAction.allCases.map(\.number)
expect(Set(numbers).count == numbers.count && LinkAction.from(number: 1) == .copyURL, "action numbers")
let keys = LinkAction.allCases.compactMap { a in a.defaultShortcut.map { $0.signature + (a.defaultDoubleTap ? "x2" : "") } }
expect(Set(keys).count == keys.count, "default keys (with tap count) are unique")
expect(LinkAction.copyAmazon.defaultShortcut == LinkAction.copyAmazonAffiliate.defaultShortcut && LinkAction.copyAmazonAffiliate.defaultDoubleTap, "⌥A once / twice")
print("PASS: \(LinkAction.allCases.count) actions; titles, URL cleanup, Amazon, formats, tab lists, edit mode, clipboard helpers")
