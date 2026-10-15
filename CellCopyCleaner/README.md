# CellCopyCleaner

![macOS](https://img.shields.io/badge/macOS-13%2B-lightgrey) ![version](https://img.shields.io/badge/version-1.1.2-blue) ![license](https://img.shields.io/badge/license-private-lightgrey)

Microsoft Excel・Googleスプレッドシートでセルを選んで ⌥⌘C を押すと、セル内改行で付く「"」などを取り除いてクリップボードに入れ直すメニューバー常駐アプリ。Keyboard Maestro のマクロ「コピー時、セル内改行使用時に付加される「"」を削除」の移植。

- ビルド：`./build.sh`（署名後に /Applications と Latest Builds へ配置。App Store用は `APP_STORE_BUILD=1`）
- テスト：`./test.sh`（整形の規則、起動、ホットキー、4言語の文字列、KMマクロとの一致。マクロは sw_app 直下に置いたときだけ照合）
- 文字列：`Resources/*.lproj/Localizable.strings`（ヘルプ本文は `helpText`）
- アイコン：`Assets/draw-icon.swift`

## 構成

| ファイル | 内容 |
| --- | --- |
| Sources/CleanRules.swift | Excel・Googleスプレッドシートそれぞれの整形の規則（マクロから書き起こし、テスト対象） |
| Sources/ClipboardCleaner.swift | 対象アプリへの ⌘C、クリップボードの読み書き、元の内容への復元 |
| Sources/HotKey.swift | ⌥⌘C の登録（対象アプリが前面のときだけ） |
| Sources/main.swift | 画面・設定・メニュー |
| そのほか | 共通部品のコピー（AboutSection・AccessibilityPermission・AppHeader・AppSurface・HelpDocument・HotkeyManifest・LaunchPolicy・MenuBarPresence・SettingsSection・StartupWindow・UpdateSupport・WindowActivationPolicy）。原本は Shared |

## 移植の差分

- 対象アプリ（Excel・Chrome・Safari・Firefox）以外が前面のときは ⌥⌘C を登録せず、そのアプリ本来の操作に渡す。ブラウザーはGoogleスプレッドシートのウインドウのときだけ処理する。
- 整える前の内容（文字・HTML・RTF）を控え、「元のコピー内容に戻す」で戻せる。
- アポストロフィ→「"」の置き換えを設定でオン・オフできる。

## 更新履歴

- 1.1.2（build 5, 2026-10-14）：設定のショートカットの表示が狭く、⌃⌥⇧⌘ を含むキーが切れていたのを修正（文字の幅に合わせて広がる。全アプリで統一）。
- 1.1.1（build 4, 2026-10-13）：現行版。一時停止を設定から外し、メニューバーのメニューだけに。これより前の履歴は記録なし。
