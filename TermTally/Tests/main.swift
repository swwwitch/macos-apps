import Foundation

var failures = 0
func check(_ condition: Bool, _ label: String, line: Int = #line) {
    if !condition { failures += 1; print("FAIL \(label) (line \(line))") }
}
func texts(_ matches: [Match]) -> [String] { matches.map(\.text) }

let sample = "取引先との取引は、取引きの記録を残します。\n取り引きの条件。\n取引\nApple と apple と APPLE。pineapple 😀取引😀"
let ns = sample as NSString

// Basic count, order, and case handling.
var plain = SearchOptions(); plain.excludeContained = false
let basic = Matcher.search(["取引", "取引き", "", "apple"], in: sample, options: plain)
check(basic[0].count == 5, "取引 counts every hit")
check(basic[1].count == 1, "取引き")
check(basic[2].isEmpty, "empty field")
check(texts(basic[3]) == ["Apple", "apple", "APPLE", "apple"], "case-insensitive keeps the found text")
var cased = plain; cased.caseSensitive = true
check(Matcher.search(["apple"], in: sample, options: cased)[0].count == 2, "case-sensitive")

// Whole word applies to Latin words, not to Japanese.
var whole = plain; whole.wholeWord = true
check(Matcher.search(["apple"], in: sample, options: whole)[0].count == 3, "whole word drops pineapple")
check(Matcher.search(["取引"], in: sample, options: whole)[0].count == 4, "whole word: not inside 取引先")
check(Matcher.search(["事"], in: "仕事の事と事実", options: whole)[0].map(\.range.location) == [3], "whole word: kanji")
check(Matcher.search(["サーバ"], in: "サーバとサーバラック", options: whole)[0].count == 1, "whole word: katakana")
check(Matcher.search(["こと"], in: "することが", options: whole)[0].count == 1, "whole word: hiragana has no edge")

// Parts of longer keywords.
var contained = SearchOptions()
let kept = Matcher.search(["取引", "取引き", "取引先"], in: sample, options: contained)
check(kept[0].count == 3, "取引 without 取引き and 取引先")
check(kept[1].count == 1 && kept[2].count == 1, "longer keywords stay")
let same = Matcher.search(["取引", "取引"], in: sample, options: contained)
check(same[0].count == 5 && same[1].count == 5, "same keyword twice does not cancel out")

// Within a paragraph the context stops at the break and leaves it out.
let lines = "前の段落\n本文の取引です\n次の段落"
let middle = Matcher.search(["取引"], in: lines, options: plain)[0][0]
check(Matcher.context(of: middle.range, in: lines as NSString, length: 6).before == "段落¶本文の", "context crosses the break when off")
let inside = Matcher.context(of: middle.range, in: lines as NSString, length: 6, withinParagraph: true)
check(inside.before == "本文の" && inside.after == "です", "context stops at the break: \(inside)")
let crlf = "前\r\n取引\r\n後" as NSString
let crlfContext = Matcher.context(of: NSRange(location: 3, length: 2), in: crlf, length: 3, withinParagraph: true)
check(crlfContext.before == "" && crlfContext.after == "", "CRLF is a break too")

// Context keeps whole characters and shows breaks.
let emoji = basic[0].last!
let context = Matcher.context(of: emoji.range, in: ns, length: 2)
check(context.before == " 😀" && context.match == "取引" && context.after == "😀", "context around emoji: \(context)")
check(Matcher.context(of: NSRange(location: 1, length: 1), in: "a\tb\nc" as NSString, length: 3).before == "a", "start of text")
check(Matcher.display("a\nb\tc\u{FEFF}\u{FFFC}\u{01}d") == "a¶b cd", "display text")

// Paragraph numbers.
let starts = Matcher.paragraphStarts(in: "a\nb\r\nc\rd" as NSString)
check(starts == [0, 2, 5, 7], "paragraph starts \(starts)")
check([0, 1, 2, 4, 5, 7].map { Matcher.paragraphNumber(of: $0, starts: starts) } == [1, 1, 2, 2, 3, 4], "paragraph numbers")

// Replacement plan: back to front, overlaps go to the later match.
let all = Matcher.search(["取引", "引き"], in: "取引き 取引", options: plain).flatMap { $0 }
let plan = Matcher.replacementPlan(all)
check(plan.ordered.map(\.range.location) == [4, 1], "plan order \(plan.ordered.map(\.range.location))")
check(plan.overlapped == 1, "overlap skipped")

// Position in Docs' find bar counts hits that the search itself filtered out.
let bar = Matcher.findBarPosition(of: NSRange(location: 8, length: 5), keyword: "apple", in: "APPLE - apple pineapple" as NSString)
check(bar?.index == 1 && bar?.total == 3, "find bar position")
check(Matcher.findBarPosition(of: NSRange(location: 3, length: 5), keyword: "apple", in: "APPLE" as NSString) == nil, "unknown position")

