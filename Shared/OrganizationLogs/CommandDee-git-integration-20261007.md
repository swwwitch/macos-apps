# CommandDee Git統合

CommandDeeを親のmacos-appsリポジトリで管理する通常フォルダに変更した。作業ファイルは全件SHA-256一致。未コミット変更・未追跡ファイルは保持。親のHEAD・既存インデックスは変更せず、コミット・pushは行っていない。

- 元HEAD: `e506bc04e2c64b47d7ce34218d09305dfb89f614`
- 履歴保存参照: `refs/archive/commanddee/main`（元2コミットを保持。親ブランチへのマージはしていない）
- バックアップ: `/Users/takano/sw Dropbox/takano masahiro/Dropbox-shared/setup2026/sw_app/Shared/BuildBackups/CommandDee-git-integration-20261007-083419`
- 元Git情報: `git-metadata/`
- 全参照履歴: `history.bundle`（verify済み）
- 元リモート: https://github.com/swwwitch/CommandDee.git
- 現在の管理リモート: https://github.com/swwwitch/macos-apps.git

復元する場合は、親GitでCommandDeeをコミットする前なら、git-metadataをCommandDee/.gitへ戻せる。保存参照は通常のgit pushでは送信されない。
