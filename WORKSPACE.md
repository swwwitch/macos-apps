# 開発フォルダーの使い分け

- 開発・ビルド・Git操作：`~/Git/macos-apps`。
- 起動確認：`/Applications` に配置したアプリ。
- 共有配布：Dropbox内 `sw_app/Latest Builds`。共通設定は `Shared/BuildTools/distribution_paths.py`。
- 公証済みDMG：共有配布先の `Notarized DMGs/Latest`。過去版は `Archive/<アプリ名>`、検証・移動履歴は `Records`。
- ローカルの保全・検証記録：`.local/`。GitHubへ公開しない。内容と復元方法は `.local/README.md` を参照。
- アプリ別の `Backups`、`Shared/Backups/Build`：更新前の復元用。自動削除しない。
- `.build` などの生成キャッシュ：ビルド実行中でないこと、独自変更がないことを確認して整理できる。

既存の最新版ソースへ旧ソースを一括上書きしない。ローカル専用アプリの.gitignoreや非公開資料の除外設定を、整理を理由に解除しない。

[開発共通ルール](AGENTS.md)・[共通仕様](Shared/AppStandards/BASELINE.md)・[リリース作業チェックリスト](Shared/BuildTools/RELEASE-CHECKLIST.md)に従う。

ソースの同期は配布物の更新とは別工程。アプリの署名・公証・実機動作・公開ダウンロードは個別に検証する。

## ローカルの索引

[アプリ・ビルド入口・リリース記録の索引](.local/WORKSPACE-INDEX.md) と [.localの内容と復元方法](.local/README.md) を参照してください。索引はローカル専用です。
