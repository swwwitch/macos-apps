# FavoriteFolders

旧名 FavoritesTidy（1.2.0まで）。1.2.1 で改名し、Bundle ID `jp.dtp-transit.favoritestidy`・設定は引き継ぐ。旧バックアップ（~/Library/Application Support/FavoritesTidy/Backups）は起動時に新しいフォルダーへ移す。

Default Folder X のお気に入り（Favorites.plist）を並べ替え、区切り線でカテゴリに分けるAppKit/SwiftUIアプリ。Apple Silicon / macOS 13以降。

- 並べ替え：名前順・名前の逆順・場所（パス）順・追加日の新しい順／古い順。カテゴリ（区切り線から次の区切り線まで）の中で並べ、区切り線は動かさない。選択があればそのカテゴリだけ
- ドラッグで並べ替え（複数選択可）、区切り線の追加（⇧⌘N）、カテゴリへ移動、カテゴリごとの上下移動、削除（⌫）、取り消し（⌘Z）
- カテゴリの見出しに名前を付けられる（Default Folder X の区切り線は名前を持てないので、名前はこのアプリの UserDefaults `categoryNames` だけに保存）
- フォルダーが無い項目に ⚠、Dropbox 内の項目に「Dropbox」の印（~/.dropbox/info.json のフォルダー）
- 検索窓の下のチェックボックスで表示を切り替え：フルパス・メモ・使用回数・ファイル数・サイズ（UserDefaults、Macごと）
- メモ（⌘I）：フォルダーごとの文章。アプリ内のみ（UserDefaults `folderNotes`、設定の共有で同期）。検索の対象
- ファイル数・サイズ：サブフォルダーまで（隠しファイル除外、パッケージは1ファイル）。読み込みごとに OperationQueue（同時2）で計算、読み直しで取り消し
- 使用回数（設定でオン、初期値オフ）：DFX に Apple event（DFDXactv・DFDXgCfl・DFDXgRfo）を1.5秒ごとに送り、ダイアログボックスを閉じたときと最近使ったフォルダーの先頭の入れ替わりで数える（Source/Usage.swift の UsageCounter）。オートメーションの許可が必要。よく使う順の並べ替え
- キーボード（⇧⌘K）：ホットキーの割り当てを現在の配列のキーボードの図で表示（空き・重複）
- 上部の検索窓（⌘F）で名前・パスを絞り込み（空白区切りで AND、検索中はドラッグ無効）
- Default Folder X の起動中に編集しようとすると［終了して編集］を確認（ホットキーの変更も画面を開く前に確認）
- お気に入りのホットキーの変更・解除（右端をクリック、⌘K）。共通部品 HotkeyField で記録し、⌘か⌃を必須・お気に入り同士の重複を拒否
- ［Default Folder X を終了／起動］ボタン。ここで終了した Default Folder X は保存時と FavoriteFolders の終了時に起動し直す
- 保存（⌘S）は Default Folder X を終了 → 外部変更の確認 → バックアップ → 書き込み → 起動し直し

## しくみ

- 場所：`~/Library/Application Support/com.stclairsoft.DefaultFolderX5/<フォルダセット>/Favorites.plist`（Setapp版も同じフォルダー）。フォルダセットは環境設定（`com.stclairsoft.DefaultFolderX5-setapp` または `com.stclairsoft.DefaultFolderX5`）の `folderSetInfo` から読む
- 項目は辞書のまま保持して書き戻す（bookmark・hotkey・未知のキーを変えない）。XML plist で書く
- 区切り線は `itemType` 4・`url` "DXMenuSeparator"・`name` 罫線文字列・bookmark なし（Default Folder X 6.3.3 で実測）。カテゴリ名の照合キーは区切り線の `date`
- Default Folder X はお気に入りをメモリーに持ち、終了時に Favorites.plist を書き出す（実測）。起動中に書き込むと終了時に上書きされるため、保存の前に `NSRunningApplication.terminate()` で終了させて待つ
- 終了時に書き出された内容が読み込み時と異なれば（Default Folder X 側での変更）、保存を中止して起動し直す
- 保存直前のファイルを `~/Library/Application Support/FavoriteFolders/Backups` に最新30件まで残す
- ホットキーは NSEvent の形で書く：`modifierFlags`（⌃⌥⇧⌘、矢印・F キーは function フラグ 0x800000 も）、`characters`（全修飾キーを効かせた文字。⌃なら制御文字、矢印などは U+F700 台）、`charactersIgnoringModifiers`（⇧だけ効かせた文字）、`keyCode`。現在のキーボード配列で UCKeyTranslate。Default Folder X が書いた実データ23件と一致することをテストで確認
- 環境設定の `favoritesStaySorted`（「常に名前順に並べる」）がオンなら、並び順が反映されない旨を警告する
- 権限は使わない。外部通信なし（更新確認を除く。配信先は未設定）

## ビルド・テスト

```
./test.sh            # 並べ替え・カテゴリ・移動・区切り線形式・ホットキー表示・plist往復（一時ファイル）＋実ファイルの読み取り、4言語の翻訳キー検証
./build.sh           # build/FavoriteFolders.app
./build.sh --deploy  # /Applications と Latest Builds へ配置
```

- `Source/Favorites.swift`：plist の項目・カテゴリ・並べ替え・移動（UIなし、テスト対象）
- `Source/DFX.swift`：Default Folder X の検出・フォルダセット・終了と起動・バックアップ
- `Source/main.swift`：画面・メニュー・設定
- `Assets/GenerateIcon.swift`：アイコン（マスタード基調、★付きフォルダーと区切り線で分けた一覧）
