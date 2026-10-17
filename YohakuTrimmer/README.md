# YohakuTrimmer

![macOS](https://img.shields.io/badge/macOS-14%2B-lightgrey) ![version](https://img.shields.io/badge/version-1.1.4-blue) ![license](https://img.shields.io/badge/license-private-lightgrey)

画像の四辺にある同じ色の余白（透明を含む）を切り取り、元画像と同じフォルダに「元の名前-trim.png」で保存するアプリ。ドロップ・⌘O・Finderの「このアプリケーションで開く」で複数枚をまとめて処理する。設定の「設定の共有」タブで、色の許容範囲を `YohakuTrimmer-Settings.plist` に書き出し・読み込みしたり、iCloud Drive・Dropboxなどのフォルダーで複数のMacと同期したりできる。

- ビルド：`Development/build.sh`（署名後に /Applications と Latest Builds へ配置。4言語の文字列も確認）
- テスト：`Development/Tests/ProcessorSmoke.swift`（余白の判定と切り取り）
- 文字列：`Development/Localizations/*.lproj/Localizable.strings`、ヘルプは同じフォルダの `Help.txt`
- アイコン：`Assets/make-icon.swift`

## 構成

| ファイル | 内容 |
| --- | --- |
| Development/Sources/MarginProcessor.swift | 辺ごとに外側から1行ずつ調べて余白を判定（辺の中央のピクセルの色、許容範囲 なし／小8／大32）、切り取り、dpi・向きを引き継いだPNG保存 |
| Development/Sources/YohakuTrimmerApp.swift | 画面・設定・メニュー |
| Development/Sources/LocalHelp.swift・Localization.swift | ヘルプと文字列の読み込み |
| そのほか | 共通部品のコピー。原本は Shared |

## 更新履歴

- 1.1.4（build 6, 2026-10-17）：共通のホットキー記録欄の更新を取り込んだ（［初期値に戻す］でもほかの割り当てとの重複を確かめる）。
- 1.1.3（build 5, 2026-10-17）：「アプリを呼び出すホットキー」を共通の記録欄（Shared/HotkeyRecorder）にした。［変更…］で押したキーを割り当て、［初期値に戻す］で ⌃⌥⌘Y。修飾キーとキーのポップアップはやめた。保存先（shortcutEnabled・shortcutKey・shortcutModifiers）は変えていない。登録は共通の HotkeySet。
- 1.1.2（build 4, 2026-10-17）：設定の共通部品の更新を取り込んだ（「設定の共有」タブの高さは共通部品で合わせ、アプリ側の回避策を外した）。ホットキーのボタンを「初期値に戻す」に改めた。
- 1.1.1（build 3, 2026-10-16）：設定に「設定の共有」タブ（共通部品 SettingsSync）を追加した。色の許容範囲を書き出し・読み込みでき、iCloud Drive・Dropboxなどのフォルダーで同期できる（ログイン時の起動・メニューバー・ホットキーはMacごと）。「情報」タブとヘルプの「note記事を開く」を個別記事（https://note.com/swwwitch/n/n03c9b6ecb00a）にした。
- 1.1.0（build 2, 2026-10-16）：アプリを呼び出すホットキーで、FinderまたはPath Finderで選択している画像をすぐに処理するようにした（KageTrimmerと同じ動作。選択がなければウインドウを表示、App Store版は対象外）。
- 1.0.0（build 1, 2026-10-14）：最初の版。
