# アプリ別リポジトリへのソース公開（2026年10月23日）

公開対象33アプリをそれぞれ `swwwitch/<正式アプリ名>` に公開。SVGExporter・InsertSnippetsは対象外。

元の確定済みソース：`897678c1ae1a5e593d968f8202da23f3d164a8b5`。KeynoteMaestroなどの未コミット作業は含めない。元リポジトリのソースと履歴は保持。

各リポジトリはアプリ本体、対応するShared、ビルド入口、出所の説明を含む。相対パスを保持し、不要な生成物・バックアップ・配布アーカイブは含めない。既存のREADMEと初回コミットを保持して公開コミットを追加。情報画面のGitHubリンクは各アプリの個別リポジトリを指す。

## 検証範囲

- 33件すべてで登録したGit treeが準備済みソースのtreeと一致。
- 公開後のmainが作成したコミットを指すことを33件確認。
- 各公開コミットの親が既存の初回コミットであることを33件確認。
- 準備段階でシェル構文、Python構文、Shared参照とスタンドアロンのUpdater準備を確認。
- 開発ワークスペース側も個別リポジトリへのリンクを参照。共通情報画面のSwift型検査が成功。
- 全アプリの再ビルド・起動・実機表示・配布先更新は未確認。アプリ本体の新バージョン公開ではない。

## 公開コミット

