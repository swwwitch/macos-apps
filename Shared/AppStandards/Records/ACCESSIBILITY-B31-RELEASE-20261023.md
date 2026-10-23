# アクセシビリティ共通動作 B31：配布結果（2026-10-23）

利用者の明示承認に基づき、KeynoteMaestroを除く公開対象22本の配布更新を実施。個人用1本はAppleへのバイナリ送信に関する自動承認レビューで保留となり、送信・配置・公開していない。

## 完了した検証

- 公開22本の隔離ビルドと、存在する既存テスト実行スクリプト14本が成功。共通ポリシー・統合テストも成功。
- 22本すべて、アプリ本体とDMGのApple公証がAccepted。stapler、Gatekeeper、DMG整合性、マウントしたアプリ内容の一致を確認。
- 旧版をバックアップし、通常終了を確認してから/ApplicationsとDropbox Latest Buildsへ同じアプリを配置。署名・内容・バージョン・Bundle IDの一致を確認し、/Applications版の起動を確認。
- 公証済みDMGをLatest Buildsへコピーし、SHA-256の一致を確認。
- GitHub公開リリース22本がLatestであること、添付DMGのサイズとSHA-256が一致することを確認。既存リリースは保持。

## 未確認・保留

- 全アプリの全機能・アクセシビリティ設定画面での一連の実操作、Intel実機、再ログイン：未確認。
- KeynoteMaestro：別作業の未コミット変更を保持し、指定により配布保留。共通仕様のソース反映のみ。
- 個人用アプリ：追加の明示承認が必要。ソース・バイナリとも公開していない。

## 公開版

| アプリ | バージョン | build | リリース |
| --- | --- | --- | --- |
| CommandDee | 1.9.0 | 57 | [GitHub](https://github.com/swwwitch/CommandDee/releases/tag/v1.9.0-build57) |
| DocklessLauncher | 1.11.0 | 27 | [GitHub](https://github.com/swwwitch/DocklessLauncher/releases/tag/v1.11.0-build27) |
| FnNumpad | 1.0.0 | 4 | [GitHub](https://github.com/swwwitch/FnNumpad/releases/tag/v1.0.0-build4) |
| HotkeyHound | 0.4.0 | 17 | [GitHub](https://github.com/swwwitch/HotkeyHound/releases/tag/v0.4.0-build17) |
| IncrementPaste | 1.1.0 | 10 | [GitHub](https://github.com/swwwitch/IncrementPaste/releases/tag/v1.1.0-build10) |
| KakkoReplace | 0.4.0 | 69 | [GitHub](https://github.com/swwwitch/KakkoReplace/releases/tag/v0.4.0-build69) |
| KeynoteSweeper | 1.2.0 | 13 | [GitHub](https://github.com/swwwitch/KeynoteSweeper/releases/tag/v1.2.0-build13) |
| LinkMaker | 1.3.0 | 33 | [GitHub](https://github.com/swwwitch/LinkMaker/releases/tag/v1.3.0-build33) |
| MightyEdit | 0.3.0 | 111 | [GitHub](https://github.com/swwwitch/MightyEdit/releases/tag/v0.3.0-build111) |
| PasteInARow | 1.5.0 | 22 | [GitHub](https://github.com/swwwitch/PasteInARow/releases/tag/v1.5.0-build22) |
| PasteMatchStyle | 1.1.0 | 11 | [GitHub](https://github.com/swwwitch/PasteMatchStyle/releases/tag/v1.1.0-build11) |
| PodiumAssist | 3.3.19 | 83 | [GitHub](https://github.com/swwwitch/PodiumAssist/releases/tag/v3.3.19-build83) |
| SpreadsheetHelper | 1.5.0 | 17 | [GitHub](https://github.com/swwwitch/SpreadsheetHelper/releases/tag/v1.5.0-build17) |
| ProjectFolder | 1.12.0 | 26 | [GitHub](https://github.com/swwwitch/ProjectFolder/releases/tag/v1.12.0-build26) |
| note2markdown | 1.3.0 | 12 | [GitHub](https://github.com/swwwitch/note2markdown/releases/tag/v1.3.0-build12) |
| VectorMate | 2.19.1 | 78 | [GitHub](https://github.com/swwwitch/VectorMate/releases/tag/v2.19.1-build78) |
| BrowserSwitcher | 1.7.0 | 60 | [GitHub](https://github.com/swwwitch/BrowserSwitcher/releases/tag/v1.7.0-build60) |
| ExtensionLinker | 0.3.3 | 53 | [GitHub](https://github.com/swwwitch/ExtensionLinker/releases/tag/v0.3.3-build53) |
| KageTrimmer | 1.4.0 | 73 | [GitHub](https://github.com/swwwitch/KageTrimmer/releases/tag/v1.4.0-build73) |
| FolderHopper | 0.2.0 | 121 | [GitHub](https://github.com/swwwitch/FolderHopper/releases/tag/v0.2.0-build121) |
| QuickIconExporter | 1.2.0 | 39 | [GitHub](https://github.com/swwwitch/QuickIconExporter/releases/tag/v1.2.0-build39) |
| YohakuTrimmer | 1.2.0 | 11 | [GitHub](https://github.com/swwwitch/YohakuTrimmer/releases/tag/v1.2.0-build11) |

## 証拠

ローカルの `Shared/ReleasePreparation/20261023-Accessibility-B31-Release/` にpublic-plan.json、release-results.json、deployment-results.json、github-results.json、final-integrity.jsonと、各アプリの署名・公証・DMG・配置・起動ログを保存。公開用資料には個人用ソース・データを含めない。
