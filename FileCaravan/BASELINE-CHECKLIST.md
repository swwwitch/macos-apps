# 共通仕様の実装と確認

アプリ名：FileCaravan
バージョン/build：1.0.1 / 16
確認OS/CPU：macOS 26.7.1 / arm64
確認日：2026-10-07

状態は「未実装／実装済み・実機未確認／実機確認済み／適用外」。証拠なしに完了へ変更しない。

| ID | 項目 | 状態 | ソース・検証証拠・残件または適用外の理由 |
| --- | --- | --- | --- |
| B01 | 二重起動防止 | 実装済み・実機未確認 | main.swift + LSMultipleInstancesProhibited。launchDate/PIDで既存インスタンスへ戻す。別コピー起動の実機検証は後述。ファイルopenイベントは未提供。 |
| B02 | ログイン起動設定 | 実装済み・実機未確認 | Source/LoginAtLaunch.swift。SMAppServiceの状態を読み取り、ON/OFF・承認待ち・未登録・失敗を表示。設定画面のOFFは実機確認。登録ON、再ログイン、OS側OFFは未確認。 |
| B03 | ログイン時の非表示 | 実装済み・実機未確認 | LaunchPolicy.swift。ログインAppleEventではshowMainを呼ばない。実際の再ログイン未確認。 |
| B04 | 常駐と再表示 | 実装済み・実機未確認 | main.swift。常駐初期ON、閉じると非表示、Dock/再オープン/⌘0で再表示。設定保持を確認。常駐OFF終了は未確認。 |
| B05 | 終了と処理保護 | 実装済み・実機未確認 | main.swift applicationShouldTerminate。移動中は終了拒否して理由と停止を提示。待機時⌘Qでプロセス終了を確認。処理中終了ダイアログは未確認。 |
| B06 | 標準キー操作 | 実機確認済み | ⌘,で設定表示、⌘Q終了を実機確認。標準編集メニュー、⌘W、Esc停止を実装。Esc停止はエンジン自動テストのみ。 |
| B07 | ショートカット管理 | 適用外 | 外部アプリに作用するグローバル操作なし。起動キーはmacOS ShortcutsでOpen Appをユーザーが作成・変更・解除。アプリ内自動登録/キー録音は未実装。 |
| B08 | 設定・位置の保持 | 実機確認済み | UserDefaultsへフォルダ・オプション・常駐、NSWindow frame autosaveを保存。build1→2更新後に両フォルダと設定保持を確認。build2では要求に沿ったサイズ移行を一度だけ実施。画面外復帰はソースのみ。 |
| B09 | 権限の案内と再判定 | 実装済み・実機未確認 | 必要なのはユーザーが指定したフォルダの読書き。事前検証とエラー時案内、ヘルプにシステム設定経路。AX/Automation権限は不要で要求しない。拒否→復帰の実機確認なし。 |
| B10 | 原本保護・復元 | 実装済み・実機未確認 | MoveEngine.swift mv -n + 実行前衝突/identity確認。同名をスキップ、実行確認に移動・Undo非対応を明記。履歴と手動復元説明あり。衝突/置換/特殊名は17自動アサーション通過。別ディスク途中失敗は未確認。 |
| B11 | 二重処理・中断対策 | 実装済み・実機未確認 | バックグラウンド処理、busy二重実行防止、実行中mvをkillせずバッチ境界停止。2,000件一括と128件後中断を自動確認。強制終了/電源断では別ディスクの部分コピーがあり得る旨をヘルプ記載。 |
| B12 | 成否・復旧表示 | 実機確認済み | 移動/スキップ/失敗/未処理を別表示。JSONL結果・attempt記録、履歴保存失敗は実行停止。実機画面で3,292件移動完了・失敗0表示を観測（ユーザーが操作した状態、こちらによる本番データのテストではない）。診断stderrは4KBに制限。復元履歴は自動削除せずユーザー管理。 |
| B13 | 待機負荷・復帰 | 実装済み・実機未確認 | 待機ポーリングなし。バックグラウンド処理は移動要求時のみ。CPU/メモリ、スリープ復帰は未確認。 |
| B14 | 見出し左の現行アプリアイコン・共通ヘッダー・表示・アクセシビリティ | 実機確認済み | Shared/AppStandards/AppHeader.swift、AppSurface.swiftを参照。バンドルの現行icnsを表示。薄灰背景、タイトルバー無名、コンパクトカードを実機スクリーンショットで確認。AXラベル実装。Dark/VoiceOver読み上げは未確認。 |
| B15 | 多言語 | 実装済み・実機未確認 | Resources/{ja,en,zh-Hans,ko}.lproj。全キー集合一致・plutil構文・ソースの固定L参照を検証。日本語UI/ヘルプ実機確認。他3言語の画面・長文レイアウト/フォールバックは未確認。 |
| B16 | 同梱ヘルプ・メニューからの表示・アプリ情報 | 実機確認済み | アプリのヘルプメニュー→日本語オフラインヘルプ表示を/Applications版で確認。4言語本文同梱、標準Aboutへ名称/版/build/サポート（作成元チャット）を設定。 |
| B17 | プライバシー | 実装済み・実機未確認 | 外部通信なし。ローカルUserDefaultsと復元履歴だけを保存。パスを含む履歴の用途と削除方法をヘルプへ。 |
| B18 | 更新・配布・最終版の/ApplicationsとLatest Buildsへの配置 | 実装済み・実機未確認 | 更新メニューは未設定と明示。ローカルad-hoc署名、Developer ID/公証/更新feed/公開鍵なし。2配置先の検証は確認記録を参照。 |
| B19 | マスタード基調の共通アイコン | 実機確認済み | Shared/DesignAssets/app-icons-mustard-final.pngを実際に参照。Assets/GenerateIcon.swiftでマスタード背景・白い積層書類/フォルダ・茶色矢印を作成。現行.icnsはメインヘッダーで表示確認。Finder/情報ウインドウは未確認。 |
| B20 | 共通UI統一・起動/常駐/起動ショートカットの同一グループ・アクセシビリティの別グループ | 実機確認済み | Shared/AppStandards/LaunchPresenceSection.swiftを新設して再利用可能に。ログイン起動→常駐→アプリ起動ショートカットの順。プライバシー/履歴を別グループ。起動キーはOSショートカット設定への導線と手順。AX不要につき許可グループなし。 |
| B21 | 対象外アプリの設定・処理抑制・標準キー操作の保持 | 適用外 | ユーザーが明示指定したフォルダを自アプリ内で処理。前面アプリの選択やキー入力には作用しない。外部アプリ連携/グローバルキー監視がないのでBundle ID除外設定は対象にならない。 |

