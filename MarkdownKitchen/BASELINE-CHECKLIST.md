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

## 1.47.0 (115) — 2026-10-23

- B07/B08: ツールの27コマンドとDoorkeeper各テーマを既存ShortcutStore/HotkeyFieldで管理。既存ID・保存形式を保持、テーマはUUIDで識別。初期キーなし、既存コマンドとテーマ間の重複、⌘N/⌃⌘Nも予約キーとして確認。ソース確認・リリースコンパイル済み。UI操作接続が切れたため、新規キー割り当て→実行→再起動保持の実機確認は未確認。
- B10/B17: テキスト変換ダイアログは選択範囲または全文のコピーを読み込み、原稿を書き換えない。指定されたCSS Niteツールの変換関数をそのまま同梱。非永続WebKit、CSPで外部通信を禁止。UTF-8のtxt保存を実機確認。コピー・設定保持の実機確認は未確認。
- B15/B16: 新規ネイティブメニュー・ヘルプは4言語、整合検査PASS。移植したHTMLダイアログ内部は元ツールの日本語UI。ヘルプを開く実機確認は未確認。
- B18: 署名済みビルド成功。既存版のBundle ID一致、共通deploy_both.pyで両配置先をバックアップ後に更新。/ApplicationsとDropbox Latest Buildsとも1.47.0 (115)、署名・ファイル内容一致。/Applicationsから起動・ツールメニュー・変換ダイアログ・txt保存確認済み。
- 自動検証: test.sh PASS（HeadingParser等、MenuShortcutCombo 33往復、4言語整合）。node Tests/MarkdownTextCheck.js PASS（9項目）。27コマンドの設定掲載を検査。元サイトと変換関数の一致を検査。メニューバー共通構成の変更なし。整形ポップアップの先頭順序はソース確認、実機未確認。


### B30 2026-10-25改定

メイン・設定ウインドウがある間はDock・⌘Tabとアプリメニューを表示。最小化中も保持し、対象ウインドウをすべて閉じると非表示。パレットは除外。設定値は保持。共通AppKit回帰テスト17項目成功。各アプリのコンパイル結果はShared/ReleasePreparation/20261025-DockMenu/に記録し、個別の画面操作は未確認。署名・公証・配布は未実施。

## 1.47.1 (119) — 2026-10-25 書類ウインドウ管理

- ソース：DocumentWindowRegistryで作成中・非表示・最小化中も同一書類のウインドウを一つに制限。復元書類をファイル受信前に読み込み、実ファイル同一性で照合。新規は独立書類。全削除を含む未保存内容を保護。
- 自動検証：HeadingParser、MenuShortcutCombo 33件、4言語整合、MarkdownText 9件PASS。追加DocumentWindowRegistryCheck（作成予約・重複所有・再オープン・別書類・シンボリックリンク・ハードリンク）PASS。
- ビルド・配置：build.sh成功。deploy_both.pyでバックアップ後に/ApplicationsとLatest Buildsへ配置。両方1.47.1 (119)、署名・内容一致。
- 実機：/Applications版でFinderから同じA.mdを再オープンし同一ウインドウに復帰、B.mdは独立、新規で元のA.md保持。B.md最小化後の再オープンで同一ウインドウ復帰。全削除後の⌘Wで保存確認。通常終了後にFinderからA.mdで起動し、閉じたあと残存ウインドウなしを確認。検証用書類の変更は保存せず終了。
- 未確認：過去の競合した復元データの実機移行、再ログイン、別Mac。公証・公開リリースは未実施。

## 1.47.2 (122) — 2026-10-26 クラッシュ修正

- 提供レポートとDiagnosticReportsの119を確認。120で全閉じ後の再オープン、121でもObservation/SwiftUI環境の不正参照が再発したため採用せず、122でWindowGroup/openWindowを廃止。書類ごとのNSWindowControllerとNSHostingViewに変更し、SwiftUIは原稿表示とメニューに限定。
- ファイル受信はDocumentOpenEventsへ一本化。日本語・空白・複数URL・不正入力の自動テストPASS。既存HeadingParser・MenuShortcutCombo・4言語・MarkdownText・同一ファイル判定テストPASS。

- 122の実機検証：全閉じ→Finderで2書類再オープンを5回完了。同じPID 28235を前後で確認し、122のDiagnosticReportsは0件。日本語・空白のあるファイル名、同じ2書類の再オープン5回、新規、赤い閉じるボタンで未保存の保存確認を確認。正常終了（実行中一覧から消失）後、Finderから2書類で再起動成功。検証用変更は保存せず破棄。
- ビルド・配置：1.47.2 (122) build.sh成功、/Applications・Latest Buildsとも署名・内容一致。実機検証は/Applications版。長時間利用、スリープ復帰、別Mac、公証・公開リリースは未確認／未実施。

## 1.47.3 (124) — 2026-10-26

設定の空白表示、リサイズ指定、文書名更新、エディター・プレビュー解放を修正。自動テスト／ローカライズ／ビルド／両配置先一致PASS。実機確認範囲と未確認点、追加レビュー所見はRELEASE-VERIFICATION-20261026.md参照。

## 1.47.3 (125) — 2026-10-26 設定リサイズ再修正

- 124では端ドラッグできないとのユーザー報告。SwiftUI Settingsシーンのウインドウを採用する方式を廃止し、システム経由の表示も専用AppKitウインドウへ転送。シーンのview graphは閉じずに保持する。
- 専用NSHostingViewはminSizeのみを報告。設定ウインドウのサイズ・位置を自動保存。設定項目・保存キーは維持。
- build.sh・4言語整合・署名検証成功。/ApplicationsとLatest Buildsとも125、署名・内容一致。起動、⌘,で内容表示、ネイティブ拡大と元サイズへの復帰を実機確認。確認時の125クラッシュレポート0件。端ドラッグは操作ツールでは変化を確認できず、ユーザー確認待ち。

## 1.47.3 (126) — 2026-10-29 ツールバーメニュー再編・Swift 6.4対応

- 188a6c7（ツールバーに「書式」メニューを追加し、旧「整形」を「ツール」、旧「Doorkeeper用に整形」を「整形」に改名）は125からの変更だが番号が据え置きだったため、配布前に公証Mac（MacBookPro13-M5-2025）でbuildのみ126へ更新。4言語の訳語は既存。
- 共有SettingsSync.swiftの `fileImport` を `@MainActor` クロージャ型に変更（Swift 6.4／Xcode 27.1でのSendingRisksDataRaceビルドエラー対応、挙動変更なし）。
- Latest Builds 12本の再配置（RELEASE-QUEUE 2026-10-29）で公証・配置。新メニューの実機操作は未確認。
