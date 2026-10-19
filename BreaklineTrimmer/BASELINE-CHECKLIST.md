# 共通仕様の実装と確認

アプリ名：BreaklineTrimmer
バージョン/build：1.2.0 / 4
確認OS/CPU：macOS 26 (Darwin 25.6.0) / arm64（x86_64はビルドのみ）
確認日：2026-10-19

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。

「画面表示」は Tests/snapshot.sh で実際のSwiftUI画面をオフスクリーン描画した画像（日本語・英語、ライト・ダーク、7状態）での確認。この環境には画面収録の許可がなく、マウス・キーボードでの実操作は未確認。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 実機確認済み（一部） | main.swift SingleInstanceLaunch（Bundle ID）＋LSMultipleInstancesProhibited。/Applications版の起動中に `open -a … sample.png` で再度渡しても1プロセスのまま。別フォルダのコピーからの起動は未確認。 |
| B02 | ログイン起動設定 | 実装済み・実機未確認 | Shared/LoginAtLaunch（LoginAtLaunchView）、初期値オフ。画面表示で確認。再ログインは未確認。 |
| B03 | ログイン時の非表示 | 実装済み・実機未確認 | AppDelegate.isLoginLaunch でメインウインドウを出さない（ファイルを渡された場合は表示）。 |
| B04 | 常駐と再表示 | 実装済み・実機未確認 | 通常アプリ（Dock常時表示）。「ウインドウを閉じても常駐」初期値オン（オフで閉じると終了）。Dock・⌘0・メニューバー（選択時）から再表示。画像と範囲は閉じても保持。 |
| B05 | 終了と処理保護 | 実装済み・実機未確認 | PNGの書き出し中は applicationShouldTerminate で理由を表示して終了を取り消す。それ以外は即終了（保存していない成果物は元画像から作り直せる）。 |
| B06 | 標準キー操作 | 実装済み・実機未確認 | ⌘O・⌘S・⇧⌘C・⌘0・⌘,・⌘W・⌘Q・⌘?、標準の編集メニュー。入力欄の外では ⌘C で結果をコピー、⌘V で画像をペーストして開く（入力欄では通常のコピー・ペースト）。 |
| B07 | ホットキー管理 | 適用外 | グローバルホットキーなし（画像を開いて調整する編集アプリのため）。 |
| B08 | 設定・位置の保持 | 実装済み・実機未確認 | UserDefaults（切り口・省略線・マスク用の図形の13項目、keepRunning、1.1.0からoutputLocation・outputFolder・outputSuffix）、frame autosave（TrimBreaklineMain・BreaklineTrimmerSettings）、画面外なら中央へ。 |
| B09 | 権限の案内と再判定 | 適用外 | 許可が必要な操作なし。読むのは開いた・ドロップした・ペーストした画像、書くのは保存先に選んだファイルだけ。 |
| B10 | 原本保護・復元 | 実装済み（自動テスト一部） | 元画像は書き換えない。1.1.0：保存先を設定で選ぶ（元画像と同じ・デスクトップ・指定・毎回指定）。直接保存は隠しファイルに書いてから空いている名前へ移動し、既存ファイルを置き換えない（名前は元の名前＋設定の文字、初期値「-breakline」）。毎回指定は保存パネル、元画像そのものは拒否。指定フォルダが無いときは理由を表示して保存パネル。 |
| B11 | 二重処理・中断対策 | 実装済み | プレビューはバックグラウンドで描画し、新しい変更が古い結果を破棄（generation）。保存中は保存・コピー・開くを無効。4000×3000の描画0.02秒（test.sh）。 |
| B12 | 成否・復旧表示 | 実装済み・画面表示確認 | 状態欄に元と結果のサイズ・切り分け方、保存・コピーの結果、開けない／範囲が端から端までの理由（アイコン＋文字）。6-error の画面で確認。 |
| B13 | 待機負荷・復帰 | 実装済み | ポーリング・タイマーなし。変更時だけ描画。実測は未実施。 |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 画面表示確認（ライト・ダーク） | AppHeader（バンドル内アイコン・版）＋AppSurface。元画像・プレビュー・切り口ボタンに accessibilityLabel、状態はアイコン＋文字。VoiceOverは未確認。 |
| B15 | 多言語 | 実装済み・画面表示確認（ja・en） | make-resources.py で ja/en/zh-Hans/ko、check-localization.py 通過（ビルド時にも実行）。中国語・韓国語の画面は未確認。 |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 実装済み・実機未確認 | Help.txt（4言語）、ヘルプメニュー ⌘? と「note記事を開く」、メインウインドウの［ヘルプ］、「情報」タブ、標準のアプリについて。 |
| B17 | プライバシー | 実装済み | 外部通信なし。画像は保存しない（UserDefaults は設定値だけ）。 |
| B18 | 更新・配布・最終版の/ApplicationsとLatest Buildsへの配置 | 実機確認済み（配置・起動） | build.sh → deploy_both で両配置先に配置、署名・内容一致を確認、/Applications版の起動を確認（2026-10-19）。更新は Shared/Updater 組み込み済みだが配信先・鍵が未設定のため準備中（通信しない）。公証：1.1.0 build 3 の配布用DMGを Developer ID＋Hardened Runtime で署名し Accepted・staple・Gatekeeper accepted（Shared/ReleasePreparation/20261019-BreaklineTrimmer）。 |
| B19 | マスタード基調の共通アイコン | 実装済み・画像確認 | Assets/GenerateIcon.swift：YohakuTrimmer と同じマスタード・アイボリー・茶。波形の切り口で上下に分かれた写真と2本の省略線。apply-app-icon.sh 適用。Finder表示は未確認。 |
| B20 | 共通UI統一 | 画面表示確認 | SettingsTabs：「起動・常駐」（ログイン起動・起動時非表示・常駐・メニューバー／操作）、「設定の共有」、「情報」。トリミングの項目はメインウインドウ。呼び出しホットキー（B07）・アクセシビリティ区画は不要のため設けない。 |
| B21 | 対象外アプリ | 適用外 | 他アプリに作用しない。 |
| B22 | 起動時にメインウインドウを表示しない | 実装済み・実機未確認 | LoginAtLaunchControl 内の StartupWindowControl。ファイルを渡された起動では表示。 |
| B23 | 開き直しと⌘Tab・⌘0 | 実装済み・実機未確認 | applicationShouldHandleReopen、通常アプリ、⌘0/⌘1（MenuBarPresence）。 |
| B24 | 設定ウインドウのふるまい | 実装済み・実機未確認 | リサイズ可・最小サイズ（sizingOptions .minSize）、タブ復元、即時反映、タイトル「設定」。 |
| B25 | アプリ情報と目印 | 実装済み | NSHumanReadableCopyright・SWAppFamily。SWNoteArticleURL は専用記事がまだないため、まとめ（https://note.com/swwwitch/m/m057948d2fbeb）。記事公開後に差し替える。 |
| B26 | 証明書での署名 | 実装済み | build.sh でチーム証明書（PL9S9PXX96）署名、codesign --verify 通過。配布用は Developer ID＋Hardened Runtime＋公証（20261019-BreaklineTrimmer、Accepted）。 |
| B27 | 取消と失敗の伝え方 | 実装済み・実機未確認 | 失敗は状態欄に理由。出力できないときは保存・コピーのボタンとメニューを無効。保存・開くパネルは標準（Escで取消）。 |
| B28 | ウインドウ位置とアクセシビリティの細目 | 実装済み・実機未確認 | 初回中央・画面外復帰、自作描画（元画像・プレビュー・切り口ボタン）に accessibilityLabel。 |
| B29 | 設定の書き出し・読み込みと同期 | 実装済み・画面未確認 | SettingsSharingView。共有キーは Model.sharedKeys（15項目：トリミング13・outputSuffix・outputLocation）。keepRunning・ログイン起動・起動時非表示・メニューバー・指定フォルダ（outputFolder）はMacごと。onImport で reloadSharedSettings。 |
| — | ホットキーの記録欄 | 適用外 | 設定にホットキーを割り当てる欄がない（B07）。 |

