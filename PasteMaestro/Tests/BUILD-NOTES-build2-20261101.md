# PasteMaestro 1.0.1（2）待ち時間短縮

- 2026-11-01 JST、開発Mac MacBook-Pro-14-2024-sw.local。ブランチcodex/pastemaestro-integration-20261101、基点d8b9953bb7c2e48ed20a098fdd214dd267e9f825。対象SHAは本記録を含む実装コミット、確定値をキューに追記。
- 連番・行貼り付けの排他待ち：1.1秒→0.15秒。行貼り付けのクリップボード復元：1.0秒→0.10秒。復元を終えてから次の操作を許可し、既存changeCount確認による新しいコピーの保護を保持。書式モードの1.1秒待ちは変更しない。
- NO_DEPLOY=1 SKIP_PUBLISH=1 build.sh成功。Apple Distribution（PL9S9PXX96）署名、deep/strict検証PASS。arm64開発用、Universal・Developer ID配布署名・公証は未実施。
- test.sh PASS：増加規則、行整形、メニュー、クリップボード排他、0.2秒間隔の5連続取得・解放、全4テーブル×4言語キーと書式指定子。
- マニフェスト：APP-MANIFEST-build2-20261101.json（相対パス、モード、SHA-256、symlink先）。専用worktreeと通常workspaceの.app内容一致を確認。旧workspace版はPasteMaestro/Backupsへ保全。
- 旧アプリを終了し、/Users/takano/Git/macos-apps/PasteMaestro/PasteMaestro.appの起動・画面の1.0.1（2）表示を確認。設定保存領域とBundle IDは維持。
- 他アプリへの実貼り付け・混雑時の読取・手動連打の速度と欠落／重複は未確認。0.15秒以内の操作は従来どおり拒否し、キューへ蓄積しない。
- /Applications・Dropbox配置・DMG・GitHub Release・公開は未実施。
