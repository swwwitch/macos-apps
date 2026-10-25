# 開発Mac 工程1・2の確認記録（2026-10-25）

対象：NotMyType 1.58.0 (89)
ソース確定コミット：ddb6242ddc869c51e8a90e2c9af15388ce69fc3a
GitHub main確認値：ddb6242ddc869c51e8a90e2c9af15388ce69fc3a（上記ソースを含む）

- 正本：~/Git/macos-apps。Dropbox旧ソースは未使用。
- 対象アプリのみcommit・push済み。SettingsCourier等の無関係な未コミット変更は保持。
- ユニバーサルビルド、日英ローカライズ、リンク集15件と移行・追加・削除・保存の自動テスト成功。
- /ApplicationsとLatest Buildsに配置済み。署名・内容一致を確認。
- /Applications版の起動と、閉じた後の再アクティブ化による再表示を確認。
- 今回の追加検証：通常終了・再起動成功。再起動前後のdefaults比較でNSWindow Frame main-AppWindow-1のみ変更。その他の保存設定は一致。
- 未確認：実際の⌘Tabキー操作、ログイン起動、設定表示中の復帰、登録済み✓・一部登録−の状態別実メニュー、最新オプション画面の目視。これらを実機検証完了とは扱わない。
- 公証・公開Release・別Macでの検証は今回の対象外、未実施。

工程1のソース・履歴確定と工程2のcommit・pushは済み。工程2の実機検証には上記の未確認項目が残る。
