# TextLens 1.0.0（1）開発検証

- 日付：2026-11-01 JST。担当：開発Mac MacBook-Pro-14-2024-sw.local。
- ブランチ：codex/filesorter-screenshot-rename-20261101。基点：c706dd2f786da2ac31b47c46ebc4a13697393c53。対象SHA：本記録を含むTextLens確定コミット（Git履歴で特定）。
- OS：26.7.1 / arm64。ワークスペース成果物：TextLens/build/TextLens.app。
- ShotSorterは廃止のまま。保全フォルダーからOCR・整形だけを移管し、命名・監視・Finderコメント処理は含めない。
- NO_DEPLOY=1 zsh TextLens/build.sh：PASS。証明書署名 TeamIdentifier=PL9S9PXX96、codesign deep/strict PASS。初回の制限環境ではXcodeマクロ起動失敗、通常実行権限で再ビルド成功。
- zsh TextLens/test.sh：整形（改行・英語空白保持、ルールOFF）、4言語78キー・プレースホルダー整合、4言語ヘルプ、Vision生成画像認識・原本バイト一致・無効画像拒否PASS。制限環境内のVision実行はnilError、通常実行権限でPASS。
- 主画面の起動とアイコン・結果欄・整形・説明折りたたみ表示を確認（最終調整前の同版ビルド）。設定メニュー操作はUI自動操作で画面遷移を確認できず、設定・ヘルプの実表示は未確認。⌘W・⌘,・終了再起動・設定保持・ログイン・範囲選択・対象外アプリとキー通過・通知・共有の実機検証は未確認。
- 更新配信と専用note未設定。公証・DMG・/Applications・Latest Builds・公開は未実施。開発Macから配布先へ書込なし。
- マニフェスト：BUILD-MANIFEST-20261101.txt（相対パス・権限・通常ファイルSHA-256・リンク先）。マニフェスト自体のSHA-256：759e92b70e9d794b502dcccaf097603f7c3cfdea7ce91e859ccf5feca8ef3a0c。
- 共通部品の既存警告：StartupWindow未使用ローカル、AccessibilityPermissionのSwift 6 actor分離警告。Swift 5ビルド成功。共通部品は変更していない。
