# 現行リリースの確認

現行配布版：1.2.2 build 16。build 15の記録は以下に保持。詳細はBASELINE-CHECKLIST.md。

- ローカル版：全テスト、両配布先の署名／内容一致、起動、設定保持を確認。
- 実機：メイン画面の一括スイッチ撤去・標準セット・スペシャルの表示を確認。全標準操作の実行は未確認。
- 公開記事：https://note.com/swwwitch/n/n7b7e549f7379 。現行名称と機能説明へ更新済み。
- 公証済みbuild 15：アプリ／DMGともAccepted、stapler検証、Gatekeeper受理を確認。DMG整合性とマウントしたアプリの内容一致を確認。
- noteへKeynoteMaestro-1.2.2-build15-notarized.dmgを追加して公開済み。旧build 7は保持。公開ファイルを再取得しSHA-256一致を確認。
- リポジトリ全アプリの整合性：Shared/OrganizationLogs/20261022-app-consistency/REPORT.md。35アプリの両配布先は一致、5アプリはソースbuildが1先行。

## 公証・配布記録（2026-10-22〜23）

- アプリ公証ID：`5e17935a-9787-4c86-9400-0bba5297f092`（Accepted）
- DMG公証ID：`3bb62f4a-727b-4039-9e97-eff4310e2854`（Accepted）
- DMG SHA-256：`df130a20e6ea0179cbcfe86d3f131e0d492d0f70e40a6515a8943def09891581`
- 公開添付：https://note.com/api/v2/attachments/download/018aa101cf65bbe32f5f7d90933d01be
- アプリの公証チケット付与後、共通deploy_both.pyで既存版をバックアップして両配置先へ更新。署名・内容一致、/Applicationsからの起動、カスタム設定の保持を確認。
- 承認された既存DMGをそのまま公証。DMG内アプリは署名済みステージと一致しGatekeeperで受理。インストール済みアプリには本体の公証チケットも付与。
- Keynote上で全操作の実行確認は未確認。

## build 16（2026-10-23）

- 設定のスペシャルタブから全体有効スイッチを削除。メインウインドウのスイッチと保存値は保持。
- ビルドと既存test.shは成功。画面の実機確認は未確認。
- 自動承認レビューが未公証ローカル版の共有配布先への置換を拒否したため、配布先はbuild 15を維持。build 16の配置・起動確認は未完了。

## build 16公証・公開完了（2026-10-23）

- 全アプリ一括リリースの中でビルド・既存テスト・アプリ／DMG公証Acceptedを確認。
- 公証チケット、Gatekeeper、DMGの整合性、マウント内のファイル一致を確認。
- /ApplicationsとLatest Buildsへバックアップ付きで反映し、署名・内容一致・起動確認まで完了。
- 公開：https://github.com/swwwitch/KeynoteMaestro/releases/tag/v1.2.2-build16
- 公開DMGのSHA-256：`ef9a7278172a123b7b28d25b8b1982619c6c27b2f78d9fbb92edfbb6ccb4c23b`
- noteはGitHub Releasesへの最新版リンクに更新し、旧build 15・7を保持。
- 全Keynote操作・設定リサイズの実機確認は未確認。

## build 17：自動マジックムーブ（未公開開発版）

- 実装：Sources/AutoMagicMove.swift、KeynoteCommands.swift、CommandRunner.swift、main.swift。既存設定を変更しない新規ID、初期値OFF。
- 自動テスト：`test.sh --integration`成功。記録：Shared/ReleasePreparation/20261023-KeynoteMaestro-build17/test-and-integration.log。
- 実Keynote：専用16枚で5枚への適用と非対象効果・遅延・自動切り替え・スキップの保持を確認。実ムービー/オーディオの挿入は未確認。
- 公開：GitHub/noteへは追加・更新しない。公開配布版はbuild 16を保持。
- build 17の公証・配置・画面確認は下記の最終記録へ追記する。

## build 18：標準ショートカット設定のコンパクト化（未公開）

