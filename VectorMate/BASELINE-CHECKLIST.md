# 共通仕様の実装と確認

アプリ名：VectorMate
バージョン/build：1.3.0 / 8
確認OS/CPU：macOS 26（Darwin 25.6）/ Apple Silicon（Intel未確認）
確認日：2026-10-18

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 実装済み・実機未確認 | main.swift SingleInstanceLaunch、LSMultipleInstancesProhibited |
| B02 | ログイン起動設定 | 実装済み・実機未確認 | LoginAtLaunchView（初期値OFF） |
| B03 | ログイン時の非表示 | 実装済み・実機未確認 | LaunchPolicy.isLoginLaunch |
| B04 | 常駐と再表示 | 実装済み・実機未確認 | 通常アプリ（Dock・⌘Tab）＋メニューバー、「ウインドウを閉じても常駐」（初期値ON）、applicationShouldHandleReopen。「Dockとアプリケーションスイッチャーに表示しない」（初期値オフ、Shared/AppStandards/StartupWindow.swift の DockPresence、LoginAtLaunchView に内包、起動時は MenuBarPresence.install で適用）：ビルド確認済み・実機未確認。 |
| B05 | 終了と処理保護 | 実装済み・実機未確認 | 終了時に監視を解除（applicationWillTerminate → watcher.isActive = false） |
| B06 | 標準キー操作 | 実装済み・実機未確認 | ⌘, ⌘W ⌘Q ⌘0 ⌘? |
| B07 | ショートカット管理 | 実装済み・実機未確認 | UIの明るさ ⇧F2／⇧F1：HotkeyField（変更・初期値に戻す・解除）、有効化スイッチ、登録失敗の表示。Illustratorが前面のときだけ登録。一時停止は有効化スイッチで代用 |
| B08 | 設定・位置の保持 | 実装済み・実機未確認 | UserDefaults、setFrameAutosaveName、画面外なら中央 |
| B09 | 権限の案内と再判定 | 実装済み・実機未確認 | AccessibilitySection、アクティブ化時に AXIsProcessTrusted を再判定して監視を張り直す、オートメーション拒否時に設定ボタン |
| B10 | 原本保護・復元 | 実装済み・実機未確認 | プロポーショナルメトリクスのONはIllustratorの取り消し1段。環境設定はチェックボックスが揃わなければキャンセル |
| B11 | 二重処理・中断対策 | 実装済み・実機未確認 | 確認は1本ずつ（実行中の要求は1回にまとめる）、オフ操作中はボタン・メニューを無効 |
| B12 | 成否・復旧表示 | 実装済み・実機未確認 | 前回の結果、失敗理由ごとの文言、操作後に設定キーを読み直し |
| B13 | 待機負荷・復帰 | 実装済み・実機未確認 | イベント駆動（グローバル監視＋前面アプリ判定）。タイマーなし。CPU・メモリ未計測 |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 実装済み・実機未確認 | appHeader、AppSurface、StatusRow の accessibilityLabel |
| B15 | 多言語 | 実装済み・実機未確認 | make-resources.py（ja/en/zh-Hans/ko）、Tests/check_resources.py で鍵・置換子を検査（通過） |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 実装済み・実機未確認 | helpContent、ヘルプメニュー⌘?、常駐メニューのヘルプ |
| B17 | プライバシー | 実装済み・実機未確認 | 外部通信なし、PrivacyInfo.xcprivacy |
| B18 | 更新・配布・最終版の/ApplicationsとLatest Buildsへの配置 | 実装済み・配信未設定 | Shared/Updater（配信先未設定で準備中表示）、publish_latest.py |
| B19 | マスタード基調の共通アイコン | 実装済み | Assets/GenerateIcon.swift（CCAutoUpdateOffと同じタイル、AVと字間の括弧） |
| B20 | 共通UI統一・起動/常駐/起動ショートカットの同一グループ・アクセシビリティも同一タブ内の区画 | 一部 | 起動・常駐タブにログイン起動・起動時非表示・常駐・メニューバー・アクセシビリティ。アプリ起動のホットキーは未実装（CCAutoUpdateOffと同じく残件） |
| B21 | 対象外アプリの設定・処理抑制・標準キー操作の保持 | 適用外 | 作用するのはIllustratorだけ。実行直前に前面がIllustratorか再確認し、キーは消費しない |
| B22 | 手動起動は表示・ログイン自動起動は非表示 | 実機未確認 | 共通StartupWindowで起動経路を判定。旧非表示設定は参照しない。2026-10-24の検証記録を参照 |
| B23 | 開き直しと⌘Tab・⌘0 | 実装済み・実機未確認 | ユーザーの指示で通常アプリ（.regular、常に⌘TabとDockに表示）。WindowActivationPolicyは使わない。Dockからの開き直しは applicationShouldHandleReopen、MenuBarPresence（⌘1） |
| B24 | 設定ウインドウのふるまい | 一部 | 最小サイズ（sizingOptions .minSize）。タブ復元は SettingsTabs 任せ。Escで閉じるは未確認 |
| B25 | アプリ情報と目印 | 実装済み | 情報タブ、SWNoteArticleURL（専用記事）、コピーライト、SWAppFamily |
| B26 | 証明書での署名 | 実装済み | build.sh（301A41C0…、PL9S9PXX96）。developer-id 時は Entitlements.plist（apple-events） |
| B27 | 取消と失敗の伝え方 | 実装済み・実機未確認 | 失敗はビープ＋TransientMessage＋結果欄 |
| B28 | ウインドウ位置とアクセシビリティの細目 | 実装済み・実機未確認 | 初回中央・画面外復帰 |
| B29 | 設定の書き出し・読み込みと同期 | 実装済み・実機未確認 | 「設定の共有」タブ（Shared/SettingsSync）。共有キーは Model.sharedKeys、読み込み後は reloadSharedSettings() |

## 確認記録

- ソース確認：実施
- ビルド・自動テスト：実施（./test.sh 通過、build.sh 警告なし）
- MetricsScript の読み取り（前回状態なし＝書き換えなし）を実機のIllustrator 30.8.2で実行：応答の解析まで確認
- 実機で起動・閉じる・再表示・⌘Q：未実施
- メトリクス変更でのプロポーショナルメトリクスON：ユーザーが実機確認（1.0.2、中央／右揃えのポイント文字。ログで「A 1 sameSelection=true」）
- バックグラウンド保存・書き出しのオフ：ユーザーが実機確認（1.0.0、日本語版Illustrator 30.8.2）
- 再ログイン・OS側で自動起動OFF：未実施
- UIの明るさ・シェイプ形成ツールのカラー・メトリクス以外でOFF：未実施（1.1.0、ユーザーの確認待ち）
- /ApplicationsとLatest Buildsへの配置：1.1.0 (4) を両方に配置、署名・内容一致を確認、/Applications から起動


### B30 2026-10-25改定

メイン・設定ウインドウがある間はDock・⌘Tabとアプリメニューを表示。最小化中も保持し、対象ウインドウをすべて閉じると非表示。パレットは除外。設定値は保持。共通AppKit回帰テスト17項目成功。各アプリのコンパイル結果はShared/ReleasePreparation/20261025-DockMenu/に記録し、個別の画面操作は未確認。署名・公証・配布は未実施。
