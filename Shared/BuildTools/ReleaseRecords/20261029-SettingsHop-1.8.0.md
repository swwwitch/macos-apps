# SettingsHop 1.8.0（24）配置・公開記録

確認日時: 2026-10-29T10:43:04.802015+09:00 / 公証Mac MacBookPro13-M5-2025.local

- 対象ソースSHA: `0ce65a5415cb219e0f6f35313c2747517b0ff699`。通常版arm64。版/buildを重複更新していない。
- ソース・履歴・4言語ヘルプ・自動テスト・ビルド: 成功（前工程）。実キーの1回/2回/長押しはユーザー「3項目とも正常」。
- アプリ: Developer ID/runtime/timestamp署名、公証Accepted `42a99fc6-1a30-403f-b014-2e0f0e24b1e2`、stapler・Gatekeeper成功。
- DMG: 公証Accepted `eede1243-2a08-400f-bf10-eb95aa349f84`、署名・stapler・Gatekeeper・hdiutil整合性・読み取り専用内包一致検証成功。
- DMG SHA-256: `e5455f6eb5ecde0827fe9d6e50c4ba41d2e03ab58972b31c2e9be48910ba8f52`。
- 配置: `/Applications/SettingsHop.app` と `/Users/takano/sw Dropbox/takano masahiro/Dropbox-shared/sw_app-Latest Builds/SettingsHop.app`。Bundle ID・版/build・署名・stapler・Gatekeeper・全内容一致成功。
- バックアップ: `Shared/Backups/Build/20261029-103712-489747/Applications/SettingsHop.app`、同 `LatestBuilds/SettingsHop.app`。旧版1.7.2（23）。
- `/Applications`版の起動: CUAで1.8.0（24）表示、実行プロセスのパスで確認。設定差分: `{"NSWindow Frame MainWindow": ["674 -678 420 736 0 0 1920 1049 ", "739 123 420 736 0 0 1920 1049 "]}`。配布版での実キー再確認は回答待ち（未確認）。
- 配布物: `Notarized DMGs/Latest/SettingsHop-1.8.0-build24-notarized.dmg`。旧DMGはArchive/SettingsHopへ保全。SHA256SUMS.txt・一覧・Unicode名を保ったバージョン一覧更新。
- [GitHub Release](https://github.com/swwwitch/macos-apps/releases/tag/SettingsHop-v1.8.0-build24): 公開成功。タグと対象SHA照合、公開からの実DL SHA一致、DMG/内包アプリを再検証。
- [note](https://note.com/swwwitch/n/n9b5032198e57): Safariで既存公開記事の下部ダウンロード節・更新履歴・確定ソースリンク更新。既存本文・画像・6タグ・過去添付保持。新添付 `acb20cf0b22a8f7adee7fe1e153a28b2` の実DL SHA一致、DMG/内包アプリ再検証成功。
- Projects: API FORBIDDEN。Chromeの既存Project2をSettingsHopで検索し0件。以前の「既存項目のURLを指定する」の回答を保持し、未更新・URL待ち。重複作成なし。
- 未確認: 開発Macの現物、配布版の実キー再確認、今回変更外の実ログイン/AX補助。全体キューは必要な確認待ち。
- 検証ログと復元可能な保全: `.local/settingshop-doublepress-20261029/`。未コミット・未追跡の元作業は保全し未変更。
