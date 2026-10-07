# PandocDesk → CarmaChameleon（2026-10-07）

pandoc 以外の変換（PDF・IDML・Keynote・構造を保持したテキスト）が増えたため改名。AGENTS.md「アプリ名とディレクトリ名の整合」に従う。

| 項目 | 旧 | 新 |
| --- | --- | --- |
| 開発フォルダ | `PandocDesk/` | `CarmaChameleon/` |
| アプリ | `PandocDesk.app` | `CarmaChameleon.app` |
| 実行ファイル（CFBundleExecutable） | `PandocDesk` | `CarmaChameleon` |
| CFBundleName／DisplayName | PandocDesk | CarmaChameleon |
| アイコン | `Assets/PandocDesk.icns` ほか | `Assets/CarmaChameleon.icns` ほか（絵柄は同じ） |
| 画面・メニュー・ヘルプ・README | PandocDesk | CarmaChameleon |

変えていないもの（互換性のため）

- Bundle ID `jp.local.PandocDesk`（設定の保存先、オートメーション許可の対象）
- `~/Library/Application Support/PandocDesk/`（導入した pandoc・Typst の保存先）
- 内部の一時フォルダ名・エラーの識別子（画面に出ない）
- README の過去の更新履歴、点検記録などの旧名

配置：`/Applications/PandocDesk.app` と `Latest Builds/PandocDesk.app` は `Shared/Backups/Build/` へ退避し、`CarmaChameleon.app` を配置。ログイン項目は旧アプリのパスで登録されていたため、新しいアプリで登録し直す。
