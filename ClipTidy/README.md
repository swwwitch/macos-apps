# ClipTidy

コピーした文字を、一覧のルールに合わせて自動で書き換えるAppKit/SwiftUIアプリ。Apple Silicon / macOS 13以降。

- ルール：条件（正規表現、任意）・検索・置換・正規表現の有無・大文字小文字の区別・コピーしたアプリ（任意）・「書き換えたら画面に表示」。上から順に適用し、各ルールは前の結果に当たる。
- 最初のルール：VimeoのURL（`&fl=sv&fe=ci`・`?share=copy`）、FacebookのURL（`?acontext…`）、先頭の`mailto:`、`mobile.twitter.com`→`twitter.com`、NotionのページURLの短縮（Firefoxでコピーしたときだけ）、ルタオのギフト案内文の整形（画面に表示）。
- Dropbox：末尾が`dl=0`の共有リンクをコピーすると画面右上にパネルを出し、［直接ダウンロード］で`dl=1`に変える（その間に別の内容をコピーしていたら変えない）。
- 対象外アプリ（初期値 Illustrator・Keynote）が前面のときにコピーした内容と、ClipTidy自身でのコピーは処理しない。
- ⌃⌥T（設定で変更・無効化）でメインウインドウを呼び出す。メニューバーのアイコンから監視の一時停止・再開。

Keyboard Maestroの「Clipboard changes」グループ（Vimeo・Facebook・mailto・Dropbox・ルタオ・Notion）とBiscuitグループの「Twitter URL」を元にした。

## しくみ

- `NSPasteboard.changeCount` を0.3秒ごとに比べ（macOSにクリップボードの変更通知は無い）、変わったときだけ文字を読む（`Source/Monitor.swift`）。`org.nspasteboard.ConcealedType` など秘密・一時的の印がある内容、文字の無い内容、20万文字を超える内容は読まない。
- 書き換えたらクリップボードを書式なしの文字1つに置き換え、そのchangeCountを控えて自分の書き込みを再処理しない。
- 置換は `NSRegularExpression`。置換文字列の `\1` は `$1` に、`\n`・`\t` は改行・タブに変える（`Rule.template`）。
- 画面右上の表示は、フォーカスを奪わない `NSPanel`（`.nonactivatingPanel`）。
- 履歴はメモリだけで保存しない。外部通信なし（更新確認を除く。配信先は未設定）。権限は不要。

## ビルド・テスト

```
./test.sh            # ルール・置換テンプレート・Dropboxリンクの単体テスト＋4言語の翻訳キー・プレースホルダー検証
./build.sh           # build/ClipTidy.app
./build.sh --deploy  # 検証後、/Applications と Latest Builds へ配置（Shared/BuildTools/publish_latest.py）
Assets/make-icon.sh  # アイコンを作り直す
```

## ファイル

- `Source/Rules.swift`：ルールと書き換え、最初のルール、Dropboxリンクの判定
- `Source/Monitor.swift`：クリップボードの監視と書き込み
- `Source/Panels.swift`：画面右上のパネル
- `Source/Views.swift`：主画面・ルールの編集・設定
- `Source/main.swift`：モデル・メニュー・起動
- `make-resources.py` / `help_text.py`：4言語の文字列とヘルプを生成
- `Assets/GenerateIcon.swift`：アイコン（マスタード基調、クリップボードと輝き）

## 更新履歴

### 1.0.0（build 2、2026-10-26）

- メインウインドウを広げたとき、上下に白い帯が出ないように（背景をウインドウ全体に）。

### 1.0.0（build 1、2026-10-26）

- 最初の版。


## 2026-10-26：解説記事リンク（1.0.1／build 3）

- 設定「情報」の解説記事リンクを https://note.com/swwwitch/n/n42b01cf44c67 に設定。
