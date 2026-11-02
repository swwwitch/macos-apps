# PodiumAssist 3.3.19（build 92）公開記録

確認日時: 2026-10-30T10:42:32.323443+09:00
実行Mac: MacBookPro13-M5-2025.local（公証Mac）

- 成功: 確定ソース d0d8c550139e441f50c2cd72ba5ccd40104b541c から既存経路でビルド済み。版/buildを再更新せず公証済み成果物を再利用。自動テスト4組・4言語チェックはビルド記録参照。
- 成功: アプリ公証Accepted c2475e97-4b60-4b49-a79f-dbd8d981589d、DMG Accepted e0a7c776-33e2-4e9c-ae9b-8a7cca94bbac。署名・チケット・Gatekeeperを再検証。
- 成功: /Applications・現在のLatest Builds・公証済みソースアプリのBundle ID jp.local.toki、3.3.19（92）、署名・公証・全内容一致を再確認。配置時起動記録は ../20261030-PodiumAssist-build92-002436/deployment.json。
- 成功: 個別リポジトリの既存履歴・構成を保持して12ファイルと出所記録を同期。公開コミット 8b68675c1b7752a63b41cf5a40eb1bd1d2b4b351。ローカル準備treeとGitHub tree一致（9be6e556f0745af2f884af4fba88f9571eecb57c）。通常pushの403は接続済みGitHubツールで解消。
- 成功: Safariで [GitHub Release](https://github.com/swwwitch/PodiumAssist/releases/tag/v3.3.19-build92) を公開。タグ・コミット・DMG一致。
- 成功: Safariで [既存note記事](https://note.com/swwwitch/n/n084fa4c99650) を更新し「記事が公開されました」を確認。本文・画像・9タグ・旧版DMGを保持し、F3変更説明・Releaseリンク・build92 DMGを追加。note-before.htmlに更新前公開記事を保全。
- 成功: GitHub公開DMGを実ダウンロードしSHA-256・署名・公証・整合性・読み取り専用マウント内のBundle ID・版/build・全内容一致を検証。note公開添付も実ダウンロードしGitHubの検証済みDMGと全バイト一致。
- 成功: Notarized DMGs/LatestをPodiumAssist1本に更新、旧版をArchive/PodiumAssistに保全、DMG一覧・SHA256SUMS更新。distribution.json参照。
- 成功: [既存Projects対象項目](https://github.com/swwwitch/PodiumAssist/issues/1) にbuild92の進捗・検証結果・Release/noteリンクを追記。未確認項目を残しopenを維持。
- 未確認: F3操作の実機動作、開発Macの現物インストール版。
- 未実施: 個別リポジトリ単体からの再ビルド。全体Doneにはしない。

DMG SHA-256: bc8a1a183b7afbe9706ae4729d93609b22bcdf69ab4669c6066a4e45cf23b351

旧アプリバックアップ: Shared/Backups/Build/20261030-002820-515289。既存プリセット5件のclock/killDockのみ配置時保全値へ修復済み（deployment.json）。本公開作業ではアプリ・設定を変更しない。
ローカル未コミット/未追跡作業は保持。正本の無関係差分をコミット/pushしない。公開用独立repo、source-sync.json、placement-verification.json、github-verification.json、note-verification.jsonを本ディレクトリに保存。
