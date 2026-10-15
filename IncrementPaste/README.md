# IncrementPaste

![macOS](https://img.shields.io/badge/macOS-13%2B-lightgrey) ![version](https://img.shields.io/badge/version-1.0.1-blue) ![license](https://img.shields.io/badge/license-private-lightgrey)

⌥V を押すたびに、クリップボードの数字・日付・英字を1つ進めてペーストするメニューバー常駐アプリ。Keyboard Maestro のマクロ「increment-paste」（[increment-paste.kmmacros](increment-paste.kmmacros)）の移植。

- ビルド：`./build.sh`（署名後に /Applications と Latest Builds へ配置）。配置しない確認用は `SKIP_PUBLISH=1 ./build.sh`
- テスト：`./test.sh`（増やし方の規則、起動、ホットキー、対象外アプリ、4言語の文字列、KMマクロとの一致）
- 文字列：`Resources/*.lproj/Localizable.strings`（ヘルプ本文は `helpText`）
- アイコン：`Assets/draw-icon.swift`

## 構成

| ファイル | 内容 |
| --- | --- |
| Sources/Incrementer.swift | 日付（月末・うるう年・曜日）→最後の数字（先頭の0・全角・丸数字）→英字の順で1つ進める規則（テスト対象） |
| Sources/IncrementPaster.swift | クリップボードの書き換え、⌘V の送信、1つ前に戻す |
| Sources/ExcludedAppList.swift | 対象外アプリ（Bundle ID）。初期値はマクロと同じ Illustrator・Excel・InDesign・ScreenFlow |
| Sources/HotKey.swift | ⌥V の登録 |
| Sources/main.swift | 画面・設定・メニュー |
| そのほか | 共通部品のコピー。原本は Shared |

## 移植の差分

- 日付・英字（A→B、Z→AA）・丸数字も進める。設定で日付・英字をオフにできる。
- 「コピー直後の1回目はそのままペーストする」を設定で選べる（初期値オフ＝マクロと同じ）。
- 進めすぎたときに「クリップボードを1つ前に戻す」。増やせなかったときはクリップボードを書き換えない。

## 更新履歴

- 1.0.1（build 2, 2026-10-14）：設定のショートカットの表示が狭く、⌃⌥⇧⌘ を含むキーが切れていたのを修正（文字の幅に合わせて広がる。全アプリで統一）。
- 1.0.0（build 1, 2026-10-14）：最初の版。
