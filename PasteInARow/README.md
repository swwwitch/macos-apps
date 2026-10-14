# PasteInARow

![macOS](https://img.shields.io/badge/macOS-13%2B-lightgrey) ![version](https://img.shields.io/badge/version-1.4.3-blue) ![license](https://img.shields.io/badge/license-private-lightgrey)

⌃⌥⌘C で選択中の文字を行に分けてスロットに追加し、⌃⌥V で上から1行ずつ、またはウインドウから好きな行をペーストするメニューバー常駐アプリ。Keyboard Maestro のマクロ「01)連続ペースト」「02)非連続ペースト」（直下の .kmmacros）の移植。

- ビルド：`./build.sh`（署名後に /Applications と Latest Builds へ配置）。配置しない確認用は `SKIP_PUBLISH=1 ./build.sh`
- テスト：`./test.sh`（行の整形、起動、ホットキー、対象外アプリ、4言語の文字列、KMマクロとの一致）
- 文字列：`Resources/*.lproj/Localizable.strings`（ヘルプ本文は `helpText`）
- アイコン：`Assets/draw-icon.swift`

## 構成

| ファイル | 内容 |
| --- | --- |
| Sources/LineRules.swift | マクロの「整形」グループと同じ順の行の整形（行頭の空白・記号・番号の削除、空行を飛ばす。テスト対象） |
| Sources/LinePaster.swift | ⌘C・⌘V の送信、クリップボードの一時使用と復元 |
| Sources/ExcludedAppList.swift | 対象外アプリ（Bundle ID）。初期値は Illustrator・Path Finder・Keynote |
| Sources/HotKey.swift | ⌃⌥⌘C・⌃⌥V の登録 |
| Sources/main.swift | スロットの一覧・★・設定・メニュー |
| そのほか | 共通部品のコピー。原本は Shared |

## 移植の差分

- スロットに入るのは ⌃⌥⌘C で追加した行だけ。ふつうのコピーではスロットは変わらない。
- ★を付けた行はペーストしても消えない。「最初からやり直す」で追加した行を戻せる。
- ウインドウで行を選んで Return（⌥Return で行を残す、⌘Return で改行付き）。

## 更新履歴

- 1.4.3（build 13, 2026-10-13）：⌃⌥⌘C で追加するスロット、★、選んで Return でペースト（1.1.1〜1.4.3 をまとめて記録）。
- 1.1.1（2026-10-13）：最初の公開版。複数行を1行ずつペースト。
