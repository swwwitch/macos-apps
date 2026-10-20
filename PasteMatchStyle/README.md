# PasteMatchStyle

![macOS](https://img.shields.io/badge/macOS-13%2B-lightgrey) ![version](https://img.shields.io/badge/version-1.0.6-blue) ![license](https://img.shields.io/badge/license-private-lightgrey)

⇧⌘V で、前面のアプリに「ペーストしてスタイルを合わせる」などのメニュー項目があればそれを、無ければクリップボードの文字だけをペーストするメニューバー常駐アプリ。Keyboard Maestro のマクロ「Paste and Match Style」「Universal Paste Without Style」（直下の .kmmacros）の移植。

- ビルド：`./build.sh`（署名後に /Applications と Latest Builds へ配置）。配置しない確認用は `SKIP_PUBLISH=1 ./build.sh`
- テスト：`./test.sh`（メニュー項目名、起動、ホットキー、4言語の文字列、KMマクロとの一致）
- 文字列：`Resources/*.lproj/Localizable.strings`（ヘルプ本文は `helpText`）
- アイコン：`Assets/draw-icon.swift`

## 構成

| ファイル | 内容 |
| --- | --- |
| Sources/MenuTitles.swift | 「書式なしでペースト」にあたるメニュー項目名の一覧（テスト対象） |
| Sources/PlainPaster.swift | メニュー項目の実行（AX）、無いときは文字だけにして ⌘V、約1秒後にクリップボードを復元 |
| Sources/ExcludedApps.swift | 対象外アプリ（共通部品 Shared/ExcludedApps のコピー、キー excludedBundleIDs）。初期値（main.swift の ExcludedDefaults）は Illustrator・Path Finder・Keynote |
| Sources/HotKey.swift・ShortcutCombo.swift | ⇧⌘V の保存形式（JSON）と KeyCombo への変換。記録欄と登録は共通部品 Shared/HotkeyRecorder（HotkeyField・HotkeySet） |
| Sources/main.swift | 画面・設定・メニュー |
| そのほか | 共通部品のコピー。原本は Shared |

## 移植の差分

- 2つのマクロを1つにまとめ、メニュー項目があればそちらを優先する。
- 使うメニュー項目名を設定で編集できる。ペースト後にクリップボードを元に戻す（初期値オン）。
- どちらの方法でペーストしたかを「直前の結果」に表示。

## 設定の共有

設定の「設定の共有」タブ（「情報」の直前、共通部品 Shared/SettingsSync）で、「書き出し・読み込み」（PasteMatchStyle-Settings.plist）と「設定の同期」（iCloud Drive・Dropbox などのフォルダー）を使える。共有するのはホットキー（有効・キー）とペーストの方法（メニュー項目を使う・メニュー項目名・クリップボードを元に戻す）。ログイン時の起動・起動時非表示・常駐・メニューバー・対象外アプリはMacごとに残る。

## 更新履歴

- 1.0.7（build 8, 2026-10-17）：メインウインドウのアイコンの下にバージョンとbuild番号を表示。
- 1.0.6（build 7, 2026-10-17）：設定のホットキー欄を全アプリ共通の部品に（［変更…］［初期値に戻す］、記録中の案内・重複や登録失敗の表示をそろえ、記録中はホットキーを一時的に外す）。有効化のスイッチは「ホットキーを有効にする」に。保存形式はそのまま。
- 1.0.5（build 6, 2026-10-17）：設定の「対象外アプリ」を全アプリ共通の部品に置き換え（一覧・追加…・削除・文言をそろえた。登録済みの一覧はそのまま引き継ぐ）。「起動・常駐」の「アクセシビリティ」を共通の部品に、未許可で実行できなかったときの表示を共通の文言に。常駐・初期値に戻すなどの文言をそろえた。
- 1.0.4（build 5, 2026-10-16）：設定に「設定の共有」タブを追加（書き出し・読み込み、iCloud Drive・Dropboxなどでの同期）。「情報」タブとヘルプの「note記事を開く」を専用の記事に変更。
- 1.0.3（build 4, 2026-10-16）：画面・ヘルプからKeyboard Maestroマクロに関する説明を削除。
- 1.0.2（build 3, 2026-10-14）：設定のショートカットの表示が狭く、⌃⌥⇧⌘ を含むキーが切れていたのを修正（文字の幅に合わせて広がる。全アプリで統一）。
- 1.0.1（build 2, 2026-10-14）：Excel の「貼り付けて書式設定に合わせる」をメニュー項目名の初期値に追加。
- 1.0.0（build 1, 2026-10-14）：最初の版。
