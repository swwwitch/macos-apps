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
