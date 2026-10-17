# 共通仕様の実装と確認

アプリ名：LinkMaker
バージョン/build：1.2.3 (6)
確認OS/CPU：macOS 26（Darwin 25.6）/ arm64
確認日：2026-10-13

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 実装済み・実機未確認 | main.swift SingleInstanceLaunch、LSMultipleInstancesProhibited。連続起動は未確認 |
| B02 | ログイン起動設定 | 実装済み・実機未確認 | Model.changeLogin（SMAppService）、初期値オフ。再ログイン未確認 |
| B03 | ログイン時の非表示 | 実装済み・実機未確認 | LaunchPolicy.isLoginLaunch でメインウインドウを出さない（LaunchTests PASS） |
| B04 | 常駐と再表示 | 実装済み・実機未確認 | LSUIElement＋MenuBarPresence、keepRunning（初期値オン）、applicationShouldHandleReopen |
| B05 | 終了と処理保護 | 実装済み・実機未確認 | アプリメニュー・常駐メニュー・設定に終了。stop() でホットキー解除。⌘Qはアプリが前面のときだけ |
| B06 | 標準キー操作 | 実装済み・実機未確認 | ⌘, ⌘W ⌘0、記録中のEscで取消 |
| B07 | ショートカット管理 | 実装済み・実機未確認 | パレットのホットキー（⌃⌥⌘M、全アプリ共通、変更・初期値・登録失敗表示）を追加。機能ごとのオン・オフ／変更／初期値／すべて初期値、一時停止、重複と登録失敗を表示。HotkeyManifest公開 |
| B08 | 設定・位置の保持 | 実装済み・実機未確認 | UserDefaults、ウインドウ位置の自動保存と画面外復帰 |
| B09 | 権限の案内と再判定 | 実装済み・実機未確認 | アクセシビリティ（必須）は共通部品で状態表示と設定ボタン、オートメーションは拒否時に理由と設定への案内 |
| B10 | 原本保護・復元 | 実装済み・実機未確認 | 書き出しは同名回避（withoutOverwriting）。開き直しで使うクリップボードは、その後の別コピーがなければ復元 |
| B11 | 二重処理・中断対策 | 実装済み・実機未確認 | busy で二重実行を抑止、メニューも無効化 |
| B12 | 成否・復旧表示 | 実装済み・実機未確認 | 成功・失敗・取消を区別して表示、クリップボード本文はログに残さない |
| B13 | 待機負荷・復帰 | 実装済み・実機未確認 | アプリ切替の通知で登録・解除（ポーリングなし）。CPU・メモリ未計測 |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 実装済み・実機確認済み（表示のみ） | AppHeader でバンドル内アイコン＋機能見出し。/Applications版の主画面をスクリーンショットで確認。VoiceOver未確認 |
| B15 | 多言語 | 実装済み・実機未確認 | ja/en/zh-Hans/ko 147キー（check_resources PASS）。日本語以外の表示未確認 |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 実装済み・実機未確認 | ヘルプメニュー⌘?・常駐メニュー。ヘルプを開く操作は未確認 |
| B17 | プライバシー | 実装済み | 外部通信なし（QRコードもローカル生成）。Apple Events の用途を NSAppleEventsUsageDescription に記載 |
| B18 | 更新・配布・最終版の/ApplicationsとLatest Buildsへの配置 | 一部 | /Applications と Latest Builds へ deploy_both.py で配置、両方一致を確認、/Applications版の起動を確認。更新配信先・鍵は未設定（準備中表示）。Developer ID配布時は apple-events のエンタイトルメントが必要（未設定） |
| B19 | マスタード基調の共通アイコン | 実装済み | マスタードのタイル＋ブラウザー画面＋リンクのバッジ（Assets/draw-icon.swift）。Finder表示は未確認 |
| B20 | 共通UI統一・起動/常駐/起動ショートカットの同一グループ・アクセシビリティも同一タブ内の区画 | 実装済み・実機未確認 | タブ：起動・常駐／ホットキー／パレット／対象ブラウザー／出力／対象外アプリ／設定の共有／情報。2026-10-17 1.2.11：起動グループの下に AccessibilitySection()、その下にオートメーション。独自の accessibilityAllowed・メインウインドウの許可状態の行・fail.access を削除し、AccessibilitySection.isTrusted と AccessibilityText.text("blocked") に。配置・起動確認、画面表示は未確認 |
| B21 | 対象外アプリの設定・処理抑制・標準キー操作の保持 | 実装済み・実機未確認 | ブラウザー専用の機能は「対象ブラウザー」でBundle IDごとにオン・オフ。「選択した文字列から」は 2026-10-17 1.2.11 から共通部品 ExcludedApps（初期値は Illustrator・InDesign・Photoshop・Word、下に「初期値に戻す」を残す）。キー excludedBundleIDs、旧キー excludedApps を引き継ぎ（defaults read で4件の移行を確認、旧キーは残す）。onChange でホットキー再登録とパレットの表示更新。実行直前に前面アプリを再確認。画面操作は未確認 |