## 確認記録

### build 5: ラベル変更

- 日本語のsourceを「ソース」、destinationを「コピー先」に変更。移動処理は変更なし。
- ビルド・署名検証成功。旧版をBackups/Applications-build4へ保存。/ApplicationsとLatest Buildsの内容一致、/Applications版の画面・AXラベルを実機確認。

### build 4: Dropboxパス簡易表示

- FolderHopperのdisplayPathを参照し、Source/PathDisplay.swiftでDropbox-sharedより前を表示上省略。実際のURL、確認画面、履歴、ツールチップは完全なパスを保持。
- 設定の「表示」に「Dropboxのパスを簡易表示」を追加。初期ON、AppStorageで保存して即時反映。4言語のリソースとヘルプを更新し、strings構文確認済み。
- ビルド成功。旧/Applications版はBackups/Applications-build3へ保存。停止確認後に更新。build・/Applications・Latest Buildsの内容SHA-256一致、署名検証成功。
- /Applications版で設定ONと左右の /Dropbox-shared/Pictures、/Dropbox-shared/Pictures-2026-10 表示をスクリーンショット確認。完全パスの保持はAXで確認。移動処理は変更なし。

- ソース確認：完了。共有ヘッダー/地色/起動設定部品、既存LoginAtLaunch/LaunchPolicy/LocalHelp/Updater/BuildToolsを調査。Updaterはfeed/鍵なしのため開始しない。
- ビルド・自動テスト：build 1・2成功。17アサーション（2,000件移動を含む）通過。build 3最終確認は下記追記。
- 実機：/Applications版の主画面・コンパクト化・見出し・設定・ヘルプメニュー、待機時⌘Q、再起動後の設定保持を確認。
- 再ログイン・OS側OFF・ログイン起動実登録・スリープ復帰：未実施。ユーザー環境の設定変更/ログアウトは行わない。
- 本番ファイル：エージェントの自動テストは一時フォルダのみ。UI取得時にユーザー操作による3,292件完了表示を観測。
- 配置：新規作成時既存/Applications/FolderMover.appなし。build 2置換前はFolderMover/Backups/Applications-build1に保存。Latest Buildsは共通publish_latest.pyで版/ID/署名/内容照合とバックアップ。


### build 3 最終配置確認

