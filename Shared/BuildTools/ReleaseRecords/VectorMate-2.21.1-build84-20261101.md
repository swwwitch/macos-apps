
## VectorMate 2.21.1（84）配置・Latest DMG 2026-11-01T21:18:10.716059+09:00

公証Mac: MacBookPro13-M5-2025.local。確定SHA dfa27d5eb8700e405265d7aa39d968504174c23f。成功: 自動テスト、Universal、アプリ/DMG Developer ID署名・公証Accepted・stapler・Gatekeeper・DMG整合性・内包内容一致。/Applications版とLatest Builds版は2.21.1（84）で全内容一致、起動・既存設定保持を確認。配布版の正負反転はユーザー確認済み（自動検証と区別）。

Latest DMG: /Users/takano/sw Dropbox/takano masahiro/Dropbox-shared/sw_app-Latest Builds/Notarized DMGs/Latest/VectorMate-2.21.1-build84-notarized.dmg
SHA-256: 109f1b646c196a5bb35ea132abd2f9e55e67b6794e5fb30bdde4225243ebb213
過去版はArchive/VectorMateへ保全。旧アプリ: /Users/takano/Git/macos-apps/Shared/Backups/Build/20261101-211613-569690/LatestBuilds/VectorMate.app, /Users/takano/Git/macos-apps/Shared/Backups/Build/20261101-211613-569690/Applications/VectorMate.app。設定・証跡: /Users/takano/Git/macos-apps/Shared/ReleasePreparation/VectorMate84-20261101-210825。開発Mac現物版は今回未確認。GitHub公開版は今回未更新、Releaseリンクは未確定。note既存記事は別アカウント編集権限待ち。全体完了にしない。

初回失敗はSDKコピーでsymlinkを平坦化したため。InitialFailureとinitial-run.logを保持。元SDKをdittoし原署名検証後、同じ確定ソース・版/buildで再試行成功。

## 最終中間記録 2026-11-01T21:26:40.161560+09:00

実行Mac: MacBookPro13-M5-2025.local。VectorMate 2.21.1（84）、確定ソース `dfa27d5eb8700e405265d7aa39d968504174c23f`。

| 工程 | 状態・根拠 |
|---|---|
| 3 | 成功：確定SHA隔離取得、ローカル変更保全 |
| 4 | 成功：Universal・自動テスト・Developer ID署名・公証Accepted・チケット・Gatekeeper |
| 5 | 成功：DMG署名・公証・整合性・読み取り専用内包照合 |
| 6 | 成功：両配置・起動・既存設定保持・正負反転ユーザー確認。全パレット・単位変更の実機全件確認は未確認 |
| 7 | 成功：Latest1本、旧81 Archive保全、SHA256SUMS更新 |
| 8 | 成功：既存個別repo履歴保持、単独ビルド・テスト、Release公開 |
| 9 | 成功：既存Issue1更新・Projects In Progress。重複作成なし |
| 10 | ブロック中：Safariのnoteアカウント切り替え待ち。既存記事・有料設定等を保持 |
| 11 | GitHub成功：実DL SHA・DMG/アプリ署名公証・内容一致。note未実施 |
| 12 | 途中更新済み：開発Mac現物版は未確認、全体未完了 |

- [GitHub Release](https://github.com/swwwitch/VectorMate/releases/tag/v2.21.1-build84)
- 公開repoコミット: `db91bc86534682cb6ac60683acf58f81569dfa54`。Git tree `214289a00b5c3c3ef02434cb1624c8fa3d612df5` 一致。通常git push403を記録し、書き込み可能なGitHub連携で同期。
- SHA-256: `109f1b646c196a5bb35ea132abd2f9e55e67b6794e5fb30bdde4225243ebb213`
- 公証Macインストール版 / Latest Builds版 / GitHub公開版はいずれも2.21.1（84）。note公開版は2.19.2（81）のまま、更新未実施。開発Mac現物版は今回未確認。
- 旧アプリと設定バックアップ: /Users/takano/Git/macos-apps/Shared/ReleasePreparation/VectorMate84-20261101-210825/Deployment のresults.jsonに記録。公証・署名・公開実DLログも本作業領域に保存。
- VectorKeys Git更新成功：1.21.0（38）、GitHub確定 `880ffcb7e873940c7ffd48d27c0d94abb1e6f2f3`、ローカルHEAD `1785e39e5dc22285eb11b0a5a7371a21e1b69a64`。保全 /Users/takano/Git/macos-apps/migration-backups/git-update-vectorkeys-20261101-211646、競合した更新キューは双方の追記を保持し復元照合。新38のビルド・公証・配置・公開は今回未実施。