## 確認記録

- ソース確認：実施
- ビルド・自動テスト：実施（test.sh 全PASS、build.sh 成功）
- 実機で起動・閉じる・再表示・⌘Q：未実施
- 再ログイン・OS側で自動起動OFF：未実施
- 別コピー起動・引数/ファイル受け渡し：未実施
- 設定保持・更新・配布物確認：未実施
- /ApplicationsとLatest Buildsへの配置・両配置先の版/build/署名・内容一致確認：実施（新規のため既存版なし）
- /Applicationsのアプリを起動して動作確認：起動と主画面表示のみ。ホットキーでの各機能は未確認（アクセシビリティ未許可、KMマクロが有効なため）。AXでのURL・タイトル取得はChrome・Firefoxで別プローブにより確認

| B22 | 起動時にメインウインドウを表示しない | 実装済み・実機未確認 | StartupWindow 共通部品 |
| B23 | 開き直しと⌘Tab・⌘0 | 実装済み・実機未確認 | WindowActivationPolicy、⌘0／⌘1 |
| B24 | 設定ウインドウのふるまい | 実装済み・実機未確認 | SettingsTabs（タブ復元）、最小サイズ 720×560 |
| B25 | アプリ情報と目印 | 実装済み・実機確認済み（タグ） | 情報タブ、Info.plist の3キー、Finderタグ swwwitch を mdls で確認。2026-10-16 1.2.10：SWNoteArticleURL を専用記事 https://note.com/swwwitch/n/n8b43a7eba379 に変更（/Applications・Latest Builds の Info.plist で確認） |
| B26 | 証明書での署名 | 実機確認済み | TeamIdentifier=PL9S9PXX96（codesign -dv） |
| B27 | 取消と失敗の伝え方 | 実装済み・実機未確認 | 失敗は TransientMessage で理由表示＋ビープ |
| B28 | ウインドウ位置とアクセシビリティの細目 | 実装済み・実機未確認 | 初回中央・画面外復帰、accessibilityLabel |
| B29 | 設定の書き出し・読み込みと同期 | 実装済み・実機未確認 | 2026-10-16 1.2.10 (13)：「設定の共有」タブ（SettingsSharingView）を「情報」の直前に。keys: shortcuts, actionEnabled, doubleTap, browserEnabled, simplifyURL, associateID, notifySuccess, translateTarget, paletteShortcut, paletteHotkeyEnabled, paletteMode, paletteSimple, paletteSimpleActions。merge なし（置き換えのみ）。onImport＝Model.reload()＋palette.refresh()。ビルド・test.sh 合格、両配置先 1.2.10 (13)・署名一致、/Applications 版の起動を pgrep で確認。画面操作は未確認 |
| — | ホットキーの記録欄 | 実装済み・実機未確認 | 2026-10-17 1.2.13：機能とパレットの欄に allowsOption: true（⌥だけ・⌥⇧だけも記録可）、初期値に戻すの重複確認を取り込み。1.2.12：「ホットキー」の機能ごとの行（機能名のオン・オフ＋HotkeyField＋2回押し）とパレットのホットキーを HotkeyField に。保存は shortcuts／paletteShortcut の Shortcut JSON のまま（ShortcutCombo.swift で KeyCombo と相互変換、往復を ShortcutTests で検証）。登録は独自の HotKeySet のまま（ダブルタップのため）、onRecordingChanged で記録中は外す。others は同じ押し方の有効な機能とパレット。独自の NSEvent 記録・Shortcut.recorded・関連文言9キーを削除。注意：初期値のうち ⌥だけのキー13個（⌥S ⌥T ⌥Y ⌥M ⌥H ⌥A ⌥G ⌥F ⌥K ⌥R ⌥W ⌥Q、⌥A×2）は共通部品の新しい規則（⌘か⌃必須）では記録し直せない（初期値に戻すでは入る）。記録操作は未確認 |
