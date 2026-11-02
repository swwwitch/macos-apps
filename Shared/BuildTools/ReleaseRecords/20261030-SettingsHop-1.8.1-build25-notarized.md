# SettingsHop 1.8.1（build 25）公証ビルド

実行Mac: MacBookPro13-M5-2025.local（公証Mac）
確認日時: 2026-10-30T10:38:57.027673+09:00
対象ブランチ: codex/settingshop-double-tap-zoom-20261029
対象コミット: `e02e8df219fd40fe12036a58d99b3c35869bd242`
Bundle ID: jp.dtp-transit.settingshop
CPU: arm64 / macOS13以降

## 成功

- 未コミット/未追跡430ファイルをlocal-work-before.tar.gzへ保全。before-manifest.json・before-status.txtあり。git archiveで対象SHAを隔離し、番号変更なし。build/test後のSettingsHop追跡ファイルは対象コミットと一致。
- 配布済みbuild24ソース0ce65a5と比較しmain.swift・LaunchPolicy.swiftは変更なし。1回/2回/長押し判定を保持。Pane.openに起動済みシステム設定の直接activate、新項目rapidZoom（AirDropの下・初期キーなし）を追加。旧de1c33e7/1.7.2(23)は使用しない。
- 既存build.shをNO_DEPLOY=1でビルド。既存test.shのPaneLayout・URL・ダブルプレス判定テスト、4言語キー/プレースホルダー/ヘルプ成功。
- Developer ID Application: masahiro takano (PL9S9PXX96)、Hardened Runtime・timestamp、内側からの署名・検証。
- アプリ公証Accepted `c419fe50-0461-48c2-8916-b3d37bcf233f`、チケット添付・stapler・Gatekeeper。
- DMG署名・公証Accepted `15e515b5-c3b4-493c-ab3b-61cc1c5b0b09`、チケット添付・stapler・Gatekeeper・hdiutil整合性。
- 読み取り専用マウントで内包アプリ全内容一致・署名・チケット検証。内包版/BundleID/buildは元アプリと全内容一致で照合。

## 未実施

- 今回build25の実機キー操作・直前システム設定画面の保持・高速ズーム詳細への到達。
- /Applications・Latest Buildsへの配置、起動・設定保持確認。
- mainへの統合、GitHub Release・note公開、App Store提出。

アプリ: `/Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261030-SettingsHop-1.8.1-build25-103617/SignedApps/SettingsHop.app`
DMG: `/Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261030-SettingsHop-1.8.1-build25-103617/SettingsHop/SettingsHop-1.8.1-build25-notarized.dmg`
DMG SHA-256: `28d16cf6843ae44a974fe9395f0122c45ac59daf45cda32adfbd87647ce286e6`
アプリmanifest SHA-256: `75b4e1c982d8aadd545523a8451ada6428d0e4ac818251a25e77cd9e0ef68bbd`（app-manifest.json）
バックアップ: `/Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261030-SettingsHop-1.8.1-build25-103617/local-work-before.tar.gz`
詳細証跡: release-results.json、SettingsHop/build.log・test.log・dmg-notary.json、Notarization/SettingsHop/result.json。
