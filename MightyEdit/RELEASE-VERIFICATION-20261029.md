# MightyEdit 0.3.4（117）検証用ビルド

- 日付：2026-10-29 JST。担当：開発Mac MacBook-Pro-14-2024-sw。
- 基点：main / 199eacd150a5a27952a22dcae2cb890a940934b1。今回の変更は本記録を含むコミットを参照。
- 対象：設定の機能名・ホットキー検索、数値関連3キーの初期値更新、既存の共通クリック記録UIを含む検証用ビルド。
- 実行：`NO_DEPLOY=1 MIGHTYEDIT_SKIP_SHARED_SYNC=1 zsh MightyEdit/build.sh`。別作業の共通部品変更を取り込まず既存のMightyEdit内ソースでビルド。HotkeyRecorderは共通正本と一致。
- ビルド成功。Apple Distribution: masahiro takano (PL9S9PXX96)でローカル署名。通常のOSアクセスで `codesign --verify --deep --strict` 成功。制限環境では証明書検証がCSSMERR_TP_NOT_TRUSTEDになるため署名と実行確認は通常アクセスで実施。
- 成果物：`MightyEdit/MightyEdit.app`。Bundle ID `jp.local.TextPalette`、0.3.4 / 117。
- 実行ファイルSHA-256：`fc1ca01dcb7404ac522816bc2336a480da8f73d5853598996fc3a9684752f7cc`。
- ローカル証拠：`.local/MightyEdit-20261029/manifest.json`（ファイル相対パス・権限・SHA-256・リンク先）、`settings-before.plist`、`search-focused.png`。
- 11組の自動テストPASS（検索の機能名、修飾キー名、順不同、記号、全角、該当なしを含む）。4言語278キーと同梱ヘルプ検証PASS。
- 起動：旧プロセス終了直後の初回openは-600。終了後の再実行で成功。PID 21002の実行パスが上記ワークスペースの.appであることを確認。パレットの0.3.4（117）表示を確認。
- 実機：設定の検索欄を表示。「=」を入力して「数値を合計」のみに絞り込まれる画面を確認。機能名検索は自動テストで検証、実機の日本語入力による絞り込みは未確認。
- 実機：キー欄クリックで入力待ち説明が表示され、Escで取消。［変更］ボタンなし。割り当て保存を伴う実キー変更は未実施。
- 実行時マニフェスト：action-7＝keyCode43 / modifiers6400、action-8＝47 / 6400、action-21＝24 / 6400。指定3キーと一致。元の保存値も同じ値のため変更不要。
- 共通部品正本・コピー計19本が同一。他アプリの再ビルド・実機確認は未実施。
- 未実施：外部エディターへの3操作実行、公証、配布、GitHub Release更新。/Applications・Dropbox Latest Buildsは書き換えていない。
- 既存の警告：StartupWindow未使用変数、AccessibilityPermissionのactor分離、main.swift未使用weak self。今回の検索機能のビルドエラーなし。
