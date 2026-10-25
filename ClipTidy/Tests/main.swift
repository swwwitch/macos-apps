import Foundation

var failures = 0
func check(_ condition: Bool, _ message: String) {
    if !condition { failures += 1; print("FAIL:", message) }
}
func run(_ text: String, front: String? = nil) -> RuleOutcome { RuleEngine.run(Rule.defaults, on: text, frontApp: front) }

check(run("https://vimeo.com/123?share=copy").text == "https://vimeo.com/123", "vimeo share")
check(run("https://vimeo.com/123&fl=sv&fe=ci").text == "https://vimeo.com/123", "vimeo fl")
check(run("https://www.facebook.com/abc?acontext=xyz").text == "https://www.facebook.com/abc", "facebook")
check(run("mailto:name@example.com").text == "name@example.com", "mailto")
check(run("see mailto:name@example.com").text == "see mailto:name@example.com", "mailto only at start")
check(run("https://mobile.twitter.com/swwwitch").text == "https://twitter.com/swwwitch", "twitter")
let notion = "https://swwwitch.notion.site/Event-2026-10-26-0123456789abcdef0123456789abcdef?pvs=4"
check(run(notion, front: "org.mozilla.firefox").text == "https://swwwitch.notion.site/0123456789abcdef0123456789abcdef", "notion in firefox")
check(run(notion, front: "com.google.Chrome").text == notion, "notion only in firefox")
let letao = "入力期限:2026/11/30\n※ご注文者様のご依頼により、小樽洋菓子舗ルタオからギフトをお届けいたします。ＵＲＬをクリックし配送先のご設定をお願いいたします。\nhttps://www.letao.jp/letao_send_info_input.html?id=42"
let letaoOut = run(letao)
check(letaoOut.text == "小樽洋菓子舗ルタオからギフトをお届けします。\nURLをクリックして配送先のご設定をお願いします。\n（入力期限：2026/11/30）\nhttps://www.letao.jp/letao_send_info_input.html?id=42", "letao: \(letaoOut.text)")
check(letaoOut.applied.count == 1, "letao applied once")
check(run("ふつうの文章").applied.isEmpty, "plain text untouched")
check(run("$1 costs").text == "$1 costs", "dollar text untouched")

// Templates: \1 and $1, \n, literal $ and backslash.
check(Rule.template(#"a\1b$2\nc"#) == "a$1b$2\nc", "template")
check(Rule.template(#"\$5"#) == #"\$5"#, "escaped dollar")
var literal = Rule(name: "x", find: "a.b", replace: "$1\\", isRegex: false)
check((try? literal.apply(to: "a.b axb", frontApp: nil)) == "$1\\ axb", "literal mode")
literal.enabled = false
check((try? literal.apply(to: "a.b", frontApp: nil)) == .some(nil), "disabled")
let broken = Rule(name: "broken", find: "(", replace: "")
check(RuleEngine.run([broken], on: "(", frontApp: nil).errors == ["broken"], "invalid pattern reported")
check(broken.patternError != nil, "pattern error text")

// Dropbox.
let link = "https://www.dropbox.com/scl/fi/abc123/%E8%B3%87%E6%96%99.pdf?rlkey=xyz&dl=0"
check(DropboxLink.isShareLink(link), "dropbox link")
check(!DropboxLink.isShareLink("https://www.dropbox.com/scl/fi/abc/a.pdf?rlkey=xyz&dl=1"), "dl=1 is not offered")
check(DropboxLink.direct(link).hasSuffix("&dl=1"), "direct")
check(DropboxLink.item(link)?.name == "資料.pdf" && DropboxLink.item(link)?.isFolder == false, "file name")
check(DropboxLink.item("https://www.dropbox.com/scl/fo/abc/folder?rlkey=x&dl=0")?.isFolder == true, "folder")

if failures == 0 { print("PASS: rules, templates and Dropbox links") } else { print("\(failures) failure(s)"); exit(1) }
