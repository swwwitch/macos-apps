# VectorMate2.22.1（86）公証・配置・公開進捗

実行Mac MacBookPro13-M5-2025.local。確認日時 2026-11-02T06:31:34.872036+09:00。
確定ソース 54b4e675bd03b806ee2b23d144646c52d2ddd7f5、ブランチcodex/vectorassist-build-20261101。ブランチ最新54be3fabは引継ぎ文書のみで、指定SHAに固定。版/build変更なし。

| 工程 | 状態・根拠 |
|---|---|
| 3 | 成功：ローカル486ファイルをlocal-work-before.tar.gz・before-manifest.jsonへ保全、指定SHAをgit archive隔離。競合・強制上書きなし |
| 4 | 成功：既存SKIP_DEPLOY=1 VECTORMATE_DISTRIBUTION=developer-id、Universal、単体/4言語/49項目/88生成スクリプト/ログイン判定/StartupWindow回帰成功。Apple Events entitlement、Developer ID/runtime/timestamp内側署名。アプリAccepted 2abf458f-8a7c-48a5-92a3-de3e6a4caa34、staple/Gatekeeper |
| 5 | 成功：DMG署名・Accepted a60a2fd5-2d76-4792-92ca-a588dd9036bd・staple/Gatekeeper/hdiutil、read-only mount内包マニフェスト・署名・チケット一致 |
| 6 | 両配置・起動・表示・設定比較成功。Illustrator未起動で実適用はユーザー確認待ち。84の正負反転確認等を86へ流用しない |
| 7 | 成功：Latest1本・Archive・SHA256SUMS・app-manifest.json更新 |
| 8 | 個別repo既存履歴/構成保持同期成功 fbce514884b878b57f029e3464e40f9df58b23a7、Git tree完全一致。通常push403、GitHub連携でlease照合して更新。Releaseは未公開 |
| 9 | 成功：既存VectorMate Issue1へ86の検証・配置・ソース同期・残件を更新、重複作成なし。全体未完了・Issue open。Projectsの現在Statusはブラウザー操作無効のため再照合未実施 |
| 10 | ブロック中：Work設定でローカルブラウザー操作無効。有効化待ち。既存note本文・有料設定は未変更 |
| 11 | 未実施：公開Release/noteの実DL検証 |
| 12 | 途中更新：公証Mac/Latestを86と記録、開発Mac現物未確認、公開版は今回未更新。全体未完了 |

DMG /Users/takano/sw Dropbox/takano masahiro/Dropbox-shared/sw_app-Latest Builds/Notarized DMGs/Latest/VectorMate-2.22.1-build86-notarized.dmg
SHA256 69d4fa178b315624426e2bf9b0f14cee5b06430a11b9af720a7c7c771b1228d5
旧版バックアップ /Users/takano/Git/macos-apps/Shared/Backups/Build/20261102-062954-409976
ログ・SDK・テスト・公証・マニフェスト・ソース公開の根拠 /Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261102-VectorMate86-062353。
追加未確認：実ログイン/再ログイン、物理⌘Tab、86の全機能適用、Intel実機。ログイン設定/権限は変更しない。
SDKコピーはdittoでsymlink保持・原署名検証。初回準備ではブランチ先頭が文書追記SHAだったため停止し、対象SHAの祖先関係を照合して指定ソースで再開。ソースは変更していない。
個別repo syncのAIデータ空白とAppearanceViews末尾空行は確定ソース由来のため保持。不要な新規Shared作業文書18ファイルは未公開ローカルコミットから除外後に同期。