## 確認記録（2026-10-19）

- 自動テスト：test.sh 54項目通過（切る向き・片側だけ残す・間隔と移動量・幅での切りそろえ・大きさ・位置・省略線の位置と色・丸型線端と直線端の範囲・破線の長さ・4形状の切り口の中心・ギザギザの点数・カーブのかみ合わせ・透明の保持・PNGの往復（アルファ・144dpi）・設定の範囲・大きな画像）＋4言語の文字列とヘルプ。
- 画面表示（Tests/snapshot.sh）：空・旗・ダーク・ギザギザ＋破線・左右＋上昇・片側（直線）・エラー・設定。出力サイズが帯の幅どおり（1200 px）になることを確認。
- 書き出し：同じコードでサンプル（1200×800、四隅透明、144dpi）から 1200×688・アルファあり・144dpi のPNGを確認。
- 未確認：マウスでの範囲の描画・移動、保存パネル・コピー・ペーストの実操作、ログイン起動、VoiceOver、中国語・韓国語の画面、Intel実機、公証。

## 1.1.0（2026-10-19）

- 追加：ガイドのドラッグで範囲の端を動かす（CanvasDrag：端・ガイドの6pt以内、ガイドは画像の幅いっぱい）。設定「出力」タブ（保存先4種・指定フォルダ・付ける文字）。保存後の「Finderで表示」。
- 自動テスト：test.sh 54項目通過。画面表示：ガイドとつまみ、「出力」タブ（Tests/snapshot.sh）。
- 未確認：ガイドのドラッグとカーソルの実操作、直接保存・番号付け・フォルダ選択の実操作。

## 改名（2026-10-19）

- TrimBreakline → BreaklineTrimmer。対応表：フォルダー TrimBreakline/ → BreaklineTrimmer/、TrimBreakline.app → BreaklineTrimmer.app、実行ファイル・アイコン（BreaklineTrimmer.icns）・メニュー・ヘルプ・常駐メニュー名・設定の書き出しファイル名（BreaklineTrimmer-Settings.plist）。
- Bundle ID：利用者の指示で jp.dtp-transit.trimbreakline → jp.dtp-transit.breaklinetrimmer（1.1.0 build 3）。Model.migrateFromFormerBundleID が初回起動時に旧ドメインの値を、未設定のキーにだけ写す（ウインドウ位置の保存名は BreaklineTrimmerMain・BreaklineTrimmerSettings に読み替え）。UserDefaults のキー名は変えていない。ログイン項目は旧アプリの登録を引き継がない（初期値オフ）。
- 旧 1.1.0 build 2（旧Bundle ID）は Backups/bundleid-20261019-112218 へ退避。
- 旧 /Applications/TrimBreakline.app と Latest Builds/TrimBreakline.app（1.0.0、SHA-256 一致を確認）は Backups/rename-20261019-112103 へ退避。

## 1.2.0（2026-10-19）

- 追加：プレビューの背景（PreviewBackground、@AppStorage previewBackground、表示のみ・Macごと）。省略線の色（TrimSettings.ruleColor、UserDefaults ruleColor "#RRGGBBAA"、sharedKeys に追加）。
- 自動テスト：test.sh 56項目通過（赤い省略線の画素、16進の往復）。画面表示：背景グレー・赤い破線（Tests/snapshot.sh）。
