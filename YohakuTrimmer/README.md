# YohakuTrimmer

![macOS](https://img.shields.io/badge/macOS-14%2B-lightgrey) ![version](https://img.shields.io/badge/version-1.0.0-blue) ![license](https://img.shields.io/badge/license-private-lightgrey)

画像の四辺にある同じ色の余白（透明を含む）を切り取り、元画像と同じフォルダに「元の名前-trim.png」で保存するアプリ。ドロップ・⌘O・Finderの「このアプリケーションで開く」で複数枚をまとめて処理する。

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

- 1.0.0（build 1, 2026-10-14）：最初の版。
