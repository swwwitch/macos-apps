# 共通仕様の実装と確認

アプリ名：note2markdown
バージョン/build：1.0.0 / 1
確認OS/CPU：macOS 26.6 (Darwin 25.6.0) / arm64
確認日：2026-10-15

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 実装済み・実機未確認 | main.swift（Bundle IDで既存インスタンスへ戻す）＋LSMultipleInstancesProhibited。 |
| B02 | ログイン起動設定 | 実装済み・実機未確認 | Shared/LoginAtLaunch（LoginAtLaunchView）、初期値オフ。 |
| B03 | ログイン時の非表示 | 実装済み・実機未確認 | LaunchPolicy.isLoginLaunch でメインウインドウを出さない。 |
| B04 | 常駐と再表示 | 実装済み・実機未確認 | 「ウインドウを閉じても終了しない」初期値オン（オフで閉じると終了）。Dock・⌘0・メニューバー（選択時）から再表示。「Dockとアプリケーションスイッチャーに表示しない」（初期値オフ、Shared/AppStandards/StartupWindow.swift の DockPresence、LoginAtLaunchView に内包、起動時は MenuBarPresence.install で適用）：ビルド確認済み・実機未確認。 |
| B05 | 終了と処理保護 | 実装済み・実機未確認 | 読み込み中の終了は通信を捨てるだけでファイルは書かない。書き込みは atomically。 |
| B06 | 標準キー操作 | 実装済み・実機未確認 | ⌘R読み込む・⌘S書き出す・⇧⌘Cコピー・⌘,・⌘0・⌘W・⌘Q・⌘?、標準の編集メニュー、Returnで読み込み、読み込み中Escで取消。 |
| B07 | ホットキー管理 | 適用外 | グローバルホットキーなし。 |
| B08 | 設定・位置の保持 | 実装済み・実機未確認 | UserDefaults（keepRunning・fetchEmbedTitles・exportDirectory）、frame autosave、画面外なら中央へ。 |
| B09 | 権限の案内と再判定 | 実装済み・実機確認済み（未許可の表示） | 1.1.0から「ブラウザーから」だけアクセシビリティ許可を使う。Shared/Accessibility/AccessibilityPermission.swift を「起動・常駐」タブの独立区画に（理由はneededOverride）。未許可で押すと主画面に理由と「アクセシビリティ設定を開く」を表示（実機で表示を確認）。状態確認だけで許可要求は出さない。 |
| B10 | 原本保護・復元 | 実装済み・実機未確認 | 書き出しは新規ファイル。同名はNSSavePanelが置き換えを確認。noteの記事は読むだけ。 |
| B11 | 二重処理・中断対策 | 実装済み・実機未確認 | 読み込み中はボタン・メニューを無効化、キャンセル可。失敗時はファイルを作らない。 |
| B12 | 成否・復旧表示 | 実装済み・実機確認済み（成功のみ） | URL不正・未検出・非公開・本文なし・応答異常・通信失敗・書き込み失敗を区別して表示。有料記事は無料部分のみと表示。読み込み成功の表示を実機で確認。 |
| B13 | 待機負荷・復帰 | 実装済み | ポーリング・タイマーなし。操作時だけ通信。 |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 実機確認済み（ライトのみ） | AppHeader/AppSurface、入力欄とプレビューにaccessibilityLabel。ダークモード・VoiceOverは未確認。 |
| B15 | 多言語 | 実装済み・実機未確認 | make-resources.py で4言語、plutil OK。日本語UIのみ確認。 |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 実装済み・実機未確認 | ⌘?、HelpDocument、「情報」タブ（AboutView）。 |
| B17 | プライバシー | 実装済み | 通信先は note.com の公開APIのみ（ヘルプ・READMEに記載）。PrivacyInfo.xcprivacy同梱。 |
| B18 | 更新・配布・最終版の/ApplicationsとLatest Buildsへの配置 | 実機確認済み（配置） | 更新は未設定（準備中表示）。deploy_both で両配置先に配置し署名・内容一致を確認。 |
| B19 | マスタード基調の共通アイコン | 実機確認済み | GenerateIcon.swift：見出し記号「#」の書類＋書き出しの下向き矢印。 |
| B20 | 共通UI統一 | 実装済み・実機未確認 | SettingsTabs：「起動・常駐」（ログイン起動・起動時非表示・常駐・メニューバー／アクセシビリティ区画／終了・再起動）、「出力」、「情報」。呼び出しホットキーは不要のため設けない。 |
| B21 | 対象外アプリ | 適用外 | 他アプリに作用しない。 |
| B22 | 手動起動は表示・ログイン自動起動は非表示 | 実機未確認 | 共通StartupWindowで起動経路を判定。旧非表示設定は参照しない。2026-10-24の検証記録を参照 |
| B23 | 開き直しと⌘Tab・⌘0 | 実装済み・実機未確認 | applicationShouldHandleReopen、通常アプリ（Dock常時表示）、⌘0/⌘1（MenuBarPresence）。 |
| B24 | 設定ウインドウのふるまい | 実装済み・実機未確認 | リサイズ可・最小サイズ、タブ復元（RememberedTabView）、即時反映、タイトル「設定」。 |
| B25 | アプリ情報と目印 | 実装済み | NSHumanReadableCopyright・SWAppFamily・SWNoteArticleURL（https://note.com/swwwitch/n/n003d1941c652、1.1.3）。 |
| B26 | 証明書での署名 | 実装済み | build.sh でチーム証明書（PL9S9PXX96）署名、codesign --verify 通過。 |
| B27 | 取消と失敗の伝え方 | 実装済み・実機未確認 | 失敗は状態欄に理由を表示（ビープは不正URL時に併用）、実行できないメニューは無効。 |
| B28 | ウインドウ位置とアクセシビリティの細目 | 実装済み・実機未確認 | 初回中央・画面外復帰。 |
| B29 | 設定の書き出し・読み込みと同期 | 実装済み・実機未確認 | 1.1.3：「情報」の直前に「設定の共有」タブ（SettingsSharingView）。共有キー fetchEmbedTitles。keepRunning・exportDirectory・ログイン起動・起動時非表示・メニューバーはMacごと。onImport で Model.reloadSharedSettings()。ビルド・test.sh 通過、/Applications と Latest Builds に配置して起動を確認（2026-10-16）。書き出し・読み込み・同期の操作は未確認。 |
| — | ホットキーの記録欄 | 適用外 | 2026-10-17 ソース確認：グローバルホットキーも「アプリを呼び出すホットキー」も無い（RegisterEventHotKey・NSEventモニターなし、キー操作はメニューのキー equivalents だけ）。設定にホットキーを割り当てる欄が無いため HotkeyField は使わない。 |

