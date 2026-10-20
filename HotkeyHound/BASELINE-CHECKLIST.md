# 共通仕様の実装と確認

アプリ名：HotkeyHound
バージョン/build：0.1.0 (2)
確認OS/CPU：macOS 26（Darwin 25.6.0）/ arm64
確認日：2026-10-11

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 実装済み・実機未確認 | HotkeyHoundApp.swift SingleInstanceLaunch（BundleIDInspectorと同じ）。Info.plist LSMultipleInstancesProhibited |
| B02 | ログイン起動設定 | 実装済み・実機未確認 | LoginAtLaunch.swift（共通部品）、初期値OFF |
| B03 | ログイン時の非表示 | 実装済み・実機未確認 | StartupWindow.swift（共通部品） |
| B04 | 常駐と再表示 | 実装済み・実機未確認 | AppDelegate：閉じても終了しない、applicationShouldHandleReopen、⌘0、MenuBarPresence。2026-10-20 0.4.0(15)：「Dockとアプリケーションスイッチャーに表示しない」（StartupWindow.swift の DockPresence。LoginAtLaunchControl 内の StartupWindowControl に表示、起動時は MenuBarPresence.install で適用）。ビルド確認済み・実機未確認 |
| B05 | 終了と処理保護 | 実装済み・実機未確認 | 終了時に KeyRecorder.stop() でイベントタップを外す。AppleScript の quit が -128（取り消し）になった現象を確認、原因未調査 |
| B06 | 標準キー操作 | 実装済み・実機未確認 | ⌘, ⌘W ⌘0 ⌘? ⌘Q、記録中の修飾なしEscで取り消し |
| B07 | ショートカット管理 | 適用外 | グローバルホットキーを登録しない。記録中だけイベントタップを張り、記録したキーを離すか1.5秒で外す。アプリ外へ移ると記録を取り消す |
| B08 | 設定・位置の保持 | 実装済み・実機未確認 | 照合元のオン／オフを UserDefaults（source.*）、ウインドウは画面外復帰（MainWindow.keepOnScreen） |
| B09 | 権限の案内と再判定 | 実装済み・実機未確認 | 設定「起動・常駐」にアクセシビリティ区画（共通部品・required）、主画面に未許可の案内。未許可でもアプリ内のキーで記録できる |
| B10 | 原本保護・復元 | 適用外 | 設定ファイルは読むだけ（SQLiteは読み取り専用で開く） |
| B11 | 二重処理・中断対策 | 実装済み | 読み込みは前回のタスクを取り消してから開始 |
| B12 | 成否・復旧表示 | 実装済み・実機確認済み | 件数／有効件数／見つからない旨、無効・停止中の表示を実機で確認（⌘S） |
| B13 | 待機負荷・復帰 | 実装済み・実機未確認 | 常時のポーリング・タップなし。読み込みは表示時・記録時（30秒以内は再利用）・読み直しのみ |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 実機確認済み（表示） | ContentView ヘッダー。VoiceOverは未確認 |
| B15 | 多言語 | 実装済み | ja/en/zh-Hans/ko、Tests/check-localization.py PASS |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 実装済み・実機未確認 | Help.txt 4言語、⌘?、情報タブ |
| B17 | プライバシー | 実装済み | 通信なし、ローカルの設定を読むだけ |
| B18 | 更新・配布・最終版の/ApplicationsとLatest Buildsへの配置 | 配置確認済み | deploy_both.py で両方 0.1.0 (2) signature/content match。更新配信先は未設定（Updater は準備中表示） |
| B19 | マスタード基調の共通アイコン | 実装済み | Assets/GenerateIcon.swift（BundleIDInspector と同じタイル、キーキャップ⌘＋虫めがね） |
| B20 | 共通UI統一・起動/常駐/起動ショートカットの同一グループ・アクセシビリティも同一タブ内の区画 | 実装済み・実機未確認 | SettingsView：起動・常駐（＋アクセシビリティ区画）／照合元／情報。2026-10-17 0.3.3(12)：起動・常駐を Form(.grouped) から SettingsSection に変更し、その下に AccessibilitySection()。理由は AccessibilityText.neededOverride（4言語）。メイン画面の判定を AccessibilitySection.isTrusted に（独自の KeyRecorderStatus を削除）。ビルド・配置・起動確認、見た目は未確認 |
| B21 | 対象外アプリの設定・処理抑制・標準キー操作の保持 | 適用外 | 他アプリに作用しない（読むだけ）。2026-10-17 再確認：適用外のまま（他アプリに作用しない）。ExcludedApps は使わない |
| B29 | 設定の書き出し・読み込みと同期 | 実装済み・実機未確認 | 2026-10-16 0.3.2(11)：SettingsView に「設定の共有」タブ（情報の直前）、AppDelegate.startSettingsSync。共有: source.order・source.*・customSources・lookup.hideInactive（独自の照合元は merge で「追加する」）。Macごと: ログイン起動・起動時非表示・メニューバー・lookup.target/lookup.app。onImport で CustomSources のキャッシュ破棄＋HotkeyStore.reload、設定画面の一覧を作り直す。build.sh 成功・check-localization PASS・両配置 0.3.2(11) 一致・起動確認。書き出し/読み込み/同期の操作は未確認 |
| ホットキーの記録欄 | 共通の HotkeyField（Shared/HotkeyRecorder） | 適用外 | 2026-10-17：設定で割り当てるホットキー（機能・アプリ呼び出し）が無い。キーを扱うのはアプリ本体の照合（KeyRecorder）と独自の照合元の一覧の登録で、どちらも調べる対象のキーを控えるもの。アプリ独自の KeyCombo 型が共通部品と同名のため、取り込むなら改名が要る |

## 確認記録

- ソース確認：実施
- ビルド・自動テスト：build.sh 成功、check-localization PASS、スキャナーを単体ハーネスで実データ照合（KM 3,038件・BTT 48件・Karabiner 33件・DFX 32件・メニュー546件）
- 実機で起動・閉じる・再表示・⌘Q：起動と記録・照合のみ確認。他は未実施
- 再ログイン・OS側で自動起動OFF：未実施
- 別コピー起動・引数/ファイル受け渡し：未実施