- 1.0.0 / build 3 / local.takano.FolderMover。ソースbuild、/Applications、Latest Buildsの全12ファイルSHA-256一致。3か所すべてcodesign --verify --deep --strict成功。署名はad-hoc。
- 旧build2はFolderMover/Backups/Applications-build2へ保存し、プロセス停止を確認して置換。設定は変更せず保持。
- /Applications/FolderMover.appの主画面と設定をCUAで確認。見出し「大量のファイルをまとめて移動」、左右フォルダ保持、ログインOFF（未登録表示）、常駐ONを確認。
- 設定・ヘルプの⌘W閉じるは確認。主画面閉じるのAX取得は可視性を判定できなかったため、常駐/再表示の完全検証は未確認のまま。
- build3の4言語リソース構文・キー一致・参照整合を再確認。移動エンジンは初回17アサーション通過後に変更なし。
- 別コピー起動：Latest Builds版をopen -nで起動後、実行中のFolderMoverは/Applications版の1プロセスだけであることをpsで確認（PID 17490）。

## build 6（2026-10-06）

FolderHopperと同じタグ着色を導入。/Applications版でオレンジ／緑のテストフォルダー表示を実機確認。通常版・Store候補コンパイル／strict署名検証成功。通常版2配置先とビルドの内容ハッシュ一致。Sandbox候補でフォルダー選択→mv移動、再起動後のbookmark復元→mv移動を各1件、内容一致まで確認。Store配布profile／Installer署名／申請情報／残りのSandbox条件検証はAppStore/README.md参照。審査未提出。

## build 7（2026-10-06）

ソース／コピー先の見出し右にクリアボタンを追加。選択URLをnilにして保存済みパスを解除し、移動中と未選択時は無効化。ファイル／履歴には触れない。4言語とヘルプ更新、通常版ビルド成功。Applications／Latest Buildsの署名と内容ハッシュ一致。Applications版でボタン表示とクリア後の移動不可を確認。移動処理は変更なし、新規自動テストは追加していない。

## build 8（2026-10-06）

B14: 中央の移動方向矢印を30pt・semiboldに拡大、幅40ptを確保。コンパクトなウインドウ寸法は維持。ビルド成功、Applications版の実画面で表示・レイアウトを確認。B18: 既存版をバックアップし、Applications／Latest Buildsのversion 1.0.0 build 8・strict署名・内容ハッシュ一致を確認。表示のみの変更につき自動テストは追加していない。

## build 9（2026-10-06）

B14: 中央矢印を見出し込みの高さではなくフォルダー選択枠の天地中央にcustom alignment guideで整列。実機スクリーンショットで枠上下282〜626px、矢印中心455pxを確認。ビルド成功。B18: バックアップ後、ApplicationsとLatest Buildsへ配置しbuild 9・strict署名・内容一致・Applications版起動を確認。表示変更のため自動テスト追加なし。

## build 10（2026-10-06）

B14/B15/B16: 日本語ラベルを「コピー先」から「移動先」へ変更。クリアのアクセシビリティ名、選択ダイアログ、ヘルプ、申請メタデータ案も統一。ビルド成功、Applications版の表示を確認。B18: バックアップ後に両配置先へbuild 10を配置。strict署名と内容一致を確認。文言変更のため自動テスト追加なし。

## build 11–12（2026-10-06）

B08/B14/B15: 完了後に移動先を開くオプション（初期OFF、保存、処理中は無効）を追加。成功時のみNSWorkspace.openを実行し、エラー時は状態文言を表示。隔離した検証アプリでOFF初期値・ONで1件正常移動を実機確認。フォルダー表示そのものの確認は未完了。build 12で包含オプションを4言語ともサブフォルダーと明示。Applications版で文言と収まりを確認。B18: build 12を両配置先へバックアップ後配置、署名・内容一致確認。文言変更の新規自動テストなし。

- B22: StartupWindow.swiftと起動処理に実装。初期値OFF・永続保存。ビルド済み、実機確認は進行中。

## build 16（2026-10-07）

B15/B16: About・ヘルプのサポート案内を4言語とも「同梱のREADME.md」に変更し、README.mdをContents/Resourcesへ同梱。make-resources.pyはInfo.plistのversion/buildを引き継ぐよう修正し、再生成でbuildが戻らないことを確認。ビルド成功、test.sh成功、strict署名を確認。B18: Applications／Latest Buildsへの配置・実機確認は未実施。

## FileCaravan名称変更（2026-10-07）

- 現行ソースは FileCaravan/。Bundle ID local.takano.FolderMover、履歴 FolderMover/History、ウインドウ位置キー FolderMoverMain は互換性のため保持。
- メニュー・4言語ヘルプ・アイコン資産名・ビルド経路・申請原稿を変更。旧版・過去の検証記録は履歴として保持。
- 配布と起動の検証結果は Rename-20261007.md を参照。