- 自動マジックムーブの実装を保持。初期設定サイズ1100×720→820×620ポイント（面積約36%減）、最小720×560は維持。保存済みの大きいサイズは初回のみ縮小し、以後のリサイズは保持。
- 標準タブの固定3列（標準キー150・変更欄420・最小一覧幅760）を撤廃。標準キーを操作名の下に置き、変更欄340の2列へ整理。幅不足は縦並びへ切替。文字サイズは維持し、長い一覧は縦スクロール。スペシャル等のタブ本文は変更なし。
- 標準セット・検索・カテゴリ・リセット・変更/クリア・登録状態表示・キー保存の既存処理を維持。機能設定の保存形式・Bundle IDを変更していない。
- 署名付きビルド成功。既存の全テストPASS（自動マジックムーブ、104互換ID、103操作、標準/スペシャル分離、305標準アクション、341原典、4言語256キー）。ログはShared/ReleasePreparation/20261023-KeynoteMaestro-compact/。
- 実画面確認：既存build16の主画面は読み取れたが、設定を開くクリック時にmacOS操作接続が切断。接続初期化後も復旧せず。変更後の初期サイズ・タブ切替・スクロール・キー欄の見切れ・4言語の画面は未確認（記載サイズはコード上の指定値）。
- 成果物：同フォルダーSignedApps/KeynoteMaestro.app、1.2.2（18）、Developer ID署名。公証・両配置先の更新・配置後起動は未実施。現在の公証済みbuild16を保持。GitHub/noteは変更なし。

## build 19：背景グループ修正・9ボタンパレット（未公開）

- build17の自動マジックムーブ、build18の標準設定縮小（初期1100×720→820×620、最小720×560）を保持。設定の保存済みフレームは実起動時に820×652ポイント（タイトルバーを含む）を確認。
- 背景の原因：従来は最前面移動後の「最後の2個」を選んでおり、Keynoteが重ね順変更時に要素の順序とインデックス参照を書き換えるため、無関係な図形を拾う。さらに閉じた配置メニューの有効状態が古く、正しい2個選択後もGroupが無効扱いとなる。作成処理は元から1回で、単一実行内の二重作成は再現していない。
- 修正：作成前の元の位置・件数を保存、背景1個のみ作成・背面移動。作成した背景の選択・背面位置・件数・同一書類/スライドを確認して元の位置を対応付け直す。配置メニューを更新してから正確な2個をグループ化。色・既定スタイル・サイズ・不透明度100を保持。従来の最後の2個取得スクリプトは呼び出さない。
- Tests/GroupedBackgroundIntegration.swift：Keynote 14.5の専用未保存文書で本番CommandRunnerとAXメニューを実行。元が背面・中間・前面の3ケースで、背景が正確に1個、背景が背面、グループ内2個、元の文字/位置/サイズ、無関係な2図形、busy中の2回目呼び出しが追加作成しないことをPASS。テスト文書は閉じた。途中ハーネスの初期化エラーで残った空文書2件もIDと内容を照合して閉じ、元の利用者書類1件だけが残ることを確認。
- 自動マジックムーブの16スライド実機テストもPASS。最終背景ログはShared/ReleasePreparation/20261023-KeynoteMaestro-build19/background-integration-final.log。初期ハーネスエラーのintegration.log / integration-retry.logは失敗履歴であり、最終背景結果ではない。
- パレット：CommandPalette.swiftの非アクティブNSPanel（key/main不可）、9既存コマンド、1/6/2の3グループと2区切り、指定日本語名、4言語ヘルプ。メイン/ファイル/メニューバー入口、閉じる・再表示・位置保存・画面外復帰。新規グローバルキーなし。個別ホットキーのオンオフとは独立。
- ガード：前面の実Keynote Bundle ID/プロセス、共通ExcludedApps、アクセシビリティ、pause/native sending/busyを実行直前と各ステップで確認。パレットは書類IDを捕捉し、スクリプト実行時に前面書類の一致も確認して同じ書類に限定。ボタンからの失敗はホットキー送信へフォールバックしない。
- ビルド・自動テスト：Developer ID＋Hardened Runtime・timestamp署名build19成功、全既存テストと9ボタン対応/区切り/書類固定/実行禁止ガード/正確な日本語・4言語269キーPASS。コマンドID104、利用可103、設定保存形式・Bundle ID維持。
- 起動：署名済みSignedApps/KeynoteMaestro.appのbuild19を起動し、主画面の103操作、カスタム選択、AX許可済み、パレット入口を確認。機能設定のスナップショット照合PASS。設定の初期サイズ縮小は保存フレームから確認。
- 画面の未確認：標準設定を開くとコンピューター操作接続が切断。アプリのmain threadが通常のイベント待ちに戻りCPU約1%で停止していないことをsampleで確認。標準のタブ切替・スクロール・キー欄の見切れ・多言語画面は未確認。パレット入口のクリックは実行したが、非アクティブパネル自体を操作ツールが取得できず、各ボタンクリック時の選択保持・閉じる/再表示・画面外復帰は実機未確認。これらはソース確認/自動テストの結果と区別する。
- 公証・両配置先更新・配置後起動は未実施。公証済みbuild16を保持。GitHub/noteは今回変更していない。

## build 20：パレットの横幅（2026-10-23）

