# 共通仕様の実装と確認

アプリ名：PasteMatchStyle
バージョン/build：1.0.0 (1)
確認OS/CPU：macOS 26 (Darwin 25.6) / arm64
確認日：2026-10-13

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。PasteInARow 1.4.3 の骨格（共通部品・メニュー・設定・署名・配置）を流用した。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 実装済み・実機未確認 | main.swift SingleInstanceLaunch＋LSMultipleInstancesProhibited |
| B02 | ログイン起動設定 | 実装済み・実機未確認 | SMAppService、初期値オフ、状態4種を表示 |
| B03 | ログイン時の非表示 | 実装済み・実機未確認 | LaunchPolicy.isLoginLaunch（LaunchTests PASS） |
| B04 | 常駐と再表示 | 実装済み・実機未確認 | accessory＋MenuBarPresence、keepRunning（初期値オン） |
| B05 | 終了と処理保護 | 実装済み・実機未確認 | アプリメニュー⌘Q・常駐メニュー「終了」、stop()でホットキー・監視を解除 |
| B06 | 標準キー操作 | 実装済み・実機未確認 | ⌘W・⌘,・記録中Esc |
| B07 | ホットキー管理 | 実装済み・実機未確認 | ⇧⌘V の有効/無効・変更・初期値、一時停止は常駐メニュー（ShortcutTests PASS）、登録失敗を表示、HotkeyManifest公開 |
| B08 | 設定・位置の保持 | 実装済み・実機未確認 | UserDefaults（useMenu・menuTitles・restoreClipboard ほか）、ウインドウ位置の自動保存と画面外復帰 |
| B09 | 権限の案内と再判定 | 実装済み・実機未確認 | アクセシビリティのみ（メニュー項目のAXPressと⌘V送信）。理由文・システム設定ボタン |
| B10 | 原本保護・復元 | 実装済み・実機未確認 | 文字だけでペーストした後、約1秒でクリップボードを元に戻す（初期値オン）。changeCountを確認し新しいコピーは上書きしない。「クリップボードの書式を取り除く」は復元不可とツールチップ・ヘルプに明記 |
| B11 | 二重処理・中断対策 | 実装済み・実機未確認 | 連打時は最初のスナップショットを保持（pendingRestore） |
| B12 | 成否・復旧表示 | 実装済み・実機未確認 | メニュー項目使用／文字だけ（復元あり・なし）／失敗理由を区別。クリップボードの本文はログに残さない |
| B13 | 待機負荷・復帰 | 実装済み・実機未確認 | ポーリングなし（アプリ切替通知のみ）。CPU・メモリ計測は未実施 |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 実装済み・画面確認済み | AppHeader＋AppSurface、結果欄は白。/Applications版の主画面をスクリーンショットで確認 |
| B15 | 多言語 | 実装済み | ja/en/zh-Hans/ko 89キー（check_resources PASS）。zh/koのメニュー名はAppKitのMenuCommands.loctableで確認 |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 実装済み・実機未確認 | HelpDocument、ヘルプ⌘?・note記事、情報タブ |
| B17 | プライバシー | 実装済み | 外部通信は更新確認のみ（未設定のため通信なし） |
| B18 | 更新・配布・最終版の配置 | 一部 | /ApplicationsとLatest Buildsへ配置、版・署名・内容一致を確認。Sparkleの配信先・鍵は未設定（準備中表示） |
| B19 | マスタード基調の共通アイコン | 実装済み | Assets/draw-icon.swift（マスタード地＋クリップボード＋「T」バッジ）、目視確認 |
| B20 | 設定のカテゴリ・共通UI | 実装済み・実機未確認 | 起動・常駐／ホットキー／ペースト／対象外アプリ／情報のタブ。2026-10-17：アクセシビリティを共通の AccessibilitySection() に（起動グループの直下）、判定は AccessibilitySection.isTrusted、未許可の失敗表示は AccessibilityText.text("blocked")。独自の accessibilityAllowed / refreshAccessibility は削除 |
| B21 | 対象外アプリ | 実装済み・実機未確認 | 初期値はKMマクログループ「Smart Paste」の除外アプリ（Illustrator・Path Finder・Keynote、check_km_macro PASS）。前面のときはホットキーを解除、メニュー実行前と⌘V送信直前にも再確認。2026-10-17：共通部品 ExcludedApps に移行（ExcludedAppList.swift・独自ビュー・appInfo() を削除、initial は ExcludedDefaults.initial、キー excludedBundleIDs のまま・旧キーなし、onChange でホットキー再登録）。既存の一覧が残ることを defaults read で確認 |
| B22 | 起動時にメインウインドウを表示しない | 実装済み・実機未確認 | StartupWindowView |
| B23 | 開き直しと⌘Tab・⌘0 | 実装済み・実機未確認 | applicationShouldHandleReopen、WindowActivationPolicy、⌘0 |
| B24 | 設定ウインドウのふるまい | 実装済み・実機未確認 | SettingsTabs（タブ記憶・フォーカス枠なし）、最小サイズ |
| B25 | アプリ情報と目印 | 実装済み | SWNoteArticleURL・著作権・SWAppFamily。2026-10-16 SWNoteArticleURL を専用記事に変更（/Applications 版の Info.plist で確認） |
| B26 | 証明書での署名 | 実装済み | TeamIdentifier=PL9S9PXX96 を確認 |
| B27 | 取消と失敗の伝え方 | 実装済み・実機未確認 | 失敗はビープ＋TransientMessage、クリップボードに文字が無いときは「書式を取り除く」を無効 |
| B28 | ウインドウ位置とアクセシビリティの細目 | 実装済み・実機未確認 | 初回中央、画面外復帰、accessibilityLabel |
| B29 | 設定の書き出し・読み込みと同期 | 実装済み・ビルド・配置確認済み・実機UI未確認 | 「情報」の直前に SettingsSharingView の「設定の共有」タブ。共有キー：hotkeyEnabled・pasteShortcut・useMenu・menuTitles・restoreClipboard。onImport でモデルを読み直しホットキーを再登録。GUI操作での書き出し・読み込み・同期は未確認 |
| — | ホットキーの記録欄 | 実装済み・ビルド確認済み・実機未確認 | 2026-10-17：HotkeyField（paste ⇧⌘V）。保存は pasteShortcut の JSON のまま、ShortcutCombo.swift で変換（ComboTests）。登録は HotkeySet（"PMSS"）。独自の ShortcutRow・記録モニター・SingleHotKey と関連の文字列を削除 |

## 確認記録

- ソース確認：実施
- ビルド・自動テスト：実施（test.sh 6件 PASS、build.sh 成功）
- /ApplicationsとLatest Buildsへの配置・版/build/署名・内容一致：実施（新規のため既存版なし）
- /Applicationsのアプリの起動と主画面の表示：確認済み
- ⇧⌘V での実際のペースト（メニュー項目経由・文字だけ経由・クリップボード復元）：未確認（アクセシビリティ未許可のため）
- 再ログイン・別コピー起動・常駐/終了の各操作：未実施
