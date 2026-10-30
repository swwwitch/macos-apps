# PodiumAssist / MightyEdit 公証リリース記録

確認日時: 2026-10-29T18:06:54.604945+09:00
実行Mac: MacBookPro13-M5-2025.local（公証Mac）

確定ビルドソース: `8da4865eb0fae84244b6fcb656ef9cbdd2a32c67`。未コミット・未追跡変更は `Shared/ReleasePreparation/20261029-PodiumAssist-MightyEdit/local-work-before.tar.gz` に保全。無関係な変更は含めていない。

## PodiumAssist 3.3.19（91）

- 成功: 自動テスト・ローカライズ検査、確定ソースから配布ビルド。
- 成功: Developer ID Application署名、Hardened Runtime、timestamp、アプリ/DMG公証Accepted、staple、codesign、Gatekeeper、読み取り専用マウントで内包版/ID/全内容一致。
- 成功: /ApplicationsとLatest Builds配置、両配置先の全内容一致・署名・公証・/Applications起動。
- 成功: 配布版の実機動作をユーザーが正常と確認。ズーム自動設定とキーボード輝度。プリセット5件はID・順序・各フィールド一致。
- 成功: [GitHub Release](https://github.com/swwwitch/PodiumAssist/releases/tag/v3.3.19-build91) / [既存note記事](https://note.com/swwwitch/n/n084fa4c99650)。note下部のダウンロード欄を更新し既存タグ・添付を保持。
- 成功: GitHub/noteを実ダウンロードしSHA-256・DMG整合性・内包版/ID/署名/公証/全内容一致を照合。
- 成功: [Projects既存項目](https://github.com/swwwitch/PodiumAssist/issues/1)へ検証結果とRelease/noteリンクを更新。
- 未実施: 個別リポジトリ単体からの再ビルド。配布物は上記統合ソースから作成し、個別リポジトリの同期内容・履歴・タグは照合済み。Projectsは全体Doneにしない。
- 未確認: 開発Macの現物インストール版。
- バックアップ: `Shared/Backups/Build/20261029-174152-675170/Applications/PodiumAssist.app` と同ディレクトリの `LatestBuilds/PodiumAssist.app`。
- SHA-256: `5b143539408a9dfc9dd55c05a512ce84092b938753f526bd033dd0619fa99149`
- 個別リポジトリ対象コミット: `cc4581126cf84cd110ddc6e460a2b32860a75084`

## MightyEdit 0.3.4（117）

- 成功: 自動テスト・ローカライズ検査、確定ソースから配布ビルド。
- 成功: Developer ID Application署名、Hardened Runtime、timestamp、アプリ/DMG公証Accepted、staple、codesign、Gatekeeper、読み取り専用マウントで内包版/ID/全内容一致。
- 成功: /ApplicationsとLatest Builds配置、両配置先の全内容一致・署名・公証・/Applications起動。
- 成功: 配布版の実機動作をユーザーが正常と確認。カンマ付与・除去・合計の3操作。設定の変更なし。
- 成功: [GitHub Release](https://github.com/swwwitch/MightyEdit/releases/tag/v0.3.4-build117) / [既存note記事](https://note.com/swwwitch/n/n08be828d4393)。note下部のダウンロード欄を更新し既存タグ・添付を保持。
- 成功: GitHub/noteを実ダウンロードしSHA-256・DMG整合性・内包版/ID/署名/公証/全内容一致を照合。
- 成功: [Projects既存項目](https://github.com/swwwitch/MightyEdit/issues/1)へ検証結果とRelease/noteリンクを更新。
- 未実施: 個別リポジトリ単体からの再ビルド。配布物は上記統合ソースから作成し、個別リポジトリの同期内容・履歴・タグは照合済み。Projectsは全体Doneにしない。
- 未確認: 開発Macの現物インストール版。
- バックアップ: `Shared/Backups/Build/20261029-174155-161038/Applications/MightyEdit.app` と同ディレクトリの `LatestBuilds/MightyEdit.app`。
- SHA-256: `651464f94941a60138a066c88150815dce206c05604e2cf5948a74e42a234ef0`
- 個別リポジトリ対象コミット: `8d0cb2124428748d0e0d69f69acccfdaaca892c5`

## 証跡

`Shared/ReleasePreparation/20261029-PodiumAssist-MightyEdit/` 内の release-results.json、github-publication.json、note-publication.json、settings-verification.json、各テスト/署名/公証ログを参照。DMGはLatest各アプリ1本、過去版はArchive内に保持しSHA256SUMSを更新。PodiumのRememberTestsは組み込みプリセット自動生成と独立するようテスト初期条件のみ修正。MightyEdit初回の共有SDK準備競合は再試行で解消。