- 横幅300→260ポイント（40ポイント縮小）、高さ400・文字13ポイント・9機能・区切り・非アクティブ動作を保持。保存済みの旧幅で戻らないよう、位置復元後に幅を適用。
- 実フォントによる4言語の最長ボタン名測定：日本語172、英語197、簡体字143、韓国語164ポイント。外側余白24とボタン左右余白24を加えても最大245ポイントで260以内。実画面での見切れ確認とは区別する。
- 公証・配布先更新・GitHub/note公開は対象外のまま。署名済み開発版のビルド/起動結果はShared/ReleasePreparation/20261023-KeynoteMaestro-build20/。

## build 21：パレットの区切り線（2026-10-23）

- 「スライドの幅の80%（中央）」の直下へ区切り線を追加。1/3/3/2の4グループ、計3本。幅260・高さ400・9ボタンの順序と既存機能は保持。4言語ヘルプと既存の並び順検証を更新。

## build 24：パレット見出し・13項目の表示設定（2026-10-23）

- build22/23の途中版を統合。パレットの先頭は見出し「トランジション」とディゾルブ/なし/マジックムーブ/マジックムーブ（自動）。「中央」の3項目はパレットだけ末尾の（中央）を外し、中央配置の機能を保持。「オブジェクトの揃え」の3項目、アニメーション2項目を順序どおり維持。末尾にスライドサイズ図形作成を追加。設定の既存command.*全名称をbuild21と4言語で照合し一致。
- 表示の保存値は専用paletteVisibilityV1。13項目すべて初期表示。個別/すべて表示/すべて非表示、設定の専用タブとパレット内/ファイル/メニューバーの設定入口。空グループの見出し・不要な区切りを隠し、全OFFでも設定ボタンを残す。表示順固定。既存ショートカット・有効フラグに書き込まない。設定共有も表示選択を対象とし、読み込み時に再読込。
- Settingsの旧Sharing/Aboutタブ選択番号は初回だけ補正。幅260を維持し、表示数・メッセージに合わせて高さを測定。画面に収まらなければスクロール、拡縮時は画面内に制限。
- パレット実行で書類ID・スライド番号を同時捕捉し、各ステップとAppleScript本体で再確認。図形作成スクリプトは捕捉したslide nに限定。通常/自動マジックムーブは既存の別コマンド。既存コマンドID104/利用可103は維持。
- 自動検証：13項目の全8192通りで順序・空グループ・先頭に区切りが出ないことをPASS。初期全ON、全OFF、1項目だけ再ON、全ONへ復帰、保存再読込、既存profile/commandShortcuts/commandEnabled不変を隔離UserDefaultsでPASS。既存全テスト・4言語284キーPASS。最長の日本語ボタン193ポイント、余白込み241で260以内。
- Keynote実機：Tests/PaletteShapeIntegration.swiftで専用2スライド文書を作り、本番CommandRunner＋パレットの文書/スライド捕捉を実行。対象に幅・高さがスライドと一致する図形1個、位置0/0、不透明度100、別スライド0個をPASS。スライド変更後はrunnerとbound scriptの両方が中止し件数1:0を維持。専用文書は保存せず閉じた。ログはbuild23/palette-shape-integration-retry.log（最初のハーネス比較失敗はpalette-shape-integration.log）。build24との差は設定メニュー入口と保存テストのみ。
- 起動/保持：署名済みbuild24を起動して主画面・AX許可済み・既存カスタム選択を確認。既存機能設定の照合PASS。ファイルメニューに「パレットを開く」「パレットの設定…」を確認。
- 画面実機の制限：設定入口をクリックした時にmacOS操作接続が切断するため、チェックボックス操作による即時反映、実アプリ再起動後の表示復元、非アクティブパネル自体の全13ボタン・見出し・拡縮は未確認。表示状態/保存/空グループ/全OFF再ONは自動検証であり、GUI実機確認と区別する。
- 成果物：Shared/ReleasePreparation/20261023-KeynoteMaestro-build24/SignedApps/KeynoteMaestro.app（1.2.2/24）、Developer ID署名＋Hardened Runtime・timestamp。公証・両配置先更新・配置先起動は未実施。公証済みbuild16を保持し、GitHub/noteは変更していない。

## build 26：背景パレットボタン・標準一覧可変幅・Sweeper表示（2026-10-23）

