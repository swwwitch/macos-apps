# CarmaChameleon 0.15.1（52）開発検証 — 2026-11-09 JST

- 開発Mac：MacBook-Pro-14-2024-sw。ブランチ：codex/carmachameleon-header-20261109。対象ソースはこの記録を含むコミット。独立worktreeを使用し、他アプリの未コミット変更は含まない。
- 主画面右上の「CARMA CHAMELEON」を削除。アイコン、版表示、機能見出し、補足説明を保持。
- B24：設定再表示時に最小化を復元し、アプリのアクティブ化後に設定を前面へ。メインと設定は通常レベルで、常に手前の設定は本アプリに存在しない。クリック往復の実機検証は未実施。
- `test.sh "$PWD/Vendor/typst"`：終了0、PASS行175件。PDF生成、変換、4言語キー一致、Markdown-to-text回帰を含む。
- `NO_DEPLOY=1 ./build.sh`：終了0。arm64、Apple Distribution（PL9S9PXX96）署名、codesign deep/strict検証成功。既存共通コードの未使用変数警告あり。
- 初回はSparkleダウンロードのHTTP 504で中断。既存SDK 2.10.0をコピーし署名検証後に再実行成功。
- 成果物：`CarmaChameleon/build/CarmaChameleon.app`。ファイル一覧・権限・SHA-256・リンク先はBUILD52-MANIFEST.json。
- 既存の/Applications版0.15.0（51）が稼働中のため終了・置換せず、新版の起動・画面操作・設定保持は未確認。公証Macで実機検証する。
- 公証・両配置先更新・DMG・公開は未実施。配布用署名は公証MacでDeveloper IDを使用する。
