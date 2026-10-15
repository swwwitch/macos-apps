# PasteMatchStyle

![macOS](https://img.shields.io/badge/macOS-13%2B-lightgrey) ![version](https://img.shields.io/badge/version-1.0.2-blue) ![license](https://img.shields.io/badge/license-private-lightgrey)

⇧⌘V で、前面のアプリに「ペーストしてスタイルを合わせる」などのメニュー項目があればそれを、無ければクリップボードの文字だけをペーストするメニューバー常駐アプリ。Keyboard Maestro のマクロ「Paste and Match Style」「Universal Paste Without Style」（直下の .kmmacros）の移植。

- ビルド：`./build.sh`（署名後に /Applications と Latest Builds へ配置）。配置しない確認用は `SKIP_PUBLISH=1 ./build.sh`
- テスト：`./test.sh`（メニュー項目名、起動、ホットキー、対象外アプリ、4言語の文字列、KMマクロとの一致）
- 文字列：`Resources/*.lproj/Localizable.strings`（ヘルプ本文は `helpText`）
- アイコン：`Assets/draw-icon.swift`

## 構成

| ファイル | 内容 |
| --- | --- |
| Sources/MenuTitles.swift | 「書式なしでペースト」にあたるメニュー項目名の一覧（テスト対象） |
| Sources/PlainPaster.swift | メニュー項目の実行（AX）、無いときは文字だけにして ⌘V、約1秒後にクリップボードを復元 |
| Sources/ExcludedAppList.swift | 対象外アプリ（Bundle ID）。初期値は Illustrator・Path Finder・Keynote |
| Sources/HotKey.swift | ⇧⌘V の登録 |
| Sources/main.swift | 画面・設定・メニュー |
| そのほか | 共通部品のコピー。原本は Shared |

## 移植の差分

- 2つのマクロを1つにまとめ、メニュー項目があればそちらを優先する。
- 使うメニュー項目名を設定で編集できる。ペースト後にクリップボードを元に戻す（初期値オン）。
- どちらの方法でペーストしたかを「直前の結果」に表示。

## 更新履歴

- 1.0.2（build 3, 2026-10-14）：設定のショートカットの表示が狭く、⌃⌥⇧⌘ を含むキーが切れていたのを修正（文字の幅に合わせて広がる。全アプリで統一）。
- 1.0.1（build 2, 2026-10-14）：Excel の「貼り付けて書式設定に合わせる」をメニュー項目名の初期値に追加。
- 1.0.0（build 1, 2026-10-14）：最初の版。