- 末尾のスライドサイズ図形作成の次に「選択オブジェクトに背景の図形を追加（グループ化）」を追加。修正済みwhiteBackgroundを再利用。他の順序・見出しを保持。14項目の表示選択、初回ON、保存、全OFF・再ON、ホットキー独立性を維持。旧13項目を全OFFで保存していた場合も新しい背景ボタンは初期ON。長いボタン名は13ポイントのまま折り返す。
- 背景実行の配置メニューは対象確認後に同じステップ内で開く→有効状態を更新→項目実行。メニューを開いたまま待機/AppleEventの対象確認を挟まない。
- Tests/GroupedBackgroundIntegration.swiftをパレットと同じdocumentID/slideNumber/前面プロセス確認へ更新。Keynote14.5の専用文書で元が背面・中間・前面の3ケースを実行。背景1個、元より背面、グループの構成員は背景と元の2個、無関係な2図形は外、サイズ/位置/不透明度保持、busy中の再呼び出しで増えないことをPASS。実際のクリックではなく本番パレット実行経路の実機テスト。文書は保存せず閉じた。ログ：build26/background-palette-integration.log。
- 標準一覧：section内の実測幅をPreferenceKeyで受け、StandardShortcutColumnsでヘッダー/全行の共通配分。内部幅620以上は変更欄340＋間隔16を確保し、残りを1列目へ。620未満は変更欄を下段へ。最小ウインドウ720を維持。チェックボックスを小幅コントロールに分離し、操作名Textを幅制約して折り返す。文字縮小/クリップ/横はみ出しでの回避ではない。
- 列配分の狭い/通常/広い内部幅260/540/619/620/700/900/1300で幅超過なし・1列目の伸縮を自動検証。実際の画面リサイズ確認とは区別。
- Sweeper：SpecialShortcutDisplayがスペシャル設定の6項目の末尾だけ除去。全角/半角括弧に対応。外側見出し/raw title/検索/サービス識別/Bundle ID/キー/有効状態は保持。6操作のserviceステップ、表示除去、見出し/他操作/末尾以外の文字列保持を自動検証。command.*の4言語全名称もbuild24と一致。
- Developer ID署名＋Hardened Runtime・timestamp、build26成功。全自動テストPASS（14項目全16384通り、保存再読込、空グループ、既存設定独立性、285翻訳キー、104互換ID/103操作/305標準割り当て/原典341項目）。
- build24を通常終了して署名済みbuild26を起動。主画面build26・AX許可済み・カスタム選択を確認。切替直前の既存機能設定とpaletteVisibilityV1を含む保存値が切替後も完全一致。
- GUI制限：build26でも標準設定を開くとmacOS操作接続が切断。パレットクリック自体の選択保持、通常/縮小/拡大の表示、行の見切れ、Sweeper短縮表示の実画面は未確認。ソース確認・自動検証・Keynote実機経路と区別。
- 成果物：Shared/ReleasePreparation/20261023-KeynoteMaestro-build26/SignedApps/KeynoteMaestro.app。公証・両配置先更新・配置先起動は未実施。公証済みbuild16を保持し、GitHub/noteは変更なし。


## build 27: configurable palette display hotkey (2026-10-23)

- Palette settings now provide an independent Show Palette HotkeyField, initially unassigned, with record/change/clear, dedicated persistence and settings sharing. Active feature/native bindings and the palette binding participate in duplicate detection in both directions. Registration errors use the shared field state.
- Registration is limited to the two supported Keynote bundle IDs, released outside Keynote and while recording. Palette display reuses the same nonactivating panel; no toggle or additional panel is created. Existing visibility selections and shortcut profiles are preserved.
- Earlier user-directed Keynote-only scope replaces the Excluded Apps UI; saved excludedBundleIDs remain untouched. This is the explicit B21 exception for this app.
- Palette buttons use short localized labels with full command names in tooltips/accessibility labels. Formal settings names remain unchanged. A divider now follows the centered width/height/80-percent group, including filtered visibility combinations.
- Signed development build27 and headless tests PASS: independent unset/save/reload/clear/malformed-data preservation, duplicate comparison, exact bundle scope, 16384 visibility combinations, existing commands/profiles/native catalog and 300 localization keys across four languages. Existing functional settings and palette settings match the pre-launch snapshot.
- Staged development app launched; physical hotkey recording, OS conflict display and repeated palette reveal/selection preservation through keyboard interaction remain unverified. No Apple notarization, installed-copy replacement or GitHub/note publication performed; public build16 is retained.


## build 28: narrower, Keynote-only palette (2026-10-23)

- Palette content width reduced from 260 to 230 points, including saved wider frames and height measurement.
- Workspace activation updates visibility without activating the panel. Switching away orders it out; returning restores a previously requested palette. Closing clears the request. Show outside Keynote defers display until Keynote is frontmost.
- Physical app-switch visibility and narrow-layout rendering remain unverified.
