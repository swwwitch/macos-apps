# 共通仕様の実装と確認

アプリ名：PasteInARow
バージョン/build：1.0.0 (1)
確認OS/CPU：macOS 26 (Darwin 25.6) / arm64
確認日：2026-10-13

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 実装済み・実機未確認 | main.swift SingleInstanceLaunch＋LSMultipleInstancesProhibited（CellCopyCleanerと同一） |
| B02 | ログイン起動設定 | 実装済み・実機未確認 | SMAppService、初期値オフ、状態4種を表示 |
| B03 | ログイン時の非表示 | 実装済み・実機未確認 | LaunchPolicy.isLoginLaunch（LaunchTests PASS） |
| B04 | 常駐と再表示 | 実装済み・実機未確認 | accessory＋MenuBarPresence、keepRunning（初期値オン）。2026-10-20：「起動・常駐」に「Dockとアプリケーションスイッチャーに表示しない」（共通部品 DockPresence、StartupWindowView 内で「起動時にメインウインドウを表示しない」の直下。WindowActivationPolicy.update が .accessory を保つ）。ビルド確認済み・実機未確認 |
| B05 | 終了と処理保護 | 実装済み・実機未確認 | アプリメニュー⌘Q・常駐メニュー「終了」、stop()でホットキー・監視を解除 |
| B06 | 標準キー操作 | 実装済み・実機未確認 | ⌘W・⌘,・記録中Esc |
| B07 | ショートカット管理 | 実装済み・実機未確認 | 有効/無効・変更・初期値は設定、一時停止はメニューバーのメニューのみ（ShortcutTests PASS）、登録失敗を表示、HotkeyManifest公開 |
| B08 | 設定・位置の保持 | 実装済み・実機未確認 | UserDefaults、ウインドウ位置の自動保存と画面外復帰 |
| B09 | 権限の案内と再判定 | 実装済み・実機未確認 | アクセシビリティのみ。理由文・システム設定ボタン、起動・常駐タブで再判定 |
| B10 | 原本保護・復元 | 実装済み・実機未確認 | クリップボードはKMマクロと同じく残り行に置き換える仕様（ヘルプに明記）。書き戻し前にchangeCountを確認し新しいコピーを上書きしない。「最初の行からやり直す」で全文を戻せる |
| B11 | 二重処理・中断対策 | 実装済み・実機未確認 | 連打はメモリ上の行キューで処理し、遅延書き戻しは新しい書き込みがあれば破棄 |
| B12 | 成否・復旧表示 | 実装済み・実機未確認 | 成功（残り行数・最後の行）／失敗理由を区別。本文はログに残さない |
| B13 | 待機負荷・復帰 | 実装済み・実機未確認 | ポーリングなし（アプリ切替通知のみ）。CPU・メモリ計測は未実施 |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 実装済み・画面確認済み | AppHeader＋AppSurface、行一覧は白、VoiceOverラベル。開発ビルドの主画面をスクリーンショットで確認 |
| B15 | 多言語 | 実装済み | ja/en/zh-Hans/ko 97キー（check_resources PASS） |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 実装済み・実機未確認 | HelpDocument、ヘルプ⌘?・note記事、情報タブ |
| B17 | プライバシー | 実装済み | 外部通信は更新確認のみ（未設定のため通信なし） |
| B18 | 更新・配布・最終版の/ApplicationsとLatest Buildsへの配置 | 一部 | /ApplicationsとLatest Buildsへ配置、版・署名・内容一致を確認。Sparkleの配信先・鍵は未設定（準備中表示） |
| B19 | マスタード基調の共通アイコン | 実装済み | Assets/draw-icon.swift（マスタード地＋行リスト＋矢印バッジ）、目視確認 |
| B20 | 共通UI統一・起動/常駐/起動ショートカットの同一グループ・アクセシビリティも同一タブ内の区画 | 実装済み・実機未確認 | 起動・常駐／ホットキー／ペースト／対象外アプリ／情報のタブ。2026-10-17：アクセシビリティを共通の AccessibilitySection() に（起動グループの直下）、判定は AccessibilitySection.isTrusted、未許可の失敗表示は AccessibilityText.text("blocked")。独自の accessibilityAllowed / refreshAccessibility は削除 |
| B21 | 対象外アプリの設定・処理抑制・標準キー操作の保持 | 実装済み・実機未確認 | 初期値はKMマクロの除外アプリ（Illustrator・Path Finder・Keynote）。対象外が前面のときはホットキーを解除、送信直前にも再確認（ExcludedTests PASS）。2026-10-17：共通部品 ExcludedApps に移行（ExcludedAppList.swift・独自ビュー・appInfo() を削除、initial は ExcludedDefaults.initial、キー excludedBundleIDs のまま・旧キーなし、onChange でホットキー再登録）。既存の一覧が残ることを defaults read で確認 |

