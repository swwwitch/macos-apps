import Foundation

// ./test.sh で実行する単体テスト（差分・保存形式・名前のそろえ方）
var failures = 0
func check(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition { failures += 1; print("FAIL (line \(line)): \(message)") }
}

func snapshot(_ name: String, _ rows: [(String, String)], locale: String = "ja_JP") -> MenuSnapshot {
    MenuSnapshot(meta: ["name": name, "locale": locale], entries: rows.map { MenuEntry(path: $0.0, shortcut: $0.1) })
}

// 差分：追加・削除・改名（子の移動から）・移動・親に伴う移動の省略・ショートカット
let old = snapshot("Ai30", [
    ("ファイル", ""), ("ファイル>新規...", "⌘N"), ("ファイル>開く...", "⌘O"), ("ファイル>最近使用したファイルを開く", ""),
    ("オブジェクト", ""), ("オブジェクト>パス", ""), ("オブジェクト>パス>連結", "⌘J"), ("オブジェクト>パス>古い機能", ""),
    ("オブジェクト>旧サブ", ""), ("オブジェクト>旧サブ>子A", ""), ("オブジェクト>旧サブ>子B", ""), ("オブジェクト>移動する項目", ""),
    ("ウィンドウ", ""), ("ウィンドウ>XtreamPath3", ""), ("ウィンドウ>XtreamPath3>環境設定...", ""),
])
let new = snapshot("Ai31", [
    ("ファイル", ""), ("ファイル>新規...", "⌘N"), ("ファイル>開く...", "⇧⌘O"), ("ファイル>書き出し", "⌘F1"),
    ("オブジェクト", ""), ("オブジェクト>パス", ""), ("オブジェクト>パス>連結", "⌘J"), ("オブジェクト>パス>移動する項目", ""),
    ("オブジェクト>新サブ", ""), ("オブジェクト>新サブ>子A", ""), ("オブジェクト>新サブ>子B", ""), ("オブジェクト>新機能", ""),
    ("ウィンドウ", ""), ("ウィンドウ>AI アシスタント (beta)", ""),
])
let diff = MenuDiff(old: old, new: new)
// ［ファイル］は削除・追加が1つずつなので改名の組になる。［ウィンドウ］はサブメニューの有無が異なるので組にしない
check(diff.added == ["オブジェクト>新機能", "ウィンドウ>AI アシスタント (beta)"], "added \(diff.added)")
check(diff.removed == ["オブジェクト>パス>古い機能", "ウィンドウ>XtreamPath3", "ウィンドウ>XtreamPath3>環境設定..."], "removed \(diff.removed)")
check(diff.renamed == [PathPair(old: "オブジェクト>旧サブ", new: "オブジェクト>新サブ"),
                       PathPair(old: "ファイル>最近使用したファイルを開く", new: "ファイル>書き出し")], "renamed \(diff.renamed)")
check(diff.moved == [PathPair(old: "オブジェクト>移動する項目", new: "オブジェクト>パス>移動する項目")], "moved \(diff.moved)")
check(diff.impliedMoves == 2, "implied \(diff.impliedMoves)")
check(diff.shortcutChanges == [ShortcutChange(path: "ファイル>開く...", old: "⌘O", new: "⇧⌘O")], "shortcuts \(diff.shortcutChanges)")

// 保存形式の往復と、同じパスの番号付け
let numbered = MenuSnapshot.numberingDuplicates([MenuEntry(path: "ウィンドウ>ツール", shortcut: ""), MenuEntry(path: "ウィンドウ>ツール", shortcut: "")])
check(numbered.map(\.path) == ["ウィンドウ>ツール", "ウィンドウ>ツール #2"], "numbering \(numbered.map(\.path))")
let roundTrip = MenuSnapshot.parse(new.tsv())
check(roundTrip.name == "Ai31" && roundTrip.entries == new.entries, "tsv round trip")

// 名前のそろえ方
check(MenuReader.cleanTitle("") == nil, "empty title")
check(MenuReader.cleanTitle("名称未設定-1 @ 100% (RGB/プレビュー)") == nil, "document window")
check(MenuReader.cleanTitle("ログアウト (foo@example.com)") == "ログアウト", "email in parentheses")
check(MenuReader.stateFreeTitle("ブレンドオプションの取り消し", parentPath: "編集") == "取り消し", "Ai undo")
check(MenuReader.stateFreeTitle("PDF のセキュリティ環境の設定を取り消し", parentPath: "編集") == "取り消し", "Id undo")
check(MenuReader.stateFreeTitle("すべての変更を取り消し", parentPath: "書式>変更をトラック") == "すべての変更を取り消し", "track changes kept")
check(MenuReader.stateFreeTitle("Undo Move", parentPath: "Edit") == "Undo", "English undo")
check(MenuReader.stateFreeTitle("小冊子-v38.indd の新規ウィンドウ", parentPath: "ウィンドウ>アレンジ") == "新規ウィンドウ", "new window for document")
check(MenuReader.stateFreeTitle("sw-fullをリセット", parentPath: "ウィンドウ>ワークスペース") == "（現在のワークスペース）をリセット", "workspace reset")
check(MenuReader.keyLabel("\u{F70A}") == "F7" && MenuReader.keyLabel("o") == "O" && MenuReader.keyLabel("\u{1B}") == "⎋", "key labels")

// 除外リストの先頭はアプリメニュー（年を外した名前）
for app in AdobeApp.allCases {
    check(MenuReader.excludedDescendants(for: app).contains("\(app.title)>サービス"), "services excluded for \(app.title)")
}

// 他社製プラグインの項目を外す（設定の名前＋InDesign の「プラグインについて」）
let idOld = snapshot("Id21.6 ja_JP", [
    ("InDesign", ""), ("InDesign>プラグインについて", ""), ("InDesign>プラグインについて>Em Software", ""),
    ("InDesign>プラグインについて>Em Software>WordsFlow™...", ""), ("ファイル", ""), ("ファイル>WordsFlow", ""),
    ("ファイル>WordsFlow>Place with WordsFlow...", ""), ("ファイル>開く...", "⌘O"),
])
let idNames = PluginFilter.names(for: [idOld], keywords: [])
check(idNames.contains("Em Software") && idNames.contains("WordsFlow"), "detected \(idNames)")
let idFiltered = PluginFilter.removingPlugins(from: idOld, names: idNames)
check(idFiltered.entries.map(\.path) == ["InDesign", "ファイル", "ファイル>開く..."], "filtered \(idFiltered.entries.map(\.path))")
let aiFiltered = PluginFilter.removingPlugins(from: old, names: PluginFilter.defaultKeywords)
check(!aiFiltered.entries.contains { $0.path.contains("XtreamPath") } && aiFiltered.entries.count == old.entries.count - 2, "ai plugins")
check(PluginFilter.detectedNames(in: old).isEmpty, "no auto names outside InDesign")

if failures == 0 { print("PASS: diff, snapshot format and title normalization") } else { print("\(failures) failure(s)"); exit(1) }
