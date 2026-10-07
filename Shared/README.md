# 共通部品と資料

| 用途 | フォルダ |
| --- | --- |
| 共通仕様・UI部品 | [AppStandards](AppStandards/)（監査・配置の記録は [AppStandards/Records](AppStandards/Records/)） |
| ビルド成果物の配置 | [BuildTools](BuildTools/README.md) |
| ログイン起動・権限・常駐 | [LoginAtLaunch](LoginAtLaunch/)、[Accessibility](Accessibility/)、[MenuBarPresence](MenuBarPresence/)。各アプリへのコピーは `LoginAtLaunch/sync.py`（ログイン起動・アクセシビリティ）と `MenuBarPresence/sync.py` |
| Keynoteへの書き出し（PDF2Keynote・CarmaChameleon） | [KeynoteExport](KeynoteExport/) |
| 更新機能 | [Updater](Updater/README.md) |
| ヘルプ・プライバシー | [Help](Help/)、[PrivacyPolicies](PrivacyPolicies/README.md) |
| note原稿・見出し画像 | [NoteDrafts](NoteDrafts/README.md)、[NoteHeaders](NoteHeaders/)（テンプレートは [NoteHeaders/Template](NoteHeaders/Template/README.md)） |
| アイコン一覧・見本 | [DesignAssets](DesignAssets/)（app-icons-mustard-final.png ほか） |
| App Store申請・引き継ぎ | [AppStore](AppStore/)：Handoff、Submissions/<日付>、Materials/<日付>、Preparation/<日付>、Releases/<日付>、TestFlight（PKG生成ツール） |
| 証明書 | Certificates（Git対象外） |
| 過去の配布物 | [DistributionArchive](DistributionArchive/) |
| バックアップ | [Backups](Backups/)：Build（配置前の旧版）、HIG、WindowChrome |
| 整理履歴 | [OrganizationLogs](OrganizationLogs/) |

共通コード・ビルドツールのパスは保持しています。2026-10-07に成果物・記録・バックアップを役割別フォルダへ移動しました（対応表は [OrganizationLogs/organization-20261007-shared.md](OrganizationLogs/organization-20261007-shared.md)）。過去の記録内の旧パスは履歴として書き換えていません。バックアップの中身を開発ソースとして編集しないでください。
