# 変更履歴

## 2026年10月24日 — SettingsCourier を追加

- 登録したアプリの設定（defaults）をアプリごとの `.settingscourier` に書き出し、ほかのMacで取り込む新しいアプリ。App Storeのアプリなどサンドボックスのアプリにも対応。
- Dropbox などの受け渡しフォルダーに書き出し、ほかのMacで新しい設定を選んで取り込める。終了時の自動書き出しあり。取り込みは確認・バックアップ・起動中のアプリの終了と再起動を経て行い、自動では行わない。
- 共通部品の配布スクリプト（MenuBarPresence・AppStandards・LoginAtLaunch・SettingsSync・Updater）に SettingsCourier を登録。
- 開発Macでビルド・自動テスト・/Applications と Latest Builds への配置（チームの開発証明書で署名、1.0.0 build 3）を確認。Developer ID 署名・公証・DMG・個別リポジトリ・note記事は未実施。

## 2026年10月23日 — アプリごとの個別リポジトリへ公開

- 公開対象33アプリのソースを各アプリ名の個別リポジトリに登録。元の履歴を残し、各リポジトリの既存コミットに続けて公開コミットを追加。
- READMEの一覧に個別GitHubリポジトリへのリンクを掲載。情報画面のGitHubリンクも個別リポジトリへ対応。
- SVGExporter・InsertSnippetsは対象外。未コミットのKeynoteMaestroなどの作業を保持し、公開には確定済みソースだけを使用。
- 33件の内容（Git tree）・main・既存の親コミットを確認。共通情報画面のSwift型検査が成功。再ビルド・実機確認・配布は未確認。
- [公開コミット一覧と検証範囲](SOURCE-REPOSITORIES.md)。

## 2026年10月23日 — GitHub・noteの相互リンク

### アプリの情報画面と公開ソース

- 共通の「設定 → 情報」にGitHubへのリンクを追加。情報タブがないIdBackgroundOffは既存の「アプリについて」に追加。
- 公開対象33アプリのソースコードと共通部品を反映。KeynoteHelperからKeynoteMaestroへの名称変更を公開一覧へ反映。
- BreaklineTrimmerのnote記事URLを[専用記事](https://note.com/swwwitch/n/ne4a0fc0c1dd2)へ変更。リソース生成スクリプトも同じURLへ更新。
- SVGExporterとInsertSnippetsは公開対象外のまま保持。

関連コミット：[情報画面と公開ソース](https://github.com/swwwitch/macos-apps/commit/857ef286ca4aa62a45f21fb8fcc029ddd291065e)、[BreaklineTrimmerの記事URL](https://github.com/swwwitch/macos-apps/commit/a6bd17f)。

### noteの記事更新履歴

| 記事 | 今回の変更 | 確認結果 |
| --- | --- | --- |
| [KeynoteMaestro](https://note.com/swwwitch/n/n7b7e549f7379) | ソースコードへのリンクと「2026年10月23日（記事更新）」を追記。既存のGitHub Releasesへのリンクを保持 | 公開ページで確認済み |
| [FolderHopper](https://note.com/swwwitch/n/nd532a1c19f33) | ソースコードへのリンクを冒頭にも掲載し、既存の更新履歴へ追記 | 公開ページで確認済み |
| [BreaklineTrimmer](https://note.com/swwwitch/n/ne4a0fc0c1dd2) | ソースコードへのリンクと記事更新履歴を追記 | 公開ページで確認済み。本文末尾の既存境界を保持し、通知せず更新 |
| [IdBackgroundOff](https://note.com/dtp_tranist/n/nec393e9218e9) | ソースコードへのリンクと既存の更新履歴へ追記 | 公開ページで確認済み。有料100円・既存境界を保持し、通知せず更新 |

他の記事の既存GitHubリンクは保持。記事の更新はアプリ本体の新バージョン公開を意味しない。

### 検証

- 共通情報画面のSwift型検査、設定同期・KeynoteMaestro・CCAutoUpdateOffの既存テストを確認。
- BreaklineTrimmerの4言語リソース検査を確認。
- 情報画面のリンク追加を含む全アプリの再ビルド・実機表示・配布先更新は未確認。