## 確認記録（2026-10-15）

- 自動テスト：test.sh 39項目通過（URL解析・ファイル名・API応答・各要素と埋め込みの変換）。
- 変換：自分の記事60本の本文HTMLを一括変換し、見出し・リスト入れ子・引用・コード・埋め込み7種（note・external-article・twitter・attachment・githubRepository・youtube・gist）を目視確認。
- 実機：公開APIから記事を読み込み、埋め込みnote記事のタイトル取得（9件）、存在しないキーで「見つかりません」を確認。build版で読み込み〜プレビュー表示を確認（ユーザー確認「ほぼ完璧」）。
- 未確認：書き出し（保存パネル）の実機操作、ログイン起動、ダークモード、他言語UI、Intel実機。
- Bundle ID：初回配置後に local.takano.note2markdown から jp.dtp-transit.note2markdown へ変更（最近のアプリに合わせた）。旧配置は note2markdown/Backups/ に退避。

## 1.1.0（build 2、2026-10-15）

- 「ブラウザーから」（⌘L）：FrontBrowser.swift（ウインドウの重なり順で最前面のブラウザーを選び、AXWebAreaのAXURLを読む）。CLIからChromeの表示中URLを36msで取得し、記事キーの判定まで確認。アプリ自身での許可後の読み込みは未確認（許可待ち）。
- ドラッグ＆ドロップ（URL・文字列）で読み込み。実機のドロップ操作は未確認。
- test.sh 40項目通過（エディターURLを追加）。/ApplicationsとLatest Buildsへ配置し一致を確認。

## 設定の共通化 第2弾（2026-10-17）

- B20：「起動・常駐」で LoginAtLaunchView（起動時非表示を内包）と StartupWindowView が並び二重表示だったため、StartupWindowView を外した。アクセシビリティを AccessibilitySection() に、未許可時の文言を独自の errorNoAccess から AccessibilityText.text("blocked") に。常駐の文言を「ウインドウを閉じても常駐」に。
- B21：適用外のまま。
- 1.1.4（build 6）：ビルド・test.sh 通過、両配置・起動確認。設定画面の表示は未確認。


### B30 2026-10-25改定

メイン・設定ウインドウがある間はDock・⌘Tabとアプリメニューを表示。最小化中も保持し、対象ウインドウをすべて閉じると非表示。パレットは除外。設定値は保持。共通AppKit回帰テスト17項目成功。各アプリのコンパイル結果はShared/ReleasePreparation/20261025-DockMenu/に記録し、個別の画面操作は未確認。署名・公証・配布は未実施。
