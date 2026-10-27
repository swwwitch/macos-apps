# FavoriteFolders 1.3.9（build 15）配布記録

2026-10-27（日本時間）、公証Mac MacBookPro13-M5-2025.local。本チャットで開発Mac以外での修正・検証、GitHubへのcommit/push、Apple公証送信、公証登録名の確認を明示承認。

- ソース：bee83bc176cf40fb34df9228735f1bf0d0710fd3（GitHub mainへpush済み）。その後の他アプリのコミットは、本アプリとビルドに使用する共通ソースに差分なし。
- 変更：設定ファイルに選択セットのお気に入り・並び順・区切り線・ホットキーを含める。読み込みは一覧へ復元して［保存］でDFXに反映。DFXの既定セットの翻訳表示名と実フォルダー名の差に対応。既存の日本語実フォルダーは優先。Option＋クリックでDFX設定を開き、既存AX許可内でフォルダを選択。
- 単体・実データ読取・4言語整合性、共有同期の回帰テストPASS。利用者が検証用1.3.9の読み込みを確認。
- Developer ID Application署名（Hardened Runtime、timestamp、Automation entitlement）と署名検証PASS。
- Apple公証Accepted：e3b0e56d-6a5e-4fe8-8eda-70a955168417。stapler staple/validate、GatekeeperのNotarized Developer ID受入PASS。
- 公証提出ZIP SHA-256：6f1b813c034ca368848c4c47cce6e73722d2b4ce19b20ff9db9d3351a3b10a22。
- /Applications/FavoriteFolders.appとDropbox Latest Builds/FavoriteFolders.appへ配置。両方1.3.9（15）、Bundle ID jp.dtp-transit.favoritestidy、全ファイルの相対パス・モード・SHA-256・symlink先が公証済みソースと一致。
- 旧版バックアップ：Shared/Backups/Build/20261027-135216-770835/{Applications,LatestBuilds}/FavoriteFolders.app。
- /Applications版の起動を実行パスとGUIで確認。お気に入り21件・ホットキー・メモを表示、状態欄に21件読み込み成功。DFXの実データ書換えなし。
- Latest BuildsのREADMEとアプリのバージョン一覧の対象行を更新。
- 別Macでの設定書き出し・読み込み、DFXへの実保存、Optionクリックのフォルダ選択、Intel、再ログインは未確認。DMG・GitHub Release・note公開は今回の対象外。

証跡は.local/release-preparation/FavoriteFolders-1.3.9-build15-20261027/内のsource-sha.txt、notary-result.json、app-manifest.json、deployment-result.jsonに保全。成果物はSignedApps/FavoriteFolders.app。
