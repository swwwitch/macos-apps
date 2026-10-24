# 共通仕様の実装と確認

アプリ名：FnNumpad
バージョン/build：1.0.0 (2)
確認OS/CPU：macOS 26 (Darwin 25.6) / arm64
確認日：2026-10-21

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。PasteMatchStyle 1.1.0 の骨格（メニュー・設定・署名・配置）を流用し、共通部品は Shared から直接コンパイルする（各アプリへのコピーなし）。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 実装済み・実機未確認 | main.swift SingleInstanceLaunch＋LSMultipleInstancesProhibited |
| B02 | ログイン起動設定 | 実装済み・実機未確認 | LoginAtLaunchView（Shared）、初期値オフ |
| B03 | ログイン時の非表示 | 実装済み・実機未確認 | LaunchPolicy.isLoginLaunch（LaunchTests PASS） |
| B04 | 常駐と再表示 | 実装済み・実機未確認 | accessory＋MenuBarPresence、keepRunning（初期値オン） |
| B05 | 終了と処理保護 | 実装済み・実機未確認 | ⌘Q・常駐メニュー「終了」、stop()でイベントタップと監視を解除 |
| B06 | 標準キー操作 | 実装済み・実機未確認 | ⌘W・⌘,。⌘付きのキーは変換対象外（Fnが必須） |
| B07 | ホットキー管理 | 一部 | 変換全体のオン・オフ、グループごとのオン・オフ、一時停止（常駐メニュー）。Fn＋キーはCarbonのホットキーではないためHotkeyField・HotkeyManifestは適用外。割り当ての変更は未実装（Karabinerのルールと同じ固定表） |
| B08 | 設定・位置の保持 | 実装済み・実機未確認 | UserDefaults（conversionEnabled・group.*・keyboardLayout）、ウインドウ位置の自動保存と画面外復帰 |
| B09 | 権限の案内と再判定 | 実装済み・実機未確認 | アクセシビリティのみ（イベントタップ）。理由文、DistributedNotification com.apple.accessibility.api と復帰時に再判定してタップを開始 |
| B10 | 原本保護・復元 | 実機確認済み（2026-10-21、ユーザー確認） | 日本語入力中の Fn＋, だけクリップボード経由で「,」をペースト（CommaTyper）。約0.6秒後に元へ戻し、changeCountが変わっていれば上書きしない |
| B11 | 二重処理・中断対策 | 実装済み | 押下中のキーを held に記録し、Fnを先に離してもキーアップを同じテンキーで返す |
| B12 | 成否・復旧表示 | 実装済み・実機未確認 | 主画面の「状態」に未許可・監視失敗・オフ・一時停止・グループなし・対象外を区別して表示 |
| B13 | 待機負荷・復帰 | 実装済み・実機未確認 | ポーリングなし。タップは専用スレッド、タイムアウト無効化時は再有効化。CPU・メモリ計測は未実施 |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 実装済み・画面確認済み | AppHeader＋AppSurface、キーボード表示（DocklessLauncherのKeyboardLayout）。/Applications版をスクリーンショットで確認 |
| B15 | 多言語 | 実装済み | ja/en/zh-Hans/ko 66キー（check_resources PASS） |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 実装済み・実機未確認 | HelpDocument、ヘルプ⌘?・note記事、情報タブ |
| B17 | プライバシー | 実装済み | 押したキーは保存・送信しない。外部通信は更新確認のみ（未設定のため通信なし） |
| B18 | 更新・配布・最終版の/ApplicationsとLatest Buildsへの配置 | 一部 | 両配置先へ配置し版・署名・内容一致を確認（deploy_both）。Sparkleの配信先・鍵は未設定（準備中表示） |
| B19 | マスタード基調の共通アイコン | 実装済み | Assets/draw-icon.swift（マスタード地＋テンキー＋「fn」バッジ）、目視確認 |
| B20 | 共通UI統一・起動/常駐/起動ショートカットの同一グループ・アクセシビリティも同一タブ内の区画 | 実装済み・実機未確認 | 起動・常駐／キー／対象外アプリ／設定の共有／情報。アプリ起動のホットキーは未搭載 |
| B21 | 対象外アプリの設定・処理抑制・標準キー操作の保持 | 実装済み・実機未確認 | ExcludedApps（Shared）。前面が対象外の間は TapState.active=false でキーをそのまま通す |
| B22 | 手動起動は表示・ログイン自動起動は非表示 | 実機未確認 | 共通StartupWindowで起動経路を判定。旧非表示設定は参照しない。2026-10-24の検証記録を参照 |
| B30 | Dockとアプリケーションスイッチャーに表示しない | 実装済み・実機未確認 | LoginAtLaunchView に内包（DockPresence） |
| B23 | 開き直しと⌘Tab・⌘0 | 実装済み・実機未確認 | applicationShouldHandleReopen、WindowActivationPolicy、⌘0 |
| B24 | 設定ウインドウのふるまい | 実装済み・実機未確認 | contentMinSize、SettingsTabs（タブ復元）、即時反映 |
| B25 | アプリ情報と目印 | 一部 | 情報タブ、コピーライト、SWAppFamily。SWNoteArticleURL は専用記事が無いためまとめページ |
| B26 | 証明書での署名 | 実装済み | 301A41C0…（PL9S9PXX96）、codesign --verify OK |
| B27 | 取消と失敗の伝え方 | 実装済み・実機未確認 | 理由は主画面と常駐メニュー先頭に表示、オフ時は一時停止を無効 |
| B28 | ウインドウ位置とアクセシビリティの細目 | 実装済み・実機未確認 | 初回中央・画面外復帰、キーごとのaccessibilityLabel |
| B29 | 設定の書き出し・読み込みと同期 | 実装済み・実機未確認 | conversionEnabled と group.* を共有。対象外アプリ等はMacごと |