// Exclusions follow the replacements before them and fall away when the text changed.
var list = ExclusionList()
let excluded = Match(keywordIndex: 0, range: NSRange(location: 10, length: 2), text: "取引")
list.set(excluded, excluded: true)
check(list.contains(excluded), "excluded")
check(!list.contains(Match(keywordIndex: 1, range: excluded.range, text: "別語")), "other text at the same place")
list.shift(after: [Match(keywordIndex: 0, range: NSRange(location: 2, length: 4), text: "取り引き"), Match(keywordIndex: 0, range: NSRange(location: 20, length: 4), text: "取り引き")], replacementLength: 2)
check(list.contains(Match(keywordIndex: 0, range: NSRange(location: 8, length: 2), text: "取引")), "shifted")

// Variant groups found without being given a word.
func groups(_ text: String) -> [[String]] { VariantFinder.groups(in: text).map { $0.spellings.map(\.text) } }
check(groups("Apple と apple と APPLE。pineapple は別の語です。") == [["Apple", "apple", "APPLE"]], "case: \(groups("Apple と apple と APPLE。pineapple"))")
check(groups("ユーザビリティを高める。ユーザビリティーの話。ユーザビリティの本。") == [["ユーザビリティ", "ユーザビリティー"]], "trailing long vowel, frequent first")
check(groups("ユーザービリティとユーザビリティ") == [["ユーザービリティ", "ユーザビリティ"]], "inner long vowel")
check(groups("ビルでビールを飲む。ステーキはステキ。") == [], "short words keep their long vowels")
check(groups("サーバとサーバー") == [["サーバ", "サーバー"]], "short word, trailing long vowel")
check(groups("ウィンドウとウインドウ") == [["ウィンドウ", "ウインドウ"]], "small kana")
check(groups("ヴァイオリンとバイオリン") == [["ヴァイオリン", "バイオリン"]], "ヴァ")
check(groups("サーバーとｻｰﾊﾞｰ") == [["サーバー", "ｻｰﾊﾞｰ"]], "width")
check(groups("デザイン・システムとデザインシステム") == [["デザイン・システム", "デザインシステム"]], "middle dot")
check(groups("取引は重要です。取引きの記録。取り引きの条件。") == [["取引", "取引き", "取り引き"]], "okurigana: \(groups("取引は重要です。取引きの記録。取り引きの条件。"))")
check(groups("売上と売上げと売り上げ。") == [["売上", "売上げ", "売り上げ"]], "売上")
check(groups("打ち合わせと打合せと打合わせ") == [["打ち合わせ", "打合せ", "打合わせ"]], "long ending")
check(groups("見積もりと見積り") == [["見積もり", "見積り"]], "見積もり")
check(groups("入力する場合と入力した場合と入力の場合") == [], "verb endings and particles are not okurigana")
check(groups("文書を確認して、内容を確認した。確認の結果。") == [], "the same word in different sentences")
check(groups("取消と取り消しを行う") == [["取消", "取り消し"]], "取り消し")
check(groups("記録を取り消す。取消の操作。") == [], "a verb ending is not a spelling")
check(groups("切り替える操作。切替の操作。") == [], "切り替える")
check(groups("変更せずに残す。変更の記録。変更して保存。") == [], "する forms stay with the compound")
check(groups("読み込める。読み込みの結果。読込の結果。") == [["読み込み", "読込"]], "可能形 is left out")
check(groups("The cat. the cat. In a box, in a box.") == [], "sentence case of common words")
check(groups("email e-mail E-Mail") == [["email", "e-mail", "E-Mail"]], "hyphen")
check(groups("調整する。確認する。調整をする。") == [["調整する", "調整をする"]], "する and をする: \(groups("調整する。確認する。調整をする。"))")
check(groups("確認をしました。確認しました。確認しました。") == [["確認しました", "確認をしました"]], "past form, frequent first")
check(groups("確認して、確認をして") == [["確認して", "確認をして"]], "て form")
check(groups("確認する。確認をします。") == [], "different forms are not interchangeable")
check(groups("チェックする。チェックをする。") == [["チェックする", "チェックをする"]], "katakana noun")
check(groups("資料を作成する。資料する") == [], "を before another verb")
check(VariantFinder.groups(in: "調整する。調整をする。").first?.kind == .suru, "kind suru")
check(groups("") == [], "empty")
check(groups("12個と１２個、３個") == [["12", "１２"]], "numbers group only by width")

