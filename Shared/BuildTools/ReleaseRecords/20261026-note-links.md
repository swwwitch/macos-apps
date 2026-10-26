# noteリンク追加版の工程記録

公証Mac：MacBookPro13-M5-2025。確認日時：2026-10-26T21:18:14.029549+09:00。全体未完了。

未コミット・未追跡771件を /Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261026-note-links-publication/uncommitted-and-untracked.tar.gz に保全。元作業ツリーは上書きせず、既存成果物を再利用し版・buildは再更新していない。

| アプリ | 版（build） | 工程3〜8 | 工程9 | 工程10〜11 |
|---|---|---|---|---|
| MenuShot | 1.3.3（9） | 成功（変更した情報画面を実機確認） | 既存項目へ追記、In Progress | 公開表示・実DL SHA・内包版/署名/公証成功 |
| SettingsHop | 1.7.2（23） | 成功（変更した情報画面を実機確認） | 対象項目未確認・指示待ち | 公開表示・実DL SHA・内包版/署名/公証成功 |
| FileSorter | 1.0.1（2） | 成功（変更した情報画面を実機確認） | 既存項目へ追記、In Progress | 公開表示・実DL SHA・内包版/署名/公証成功 |
| ClipTidy | 1.0.1（3） | 成功（変更した情報画面を実機確認） | 既存項目へ追記、In Progress | 公開表示・実DL SHA・内包版/署名/公証成功 |
| ShotSorter | 1.0.1（2） | 成功（変更した情報画面を実機確認） | 既存項目へ追記、In Progress | 同時編集警告で公開保留 |
| SiteMirror | 1.5.3（16） | 成功（変更した情報画面を実機確認） | 既存項目へ追記、In Progress | 公開表示・実DL SHA・内包版/署名/公証成功 |

工程4：Developer ID・Hardened Runtime・timestamp・アプリ公証Accepted・stapler・Gatekeeper。工程5：DMG署名/公証/stapler/整合性、読み取り専用マウントの内包Bundle ID・版・署名・公証・全内容。工程6：両配置先の同一成果物を再照合、/Applicationsから起動・情報画面リンクを確認。その他の権限依存機能・実ログイン等は以前の未確認記録を保持。

工程7：Latest各1本、旧版Archive/<アプリ名>、SHA256SUMSとRecordsを更新。同名異内容は上書きしていない。工程8：対象SHA・タグ・配布物一致、公開ダウンロードSHAと内包検証済み。個別リポジトリ6件は404で未検出、既存macos-apps構成を保持。

工程10：既存本文・画像・タグを保持し、最新版案内・更新履歴・DMGを追加、旧DMGは過去版と明記。ShotSorterはnote同時編集警告（両方10/26 21:08・1,041文字、内容未照合）で停止。競合画面はSafariに保持し、利用者確認待ち。

SettingsCourier：GitHubは1.3.2（9）のまま、配布版1.4.2（13）のソースが未反映のため工程3以降保留。

証拠は /Users/takano/Git/macos-apps/Shared/ReleasePreparation/20261026-note-links-publication の stage3.json、stage6-revalidation.json、stage7.json、github-publication.json、github-downloaded-dmg-verification.json、note-publication.json、note-downloaded-dmg-verification.json、stage-status.json。旧版バックアップの個別パスはstage-status.json、設定保全は各元リリースワークスペース/UserDataBackup。
