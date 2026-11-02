
## PasteMaestro 1.2.0（4）公証・Latest更新 2026-11-02T05:21:24.446874+09:00

公証Mac MacBookPro13-M5-2025.local、確定ソース 804aec37e86545dfb64967cff06f86b9dcf72c96。成功: 自動テスト、arm64、Developer ID/Runtime/タイムスタンプ、アプリ・DMG公証Accepted/stapler/Gatekeeper、読み取り専用DMG整合性と内包全内容一致。/ApplicationsとLatest Buildsアプリは1.2.0（4）で署名・公証・内容一致、配布版の起動・画面・設定保持を確認。変更機能QA: {"status": "passed", "scope": "compact main window, 3 modes, empty palette controls, settings and relaunch size", "at": "2026-11-02T05:21:23.803966+09:00", "settings_preserved": true, "expected_migration": "MainWindow compact440x560 content; compactMainWindowV1", "unverified": ["actual slot drag reordering", "physical hotkeys", "cross-app paste"], "reason": "existing paste apps running; conflict guard intentionally pauses processing; existing apps retained", "changed_existing_keys": ["NSWindow Frame MainWindow"], "added_keys": ["compactMainWindowV1", "NSWindow Frame RowPalette"]}。

Latest DMG: /Users/takano/sw Dropbox/takano masahiro/Dropbox-shared/sw_app-Latest Builds/Notarized DMGs/Latest/PasteMaestro-1.2.0-build4-notarized.dmg
SHA-256: f3716aeb33099d0ab400d562eee251c6803437f8d1d1183a166ca12f94574d13
旧アプリ保全: /Users/takano/Git/macos-apps/Shared/Backups/Build/20261102-052029-018150/LatestBuilds/PasteMaestro.app, /Users/takano/Git/macos-apps/Shared/Backups/Build/20261102-052029-018150/Applications/PasteMaestro.app。設定保全と根拠: /Users/takano/Git/macos-apps/Shared/ReleasePreparation/NewVersions-20261102-051722/PasteMaestro4/Deployment。
開発Mac現物版・物理ホットキー・他アプリへの実貼り付けは未確認。GitHub公開版は今回未確認、Release/note更新は未実施（対象外）、公開DL再検証も未実施。公開完了と混同しない。
