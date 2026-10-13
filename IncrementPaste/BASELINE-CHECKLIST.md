# 共通仕様の実装と確認

アプリ名：IncrementPaste（`jp.dtp-transit.incrementpaste`）
バージョン/build：1.0.0 (1)
確認OS/CPU：macOS 26（Darwin 25.6.0）/ arm64
確認日：2026-10-13

元にしたもの：Keyboard Maestroマクロ「increment-paste」（同フォルダ）。構成はPasteInARowを流用。

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 実機確認済み | main.swift SingleInstanceLaunch、LSMultipleInstancesProhibited。/Applications版を2回openしてプロセス1つ |
| B02 | ログイン起動設定 | 実装済み・実機未確認 | SMAppService.mainApp、初期値オフ。登録は確認（sfltool）、再ログインは未確認 |
| B03 | ログイン時の非表示 | 実装済み・実機未確認 | LaunchPolicy.isLoginLaunch（テストあり） |
| B04 | 常駐と再表示 | 実装済み・実機未確認 | accessory＋MenuBarPresence、「ウインドウを閉じても常駐」 |
| B05 | 終了と処理保護 | 実装済み・実機未確認 | メニュー「IncrementPasteを終了」⌘Q。長い処理なし、終了時にホットキー・タイマー解除（Model.stop） |
| B06 | 標準キー操作 | 実装済み・実機未確認 | ⌘, ⌘W ⌘0、編集メニュー標準 |
| B07 | ホットキー管理 | 実装済み・実機未確認 | 変更・無効化・初期値（⌥V）・一時停止、登録失敗表示 |
| B08 | 設定・位置の保持 | 実装済み・実機未確認 | UserDefaults、setFrameAutosaveName、画面外なら中央へ |
| B09 | 権限の案内と再判定 | 実装済み・実機未確認 | AccessibilityPermission共通部品、主画面に未許可表示 |
| B10 | 原本保護・復元 | 実装済み・実機未確認 | 増やしたときだけクリップボードを書き換え（機能そのもの）。「クリップボードを1つ前に戻す」は自分の書き込みが残っているときだけ有効 |
| B11 | 二重処理・中断対策 | 実装済み・実機未確認 | 1回の処理は同期で即時完了。実行直前に前面アプリを再確認 |
| B12 | 成否・復旧表示 | 実装済み・実機未確認 | 成功／そのまま／失敗を区別、失敗はTransientMessageと状態欄。本文をログに書かない |
| B13 | 待機負荷・復帰 | 実装済み・実機未確認 | イベント駆動。クリップボード監視（0.5秒）はメインウインドウ表示中だけ |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 実装済み・実機未確認 | AppHeader・AppSurface、accessibilityLabel |
| B15 | 多言語 | 実装済み | ja/en/zh-Hans/ko 101キー、Tests/check_resources.py 合格 |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 実装済み・実機未確認 | HelpDocument、ヘルプ⌘?、note記事、情報タブ |
| B17 | プライバシー | 実装済み | 外部通信なし（更新は未設定のため通信しない）、クリップボードは保存しない |
| B18 | 更新・配布・最終版の/ApplicationsとLatest Buildsへの配置 | 一部 | deploy_both.pyで両配置先に配置し署名・内容一致を確認。更新は配信先・公開鍵が未設定のため準備中（稼働していない）。Developer ID・公証は未実施 |
| B19 | マスタード基調の共通アイコン | 実装済み | Assets/draw-icon.swift（白いカードの「1」＋茶色の円に白い＋）、Assets.carも付与 |
| B20 | 共通UI統一 | 実装済み・実機未確認 | タブ：起動・常駐（＋アクセシビリティ）／ホットキー／増やし方／対象外アプリ／情報。アプリ起動のホットキーは他アプリ同様未搭載 |
| B21 | 対象外アプリの設定・処理抑制・標準キー操作の保持 | 実装済み・実機未確認 | 初期値はKMマクロの除外と同じ（Illustrator・Excel・InDesign・ScreenFlow、check_km_macro.pyで照合） |
| B22 | 起動時にメインウインドウを表示しない | 実装済み・実機未確認 | StartupWindow共通部品 |
| B23 | 開き直しと⌘Tab・⌘0 | 実装済み・実機未確認 | applicationShouldHandleReopen、WindowActivationPolicy |
| B24 | 設定ウインドウのふるまい | 実装済み・実機未確認 | SettingsTabs、contentMinSize、即時反映 |
| B25 | アプリ情報と目印 | 一部 | 情報タブ、著作権、SWAppFamily。SWNoteArticleURLは専用記事がないためまとめのURL |
| B26 | 証明書での署名 | 実装済み | TeamIdentifier PL9S9PXX96（build.sh） |
| B27 | 取消と失敗の伝え方 | 実装済み・実機未確認 | 失敗時はビープ＋画面表示、戻せないときメニュー無効 |
| B28 | ウインドウ位置とアクセシビリティの細目 | 実装済み・実機未確認 | 初回中央・画面外復帰 |

## 確認記録

- ソース確認：実施
- ビルド・自動テスト：実施（./test.sh 6本合格、SKIP_PUBLISH=1 ./build.sh 成功）
- 実機で起動・二重起動：/Applications版で確認。閉じる・再表示・⌘Q：未実施
- 再ログイン・OS側で自動起動OFF：未実施
- ⌥V で実際に増やしてペースト：未実施（アクセシビリティ未許可のため）
- /ApplicationsとLatest Buildsへの配置：新規のため既存版なし。両配置先の版・build・署名・内容一致を deploy_both.py で確認