## 確認記録

- ソース確認：実施
- ビルド・自動テスト：実施（test.sh 6件 PASS、build.sh 成功）
- 実機で起動・閉じる・再表示・⌘Q：未実施
- 再ログイン・OS側で自動起動OFF：未実施
- 別コピー起動・引数/ファイル受け渡し：未実施
- 設定保持・更新・配布物確認：未実施
- /ApplicationsとLatest Buildsへの配置・両配置先の版/build/署名・内容一致確認：実施（新規のため既存版なし）
- /Applicationsのアプリを起動して動作確認：起動のみ確認。アクセシビリティ未許可のため⌃⌥Vでのペーストは未確認

| B22 | 手動起動は表示・ログイン自動起動は非表示 | 実機未確認 | 共通StartupWindowで起動経路を判定。旧非表示設定は参照しない。2026-10-24の検証記録を参照 |
| B23 | 開き直しと⌘Tab・⌘0 | 実装済み・実機未確認 | applicationShouldHandleReopen、WindowActivationPolicy、⌘0 |
| B24 | 設定ウインドウのふるまい | 実装済み・実機未確認 | SettingsTabs（タブ記憶・フォーカス枠なし）、最小サイズ |
| B25 | アプリ情報と目印 | 実装済み | Info.plistにSWNoteArticleURL・著作権・SWAppFamily。2026-10-16 SWNoteArticleURL を専用記事に変更（/Applications 版の Info.plist で確認） |
| B26 | 証明書での署名 | 実装済み | TeamIdentifier=PL9S9PXX96 を確認 |
| B27 | 取消と失敗の伝え方 | 実装済み・実機未確認 | 失敗はビープ＋TransientMessage、やり直し不可時はメニュー無効 |
| B28 | ウインドウ位置とアクセシビリティの細目 | 実装済み・実機未確認 | 初回中央、画面外復帰、accessibilityLabel |
| B29 | 設定の書き出し・読み込みと同期 | 実装済み・ビルド・配置確認済み・実機UI未確認 | 「情報」の直前に SettingsSharingView の「設定の共有」タブ。共有キー：hotkeyEnabled・pasteShortcut・addEnabled・addShortcut・trimIndent・stripMarkers・notifyEach・closeWhenEmpty。onImport でモデルを読み直しホットキーを再登録。GUI操作での書き出し・読み込み・同期は未確認 |
| — | ホットキーの記録欄 | 実装済み・ビルド確認済み・実機未確認 | 2026-10-17：HotkeyField 2つ（paste ⌃⌥V／add ⌃⌥⌘C、others で相互の重複を断る）。保存は pasteShortcut・addShortcut の JSON のまま、ShortcutCombo.swift で変換（ComboTests）。登録は HotkeySet（"PSUC"、1・2）。独自の ShortcutRow・記録モニター・SingleHotKey・重複/失敗の文言を削除 |


### B30 2026-10-25改定

メイン・設定ウインドウがある間はDock・⌘Tabとアプリメニューを表示。最小化中も保持し、対象ウインドウをすべて閉じると非表示。パレットは除外。設定値は保持。共通AppKit回帰テスト17項目成功。各アプリのコンパイル結果はShared/ReleasePreparation/20261025-DockMenu/に記録し、個別の画面操作は未確認。署名・公証・配布は未実施。
