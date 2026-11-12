# VectorKeyMap

Illustratorのキーボードショートカットの一覧を作り、初期設定とカスタマイズしたセットを比べるAppKit/SwiftUIアプリ。Apple Silicon / macOS 13以降。.kysを読むだけで、Illustratorの起動は要らず、セットは書き換えない。

## できること

- メニューコマンドとツールのキーを1つの表にする（状態・分類・コマンド・基準・比較先・ID）
- 基準と比較先を選んで差分を出す（変更・追加・解除・同じ・重複）。任意の.kys同士も比べられる
- 名前・ID・キー（⌘E、cmd+e）で検索、分類で絞り込み、列で並べ替え
- 表示中の行をタブ区切りでコピー、CSV・Markdownに書き出し
- キーボードの図で空きキーを確かめる。修飾キーの組み合わせ8通りごとの空きの数、キーを押すと8通りの一覧

## しくみ

- `Source/Kys.swift`：.kysの解析とキーの表記。`/Menus { /<ID> { /Context /Modifiers /Represent /Key } … } /Tools { … } /type { … }`。Modifiersは⌘64・⇧32・⌥128、Keyは文字コード、F1〜F12は14〜25、Tabは9、0は未設定。Context 1は文字の編集中だけ効く。ラベルではなく`Key`で比べる（zoominはKey `=`・Represent `+`）。セットによって文字の大小（u／U）と`\`／`¥`（92／165）が揺れるので正規化する。IDの`\ooo`は上位ビットが立っているものがあり（`\743\603\651`＝E3 83 A9）、下位8ビットを取る。
- `Source/Compare.swift`：比較・検索・書き出し（Foundationのみ、テスト対象）。キーは「種類＋ID」（Adobe Presentation Modeはメニューとツールの両方にある）。
- `Source/SetScanner.swift`：`~/Library/Preferences/Adobe Illustrator <版> Settings/<言語>/*.kys`の列挙と、環境設定の`/KBSCShortcutFile`からの使用中のセットの判定。版違いは同じファイルへのリンクのことが多いので、実体で1件にまとめる。
- `Source/KeyboardLayout.swift`：JIS・USの配列（キーはmacOSの仮想キーコード）と、ショートカットから「実際に押すキー＋修飾キー」への変換（Foundationのみ、テスト対象）。.kysのKeyは文字コードなので、Shiftで入力する文字（JISの`+`・`=`など）はShiftの組み合わせの位置に置く。⌘+はJISでは⇧⌘;の位置。実際の押し方は配列からの推定で、Illustratorでの実測はしていない。
- `Source/SystemShortcuts.swift`：`CopySymbolicHotKeys`でmacOSのショートカットを読む。修飾ビットは⌘0x100・⇧0x200・⌥0x800で、それ以外（⌃0x1000、Globe 0x20000）を含むものは除く。Globe+Aは0x20000＋キーAで返り、マスクすると修飾なしのAに見える。
- `Source/KeyboardView.swift`：キーボードの図。return・delete・Spaceなどは対象外とし、空きの数に入れない。
- `Source/AppModel.swift`・`Views.swift`・`main.swift`：画面。戻ったときに.kysの更新日時を見て読み直す。

## 比較の基準

**Illustrator同梱の`Presets.localized/<言語>/キーボードショートカット/Illustrator 初期設定.kys`は基準にしない。** 実際の既定値と一致しないため。パネルなどのIDが古く（`AdobePathfinderPalette1`など。現行は`Adobe PathfinderUI`）、新しいコマンドが載らず（604＋131件。実際は752＋184件）、同梱ファイルでは`Apply Last Filter`にある⌘Eが、実際の初期設定では未設定になっている（読み込み時に衝突を解決しているとみられる。未確認）。

代わりに、Illustrator上で初期設定のセットを保存した`Data/IllustratorDefault.kys`を同梱する（HotkeyHoundの`Resources/デフォルト.kys`と同じもの）。`sw-2020.kys`のIDはすべてこの中にある。既定値が変わる版が出たら、Illustratorで初期設定を別名で保存し、「基準」で選ぶ。同梱を更新するときは下の手順で表も作り直す。

## 名前の表

.kysにはIDしかない。`Data/Commands.tsv`（種類・ID・分類・日本語名・英語名）は`make-commands.py`で作る。

- **「テキストとして書き出し」の行の並びは、同じセットの.kysの逆順になっている**（ツール184件は完全に一致。メニューは752件＋見出し103行）。この対応でプラグインも含めて全IDの日本語名が決まる。`Data/IllustratorDefault.txt`がその書き出し。
- 見出しと項目は動的計画法で振り分ける。手がかりはキーの一致・`Data/ExtendScript.txt`（AT-doc）の名前と階層。同じ語が見出しにも項目にも使われるところは`SUBMENUS`・`HEADING_LINES`・`ITEM_LINES`で手で決めた。`debugPalette`だけテキストに出ない。
- 階層は`ExtendScript.txt`の日本語のパス、なければ直前の見出し。
- 英語名はAi Command Palette（MIT、`Data/AiCommandPalette-*`）の`menu_commands.csv`・`tool_commands.csv`。

## ビルドと確認

```
./test.sh     # 単体テストと4言語のキー・プレースホルダーの検証
./build.sh    # build/VectorKeyMap.app
python3 make-commands.py -v   # 名前の表を作り直す。ExtendScript.txtと異なる名前を一覧する
```

## 更新履歴

- 1.1.1（build 3）2026-11-07：空きキーを緑の破線の空欄で表示し、使用中のキーと形で区別する。
- 1.1.0（build 2）2026-11-06：キーボードの図を追加。空きキーを修飾キーの組み合わせごとに表示し、macOSのショートカットも区別する。
- 1.0.0（build 1）2026-11-06：初版。
