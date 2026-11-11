# MenuDiff

Illustrator・InDesign・Photoshop の2つのバージョンのメニュー項目を読み、追加・削除・名前の変更・場所の変更・ショートカットの変化を一覧にする AppKit/SwiftUI アプリ。Apple Silicon / macOS 13 以降。アクセシビリティの許可が要る。アプリやメニューは操作・変更しない。

## できること

- ［Ai］［Id］［Ps］でアプリを選び、［新］［旧］でバージョンを選んで［比較］（⌘R）
- 起動中のバージョンはその場で読む。起動していないバージョンは保存済みのデータを使い、無ければ起動して読み、読み終えたら終了させる（MenuDiff が起動したものだけ。待っている間に前面に出ていれば残す）
- 結果は追加・削除・名前の変更・場所の変更・ショートカットの5種類。絞り込み、タブ区切りのコピー（⇧⌘C）、右クリックでパスのコピー
- 読んだメニューは保存先（既定 `~/Library/Application Support/MenuDiff/Snapshots`、設定で変更可）に `Ai31.0.0 ja_JP.tsv` のような名前で保存

## しくみ

- `Source/MenuReader.swift`：AX でメニューバーを辿る。先頭の Apple メニューは読まない。次のアプリメニューは「Photoshop 2026」のように年が入るので、アプリ名（`AdobeApp.title`）にそろえる。
  - ショートカット：`AXMenuItemCmdModifiers` は 1⇧・2⌥・4⌃・8＝⌘なし。F キーなどは `AXMenuItemCmdGlyph`（Carbon の kMenu…Glyph、0x6F＝F1〜）を優先し、無ければ `AXMenuItemCmdChar`。
  - 子孫を辿らない項目（フォント・最近使用したファイル・スクリプト・ライブラリ・プリセットなど）は `excludedDescendants(for:)`。InDesign の［書式］>［フォント］は除外しないと約3,200項目になる。英語版の項目名は未確認。
  - 状態で名前が変わる項目は `stateFreeTitle` で固定名にそろえる：［編集］直下の「〜を/の取り消し」「〜やり直し」（Illustrator は「ブレンドオプションの取り消し」、InDesign は「〜を取り消し」）、InDesign の「<ドキュメント名> の新規ウィンドウ」、ワークスペースの「〜をリセット」。開いているドキュメント名（` @ 100%`）は読まず、メールアドレスは消す。
  - 起動して読むとき：`NSWorkspace.OpenConfiguration` の `createsNewApplicationInstance`（同じ Bundle ID の別バージョンが起動中でも、その場所のアプリを起動）と `activates = false`。項目数が2回続けて変わらなくなるまで 1.5 秒ごとに読む（最大4分）。実測は Illustrator 2025 で21秒、InDesign 2027 で16秒。
- `Source/Model.swift`：インストールの検出（`/Applications/Adobe <アプリ名>*` の中の .app を Bundle ID の頭で判定。Beta・Prerelease は Bundle ID が別）、言語（Ai は `Presets.localized`、Id は `Presets/InDesign Shortcut Sets`、Ps は `Locales` の `ja_JP` など）、TSV の読み書き。
- `Source/MenuDiff.swift`：差分（Foundation のみ、テスト対象）。移動＝同じ名前が削除側・追加側に1つずつ。改名＝子が移った先のサブメニュー、または同じ親の下で削除・追加が1つずつ（サブメニューの有無が異なるものは組にしない）。親の改名・移動に伴うだけの移動は件数だけ数える。
- `Source/AppModel.swift`・`Views.swift`・`main.swift`：画面・メニュー・設定。

## 保存形式（TSV）

```
#name	Ai31.0.0 ja_JP
#product	Illustrator
#app	/Applications/Adobe Illustrator 2027/Adobe Illustrator.app
#version	31.0.0
#locale	ja_JP
#date	2026-11-11 09:06
#tool	MenuDiff.app 1.1.0
ファイル>新規...	⌘N	
```

メニューのパスは「>」でつなぐ（ai-scripts の SetAiMenuState と同じ書き方）。同じパスが2つ以上あるときは「 #2」を付ける。

## ビルドと確認

```
./test.sh    # 差分・保存形式・名前のそろえ方の単体テスト＋4言語のキーとプレースホルダー
./build.sh   # build/MenuDiff.app（証明書で署名）
```

試験用 CLI：`build/MenuDiff.app/Contents/MacOS/MenuDiff --capture "<アプリのパス>" [out.tsv]`（保存先には書かない）。

ヘルプは `help_text.py`、画面の文言は `make-resources.py`（日英中韓）。

## 制限

- 表示／非表示のように、オン・オフで名前が入れ替わる項目は読んだときの名前になり、「名前の変更」に出ることがある。
- 名前の変更・場所の変更は推定。
- 言語が異なるバージョンどうしでは、ほとんどの項目が追加・削除として出る。