| アプリ | 公開コミット |
| --- | --- |
| [BreaklineTrimmer](https://github.com/swwwitch/BreaklineTrimmer) | [f8556be](https://github.com/swwwitch/BreaklineTrimmer/commit/f8556bee070076472b8bad65bda31d3e708431d4) |
| [BrowserSwitcher](https://github.com/swwwitch/BrowserSwitcher) | [c18a367](https://github.com/swwwitch/BrowserSwitcher/commit/c18a367dbecd7a1df95e33e8482392e560ff8b30) |
| [BundleIDInspector](https://github.com/swwwitch/BundleIDInspector) | [65a041e](https://github.com/swwwitch/BundleIDInspector/commit/65a041e8774e22de756567fa03376983b1136ddf) |
| [CarmaChameleon](https://github.com/swwwitch/CarmaChameleon) | [5598c51](https://github.com/swwwitch/CarmaChameleon/commit/5598c5137a833bf2386a72957212554dc78f464d) |
| [CCAutoUpdateOff](https://github.com/swwwitch/CCAutoUpdateOff) | [a2a98cf](https://github.com/swwwitch/CCAutoUpdateOff/commit/a2a98cfd47a1ff8c1b250aab0b3ee6404ca6cc7a) |
| [CommandDee](https://github.com/swwwitch/CommandDee) | [a118102](https://github.com/swwwitch/CommandDee/commit/a1181022971ac662da5bf23afbdfba49ee01d496) |
| [DocklessLauncher](https://github.com/swwwitch/DocklessLauncher) | [8f3e824](https://github.com/swwwitch/DocklessLauncher/commit/8f3e824e449bb91fa9e81b2e5428d583fc359492) |
| [ExtensionLinker](https://github.com/swwwitch/ExtensionLinker) | [1dc9594](https://github.com/swwwitch/ExtensionLinker/commit/1dc9594e01abce9a9ebbf0e58ff7e09333e8a3a2) |
| [FileCaravan](https://github.com/swwwitch/FileCaravan) | [12f9fb3](https://github.com/swwwitch/FileCaravan/commit/12f9fb38b0013f8dc7ce3a8d5fa734dbac8f8ef6) |
| [FnNumpad](https://github.com/swwwitch/FnNumpad) | [e872eb8](https://github.com/swwwitch/FnNumpad/commit/e872eb8c33ef44db91d9cf9b995e010dc5be55fe) |
| [FolderHopper](https://github.com/swwwitch/FolderHopper) | [3fed122](https://github.com/swwwitch/FolderHopper/commit/3fed122db3222cc6bf332beb2a23e920fa5dda61) |
| [HotkeyHound](https://github.com/swwwitch/HotkeyHound) | [c145fb3](https://github.com/swwwitch/HotkeyHound/commit/c145fb3d6911ac617644cdec04bbecbac205e2a0) |
| [IdBackgroundOff](https://github.com/swwwitch/IdBackgroundOff) | [986ff32](https://github.com/swwwitch/IdBackgroundOff/commit/986ff32d45181b6dc1f4cb8f80f12165c7c7f805) |
| [IncrementPaste](https://github.com/swwwitch/IncrementPaste) | [3ef32e1](https://github.com/swwwitch/IncrementPaste/commit/3ef32e14c8346f2e418a9d4369f710e86e986ba7) |
| [KageTrimmer](https://github.com/swwwitch/KageTrimmer) | [8af5a39](https://github.com/swwwitch/KageTrimmer/commit/8af5a3967bfbd21d5f796e07e9a2585f7ad0df41) |
| [KakkoReplace](https://github.com/swwwitch/KakkoReplace) | [9e6cc4a](https://github.com/swwwitch/KakkoReplace/commit/9e6cc4a71246839c9eb3484aae83365c0d11311d) |
| [KeynoteMaestro](https://github.com/swwwitch/KeynoteMaestro) | [ee67da9](https://github.com/swwwitch/KeynoteMaestro/commit/ee67da9810e6597f2974ec7fb7591955ee52cece) |
| [KeynoteSweeper](https://github.com/swwwitch/KeynoteSweeper) | [c32a02d](https://github.com/swwwitch/KeynoteSweeper/commit/c32a02dd57845669610c04f4a58314fa045e7abb) |
| [LinkMaker](https://github.com/swwwitch/LinkMaker) | [71b6abe](https://github.com/swwwitch/LinkMaker/commit/71b6abe652d98a5d5acb91ca724af7923bff911d) |
| [ListMatch](https://github.com/swwwitch/ListMatch) | [9509b9f](https://github.com/swwwitch/ListMatch/commit/9509b9f0fed7b61accbe3e525c7c5c4f5f478f44) |
| [MarkdownKitchen](https://github.com/swwwitch/MarkdownKitchen) | [2fb431a](https://github.com/swwwitch/MarkdownKitchen/commit/2fb431a1dc1944cde40fa3947977b891444a8aa0) |
| [MightyEdit](https://github.com/swwwitch/MightyEdit) | [8457122](https://github.com/swwwitch/MightyEdit/commit/8457122267005117d32e5265197f1b08f14a2028) |
| [note2markdown](https://github.com/swwwitch/note2markdown) | [df3a1e2](https://github.com/swwwitch/note2markdown/commit/df3a1e27c29fff3a0b8e446414288e62e223c362) |
| [PasteInARow](https://github.com/swwwitch/PasteInARow) | [27a34c1](https://github.com/swwwitch/PasteInARow/commit/27a34c1359673d3142c6df5d2b3661ec8715874c) |
| [PasteMatchStyle](https://github.com/swwwitch/PasteMatchStyle) | [13aaf6c](https://github.com/swwwitch/PasteMatchStyle/commit/13aaf6c1504f2a43fea6ce84f223e33739d38a17) |
| [PDF2Keynote](https://github.com/swwwitch/PDF2Keynote) | [788d8af](https://github.com/swwwitch/PDF2Keynote/commit/788d8af9d94a5fb436152825486953b474572bef) |
| [PodiumAssist](https://github.com/swwwitch/PodiumAssist) | [a9f5f5b](https://github.com/swwwitch/PodiumAssist/commit/a9f5f5b54a8aca7b70bb7dc3218c04da6d1c1bef) |
| [PrefsPreset](https://github.com/swwwitch/PrefsPreset) | [e959f22](https://github.com/swwwitch/PrefsPreset/commit/e959f224ec7f70c0af1275bd7d99e475869a3f7b) |
| [ProjectFolder](https://github.com/swwwitch/ProjectFolder) | [562af80](https://github.com/swwwitch/ProjectFolder/commit/562af8062c0fd5dbc67d8a2210c8ddf02ac3a90f) |
| [QuickIconExporter](https://github.com/swwwitch/QuickIconExporter) | [adc9607](https://github.com/swwwitch/QuickIconExporter/commit/adc96078c3dda72f26aff16ebf89667b826af1b5) |
| [SpreadsheetHelper](https://github.com/swwwitch/SpreadsheetHelper) | [82d2dbd](https://github.com/swwwitch/SpreadsheetHelper/commit/82d2dbd771fb15f70c6bc891ff653df12510e85f) |
| [VectorMate](https://github.com/swwwitch/VectorMate) | [cfb9fb2](https://github.com/swwwitch/VectorMate/commit/cfb9fb2247e907e1697dacf5f37bc300e6709998) |
| [YohakuTrimmer](https://github.com/swwwitch/YohakuTrimmer) | [edd50cf](https://github.com/swwwitch/YohakuTrimmer/commit/edd50cfae30de808823df63c55b9170a3a5be6ba) |
