# 共通仕様の実装と確認

アプリ名：ScreenTake
バージョン/build：1.0.0（1）
確認OS/CPU：macOS 26（Darwin 25.6）/ Apple Silicon
確認日：2026-10-26

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 実装済み・実機未確認 | main.swift `applicationWillFinishLaunching`（Bundle IDで既存を前面に）、Info.plist LSMultipleInstancesProhibited |
| B02 | ログイン起動設定 | 実装済み・実機未確認 | 共通 LoginAtLaunchView（初期値OFF） |
| B03 | ログイン時の非表示 | 実装済み・実機未確認 | LaunchPolicy.isLoginLaunch＋StartupWindow.suppressInitialWindow |
| B04 | 常駐と再表示 | 実装済み・実機未確認 | 「ウインドウを閉じても常駐」（初期値オン）、MenuBarPresence、applicationShouldHandleReopen |
| B05 | 終了と処理保護 | 実装済み・実機未確認 | applicationShouldTerminate：収録中は動画を閉じてから終了（terminateLater）、書き出し中は確認して中止 |
| B06 | 標準キー操作 | 実装済み・実機未確認 | ⌘W・⌘,・Esc（カウントダウン・書き出しの取消）。編集用の単独キー（Space・←→・delete）は編集ウインドウが前面のときだけ有効（validateMenuItem） |
| B07 | ショートカット管理 | 実装済み・実機未確認 | 収録のホットキー（⌃⌥⇧⌘6、KM・他sw_appと照合済み）とアプリ呼び出し：共通HotkeyField（変更・無効化・初期値・解除・登録失敗表示） |
| B08 | 設定・位置の保持 | 実装済み・実機未確認 | UserDefaults、MainWindow/EditorWindowのframe autosave、画面外なら中央へ |
| B09 | 権限の案内と再判定 | 実装済み・実機未確認 | 設定「起動・常駐」の「権限」（画面収録・マイク・カメラ、復帰時に再判定、要求しない）。要求は収録開始時のみ |
| B10 | 原本保護・復元 | 実装済み・自動テスト済み | recording.movは書き換えず編集はproject.json、⌘Z/⇧⌘Z、「削除した部分をすべて戻す」。ゴミ箱は確認付き（既定はキャンセル側にEsc） |
| B11 | 二重処理・中断対策 | 実装済み・自動テスト済み | 収録中の開始・書き出し中の再書き出しを抑止。書き出しは隠しファイル→置換（テストで一時ファイルが残らないことを確認）。収録失敗時はフォルダを削除 |
| B12 | 成否・復旧表示 | 実装済み・実機未確認 | 主画面・編集画面の状態欄に成功／取消／失敗と理由、権限の設定ボタン |
| B13 | 待機負荷・復帰 | 実装済み・実機未確認 | 待機中のタイマーなし（ポインタ記録・経過時間は収録中だけ）。スリープ復帰は未確認 |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 実装済み・実機未確認 | MainViewにcurrentAppIcon＋AppVersionLabel＋機能見出し、AppSurface。画像だけのボタンにaccessibilityLabel |
| B15 | 多言語 | 実装済み・自動テスト済み | ja/en/zh-Hans/ko 179キー、test.shでキー・プレースホルダー一致を検証 |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 実装済み・実機未確認 | Help.txt 4言語、ヘルプ⌘?・note記事、情報タブ |
| B17 | プライバシー | 実装済み | ローカル保存のみ、外部通信なし（更新は未設定）。権限の説明に明記 |
| B18 | 更新・配布・最終版の/ApplicationsとLatest Buildsへの配置 | ローカル配置済み | 2026-10-26 `./build.sh --deploy`：/ApplicationsとLatest Buildsとも1.0.0（1）で署名・内容一致、/Applications版の起動を確認。更新の配信先は未設定。Developer ID署名・公証（ScreenTake.entitlementsが必要）は未実施 |
| B19 | マスタード基調の共通アイコン | 実装済み | Assets/GenerateIcon.swift（画面＋録画の赤丸＋タイムライン） |
| B20 | 共通UI統一 | 実装済み・実機未確認 | SettingsTabs：起動・常駐（LaunchPresenceSection・呼び出しホットキー・権限）／収録／出力／設定の共有／情報 |
| B21 | 対象外アプリ | 適用外 | ほかのアプリの文字・ファイル・操作に作用しない（画面を読み取るだけ） |
| B22 | 手動起動は表示・ログイン自動起動は非表示 | 実装済み・実機未確認 | StartupWindow |
| B23 | 開き直しと⌘Tab・⌘0 | 実装済み・実機未確認 | applicationShouldHandleReopen、⌘0（MainWindowShortcutAlias） |
| B24 | 設定ウインドウのふるまい | 実装済み・実機未確認 | contentMinSize 560×600、SettingsTabsでタブ復元 |
| B25 | アプリ情報と目印 | 一部 | Info.plist の著作権・SWAppFamily あり。SWNoteArticleURL はまとめのURL（専用記事なし）。GitHub個別リポジトリ未作成のため macos-apps へ |
| B26 | 証明書での署名 | 実装済み | build.sh でチームの証明書＋entitlements |
| B27 | 取消と失敗の伝え方 | 実装済み・実機未確認 | 確認ダイアログの取消にEsc、実行できないメニューは無効 |
| B28 | ウインドウ位置とアクセシビリティの細目 | 実装済み・実機未確認 | 初回中央・画面外復帰、タイムライン各レーンにラベル |
| B29 | 設定の書き出し・読み込みと同期 | 実装済み・実機未確認 | Model.sharedKeys（保存先・機器IDはMacごと） |
| B30 | Dockとアプリケーションスイッチャーに表示しない | 実装済み・実機未確認 | 共通DockPresence（LoginAtLaunchViewに内包） |
| B31 | アクセシビリティ設定 | 適用外 | アクセシビリティ権限を使わない |
| B32 | 通知 | 未実装（次版候補） | 書き出し完了の通知は有用だが1.0では見送り。結果はアプリ内の状態欄に表示 |

## 確認記録

- ソース確認：実施
- ビルド・自動テスト：`./test.sh` 成功（時間計算、生成した動画からのMP4〈カット後3秒〉・MOV 720p・GIF 30コマ書き出し、一時ファイルなし、4言語）。`./build.sh` 成功
- 実機で起動：build版を起動し、ウインドウ表示を確認（画面の目視は未確認）
- 実機での収録：ユーザーが収録・停止・編集を確認（2026-10-26、「いい感じ」「よき」）。ウインドウ収録・マイク・カメラ・一時停止、ポインタの形の切り替わりの個別確認は未記録
- 再ログイン・OS側で自動起動OFF：未実施
- 別コピー起動：未実施
- /ApplicationsとLatest Buildsへの配置：済み（版・署名・内容一致、/Applications版を起動）
