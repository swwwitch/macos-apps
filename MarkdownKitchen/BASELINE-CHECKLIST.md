# 共通仕様の実装と確認

アプリ名：MarkdownKitchen
バージョン/build：1.40.0 (85)
確認OS/CPU：macOS 26（Darwin 25.6.0）/ arm64
確認日：2026-10-14

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 実装済み・実機未確認 | MarkdownKitchenApp.swift `SingleInstanceLaunch`（BundleIDInspectorと同じ）、Info.plist LSMultipleInstancesProhibited |
| B02 | ログイン起動設定 | 実装済み・実機未確認 | 共通 LoginAtLaunch.swift。初期値OFF。再ログインは未確認 |
| B03 | ログイン時の非表示 | 実装済み・実機未確認 | StartupWindow.swift（StartupWindowGate） |
| B04 | 常駐と再表示 | 実装済み・実機未確認 | AppDelegate：最後のウインドウを閉じても終了しない、applicationShouldHandleReopen、⌘0。「Dockとアプリケーションスイッチャーに表示しない」（初期値オフ、Shared/AppStandards/StartupWindow.swift の DockPresence を Sources/MarkdownKitchen/StartupWindow.swift に同期、SettingsView の LoginAtLaunchView に内包、起動時は MenuBarPresence.install で適用）：ビルド確認済み・実機未確認。 |
| B05 | 終了と処理保護 | 実装済み・実機未確認 | 長い処理・監視なし。⌘Qは標準のアプリメニュー |
| B06 | 標準キー操作 | 実装済み・実機未確認 | ⌘W・⌘,・⌘Z/⇧⌘Z・⌘F（検索バー）をNSTextViewとメニューで提供 |
| B07 | ショートカット管理 | 適用外 | グローバルホットキーなし。アプリ内の⌘O・⇧⌘Cのみ |
| B08 | 設定・位置の保持 | 実装済み・実機未確認 | 原稿・対象レベル・コピー形式をUserDefaultsに保存。画面外は MainWindow.keepOnScreen |
| B09 | 権限の案内と再判定 | 適用外 | 権限不要 |
| B10 | 原本保護・復元 | 実装済み・実機未確認 | 書き込みは「保存」「別名で保存…」のときだけ。上書き前に Application Support/MarkdownKitchen/Backups へ控え（20件）、外部で変更されていたら確認。読み込み・変換・上げ下げはUndoに載せる |
| B11 | 二重処理・中断対策 | 適用外 | 長い処理なし |
| B12 | 成否・復旧表示 | 実装済み・実機未確認 | 読み込み失敗・コピー件数をウインドウ下部に表示 |
| B13 | 待機負荷・復帰 | 実装済み・実機未確認 | イベント駆動のみ（タイマー・ポーリングなし）。計測は未実施 |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 実機確認済み（表示） | ContentView ヘッダー。2026-10-14 スクリーンショットで確認。ダークモード・VoiceOverは未確認 |
| B15 | 多言語 | 実装済み・実機未確認 | ja/en/zh-Hans/ko。Tests/check-localization.py 通過 |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 実装済み・実機未確認 | Help.txt 4言語、⌘?、「情報」タブ（AboutSection） |
| B17 | プライバシー | 実装済み | 送信なし。プレビューは原稿内の画像URLを読み込む（ヘルプに記載）。更新機能は未設定で通信しない |
| B18 | 更新・配布・最終版の/ApplicationsとLatest Buildsへの配置 | 実機確認済み（配置） | build.sh → publish_latest.py で両方に配置、署名・内容一致を確認。更新配信は未設定 |
| B19 | マスタード基調の共通アイコン | 実装済み | Assets/GenerateIcon.swift（紙＋「#」＋字下げした見出し行） |
| B20 | 共通UI統一・起動/常駐/起動ショートカットの同一グループ・アクセシビリティも同一タブ内の区画 | 実装済み・実機未確認 | SettingsView：起動・常駐／見出し／情報。2026-10-17 1.43.2(101)：起動・常駐を Form(.grouped) から SettingsSection に変更。アクセシビリティ権限は使わないので区画なし。ビルド・テスト・配置・起動確認、見た目は未確認 |
| B21 | 対象外アプリの設定・処理抑制・標準キー操作の保持 | 適用外 | 他アプリに作用しない。2026-10-17 再確認：適用外のまま |
| B29 | 設定の書き出し・読み込みと同期 | 実装済み・実機未確認 | 2026-10-16 1.43.1(100)：SettingsView に「設定の共有」タブ（情報の直前）、AppDelegate.startSettingsSync。共有: markdownKitchen.* のうち sourceText・filePath・fileEdited を除く21キー（テーマは merge で「追加する」）。onImport で ShortcutStore・DoorkeeperPresets を読み直し、右クリック設定を作り直す。test.sh・build.sh 成功・両配置 1.43.1(100) 一致・起動確認。書き出し/読み込み/同期の操作は未確認 |
| ホットキーの記録欄 | 共通の HotkeyField（Shared/HotkeyRecorder） | 実装済み・実機未確認 | 2026-10-17 1.43.5(104)（初期値に戻すの重複確認を取り込み）／1.43.4(103)（⌘か⌃必須の共通部品を取り込み）／1.43.3(102)：設定の「ホットキー」の各行を HotkeyField（defaultCombo＝項目の初期値、allowsClear、others＝ほかの項目とアプリ標準のキー）に。メニューのキー（前面のときだけ）なので HotkeySet は使わない。保存は markdownKitchen.shortcuts の MenuShortcut のまま、MenuShortcutCombo.swift で KeyCombo と変換（test.sh で31件の往復を確認）。独自の NSEvent モニター・記録中/重複の文言を削除。build.sh・test.sh 成功、両配置 1.43.3(102) 一致、/Applications 版の起動確認。記録の操作は未確認 |

## 確認記録

- ソース確認：実施
- ビルド・自動テスト：実施（build.sh 成功、test.sh：HeadingParser 全件・ローカライズ検査 PASS）
- 実機で起動・閉じる・再表示・⌘Q：起動のみ確認
- 再ログイン・OS側で自動起動OFF：未実施
- 別コピー起動・引数/ファイル受け渡し：ファイル受け渡し（open -a で .md を渡す）を確認
