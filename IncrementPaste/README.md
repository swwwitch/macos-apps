# IncrementPaste

![macOS](https://img.shields.io/badge/macOS-13%2B-lightgrey) ![version](https://img.shields.io/badge/version-1.0.5-blue) ![license](https://img.shields.io/badge/license-private-lightgrey)

⌥V を押すたびに、クリップボードの数字・日付・英字を1つ進めてペーストするメニューバー常駐アプリ。Keyboard Maestro のマクロ「increment-paste」（[increment-paste.kmmacros](increment-paste.kmmacros)）の移植。

- ビルド：`./build.sh`（署名後に /Applications と Latest Builds へ配置）。配置しない確認用は `SKIP_PUBLISH=1 ./build.sh`
- テスト：`./test.sh`（増やし方の規則、起動、ホットキー、4言語の文字列、KMマクロとの一致）
- 文字列：`Resources/*.lproj/Localizable.strings`（ヘルプ本文は `helpText`）
- アイコン：`Assets/draw-icon.swift`

## 構成

| ファイル | 内容 |
| --- | --- |
| Sources/Incrementer.swift | 日付（月末・うるう年・曜日）→最後の数字（先頭の0・全角・丸数字）→英字の順で1つ進める規則（テスト対象） |
| Sources/IncrementPaster.swift | クリップボードの書き換え、⌘V の送信、1つ前に戻す |
| Sources/ExcludedApps.swift | 対象外アプリ（共通部品 Shared/ExcludedApps のコピー、キー excludedBundleIDs）。初期値（main.swift の ExcludedDefaults）はマクロと同じ Illustrator・Excel・InDesign・ScreenFlow |
| Sources/HotKey.swift・ShortcutCombo.swift | ⌥V の保存形式（JSON）と KeyCombo への変換。記録欄と登録は共通部品 Shared/HotkeyRecorder（HotkeyField・HotkeySet） |
| Sources/main.swift | 画面・設定・メニュー |
| そのほか | 共通部品のコピー。原本は Shared |

## 移植の差分

- 日付・英字（A→B、Z→AA）・丸数字も進める。設定で日付・英字をオフにできる。
- 「コピー直後の1回目はそのままペーストする」を設定で選べる（初期値オフ＝マクロと同じ）。
- 進めすぎたときに「クリップボードを1つ前に戻す」。増やせなかったときはクリップボードを書き換えない。

## 設定の共有

設定の「設定の共有」タブ（「情報」の直前、共通部品 Shared/SettingsSync）で、「書き出し・読み込み」（IncrementPaste-Settings.plist）と「設定の同期」（iCloud Drive・Dropbox などのフォルダー）を使える。共有するのはホットキー（有効・キー）と増やし方（量・日付・英字・1回目の扱い・ペーストごとの表示）。ログイン時の起動・起動時非表示・常駐・メニューバー・対象外アプリはMacごとに残る。

## 更新履歴

- 1.1.0（build 8, 2026-10-20）：設定の［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（オンにするとウインドウを開いているときもDockと⌘Tabの切り替えにアイコンを出さない。メニューバーのアイコンか、Finderからアプリを開き直すと表示できる。全アプリ共通の部品 StartupWindow.swift の DockPresence）。ヘルプ（4言語）に追記。
- 1.0.6（build 7, 2026-10-17）：メインウインドウのアイコンの下にバージョンとbuild番号を表示。
- 1.0.5（build 6, 2026-10-17）：設定のホットキー欄を全アプリ共通の部品に（［変更…］［初期値に戻す］、記録中の案内・重複や登録失敗の表示をそろえ、記録中はホットキーを一時的に外す）。有効化のスイッチは「ホットキーを有効にする」に。保存形式はそのまま。初期値が ⌥V のため、この欄は ⌥ だけのキーも記録できる。
- 1.0.4（build 5, 2026-10-17）：設定の「対象外アプリ」を全アプリ共通の部品に置き換え（一覧・追加…・削除・文言をそろえた。登録済みの一覧はそのまま引き継ぐ）。「起動・常駐」の「アクセシビリティ」を共通の部品に、未許可で実行できなかったときの表示を共通の文言に。英語などの文言をそろえた。
- 1.0.3（build 4, 2026-10-16）：設定に「設定の共有」タブを追加（書き出し・読み込み、iCloud Drive・Dropboxなどでの同期）。「情報」タブとヘルプの「note記事を開く」を専用の記事に変更。
- 1.0.2（build 3, 2026-10-16）：画面・ヘルプからKeyboard Maestroマクロに関する説明を削除。
- 1.0.1（build 2, 2026-10-14）：設定のショートカットの表示が狭く、⌃⌥⇧⌘ を含むキーが切れていたのを修正（文字の幅に合わせて広がる。全アプリで統一）。
- 1.0.0（build 1, 2026-10-14）：最初の版。

## 2026-10-25 Dock非表示時のメニュー修正（1.1.0 build 11）

メイン・設定ウインドウがある間はアプリメニューを使用でき、最小化中もDock・⌘Tabに残ります。最後の対象ウインドウを閉じると再び隠し、非アクティブパレットと保存済みの設定値を保持します。

Developer ID署名・アプリ/DMG公証Accepted。両配置先の内容・署名・公証チケットと、/Applications版の起動を確認。 各アプリの画面操作と実ログインの確認範囲は別途配布記録に記載。
