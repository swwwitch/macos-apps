# PasteInARow

![macOS](https://img.shields.io/badge/macOS-13%2B-lightgrey) ![version](https://img.shields.io/badge/version-1.4.8-blue) ![license](https://img.shields.io/badge/license-private-lightgrey)

⌃⌥⌘C で選択中の文字を行に分けてスロットに追加し、⌃⌥V で上から1行ずつ、またはウインドウから好きな行をペーストするメニューバー常駐アプリ。Keyboard Maestro のマクロ「01)連続ペースト」「02)非連続ペースト」（直下の .kmmacros）の移植。

- ビルド：`./build.sh`（署名後に /Applications と Latest Builds へ配置）。配置しない確認用は `SKIP_PUBLISH=1 ./build.sh`
- テスト：`./test.sh`（行の整形、起動、ホットキー、4言語の文字列、KMマクロとの一致）
- 文字列：`Resources/*.lproj/Localizable.strings`（ヘルプ本文は `helpText`）
- アイコン：`Assets/draw-icon.swift`

## 構成

| ファイル | 内容 |
| --- | --- |
| Sources/LineRules.swift | マクロの「整形」グループと同じ順の行の整形（行頭の空白・記号・番号の削除、空行を飛ばす。テスト対象） |
| Sources/LinePaster.swift | ⌘C・⌘V の送信、クリップボードの一時使用と復元 |
| Sources/ExcludedApps.swift | 対象外アプリ（共通部品 Shared/ExcludedApps のコピー、キー excludedBundleIDs）。初期値（main.swift の ExcludedDefaults）は Illustrator・Path Finder・Keynote |
| Sources/HotKey.swift・ShortcutCombo.swift | ⌃⌥⌘C・⌃⌥V の保存形式（JSON）と KeyCombo への変換。記録欄と登録は共通部品 Shared/HotkeyRecorder（HotkeyField・HotkeySet） |
| Sources/main.swift | スロットの一覧・★・設定・メニュー |
| そのほか | 共通部品のコピー。原本は Shared |

## 移植の差分

- スロットに入るのは ⌃⌥⌘C で追加した行だけ。ふつうのコピーではスロットは変わらない。
- ★を付けた行はペーストしても消えない。「最初からやり直す」で追加した行を戻せる。
- ウインドウで行を選んで Return（⌥Return で行を残す、⌘Return で改行付き）。

## 設定の共有

設定の「設定の共有」タブ（「情報」の直前、共通部品 Shared/SettingsSync）で、「書き出し・読み込み」（PasteInARow-Settings.plist）と「設定の同期」（iCloud Drive・Dropbox などのフォルダー）を使える。共有するのはホットキー2つ（有効・キー）と貼り付け方（行の整形・空になったら閉じる・ペーストごとの表示）。ログイン時の起動・起動時非表示・常駐・メニューバー・対象外アプリはMacごとに残る。

## 更新履歴

- 1.5.0（build 20, 2026-10-20）：設定の［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（オンにするとDockと⌘Tabに出さない。メニューバーのアイコンか、Finderから開き直すとメインウインドウを表示）。ヘルプにも記載。
- 1.4.9（build 19, 2026-10-17）：メインウインドウのアイコンの下にバージョンとbuild番号を表示。
- 1.4.8（build 18, 2026-10-17）：設定のホットキー欄を全アプリ共通の部品に（［変更…］［初期値に戻す］、記録中の案内・重複や登録失敗の表示をそろえ、記録中はホットキーを一時的に外す）。有効化のスイッチは「ホットキーを有効にする」に。保存形式はそのまま。⌃⌥V と ⌃⌥⌘C は互いに同じキーにできない。
- 1.4.7（build 17, 2026-10-17）：設定の「対象外アプリ」を全アプリ共通の部品に置き換え（一覧・追加…・削除・文言をそろえた。登録済みの一覧はそのまま引き継ぐ）。「起動・常駐」の「アクセシビリティ」を共通の部品に、未許可で実行できなかったときの表示を共通の文言に。英語などの文言をそろえた。
- 1.4.6（build 16, 2026-10-16）：設定に「設定の共有」タブを追加（書き出し・読み込み、iCloud Drive・Dropboxなどでの同期）。「情報」タブとヘルプの「note記事を開く」を専用の記事に変更。
- 1.4.5（build 15, 2026-10-16）：画面・ヘルプからKeyboard Maestroマクロに関する説明を削除。
- 1.4.4（build 14, 2026-10-14）：設定のショートカットの表示が狭く、⌃⌥⇧⌘ を含むキーが切れていたのを修正（文字の幅に合わせて広がる。全アプリで統一）。
- 1.4.3（build 13, 2026-10-13）：⌃⌥⌘C で追加するスロット、★、選んで Return でペースト（1.1.1〜1.4.3 をまとめて記録）。
- 1.1.1（2026-10-13）：最初の公開版。複数行を1行ずつペースト。

## 2026-10-25 Dock非表示時のメニュー修正（1.5.0 build 23）

メイン・設定ウインドウがある間はアプリメニューを使用でき、最小化中もDock・⌘Tabに残ります。最後の対象ウインドウを閉じると再び隠し、非アクティブパレットと保存済みの設定値を保持します。

Developer ID署名・アプリ/DMG公証Accepted。両配置先の内容・署名・公証チケットと、/Applications版の起動を確認。 各アプリの画面操作と実ログインの確認範囲は別途配布記録に記載。
