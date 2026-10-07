# Macアプリ開発ワークスペース

各アプリの開発フォルダ、共通部品、最新ビルドを管理します。起動するアプリは `/Applications`、保管用の現行ビルドは [Latest Builds](Latest%20Builds/) を使用します。開発フォルダ内の `.app` はビルド出力です。

## アプリ一覧

| アプリ | 用途 | ソース | ビルド |
| --- | --- | --- | --- |
| BrowserSwitcher | 既定ブラウザーの切り替え | [Source](BrowserSwitcher/Source/) | [build.sh](BrowserSwitcher/build.sh) |
| CommandDee | 連番・日付付きの複製と名前変更 | [Sources](CommandDee/Sources/) | [build.sh](CommandDee/build.sh) |
| ExtensionLinker | 拡張子ごとの既定アプリ設定 | [Development/Sources/DutiGUI](ExtensionLinker/Development/Sources/DutiGUI/) | [Development/build.sh](ExtensionLinker/Development/build.sh) |
| FolderHopper | 選択ファイルの移動・複製 | [Development/Source](FolderHopper/Development/Source/) | [Development/build.sh](FolderHopper/Development/build.sh) |
| FileCaravan | 大量のファイルをまとめて移動 | [Source](FileCaravan/Source/) | [build.sh](FileCaravan/build.sh) |
| IdBackgroundOff | InDesignの「バックグラウンド書き出し／保存」をオフ | [Source](IdBackgroundOff/Source/) | [build.sh](IdBackgroundOff/build.sh) |
| KageTrimmer | スクリーンショットの影を調整 | [Development/Sources](KageTrimmer/Development/Sources/) | [Development/build.sh](KageTrimmer/Development/build.sh) |
| KakkoReplace | カッコの追加・置換 | [Sources](KakkoReplace/Sources/) | [build.sh](KakkoReplace/build.sh) |
| MightyEdit | 選択テキストの整形 | [Source](MightyEdit/Source/) | [build.sh](MightyEdit/build.sh) |
| PDF2Keynote | PDFをKeynoteのスライドに変換 | [Source](PDF2Keynote/Source/) | [build.sh](PDF2Keynote/build.sh) |
| CarmaChameleon（旧 PandocDesk） | 文書形式の変換（pandoc・Keynote・構造を保持したテキストなど） | [Source](CarmaChameleon/Source/) | [build.sh](CarmaChameleon/build.sh) |
| PodiumFlight | Mac表示設定とタイマー | [Development/Sources/Toki](PodiumFlight/Development/Sources/Toki/) | [Development/build-app.sh](PodiumFlight/Development/build-app.sh) |
| QuickIconExporter | アイコンを透過PNGで保存 | [Development/Sources/IconDrop](QuickIconExporter/Development/Sources/IconDrop/) | [Development/build-app.sh](QuickIconExporter/Development/build-app.sh) |

## ファイルの置き場所

- 各アプリ直下：README、ビルド入口、ソース・素材・テスト。既存のビルド経路を保持。
- `Latest Builds/`：現在保管している13本のアプリ。バージョン一覧は同フォルダのREADME。
- 各アプリの `Backups/` と `Shared/Backups/Build/`：置換前のバックアップ。ソースとして編集しない。
- 各アプリの `ReleaseArchive/` と `Shared/DistributionArchive/`：過去のZIP・DMG。現行アプリと区別する。
- 各アプリの `Docs/Verification/`：検証記録・スクリーンショット。既存のVerificationやRecheckフォルダは保持。
- `Shared/`：[共通部品・申請資料の案内](Shared/README.md)。
- `Unsorted/`：所属未確認の画像・録画。内容を推測して振り分けない。

## 開発と整理のルール

[AGENTS.md](AGENTS.md)、[共通仕様](Shared/AppStandards/BASELINE.md)、[確認表テンプレート](Shared/AppStandards/CHECKLIST-TEMPLATE.md)を参照してください。新規アプリにも共通仕様を適用します。正式アプリ名のディレクトリを使い、名称整合だけでBundle IDや設定保存先を変更しません。

アプリ名単位のフォルダはビルドスクリプトが参照するため、そのまま使用します。旧版は削除せず退避し、移動前後のSHA-256を確認します。今回の移動履歴は [organization-20261007.json](Shared/OrganizationLogs/organization-20261007.json)。

CommandDeeは親Gitへ統合済み。整理作業ではコミット・pushを行っていません。
