# FolderHopper 検証ビルド（2026-10-29 JST）

- 開発Mac：MacBook-Pro-14-2024-sw.local、main。入力SHA：188a6c77108934b437f5c9589623617df170008f、変更は未コミット。
- 通常版0.2.0（build 126）、成果物：FolderHopper/FolderHopper.app。
- /Applicationsへの送信を指定の3択に変更。Setappのみは確認なしでリンク作成。混在時はSetappだけリンクに固定。専用ホットキーも対象。
- NO_DEPLOY=1、検証用ad-hoc署名。ビルド・署名検証・4言語整合・MoveTests PASS。
- 実行ファイルSHA-256：3b35d7a9b86c7f1a840ceaa6ec1d414dbcbeb69b8b7c8b10311cefb81c8fffcf
- ファイル・権限・リンク先：manifest-0.2.0-126.json。
- GUI・Finder・ホットキー実機確認、公証・配布・公開・commit/push：未実施。
- 共通SettingsSyncの既存変更がビルド同期でFolderHopperにも反映。ほかの元々クリーンなアプリへの同期差分はバックアップ後に復元。既存変更のあるMarkdownKitchenとSharedは保持。
