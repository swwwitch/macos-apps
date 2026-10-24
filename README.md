# Macアプリ開発ワークスペース

各アプリの開発フォルダ、共通部品、最新ビルドを管理します。起動するアプリは `/Applications`、配布物はDropbox内 `sw_app/Latest Builds` を使用します。リポジトリ内の `Latest Builds` は配布一覧の資料です。開発フォルダ内の `.app` はビルド出力です。

[変更履歴](CHANGELOG.md) · [フォルダーの使い分け](WORKSPACE.md) · [リリース作業チェックリスト](Shared/BuildTools/RELEASE-CHECKLIST.md)

## ソースコードの公開

公開対象33アプリは、それぞれアプリ名と同じ個別リポジトリでソースコードを公開しています。下の「GitHub」列から開けます。各リポジトリにアプリ本体と対応する `Shared/` を含め、既存の相対パスを保持しています。このリポジトリのソースと履歴も保持します。配布用アプリ本体とソースの更新・検証状況は別に管理しています。

## アプリ一覧

| アプリ | 用途 | ソース | ビルド | GitHub |
| --- | --- | --- | --- | --- |
| VectorMate（旧 AiHelper） | Illustratorの補助：メトリクスとプロポーショナルメトリクスの連動、UIの明るさ・表示・シェイプ形成・バックグラウンドの切り替え、単位パレット | [Source](VectorMate/Source/) | [build.sh](VectorMate/build.sh) | [リポジトリ](https://github.com/swwwitch/VectorMate) |
| BrowserSwitcher | 既定ブラウザーの切り替え | [Source](BrowserSwitcher/Source/) | [build.sh](BrowserSwitcher/build.sh) | [リポジトリ](https://github.com/swwwitch/BrowserSwitcher) |
| BundleIDInspector | アプリのBundle IDを調べてコピー | [Sources](BundleIDInspector/Sources/BundleIDInspector/) | [build.sh](BundleIDInspector/build.sh) | [リポジトリ](https://github.com/swwwitch/BundleIDInspector) |
| CarmaChameleon（旧 PandocDesk） | 文書形式の変換（pandoc・Keynote・構造を保持したテキストなど） | [Source](CarmaChameleon/Source/) | [build.sh](CarmaChameleon/build.sh) | [リポジトリ](https://github.com/swwwitch/CarmaChameleon) |
| CCAutoUpdateOff | Creative Cloudのアプリの自動更新がオンになっていないかを見張って通知 | [Source](CCAutoUpdateOff/Source/) | [build.sh](CCAutoUpdateOff/build.sh) | [リポジトリ](https://github.com/swwwitch/CCAutoUpdateOff) |
| SpreadsheetHelper | Excel・Googleスプレッドシートの補助：コピー時に付く「"」の除去、行・列の挿入と削除などのショートカット（KMマクロの移植。旧名 CellCopyCleaner） | [Sources](SpreadsheetHelper/Sources/) | [build.sh](SpreadsheetHelper/build.sh) | [リポジトリ](https://github.com/swwwitch/SpreadsheetHelper) |
| CommandDee | 連番・日付付きの複製と名前変更 | [Sources](CommandDee/Sources/) | [build.sh](CommandDee/build.sh) | [リポジトリ](https://github.com/swwwitch/CommandDee) |
| DocklessLauncher（旧 AppLauncher） | ホットキーでアプリを起動・前面化 | [Sources](DocklessLauncher/Sources/) | [build.sh](DocklessLauncher/build.sh) | [リポジトリ](https://github.com/swwwitch/DocklessLauncher) |
| ExtensionLinker | 拡張子ごとの既定アプリ設定 | [Development/Sources/DutiGUI](ExtensionLinker/Development/Sources/DutiGUI/) | [Development/build.sh](ExtensionLinker/Development/build.sh) | [リポジトリ](https://github.com/swwwitch/ExtensionLinker) |
| FileCaravan | 大量のファイルをまとめて移動 | [Source](FileCaravan/Source/) | [build.sh](FileCaravan/build.sh) | [リポジトリ](https://github.com/swwwitch/FileCaravan) |
| FnNumpad | Fnキーを使ったテンキー入力 | [Sources](FnNumpad/Sources/) | [build.sh](FnNumpad/build.sh) | [リポジトリ](https://github.com/swwwitch/FnNumpad) |
| FolderHopper | 選択ファイルの移動・複製 | [Development/Source](FolderHopper/Development/Source/) | [Development/build.sh](FolderHopper/Development/build.sh) | [リポジトリ](https://github.com/swwwitch/FolderHopper) |
| HotkeyHound | 押したキーをどのアプリが使っているかを調べる | [Sources](HotkeyHound/Sources/HotkeyHound/) | [build.sh](HotkeyHound/build.sh) | [リポジトリ](https://github.com/swwwitch/HotkeyHound) |
| IdBackgroundOff | InDesignの「バックグラウンド書き出し／保存」をオフ | [Source](IdBackgroundOff/Source/) | [build.sh](IdBackgroundOff/build.sh) | [リポジトリ](https://github.com/swwwitch/IdBackgroundOff) |
| IncrementPaste | クリップボードの数字・日付・英字を1つ増やしてペースト（KMマクロ「increment-paste」の移植） | [Sources](IncrementPaste/Sources/) | [build.sh](IncrementPaste/build.sh) | [リポジトリ](https://github.com/swwwitch/IncrementPaste) |
| KageTrimmer | スクリーンショットの影を調整 | [Development/Sources](KageTrimmer/Development/Sources/) | [Development/build.sh](KageTrimmer/Development/build.sh) | [リポジトリ](https://github.com/swwwitch/KageTrimmer) |
| KakkoReplace | カッコの追加・置換 | [Sources](KakkoReplace/Sources/) | [build.sh](KakkoReplace/build.sh) | [リポジトリ](https://github.com/swwwitch/KakkoReplace) |
| KeynoteMaestro（旧 KeynoteHelper） | Keynoteの操作・ショートカット支援 | [Sources](KeynoteMaestro/Sources/) | [build.sh](KeynoteMaestro/build.sh) | [リポジトリ](https://github.com/swwwitch/KeynoteMaestro) |
| KeynoteSweeper | Keynoteの未使用マスター・非表示スライド・アニメーションの削除 | [Source](KeynoteSweeper/Source/) | [build.sh](KeynoteSweeper/build.sh) | [リポジトリ](https://github.com/swwwitch/KeynoteSweeper) |
| LinkMaker | ブラウザーのページのタイトルとURLをコピー・保存・開き直し（KMマクロ「Make Link」の移植） | [Sources](LinkMaker/Sources/) | [build.sh](LinkMaker/build.sh) | [リポジトリ](https://github.com/swwwitch/LinkMaker) |
| ListMatch | 2つのリストを比べ、片方にしかないもの・共通の項目を表示（メールアドレス・CSVの列にも対応） | [Source](ListMatch/Source/) | [build.sh](ListMatch/build.sh) | [リポジトリ](https://github.com/swwwitch/ListMatch) |
| MarkdownKitchen | Markdownの整形・加工（左に原稿、右に見出しだけを表示） | [Sources](MarkdownKitchen/Sources/MarkdownKitchen/) | [build.sh](MarkdownKitchen/build.sh) | [リポジトリ](https://github.com/swwwitch/MarkdownKitchen) |
| MightyEdit | 選択テキストの整形 | [Source](MightyEdit/Source/) | [build.sh](MightyEdit/build.sh) | [リポジトリ](https://github.com/swwwitch/MightyEdit) |
| note2markdown | note記事をMarkdownファイルに書き出す | [Source](note2markdown/Source/) | [build.sh](note2markdown/build.sh) | [リポジトリ](https://github.com/swwwitch/note2markdown) |
| PasteInARow | 複数行のテキストを1行ずつペースト（KMマクロ「01)連続ペースト」の移植） | [Sources](PasteInARow/Sources/) | [build.sh](PasteInARow/build.sh) | [リポジトリ](https://github.com/swwwitch/PasteInARow) |
| PasteMatchStyle | どのアプリでも書式なしでペースト（KMマクロ「Paste and Match Style」「Universal Paste Without Style」の移植） | [Sources](PasteMatchStyle/Sources/) | [build.sh](PasteMatchStyle/build.sh) | [リポジトリ](https://github.com/swwwitch/PasteMatchStyle) |
| PDF2Keynote | PDFをKeynoteのスライドに変換 | [Source](PDF2Keynote/Source/) | [build.sh](PDF2Keynote/build.sh) | [リポジトリ](https://github.com/swwwitch/PDF2Keynote) |
| PodiumAssist | Mac表示設定とタイマー | [Development/Sources/Toki](PodiumAssist/Development/Sources/Toki/) | [Development/build-app.sh](PodiumAssist/Development/build-app.sh) | [リポジトリ](https://github.com/swwwitch/PodiumAssist) |
| PrefsPreset | Macの設定の一覧・一括変更・書き出しと読み込み | [Sources](PrefsPreset/Sources/PrefsPreset/) | [build.sh](PrefsPreset/build.sh) | [リポジトリ](https://github.com/swwwitch/PrefsPreset) |
| SettingsCourier | アプリの設定をアプリごとに書き出し、ほかのMacで取り込む（Dropbox などの受け渡しフォルダー・取り込み前のバックアップ） | [Sources](SettingsCourier/Sources/SettingsCourier/) | [build.sh](SettingsCourier/build.sh) | 未作成 |
| SiteMirror | Webサイトのページをたどり、HTML・CSS・JavaScript・画像を保存してリンクを相対パスに書き換える（SiteSucker と同じ用途） | [Sources](SiteMirror/Sources/SiteMirror/) | [build.sh](SiteMirror/build.sh) | 未作成 |
| ProjectFolder（旧 FolderMaker） | 案件フォルダーの作成（KMマクロ「Folder Maker（案件）」の移植） | [Sources](ProjectFolder/Sources/) | [build.sh](ProjectFolder/build.sh) | [リポジトリ](https://github.com/swwwitch/ProjectFolder) |
| QuickIconExporter | アイコンを透過PNGで保存 | [Development/Sources/IconDrop](QuickIconExporter/Development/Sources/IconDrop/) | [Development/build-app.sh](QuickIconExporter/Development/build-app.sh) | [リポジトリ](https://github.com/swwwitch/QuickIconExporter) |
| BreaklineTrimmer（旧 TrimBreakline） | 画像の一部を取り除いて詰め、切り口に省略線を引いて透過PNGで書き出す（Illustratorスクリプト TrimWithBreakLine の移植） | [Source](BreaklineTrimmer/Source/) | [build.sh](BreaklineTrimmer/build.sh) | [リポジトリ](https://github.com/swwwitch/BreaklineTrimmer) |
| YohakuTrimmer | 画像の余白（四辺の同じ色）を削除 | [Development/Sources](YohakuTrimmer/Development/Sources/) | [Development/build.sh](YohakuTrimmer/Development/build.sh) | [リポジトリ](https://github.com/swwwitch/YohakuTrimmer) |

## ファイルの置き場所

- 各アプリ直下：README、ビルド入口、ソース・素材・テスト。既存のビルド経路を保持。
- `Latest Builds/`：現在保管している30本のアプリ。バージョン一覧は同フォルダのREADME。
- 各アプリの `Backups/` と `Shared/Backups/Build/`：置換前のバックアップ。ソースとして編集しない。
- 各アプリの `ReleaseArchive/` と `Shared/DistributionArchive/`：過去のZIP・DMG。現行アプリと区別する。
- 各アプリの `Docs/`：検証記録（`Docs/Verification/`）・サポート／プライバシーポリシーの原稿（`Docs/SupportPrivacy/`）・スクリーンショット・申請メモ。既存のVerificationやRecheckフォルダは保持。
- `Shared/`：[共通部品・申請資料の案内](Shared/README.md)。
- `Unsorted/`：所属未確認の画像・録画。内容を推測して振り分けない。

## 開発と整理のルール

[AGENTS.md](AGENTS.md)、[共通仕様](Shared/AppStandards/BASELINE.md)、[確認表テンプレート](Shared/AppStandards/CHECKLIST-TEMPLATE.md)を参照してください。新規アプリにも共通仕様を適用します。正式アプリ名のディレクトリを使い、名称整合だけでBundle IDや設定保存先を変更しません。

アプリ名単位のフォルダはビルドスクリプトが参照するため、そのまま使用します。旧版は削除せず退避し、移動前後のSHA-256を確認します。移動履歴は [organization-20261007.json](Shared/OrganizationLogs/organization-20261007.json)、[organization-20261014.md](Shared/OrganizationLogs/organization-20261014.md)、[organization-20261018.md](Shared/OrganizationLogs/organization-20261018.md)。

CommandDeeはこのリポジトリへ統合済みです。
