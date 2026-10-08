# BundleIDInspector

アプリをドロップすると、Bundle ID（バンドルID）・表示名・バージョン（build）を一覧に表示し、コピーできるユーティリティです。

- メインウインドウ・Dockアイコンへのドロップ、ファイルメニューの「アプリを選択…」（⌘O）で追加
- 各行の「コピー」、まとめて改行区切りでコピーする「すべてコピー」
- 右クリックで Bundle ID／パスのコピー、Finderで表示、一覧から削除
- Bundle IDを持たないファイル・フォルダは追加せず、理由をウインドウ下部に表示

Info.plist を読むだけで、対象アプリを変更・起動せず、通信もしません。

## ビルド

```sh
./build.sh            # ビルド → 検証 → /Applications と Latest Builds へ配置
NO_DEPLOY=1 ./build.sh  # 配置せず build/ にだけ作る
```

- SwiftPM（`Package.swift`）。ソースは [Sources/BundleIDInspector](Sources/BundleIDInspector/)、文字列・ヘルプは [Localizations](Localizations/)（ja / en / zh-Hans / ko）。
- 共通部品（AppSurface・StartupWindow・SettingsSection・HelpDocument・MenuBarPresence・LoginAtLaunch・UpdateSupport）は各 `sync` スクリプトがビルド時に上書きするので、直接編集しない。
- アイコンは [Assets/make-icon.sh](Assets/make-icon.sh)（GenerateIcon.swift から .icns を生成）。

## 実装メモ

- 設定は SwiftUI の Settings シーンを使わず、自前のウインドウ（`SettingsWindow`）にしている。Settings シーンの「設定…」は位置を動かせず、アップデート項目が「設定…」より上に出てしまうため。これでアプリメニューが AppKit 製の他アプリと同じ「〜について／設定…／アップデート項目／サービス」の順になる。
- 「メニューバー設定…」（MenuBarPresence が差し込む項目）は、起動直後に SwiftUI がメニューを組み直すと消え、アプリを切り替えて戻ったときに再び差し込まれる。共通部品側の挙動。

## 更新履歴

- 1.0.5（build 6）2026-10-08：初版。sw_app の共通仕様（メニュー構成・設定・ヘルプ・常駐・4言語・更新機能の準備中表示）を適用。
