# PrefsPreset

Macの設定（Dock・Finder・トラックパッド・キーボード・ウィンドウ管理など約140項目）を一覧で確かめ、値を選んでまとめて変更するユーティリティです。今の設定一式を `.prefspreset` ファイルに書き出し、クリーンインストールした別のMacで読み込んで適用できます。

- 「変更後」の列で値を選ぶ／入力し、「適用」で変更した行だけを書き込む
- 「書き出す…」（⌘S）で設定一式を保存、「開く…」（⌘O）・ダブルクリック・ドロップで読み込み
- 適用前に元の値を `~/Library/Application Support/PrefsPreset/Backups/` へ保存。開いて適用すれば元に戻る
- 一覧にない設定は「項目を追加…」でドメインとキーを指定して追加

CFPreferences（defaults）を直接読み書きします。起動時のサウンド（NVRAM）とキャップスロックインジケータ（/Library の機能フラグ）だけは書き込み時に管理者のパスワードを求めます。通信はしません。

## ビルド

```sh
./build.sh            # ビルド → 検証 → /Applications と Latest Builds へ配置
NO_DEPLOY=1 ./build.sh  # 配置せず build/ にだけ作る
```

- SwiftPM（`Package.swift`）。ソースは [Sources/PrefsPreset](Sources/PrefsPreset/)、文字列・ヘルプは [Localizations](Localizations/)（ja / en / zh-Hans / ko）。
- 共通部品（AppSurface・StartupWindow・SettingsSection・HelpDocument・MenuBarPresence・LoginAtLaunch・UpdateSupport）は各 `sync` スクリプトがビルド時に上書きするので、直接編集しない。
- 設定項目は [Catalog.swift](Sources/PrefsPreset/Catalog.swift)。項目や画面の文字列を足したら、[Tools/translations.tsv](Tools/translations.tsv) に訳を加えて `python3 Tools/make-strings.py` で Localizable.strings を作り直す（訳の無いキーがあると止まる）。
- アイコンは [Assets/make-icon.sh](Assets/make-icon.sh)（GenerateIcon.swift から .icns を生成）。

## 実装メモ

- 主画面・メニュー・設定ウインドウの構成は BundleIDInspector と同じ。
- `~/Git/PrefsPreset` で作った単一ファイル版（swiftc 直ビルド、Bundle ID `com.swwwitch.PrefsPreset`）は [Backups/20261009-before-baseline](Backups/20261009-before-baseline/) に残した。配布前だったので Bundle ID と書類タイプは `jp.dtp-transit.prefspreset` にそろえた。

## 更新履歴

- 1.1.5（build 8）2026-10-10：「情報」タブの解説記事のリンクを、アプリ専用の note 記事にした（SWNoteArticleURL）。ヘルプの「note記事を開く」も同じ記事を開く。
- 1.1.4（build 7）2026-10-10：設定に「情報」タブ（バージョン・note・X）を追加。自作アプリの目印（SWAppFamily、配置時に Finder タグ）とコピーライトを追加。証明書（PL9S9PXX96）で署名し、ビルドし直してもアクセシビリティ等の許可が引き継がれるようにした。設定は前回開いていたタブで開く。メインウインドウが画面外に復元されたときは中央に戻す。
- 1.1.3（build 6）2026-10-10：⌘1 でもメインウインドウを開けるようにした（メニューの表記は ⌘0 のまま）。
- 1.1.2（build 5）2026-10-10：設定ウインドウの大きさを変えられるようにした。最小は従来の大きさ（480×400）。
- 1.1.1（build 4）2026-10-10：「変更後」の列のメニューが細く潰れて値が読めなかったのを修正。
- 1.1.0（build 3）2026-10-10：おすすめの設定（同梱プリセット）とマイプリセット（iCloud Driveに保存）を追加。カテゴリを整理（文字入力・マウス・トラックパッド・ホットコーナー・アニメーション・ズーム機能・時計・ターミナルを新設）。起動時のサウンド（NVRAM）・キャップスロックインジケータ（機能フラグ）・システムのキーボードショートカット・ポインタのサイズなどの項目を追加。検索欄を標準の検索フィールドに。
- 1.0.1（build 2）2026-10-10：スクリーンショットの「ファイル形式」を入力欄からメニュー（PNG・JPEG・HEIC・TIFF・PDF・GIF・BMP）に変更。
- 1.0.0（build 1）2026-10-09：初版。sw_app の共通仕様（メニュー構成・設定・ヘルプ・常駐・4言語・更新機能の準備中表示・マスタードのアイコン）を適用。
