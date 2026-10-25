# 共通仕様の実装と確認

アプリ名：ControlMate
バージョン/build：1.3.0 (4)
確認OS/CPU：macOS 26（Darwin 25.6.0）/ Apple シリコン
確認日：2026-10-26

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 実装済み・実機未確認 | main.swift SingleInstanceLaunch（FnNumpad と同じ）、Info.plist LSMultipleInstancesProhibited |
| B02 | ログイン起動設定 | 実装済み・実機未確認 | 設定［起動・常駐］LoginAtLaunchView（初期値OFF） |
| B03 | ログイン時の非表示 | 実装済み・実機未確認 | LaunchPolicy.isLoginLaunch／StartupWindow.suppressInitialWindow |
| B04 | 常駐と再表示 | 実装済み・実機未確認 | accessory＋メニューバーのアイコン、「ウインドウを閉じても常駐」（keepRunning、初期値ON）、applicationShouldHandleReopen |
| B05 | 終了と処理保護 | 実装済み・実機未確認 | アプリメニュー・常駐メニューの「ControlMateを終了」。終了時に KeyTap.stop()・ホットキー解除。⌘Qはアプリ内メニューのみ |
| B06 | 標準キー操作 | 実装済み・実機未確認 | ⌘,・⌘W・⌘0・編集メニュー。ControlMate が前面のときはキーを置き換えない（blocksHotkeys） |
| B07 | ショートカット管理 | 実装済み・実機未確認 | 置き換え全体のON/OFF、一時停止、キーごとのON/OFF、グループごとの素通しアプリ。置き換えるキー自体の変更は未対応（固定の Emacs キー）。アプリを呼び出すホットキーは HotkeyField（変更・解除・登録失敗の表示）。HotkeyManifest に全キーを申告 |
| B08 | 設定・位置の保持 | 実装済み・実機未確認 | UserDefaults、MainWindow／Preferences の frame autosave と画面外の復帰 |
| B09 | 権限の案内と再判定 | 実装済み・実機未確認 | AccessibilitySection（理由は neededOverride）。InDesign の ⌃K で初回にオートメーションの許可（拒否時は［直前の操作］に設定の場所を表示）、com.apple.accessibility.api 通知と復帰時に再判定。状態確認では要求しない |
| B10 | 原本保護・復元 | 実装済み・実機未確認 | 編集はアプリ自身のメニュー操作なので ⌘Z で取り消せる（ヘルプに記載）。クリップボードは控えて戻し、自分のカット後にほかから変わっていたら戻さない（TextActions.restore） |
| B11 | 二重処理・中断対策 | 実装済み・実機未確認 | 編集の操作は直列のキュー（TextActions.queue）。キーのリピートは編集の操作では無視 |
| B12 | 成否・復旧表示 | 実装済み・実機未確認 | 失敗理由をメインウインドウ［直前の操作］に表示（result.*）。キーやテキストはログに残さない |
| B13 | 待機負荷・復帰 | 実装済み・実機未確認 | イベント駆動（アプリ切り替え・復帰・アクセシビリティ通知）。ポーリングは Caps Lock を押している間だけ（CapsLockGuard）。CPU・メモリは未計測 |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 実機確認済み（表示のみ） | appHeader＋AppSurface。2026-10-26 /Applications 版のメインウインドウ（1.1.0 のキーボード図を含む）をスクリーンショットで確認。設定［キー］の表は未確認。VoiceOver・ダークモードは未確認 |
| B15 | 多言語 | 実装済み・自動テスト済み | make-resources.py（ja/en/zh-Hans/ko）、test.sh でキー・プレースホルダー・識別子由来のキーを照合 |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 実装済み・実機未確認 | helpText（4言語）、ヘルプメニュー⌘?・常駐メニュー、「情報」タブ、about パネル |
| B17 | プライバシー | 実装済み | 通信なし（更新は未設定で通信しない）。控えはメモリーのみ。PrivacyInfo.xcprivacy |
| B18 | 更新・配布・最終版の/ApplicationsとLatest Buildsへの配置 | 一部確認 | 2026-10-26 publish_latest.py で両配置先に 1.0.0 (1)、続けて 1.1.0 (2)・1.2.0 (3)・1.3.0 (4) を配置し一致を確認、/Applications 版の起動を確認。更新配信は未設定（準備中）。Developer ID署名・公証は未実施 |
| B19 | マスタード基調の共通アイコン | 実装済み | Assets/draw-icon.swift（FnNumpad と同じタイル・茶色の縁取り・円形バッジ）。256px で確認 |
| B20 | 共通UI統一・起動/常駐/起動ショートカットの同一グループ・アクセシビリティも同一タブ内の区画 | 実装済み・実機未確認 | 設定タブ：起動・常駐（＋アクセシビリティ）／キー／素通しにするアプリ／対象外アプリ／設定の共有／情報 |
| B21 | 対象外アプリの設定・処理抑制・標準キー操作の保持 | 実装済み・実機未確認 | ExcludedApps（初期値 Illustrator。InDesign は 1.3.0 で対象外から外し専用の差し替えで対応）。対象外ではタップの state.active=false でキーをそのまま通す。グループ単位の素通しは PassList |

