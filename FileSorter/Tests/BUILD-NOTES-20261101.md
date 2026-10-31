# FileSorter 1.1.0（3）開発検証記録

- 実装・検証日：2026-11-01 JST。開発Mac：MacBook-Pro-14-2024-sw.local。
- 基点：9068227c96152f37521313108259c886670d5fc6。対象ソース：本記録を含む確定コミット。
- ShotSorterのPNG命名を移植。複数フォルダー・テンプレート・手動選択。OCRは対象外。ShotSorter側は変更していない。
- 自動改名は初期値OFF。ShotSorterの同一フォルダー監視を停止してからON。改名後に振り分け判定。
- test.sh PASS：ルール・命名・衝突・4言語整合。test-engine.sh PASS：実PNGの画像情報、手動改名、自動監視、起動前ファイルの保護、衝突、カスタム名のループ回避。
- NO_DEPLOY=1 build.sh PASS。arm64、証明書署名（Team PL9S9PXX96）、codesign --verify --deep --strict PASS。通常のローカル検証署名で、公証・配布署名の完了を示さない。
- 成果物：FileSorter/build/FileSorter.app。内容マニフェスト：build-1.1.0-3-manifest.json（権限・相対パス・SHA256・リンク先）。
- 実機UI、起動・再表示・終了、実設定の保持、公証、DMG、/Applications・Latest Builds配置、GitHub Release、note公開は未実施。
- /Applications版は1.0.1（2）を読み取り確認。配布版の更新は行っていない。
- マニフェストSHA256：e588b4561c4555643cabe08bae992c6f3d1015ceb01ffa489c45e4d22370d261
