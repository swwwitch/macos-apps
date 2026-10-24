# 共通仕様の実装と確認

アプリ名：未記入
バージョン/build：未記入
確認OS/CPU：未記入
確認日：未記入

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 未確認 | |
| B02 | ログイン起動設定 | 未確認 | |
| B03 | ログイン時の非表示 | 未確認 | |
| B04 | 常駐と再表示 | 未確認 | 2026-10-20：「Dockとアプリケーションスイッチャーに表示しない」（初期値オフ、Sources/StartupWindow.swift の DockPresence、起動・常駐の StartupWindowView 内、起動時は MenuBarPresence.install、ウインドウ開閉時は WindowActivationPolicy.update で適用）：ビルド確認済み・実機未確認。 |
| B05 | 終了と処理保護 | 未確認 | |
| B06 | 標準キー操作 | 未確認 | |
| B07 | ショートカット管理 | 未確認 | |
| B08 | 設定・位置の保持 | 未確認 | |
| B09 | 権限の案内と再判定 | 未確認 | |
| B10 | 原本保護・復元 | 未確認 | |
| B11 | 二重処理・中断対策 | 未確認 | |
| B12 | 成否・復旧表示 | 未確認 | |
| B13 | 待機負荷・復帰 | 未確認 | |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 未確認 | |
| B15 | 多言語 | 未確認 | |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 未確認 | |
| B17 | プライバシー | 未確認 | |
| B18 | 更新・配布・最終版の/ApplicationsとLatest Buildsへの配置 | 未確認 | |
| B19 | マスタード基調の共通アイコン | 未確認 | |
| B20 | 共通UI統一・起動/常駐/起動ショートカットの同一グループ・アクセシビリティも同一タブ内の区画 | 未確認 | 2026-10-17：アクセシビリティを共通の AccessibilitySection() に（起動グループの直下）、判定は AccessibilitySection.isTrusted、未許可の失敗表示は AccessibilityText.text("blocked")。独自の accessibilityAllowed / refreshAccessibility は削除 |
| B21 | 対象外アプリの設定・処理抑制・標準キー操作の保持 | 適用外 | 設定の「対象アプリ」（Excel・Chrome・Safari・Firefox）が前面のときだけホットキーを登録する許可リスト方式で、ほかのアプリではキーを奪わない（2026-10-17 確認） |

## 確認記録

- ソース確認：未実施
- ビルド・自動テスト：未実施
- 実機で起動・閉じる・再表示・⌘Q：未実施
- 再ログイン・OS側で自動起動OFF：未実施
- 別コピー起動・引数/ファイル受け渡し：未実施
- 設定保持・更新・配布物確認：未実施
- /ApplicationsとLatest Buildsへの配置・既存版バックアップ・両配置先の版/build/署名・内容一致確認：未実施
- /Applicationsのアプリを起動して動作確認：未実施

| B22 | 手動起動は表示・ログイン自動起動は非表示 | 実機未確認 | 共通StartupWindowで起動経路を判定。旧非表示設定は参照しない。2026-10-24の検証記録を参照 |
| B23 | 開き直しと⌘Tab・⌘0 | 未確認 | Dock・Finderから開き直し（処理中も）、常駐アプリの⌘Tab表示としまったウインドウの復帰、⌘0と⌘1を確認 |
| B24 | 設定ウインドウのふるまい | 未確認 | 最小サイズで止まる、再起動後のタブ復元、フォーカス枠なし、即時反映、Esc・⌘Wで閉じる、元キー「設定」 |
| B25 | アプリ情報と目印 | 未確認 | 「情報」タブ、SWNoteArticleURL、NSHumanReadableCopyright、SWAppFamily、配置後のFinderタグ。2026-10-16 SWNoteArticleURL を専用記事に変更（/Applications 版の Info.plist で確認） |
| B26 | 証明書での署名 | 未確認 | TeamIdentifier=PL9S9PXX96、再ビルド後も許可が残る、ログインキーチェーン |
| B27 | 取消と失敗の伝え方 | 未確認 | パレット・シート・確認のEsc、ビープだけの箇所がない、実行不可のメニューは無効 |
| B28 | ウインドウ位置とアクセシビリティの細目 | 未確認 | 初回中央・画面外復帰、ボタンとドロップ領域のaccessibilityLabel、tintのコントラスト、視差効果を減らす |
| B29 | 設定の書き出し・読み込みと同期 | 実装済み・ビルド・配置確認済み・実機UI未確認 | 「情報」の直前に SettingsSharingView の「設定の共有」タブ。共有キー：hotkeyEnabled・cleanShortcut・targetEnabled・replaceApostrophe・notifySuccess・commandEnabled・commandShortcuts。onImport でモデルを読み直しホットキーを再登録。GUI操作での書き出し・読み込み・同期は未確認 |
| — | ホットキーの記録欄 | 実装済み・ビルド確認済み・実機未確認 | 2026-10-17：HotkeyField を ⌥⌘C と表の操作24行（Grid の キー＋ボタン列、行の並び・カテゴリ見出しは維持）に。others に全ホットキーを渡して重複を断る、初期値が ⌥/⌥⇧ だけの行は allowsOption。保存は cleanShortcut・commandShortcuts（初期値と同じなら保存しない）のまま、ShortcutCombo.swift で変換（ComboTests）。登録は HotkeySet（"CCCL"、1 と 100+n）、行ごとの登録失敗を表示。独自の ShortcutRow・ShortcutLabel・記録モニター・SingleHotKey×25 を削除 |