// Dictionary groups.
func dict(_ text: String) -> [VariantGroup] { VariantFinder.groups(in: text, dictionary: VariantDictionary.bundled) }
check(dict("ご覧ください。ご確認下さい。ご覧ください。").map(\.label) == ["ください／下さい"], "dictionary: \(dict("ご覧ください。ご確認下さい。ご覧ください。").map(\.label))")
check(dict("ご覧ください。").isEmpty, "one spelling only")
check(dict("仕事の事実と、すること").isEmpty, "事 inside kanji words does not count")
check(dict("読むこと。そんな事は").first?.recommended == "こと", "recommended spelling")
check(dict("Web と WEB とウェブ").contains { $0.id == "c:Web" }, "WEB is corrected: \(dict("Web と WEB とウェブ").map(\.id))")
check(!dict("Web と WEB").contains { $0.id == "l:web" }, "the plain case group is folded into the dictionary group")
check(dict("説明：内容 説明:内容").first?.recommended == nil, "symbols have no recommended side")
// Corrections appear with the wrong spelling alone; the right one joins the group with a count of 0.
let drag = dict("ファイルをドラックする。").first { $0.id == "c:ドラッグ" }
check(drag?.spellings == [Spelling(text: "ドラック", count: 1), Spelling(text: "ドラッグ", count: 0)] && drag?.recommended == "ドラッグ", "correction: \(String(describing: drag))")
check(dict("ファイルをドラッグする。").isEmpty, "the right spelling alone is no finding")
check(dict("Facebook と FaceBook と facebook").first { $0.id == "c:Facebook" }?.spellings.count == 3, "wrong spellings share one group")
check(dict("文字詰めの設定").isEmpty, "字詰め inside 文字詰め: \(dict("文字詰めの設定").map(\.label))")
check(dict("Google Maps を開く").isEmpty, "Google Map inside Google Maps")
check(dict("Zoom で話す").isEmpty, "Zoom is the right form")
let review = dict("対象の範囲").first { $0.id == "r:対照" }
check(review?.kind == .review && review?.recommended == nil && review?.spellings.map(\.text) == ["対象", "対照"], "review: \(String(describing: review))")
check(dict("という話").first { $0.kind == .review }?.spellings.map(\.text) == ["という"], "review without a target")
check(VariantDictionary.parse("誤字\t正字\n? 語A → 語B\n誤字2 → 正字").map(\.id) == ["c:正字", "r:語B"], "user corrections merge by target")
// No correction may undo another one.
let corrections = VariantDictionary.bundled.filter { $0.mode == .correction }
let wrongs = Set(corrections.flatMap(\.wrong))
check(corrections.allSatisfy { !wrongs.contains($0.target ?? "") }, "no cycles: \(corrections.filter { wrongs.contains($0.target ?? "") }.map(\.id))")
check(corrections.allSatisfy { $0.target != nil }, "every correction has a target")
print("dictionary entries:", VariantDictionary.bundled.count, "corrections:", corrections.count, "review:", VariantDictionary.bundled.filter { $0.mode == .review }.count)
check(VariantDictionary.parse("サーバー, サーバ\nユーザー、ユーザ\n\n一語だけ\n").map(\.spellings) == [["サーバー", "サーバ"], ["ユーザー", "ユーザ"]], "user dictionary")
let custom = VariantDictionary.parse("ねこ,猫")
check(VariantFinder.groups(in: "ねこと猫", dictionary: custom).first?.recommended == "ねこ", "user entry")
check(VariantFinder.groups(in: "ねこと猫", dictionary: custom).first?.kind == .dictionary, "kind")
check(VariantFinder.groups(in: "サーバとサーバー").first?.kind == .katakana, "kind katakana")

// Export.
let table = VariantExport.table([VariantGroup(id: "k:a", spellings: [Spelling(text: "サーバー", count: 2), Spelling(text: "サーバ", count: 1)])], header: ["組", "表記", "件数", "統一先"], preferred: { _ in "サーバー" })
check(table == "組\t表記\t件数\t統一先\n1\tサーバー\t2\t◉\n1\tサーバ\t1\t\n", "export: \(table)")
check(VariantFinder.groups(in: "サーバとサーバーとサーバ。取引と取引き").first?.spellings.first == Spelling(text: "サーバ", count: 2), "largest group first")

// Match color setting.
let code = MatchColorCode.encode(red: 0.25, green: 1.2, blue: -1)
check(code == "0.2500,1.0000,0.0000", "color code: \(code)")
check(MatchColorCode.decode(code)?.red == 0.25, "color decode")
check(MatchColorCode.decode("") == nil && MatchColorCode.decode("1,2") == nil && MatchColorCode.decode("2,0,0") == nil, "bad color codes")

if failures == 0 { print("PASS: matching") } else { print("\(failures) failure(s)"); exit(1) }
