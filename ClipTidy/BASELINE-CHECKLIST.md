# 共通仕様の実装と確認

アプリ名：ClipTidy
バージョン/build：1.0.0 / 2
確認OS/CPU：macOS 26 / Apple Silicon
確認日：2026-10-26

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 実装済み・実機未確認 | `main.swift` applicationWillFinishLaunching（Bundle IDで既存インスタンスへ戻す）＋LSMultipleInstancesProhibited。ファイルは受け取らない |
| B02 | ログイン起動設定 | 実装済み・実機未確認 | 共通 `Shared/LoginAtLaunch/LoginAtLaunch.swift`。初期値OFF |
| B03 | ログイン時の非表示 | 実装済み・実機未確認 | `LaunchPolicy.isLoginLaunch`＋`StartupWindow.suppressInitialWindow` |
| B04 | 常駐と再表示 | 実装済み・実機未確認 | 「ウインドウを閉じても常駐」初期値ON（閉じても監視を続ける）。Dock再オープン・メニューバー（MenuBarPresence）・⌃⌥Tから再表示 |
| B05 | 終了と処理保護 | 実装済み・実機未確認 | アプリメニューに⌘Q。終了時にタイマーとパネルを止める（applicationWillTerminate） |
| B06 | 標準キー操作 | 実装済み・実機未確認 | ⌘0、⌘N（新しいルール）、⌘W、⌘,、⌘?、編集メニュー。ルールの編集シートはEscで取消・Returnで保存 |
| B07 | ショートカット管理 | 実装済み・実機未確認 | 機能のグローバルホットキーは無い。アプリを呼び出す⌃⌥Tは共通HotkeyFieldで変更・無効化・初期値に戻す・解除、登録失敗を表示。KMとsw_appの既定キーと照合して重複なし（2026-10-26） |
| B08 | 設定・位置の保持 | 実装済み・実機未確認 | rules（JSON）・paused・dropboxPrompt・noticeSecondsをUserDefaultsに保存、setFrameAutosaveName、画面外なら中央へ |
| B09 | 権限の案内と再判定 | 適用外 | 特別な権限を使わない（クリップボードの読み書きのみ） |
| B10 | 原本保護・復元 | 実装済み・一部実機確認済み | 書き換えは一致したルールがあるときだけ。Dropboxの［直接ダウンロード］はパネル表示後に別の内容がコピーされていたら書き込まない（changeCountで確認、`write(_:ifStill:)`）。書き換えの取り消しは無い（ヘルプに「監視」のオフと対象外アプリを記載）。書き換えは実機確認済み |
| B11 | 二重処理・中断対策 | 実装済み・実機未確認 | 自分の書き込みのchangeCountを控えて再処理しない。処理は即時に終わる |
| B12 | 成否・復旧表示 | 実装済み・一部実機確認済み | 状態欄に「書き換えました」・正規表現の誤りで飛ばしたルール・Dropboxを変えなかった理由を表示。最近の書き換えを一覧（メモリのみ）。編集画面は正規表現の誤りを赤字で表示し保存不可 |
| B13 | 待機負荷・復帰 | 実装済み・実機未確認 | 変更通知APIが無いため0.3秒（許容0.15秒）のタイマーでchangeCountだけ比べる。一時停止中はタイマーを止める。CPU・メモリは未計測 |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 一部実機確認済み | currentAppIcon()＋機能見出し「コピーした文字を整える」＋補足、AppSurface背景、画像だけのボタンにaccessibilityLabel。ライトモードの画面を撮影して確認。ダークモード・VoiceOverは未確認 |
| B15 | 多言語 | 自動テスト済み | `make-resources.py` で4言語、`test.sh` でキーとプレースホルダーの一致、ヘルプを検証 |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 実装済み・実機未確認 | ヘルプメニュー（⌘?）とメニューバーからHelp.txt。note記事は未作成のためまとめページ |
| B17 | プライバシー | ソース確認済み | 外部通信なし（更新の配信先は未設定）。履歴はメモリのみ。秘密・一時的の印がある内容は読まない |
| B18 | 更新・配布・最終版の/ApplicationsとLatest Buildsへの配置 | 配置確認済み | `build.sh --deploy`（publish_latest.py）。更新は未設定のため準備中。Developer ID署名・公証は未実施 |
| B19 | マスタード基調の共通アイコン | 実機確認済み | `Assets/GenerateIcon.swift`（SettingsHopと同じ地色・縁・影）。モチーフはクリップボードと輝き。1024pxと主画面の52pxで確認 |
| B20 | 共通UI統一・起動/常駐/起動ショートカットの同一グループ・アクセシビリティも同一タブ内の区画 | 実装済み・実機未確認 | SettingsTabs「起動・常駐」にLaunchPresenceSection、「一般」に監視・Dropbox・表示時間。アクセシビリティ権限は不要のため区画なし |
| B21 | 対象外アプリの設定・処理抑制・標準キー操作の保持 | 実装済み・実機未確認 | 共通ExcludedApps（初期値 Illustrator・Keynote）。コピーした時点の前面アプリで判定。ホットキーは⌃⌥Tだけでキー入力の置き換えはしない |
| B22 | 手動起動は表示・ログイン自動起動は非表示 | 一部実機確認済み | 手動起動で表示を確認。ログイン起動は未確認 |
| B23 | 開き直しと⌘Tab・⌘0 | 実装済み・実機未確認 | applicationShouldHandleReopen、⌘0（⌘1は共通のMainWindowShortcutAlias） |
| B24 | 設定ウインドウのふるまい | 実装済み・実機未確認 | contentMinSize 560×560、SettingsTabsでタブ復元、即時反映、タイトル「設定」 |
| B25 | アプリ情報と目印 | 実装済み・実機未確認 | 「情報」タブ、SWNoteArticleURL（まとめページ）、NSHumanReadableCopyright、SWAppFamily。個別GitHubリポジトリは未作成のため macos-apps を開く |
| B26 | 証明書での署名 | 実機確認済み | build.sh はPL9S9PXX96の証明書で署名 |
| B27 | 取消と失敗の伝え方 | 実装済み・実機未確認 | 削除の確認とシートはEscで取消。ビープは使わず状態欄に表示 |
| B28 | ウインドウ位置とアクセシビリティの細目 | 実装済み・実機未確認 | 初回中央・画面外復帰、画像ボタンのaccessibilityLabel、tintはダーク用の明るいマスタード |
| B29 | 設定の書き出し・読み込みと同期 | 実装済み・実機未確認 | 共有キー rules・dropboxPrompt・noticeSeconds。ログイン起動・常駐・メニューバー・対象外アプリ・一時停止はMacごと。onImportでreloadSharedSettings |
| B30 | Dockとアプリケーションスイッチャーに表示しない | 実装済み・実機未確認 | 共通部品（LoginAtLaunchView内のStartupWindowControl） |
| B31 | アクセシビリティ設定を開き、可能な場合だけ自アプリを選択 | 適用外 | アクセシビリティ権限を使わない |
| B32 | 必要なアプリのみ標準通知と共通設定 | 適用外 | 通知センターは使わない。書き換えとDropboxの知らせは、許可の要らないフォーカスを奪わないパネルで出し、結果は主画面の状態欄と履歴にも残る |

## 確認記録

- ソース確認：実施
- ビルド・自動テスト：`./build.sh` 成功（自作ソースの警告なし）。`./test.sh` 全件合格
- 実機（build版）：主画面の表示を撮影。Finderを前面にして `pbcopy` で `https://mobile.twitter.com/swwwitch` をコピー → `https://twitter.com/swwwitch` に書き換わることを確認。Dropboxの共有リンクで右上にパネル（ファイル名「test2.pdf」）が出ることを確認。［直接ダウンロード］のクリックはパネルの中身がアクセシビリティから見えず未確認
- 閉じる・再表示・⌘Q・設定画面・ヘルプ：未実施
- 再ログイン・OS側で自動起動OFF：未実施
- 別コピー起動：未実施
- /ApplicationsとLatest Buildsへの配置：実施（publish_latest.pyで版・build・署名・内容一致を確認）。/Applications版を起動し `ps` でパスを確認