## 確認記録

- ソース確認：実施（2026-10-26）
- ビルド・自動テスト：実施。`SKIP_PUBLISH=1 ./build.sh` 成功（ControlMate のソースに警告なし）、`./test.sh` PASS
- 実機で起動・閉じる・再表示・⌘Q：起動とメインウインドウの表示のみ確認。ほかは未実施
- キーの置き換え・編集の操作：2026-10-26 利用者がアクセシビリティを許可（イベントタップ有効を CGGetEventTapList で確認）。テキストエディットで段落の操作（⌃⇧↑↓・⌃S・⌃S 2回・⌃X／⌃Z）は利用者が確認済み。⌃E は見た目の行末へ動く（段落末尾へ揃える要望をリリースキューに記録）。ほかのアプリ・Caps Lock・素通しは未確認
- 再ログイン・OS側で自動起動OFF：未実施
- 別コピー起動・引数/ファイル受け渡し：未実施
- 設定保持・更新・配布物確認：未実施
- /ApplicationsとLatest Buildsへの配置・既存版バックアップ・両配置先の版/build/署名・内容一致確認：実施（新規のため既存版なし）
- /Applicationsのアプリを起動して動作確認：起動とメインウインドウのみ

| B22 | 手動起動は表示・ログイン自動起動は非表示 | 実装済み・実機未確認 | StartupWindow で起動経路を判定 |
| B30 | Dockとアプリケーションスイッチャーに表示しない | 実装済み・実機未確認 | LoginAtLaunchView 内の DockPresence、WindowActivationPolicy |
| B23 | 開き直しと⌘Tab・⌘0 | 実装済み・実機未確認 | applicationShouldHandleReopen、WindowActivationPolicy、MenuBarPresence の ⌘1 |
| B24 | 設定ウインドウのふるまい | 実装済み・実機未確認 | contentMinSize 640×640、SettingsTabs、即時反映 |
| B25 | アプリ情報と目印 | 実装済み | SWNoteArticleURL（専用記事が無いためまとめ）、NSHumanReadableCopyright、SWAppFamily |
| B26 | 証明書での署名 | 実装済み | codesign で TeamIdentifier=PL9S9PXX96 を確認 |
| B27 | 取消と失敗の伝え方 | 実装済み・実機未確認 | 失敗は［直前の操作］に表示、一時停止は置き換えオフのとき無効 |
| B28 | ウインドウ位置とアクセシビリティの細目 | 実装済み・実機未確認 | 初回中央・画面外復帰、キー表の accessibilityLabel |
| B29 | 設定の書き出し・読み込みと同期 | 実装済み・実機未確認 | SettingsSync（enabled・trigger.ansi・trigger.jis・disabledCommands）。アプリの一覧はMacごと |
| B31 | アクセシビリティ設定を開き、可能な場合だけ自アプリを選択 | 実装済み・実機未確認 | 共通の AccessibilitySection |
| B32 | 必要なアプリのみ標準通知と共通設定 | 適用外 | 結果はキー操作の直後にアプリ内で分かるため通知しない。失敗はメインウインドウに表示 |
