import Foundation
let parts = ["オブジェクト", "フィルター", "前回のフィルター"]
let expected = ["［オブジェクト］メニューの［フィルター］→［前回のフィルター］", "「オブジェクト」メニューの「フィルター」→「前回のフィルター」", "「オブジェクト」 > 「フィルター」 > 「前回のフィルター」", "「オブジェクト」＞「フィルター」＞「前回のフィルター」", "オブジェクト > フィルター > 前回のフィルター", "オブジェクト＞フィルター＞前回のフィルター"]
for style in 0..<6 { precondition(MenuPathFormat.render(parts, style: style) == expected[style]) }
print("PASS: all 6 requested menu path formats")

precondition(MenuPathFormat.render([" 単独 "] , style: 0, appendClick: true) == "［単独］をクリック")
precondition(MenuPathFormat.render(["開く - test"], style: 4) == "開く - test")
precondition(Array(MenuPathFormat.render(["カ\u{3099}"], style: 4).unicodeScalars).count == 1)
print("PASS: whitespace, suffix preserved, single-level, click instruction and NFC")

precondition(MenuPathFormat.render(["選択", "共通", "アピアランス"], style: 6) == "選択／共通／アピアランス")
precondition(MenuPathFormat.render(["選択", "共通", "アピアランス"], style: 6, appendClick: true) == "選択／共通／アピアランスをクリック")
print("PASS: seventh format with click suffix on/off")
