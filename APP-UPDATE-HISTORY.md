# 全アプリのアップデート履歴

最終更新：2026-10-27（日本時間）

日付・バージョン・build番号付きの箇条書きで記録します。今後は機能変更・修正・ビルド更新の都度、該当アプリの先頭へ追記します。

今回の初期整理は、通常版のビルド経路を持つ43アプリが対象です。各アプリの直近12件のGit記録を取り込み、既存READMEの詳しい履歴は保持しています。過去の項目の日付は日本時間に換算したコミット日、版はそのコミットのソースに記載された値です。公開日・公開版を示すものではありません。同じ版の項目が複数ある場合も、番号を推測で変更しません。

作業ツリーの現在版は未コミット変更を含む場合があります。ビルド・配置・公証・公開の確認結果は各リリース記録を参照してください。App Store版の履歴は通常版へ混在させず、今後は区分を明記します。

## PasteMaestro

- 2026-11-01｜v1.0.0（build 1）｜通常版：IncrementPaste・PasteInARow・PasteMatchStyleを新規統合。3モード、共通設定、4言語ヘルプ、クリップボード排他と旧アプリ同時動作防止を追加。開発用検証ビルド。公証・配置・公開は未実施。

## InputMaestro

- 2026-11-01｜v0.1.0（build 1）｜通常版：ControlMateの編集キー、FnNumpadのテンキー入力、ShotSorterの範囲選択文字認識を新規統合。各機能の設定、旧アプリ起動時の対応機能停止、認識結果の整形・コピーを実装。既存3アプリを保持。公証・配置・公開は未実施。

## 目次

- [InputMaestro](#inputmaestro)

- [BreaklineTrimmer](#breaklinetrimmer)
- [BrowserSwitcher](#browserswitcher)
- [BundleIDInspector](#bundleidinspector)
- [CCAutoUpdateOff](#ccautoupdateoff)
- [CarmaChameleon](#carmachameleon)
- [ClipTidy](#cliptidy)
- [CommandDee](#commanddee)
- [ControlMate](#controlmate)
- [DocklessLauncher](#docklesslauncher)
- [EventDocMaker](#eventdocmaker)
- [ExtensionLinker](#extensionlinker)
- [FavoriteFolders](#favoritefolders)（旧 FavoritesTidy）
- [FileCaravan](#filecaravan)
- [FileSorter](#filesorter)
- [FnNumpad](#fnnumpad)
- [FolderHopper](#folderhopper)
- [HotkeyHound](#hotkeyhound)
- [IdBackgroundOff](#idbackgroundoff)
- [IncrementPaste](#incrementpaste)
- [KageTrimmer](#kagetrimmer)
- [KakkoReplace](#kakkoreplace)
- [KeynoteMaestro](#keynotemaestro)
- [KeynoteSweeper](#keynotesweeper)
- [LinkMaker](#linkmaker)
- [ListMatch](#listmatch)
- [MarkdownKitchen](#markdownkitchen)
- [MenuShot](#menushot)
- [MightyEdit](#mightyedit)
- [NotMyType](#notmytype)
- [NotMyType Lite](#notmytype-lite)
- [PDF2Keynote](#pdf2keynote)
- [PasteInARow](#pasteinarow)
- [PasteMatchStyle](#pastematchstyle)
- [PrefsPreset](#prefspreset)
- [ProjectFolder](#projectfolder)
- [ScreenTake](#screentake)
- [SettingsCourier](#settingscourier)
- [SettingsHop](#settingshop)
- [ShotSorter](#shotsorter)
- [SiteMirror](#sitemirror)
- [SpreadsheetHelper](#spreadsheethelper)
- [VectorKeys](#vectorkeys)
- [VectorMaestro](#vectormaestro)
- [VectorMate](#vectormate)
- [YohakuTrimmer](#yohakutrimmer)
- [note2markdown](#note2markdown)

## BreaklineTrimmer

- 2026-10-27｜v1.4.0（build 15）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.4.0（build 12）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.4.0（build 12）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.4.0（build 11）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.4.0（build 11）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.4.0（build 11）｜Document GitHub links and note article update history（ソース変更記録：`d7ee4568`）
- 2026-10-23｜v1.4.0（build 11）｜Set dedicated note article for BreaklineTrimmer（ソース変更記録：`a6bd17f4`）
- 2026-10-23｜v1.4.0（build 11）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.4.0（build 10）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-19｜v1.3.2（build 9）｜BreaklineTrimmer 1.3.2（build 9）：リポジトリに追加（ソース変更記録：`2dcbc4ed`）

既存の詳細：[README](BreaklineTrimmer/README.md)。

## BrowserSwitcher

- 2026-10-27｜v1.7.0（build 64）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.7.0（build 61）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.7.0（build 61）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.7.0（build 60）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.7.0（build 60）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.7.0（build 60）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.7.0（build 60）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v1.7.0（build 59）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.7.0（build 59）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.7.0（build 58）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.6.37（build 57）｜BrowserSwitcher 1.6.37（build 57）：バージョン表示と ⌘Tab・Dock の表示条件（ソース変更記録：`269096d1`）
- 2026-10-17｜v1.6.35（build 55）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-13｜v1.6.31（build 51）｜記事のあるアプリのソースを公開・更新（ソース変更記録：`3c636ba5`）
- 2026-10-12｜v1.6.30（build 50）｜PodiumAssist 3.2.19〜3.2.21: PodiumFlightから改名、メインウインドウをプリセット・個別操作・タイマーのタブに（ソース変更記録：`37b8594b`）

既存の詳細：[README](BrowserSwitcher/README.md)。

## BundleIDInspector

- 2026-10-27｜v1.1.0（build 16）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.1.0（build 14）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.1.0（build 14）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.1.0（build 13）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.1.0（build 13）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.1.0（build 13）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.1.0（build 13）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.1.0（build 13）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.1.0（build 13）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.0.11（build 12）｜BundleIDInspector 1.0.11（build 12）：メインウインドウにバージョンを表示（ソース変更記録：`f1da4f5c`）
- 2026-10-17｜v1.0.10（build 11）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-12｜v1.0.10（build 11）｜PodiumAssist 3.2.19〜3.2.21: PodiumFlightから改名、メインウインドウをプリセット・個別操作・タイマーのタブに（ソース変更記録：`37b8594b`）
- 2026-10-10｜v1.0.10（build 11）｜BundleIDInspector: アイコンを作り直し、Sandbox 版の動作確認記録とnote掲載画像を追加（ソース変更記録：`60ecf359`）
- 2026-10-10｜v1.0.10（build 11）｜11アプリ: 「情報」タブの解説記事をアプリ専用の note 記事に（ソース変更記録：`ff0cebcd`）

既存の詳細：[README](BundleIDInspector/README.md)。

## CCAutoUpdateOff

- 2026-10-27｜v1.4.0（build 20）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.4.0（build 18）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.4.0（build 18）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.4.0（build 17）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.4.0（build 17）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.4.0（build 17）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-24｜v1.4.0（build 17）｜Unify notification settings and establish baseline B32（ソース変更記録：`fcb72ea8`）
- 2026-10-23｜v1.4.0（build 16）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.4.0（build 15）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.3.3（build 14）｜CCAutoUpdateOff 1.3.3（build 14）：メインウインドウにバージョンを表示（ソース変更記録：`c7a90048`）
- 2026-10-19｜v1.3.2（build 13）｜各アプリ：メインウインドウの［ヘルプ］ボタンを削除（ソース変更記録：`84f443ff`）
- 2026-10-17｜v1.3.2（build 13）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-15｜v1.3.0（build 11）｜各アプリの更新と一覧の整理（2026-10-14〜15）（ソース変更記録：`920a63be`）
- 2026-10-14｜v1.2.7（build 10）｜CCAutoUpdateOff 1.2.7: 値のないアプリの扱いをCreative Cloudの画面に合わせる（ソース変更記録：`4666f58f`）

既存の詳細：[README](CCAutoUpdateOff/README.md)。

## CarmaChameleon

- 2026-10-27｜v0.15.0（build 51）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v0.15.0（build 49）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v0.15.0（build 49）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v0.15.0（build 48）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v0.15.0（build 48）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v0.15.0（build 48）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v0.15.0（build 48）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v0.15.0（build 47）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v0.14.3（build 46）｜開発先の移行：配布先を distribution_paths.py に一元化（ソース変更記録：`e6304d5e`）
- 2026-10-20｜v0.14.3（build 46）｜CarmaChameleon 0.14.3（build 46）：App Store版のフォルダアクセス・同梱エンジンの文言（ソース変更記録：`a48bb2a5`）
- 2026-10-17｜v0.14.2（build 45）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-14｜v0.14.0（build 43）｜CarmaChameleon: App Store構成（Sandbox・Typst同梱）と設定の同期（ソース変更記録：`ee008e50`）
- 2026-10-12｜v0.14.0（build 43）｜CarmaChameleon 0.12.0〜0.14.0: PDF→テキストを pdftotext で、ラスター画像に「余白を削除」「影」（ソース変更記録：`172af573`）
- 2026-10-12｜v0.11.4（build 40）｜PodiumAssist 3.2.19〜3.2.21: PodiumFlightから改名、メインウインドウをプリセット・個別操作・タイマーのタブに（ソース変更記録：`37b8594b`）

既存の詳細：[README](CarmaChameleon/README.md)。

## ClipTidy

- 2026-10-27｜v1.0.1（build 3）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.0.1（build 3）｜設定「情報」の解説記事（note）リンクを公開済み個別記事へ更新。

- 2026-10-26｜v1.0.0（build 2）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-26｜v1.0.0（build 2）｜ClipTidy・ShotSorter・FileSorter：リリース工程2の実機確認を記録（ソース変更記録：`e8abf214`）
- 2026-10-26｜v1.0.0（build 2）｜ClipTidy 1.0.0（build 2）：コピーした文字をルールで自動で書き換える新規アプリ（ソース変更記録：`4e7fce0c`）

既存の詳細：[README](ClipTidy/README.md)。

## CommandDee

- 2026-10-27｜v1.9.0（build 60）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.9.0（build 58）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.9.0（build 58）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.9.0（build 57）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.9.0（build 57）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.9.0（build 57）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.9.0（build 57）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v1.9.0（build 56）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.9.0（build 56）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.9.0（build 55）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.8.27（build 54）｜CommandDee 1.8.27（build 54）：メインウインドウにバージョンを表示（ソース変更記録：`d1a058dd`）
- 2026-10-17｜v1.8.26（build 53）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-13｜v1.8.23（build 50）｜記事のあるアプリのソースを公開・更新（ソース変更記録：`3c636ba5`）
- 2026-10-12｜v1.8.22（build 49）｜PodiumAssist 3.2.19〜3.2.21: PodiumFlightから改名、メインウインドウをプリセット・個別操作・タイマーのタブに（ソース変更記録：`37b8594b`）

既存の詳細：[README](CommandDee/README.md)。

## ControlMate

- 2026-10-27｜v1.3.2（build 6）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.3.1（build 5）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-26｜v1.3.1（build 5）｜ControlMate 1.3.1: pass browser Control-I and Control-K to Spreadsheet Helper（ソース変更記録：`df13440a`）
- 2026-10-26｜v1.3.0（build 4）｜ControlMate 1.3.0（build 4）：InDesign 対応、コピー系のキーを Z に（ソース変更記録：`4865bbaf`）
- 2026-10-26｜v1.2.0（build 3）｜ControlMate 1.2.0（build 3）：⌃⌥⌘X 文章の末尾まで選択してコピー、⌃Z を削除（ソース変更記録：`ddf1e42b`）
- 2026-10-26｜v1.1.0（build 2）｜ControlMate 1.1.0（build 2）を追加、FnNumpad 1.1.0（build 8）（ソース変更記録：`76e0f52b`）

既存の詳細：[README](ControlMate/README.md)。

## DocklessLauncher

- 2026-10-27｜v1.11.0（build 30）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.11.0（build 28）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.11.0（build 28）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.11.0（build 27）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.11.0（build 27）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.11.0（build 27）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.11.0（build 27）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v1.11.0（build 26）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.11.0（build 26）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-21｜v1.11.0（build 25）｜配布一覧と共通移行ルール・各アプリのアイコンを更新（ソース変更記録：`96e94012`）
- 2026-10-20｜v1.11.0（build 25）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.10.4（build 24）｜DocklessLauncher 1.10.4（build 24）：キーのダブルクリックで起動・バージョン表示（ソース変更記録：`ae2d5760`）
- 2026-10-19｜v1.10.2（build 22）｜各アプリ：メインウインドウの［ヘルプ］ボタンを削除（ソース変更記録：`84f443ff`）
- 2026-10-17｜v1.10.2（build 22）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）

既存の詳細：[README](DocklessLauncher/README.md)。

## EventDocMaker

- 2026-10-27｜v1.1.0（build 2）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.1.0（build 2）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-26｜v1.1.0（build 2）｜EventDocMaker 1.1.0（build 2）：イベント管理とExcelからの取り込み（ソース変更記録：`417d17c1`）
- 2026-10-26｜v1.0.0（build 1）｜EventDocMaker 1.0.0（build 1）：イベントの表からテンプレートの文書をまとめて書き出す新規アプリ（ソース変更記録：`f40b35cb`）

既存の詳細：[README](EventDocMaker/README.md)。

## ExtensionLinker

- 2026-10-27｜v0.3.3（build 56）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v0.3.3（build 54）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v0.3.3（build 54）｜docs: organize workspace navigation and development entry points（ソース変更記録：`12314874`）
- 2026-10-25｜v0.3.3（build 54）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v0.3.3（build 53）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v0.3.3（build 53）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v0.3.3（build 53）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v0.3.3（build 53）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v0.3.3（build 52）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v0.3.3（build 52）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-22｜v0.3.3（build 51）｜公証ビルドの検証修正とKeynoteHelper公開情報を反映（ソース変更記録：`a9891f10`）
- 2026-10-22｜v0.3.3（build 51）｜GitHub最新版のアプリ更新をローカルの配布変更と統合（ソース変更記録：`065407d0`）
- 2026-10-21｜v0.3.3（build 51）｜ExtensionLinker 0.3.3（build 51）：インストールタブ削除・バージョンタブで拡張子を選択・.html変更時の注意（ソース変更記録：`60213c6d`）
- 2026-10-21｜v0.3.2（build 49）｜ExtensionLinker 0.3.2（build 49）：.applescript／.scpt を1組に、反映確認を最大5秒に（ソース変更記録：`95b059a2`）

既存の詳細：[README](ExtensionLinker/README.md)。

## FavoriteFolders

- 2026-10-27｜v1.3.9（build 15）｜通常配布版：ソースbee83bcをDeveloper ID署名・Apple公証。旧版をバックアップして/ApplicationsとLatest Buildsへ配置し、署名・全内容一致、Gatekeeper受入、/Applications版の起動と21件の表示を確認。別Macでの書き出し・読み込みは未確認。

- 2026-10-27｜v1.3.9（build 15）｜通常版・検証用：DFXの表示名「デフォルト設定」と保存先Default Setの差による読み込み失敗を修正。DFXの翻訳名から既存保存先を解決し、同名の実フォルダーがある場合はそちらを優先。データ移動なし。

- 2026-10-27｜v1.3.8（build 14）｜通常版・検証用：設定ファイルに選択中のセットのお気に入り一覧・並び順・区切り線・ホットキーを追加。読み込みは一覧に復元し、保存でDFXに反映。Option＋クリックでDFXの設定を開き、既存AX許可の範囲で「フォルダ」を選択。公証・配置・公開は未実施。

- 2026-10-27｜v1.3.7（build 13）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

旧名 FavoritesTidy（1.2.0まで）。

- 2026-10-26｜v1.3.7（build 13）｜FavoriteFolders 1.3.7（build 13）：カテゴリ見出しの上の線を≡アイコンの位置から引く（各カテゴリの最後の行の区切り線を左端から）
- 2026-10-26｜v1.3.6（build 12）｜FavoriteFolders 1.3.6（build 12）：メモのある行で区切り線が短くなる不具合を修正（メモのアイコンを外し、区切り線の開始位置を名前に固定）
- 2026-10-26｜v1.3.5（build 11）｜FavoriteFolders 1.3.5（build 11）：カテゴリ見出しの上の二重線を解消（一覧の区切り線と見出しの線が重なっていた）、ここで終了した Default Folder X を FavoriteFolders の終了時に起動し直せていなかった不具合を修正（起動を待ってから終了）、狭い幅でボタンが「…」に省略されないよう［キーボード］をアイコンだけに
- 2026-10-26｜v1.3.4（build 10）｜FavoriteFolders 1.3.4（build 10）：主画面の見出しを「Default Folder Xのお気に入りフォルダーを整理」に、補足説明を「並べ替え・カテゴリ分け・メモ・使用回数で、よく使うフォルダーを管理します。」に（日英中韓）
- 2026-10-26｜v1.3.3（build 9）｜FavoriteFolders 1.3.3（build 9）：使用回数のリセットを追加（行の右クリックで選んだフォルダーだけ、［ファイル］＞［使用回数をすべてリセット…］で全件。全件は確認あり）
- 2026-10-26｜v1.3.2（build 8）｜FavoriteFolders 1.3.2（build 8）：カテゴリ名を編集できないことがある不具合を修正（一覧の行内の入力欄が選択・ドラッグにクリックを取られ、1文字ごとの保存で再描画されていた）。鉛筆ボタン・ダブルクリック・右クリックから名前の入力画面を開き、［完了］で保存
- 2026-10-26｜v1.3.1（build 7）｜FavoriteFolders 1.3.1（build 7）：設定の［一般］に「Dropbox 内のパスを短く表示する」（初期値オン、Dropbox のフォルダーからの位置で表示）、検索窓の案内を「名前・パス・メモで検索」に
- 2026-10-26｜v1.3.0（build 6）｜FavoriteFolders 1.3.0（build 6）：表示の切り替え（フルパス・メモ・使用回数・ファイル数・サイズ）、フォルダーのメモ（⌘I、検索対象）、ファイル数とサイズの表示（裏で計算）、使用回数の記録（設定でオン、DFX への Apple event、オートメーションの許可）とよく使う順の並べ替え、ホットキーの割り当てをキーボードの図で表示（⇧⌘K）
- 2026-10-26｜v1.2.2（build 5）｜FavoriteFolders 1.2.2（build 5）：保存前のバックアップが作成直後に消えていた不具合を修正（1.0.0〜1.2.1。整理処理の dropFirst がコメントに入っていた）。整理を Backups.pruned に分けて単体テストを追加
- 2026-10-26｜v1.2.1（build 4）｜FavoritesTidy から FavoriteFolders に改名（Bundle ID jp.dtp-transit.favoritestidy・設定は維持）。バックアップの保存先を ~/Library/Application Support/FavoriteFolders/Backups にし、旧フォルダーから起動時に移す
- 2026-10-26｜v1.2.0（build 3）｜FavoritesTidy 1.2.0（build 3）：Default Folder X の起動中に編集しようとすると［終了して編集］を確認、上部に検索窓（⌘F、名前・パス）、Dropbox 内の項目に「Dropbox」の印とフォルダーからの相対パス
- 2026-10-26｜v1.1.0（build 2）｜FavoritesTidy 1.1.0（build 2）：お気に入りのホットキーの変更・解除（⌘K、共通 HotkeyField、重複拒否、Default Folder X の書式で保存）、［Default Folder X を終了／起動］ボタン（ここで終了したら保存時・終了時に起動し直す）、［読み直す］ボタンでも未保存の確認
- 2026-10-26｜v1.0.0（build 1）｜FavoritesTidy 1.0.0（build 1）新規：Default Folder X のお気に入りの並べ替え（名前・パス・追加日）、区切り線でのカテゴリ分け（見出しの名前はアプリ内のみ）、カテゴリへ移動・カテゴリの上下移動、保存時に Default Folder X を終了→外部変更の確認→バックアップ→書き込み→起動し直し

既存の詳細：[README](FavoriteFolders/README.md)。

## FileCaravan

- 2026-10-27｜v1.1.0（build 37）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.1.0（build 35）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.1.0（build 35）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.1.0（build 34）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.1.0（build 34）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.1.0（build 34）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.1.0（build 34）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.1.0（build 34）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.1.0（build 33）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.0.17（build 32）｜FileCaravan 1.0.17（build 32）：メインウインドウにバージョンを表示（ソース変更記録：`91de0ee3`）
- 2026-10-19｜v1.0.16（build 31）｜各アプリ：メインウインドウの［ヘルプ］ボタンを削除（ソース変更記録：`84f443ff`）
- 2026-10-17｜v1.0.16（build 31）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-14｜v1.0.14（build 29）｜ワークスペース整理（2026-10-14）：資料をDocsへ、README追加、一覧を25本に（ソース変更記録：`183ed4c7`）
- 2026-10-14｜v1.0.14（build 29）｜FolderHopper・FileCaravan: App Store版のヘルプを差し替えてビルド（ソース変更記録：`e01f5ee7`）

既存の詳細：[README](FileCaravan/README.md)。

## FileSorter

- 2026-11-01｜v1.1.0（build 3）｜通常版：ShotSorterのPNG改名を移植。複数フォルダー監視・命名設定・手動選択・衝突回避を追加。公証・配布は未実施。

- 2026-10-27｜v1.0.1（build 2）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.0.1（build 2）｜設定「情報」の解説記事（note）リンクを公開済み個別記事へ更新。

- 2026-10-26｜v1.0.0（build 1）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-26｜v1.0.0（build 1）｜ClipTidy・ShotSorter・FileSorter：リリース工程2の実機確認を記録（ソース変更記録：`e8abf214`）
- 2026-10-26｜v1.0.0（build 1）｜FileSorter 1.0.0（build 1）：追加されたファイルをルールで振り分ける新規アプリ（ソース変更記録：`f391aeb7`）

既存の詳細：[README](FileSorter/README.md)。

## FnNumpad

- 2026-10-27｜v1.1.0（build 8）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.1.0（build 8）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-26｜v1.1.0（build 8）｜ControlMate 1.1.0（build 2）を追加、FnNumpad 1.1.0（build 8）（ソース変更記録：`76e0f52b`）
- 2026-10-25｜v1.0.0（build 5）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.0.0（build 4）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.0.0（build 4）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.0.0（build 4）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v1.0.0（build 3）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-22｜v1.0.0（build 2）｜GitHub最新版のアプリ更新をローカルの配布変更と統合（ソース変更記録：`065407d0`）
- 2026-10-21｜v1.0.0（build 2）｜FnNumpad：公証済みbuild 2とnote公開情報を反映（ソース変更記録：`10ab0fdd`）
- 2026-10-21｜v1.0.0（build 2）｜FnNumpad 1.0.0（build 2）：ビルド番号を更新（ソース変更記録：`d4cecf33`）
- 2026-10-21｜v1.0.0（build 1）｜FnNumpad：Fn＋Tab でテンキーの =（ソース変更記録：`ccd5c9d6`）
- 2026-10-21｜v1.0.0（build 1）｜FnNumpad：切り替えキー（Fn／Caps Lock／両方）、Fn＋Return で Enter、キーボード表示の調整（ソース変更記録：`315c949e`）
- 2026-10-21｜v1.0.0（build 1）｜FnNumpad 1.0.0（build 1）：Fnキーでテンキーを入力する常駐アプリを新規作成（ソース変更記録：`74ae0fc0`）

既存の詳細：[README](FnNumpad/README.md)。

## FolderHopper

- 2026-10-27｜v0.2.0（build 125）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v0.2.0（build 123）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v0.2.0（build 123）｜docs: organize workspace navigation and development entry points（ソース変更記録：`12314874`）
- 2026-10-25｜v0.2.0（build 123）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v0.2.0（build 122）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v0.2.0（build 122）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v0.2.0（build 122）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-24｜v0.2.0（build 122）｜Unify notification settings and establish baseline B32（ソース変更記録：`fcb72ea8`）
- 2026-10-23｜v0.2.0（build 121）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v0.2.0（build 120）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v0.2.0（build 120）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v0.2.0（build 118）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v0.1.102（build 117）｜FolderHopper 0.1.102（build 117）：複数ディスプレイでウインドウを出す画面を選べるように（ソース変更記録：`074c195e`）
- 2026-10-17｜v0.1.97（build 112）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）

既存の詳細：[README](FolderHopper/README.md)。

## HotkeyHound

- 2026-10-27｜v0.4.0（build 20）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v0.4.0（build 18）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v0.4.0（build 18）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v0.4.0（build 17）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v0.4.0（build 17）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v0.4.0（build 17）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v0.4.0（build 17）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v0.4.0（build 16）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v0.4.0（build 16）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v0.4.0（build 15）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v0.3.5（build 14）｜HotkeyHound 0.3.5（build 14）：フルディスクアクセスの設定・バージョン表示（ソース変更記録：`dee056e2`）
- 2026-10-17｜v0.3.3（build 12）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-15｜v0.3.1（build 10）｜各アプリの更新と一覧の整理（2026-10-14〜15）（ソース変更記録：`920a63be`）
- 2026-10-14｜v0.3.0（build 9）｜新規アプリ FolderMaker・IncrementPaste・PasteMatchStyle・YohakuTrimmer を追加（ソース変更記録：`dcc7741a`）

既存の詳細：[README](HotkeyHound/README.md)。

## IdBackgroundOff

- 2026-10-27｜v1.1.2（build 22）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.1.2（build 20）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.1.2（build 20）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.1.2（build 19）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.1.2（build 19）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.1.2（build 19）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.1.2（build 19）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.1.2（build 19）｜Document GitHub links and note article update history（ソース変更記録：`d7ee4568`）
- 2026-10-23｜v1.1.2（build 19）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.1.2（build 18）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.1.2（build 18）｜IdBackgroundOff 1.1.2（build 18）：メインウインドウにバージョンを表示（ソース変更記録：`265a1ab7`）
- 2026-10-19｜v1.1.1（build 17）｜各アプリ：メインウインドウの［ヘルプ］ボタンを削除（ソース変更記録：`84f443ff`）
- 2026-10-17｜v1.1.1（build 17）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-15｜v1.1.1（build 17）｜各アプリの更新と一覧の整理（2026-10-14〜15）（ソース変更記録：`920a63be`）

既存の詳細：[README](IdBackgroundOff/README.md)。

## IncrementPaste

- 2026-10-27｜v1.1.0（build 12）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.1.0（build 11）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.1.0（build 11）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.1.0（build 10）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.1.0（build 10）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.1.0（build 10）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.1.0（build 10）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v1.1.0（build 9）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.1.0（build 9）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-21｜v1.1.0（build 8）｜配布一覧と共通移行ルール・各アプリのアイコンを更新（ソース変更記録：`96e94012`）
- 2026-10-20｜v1.1.0（build 8）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.0.6（build 7）｜IncrementPaste 1.0.6（build 7）：メインウインドウにバージョンを表示（ソース変更記録：`73f3414c`）
- 2026-10-19｜v1.0.5（build 6）｜各アプリ：メインウインドウの［ヘルプ］ボタンを削除（ソース変更記録：`84f443ff`）
- 2026-10-17｜v1.0.5（build 6）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）

既存の詳細：[README](IncrementPaste/README.md)。

## KageTrimmer

- 2026-10-27｜v1.4.0（build 75）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.4.0（build 74）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.4.0（build 74）｜docs: organize workspace navigation and development entry points（ソース変更記録：`12314874`）
- 2026-10-25｜v1.4.0（build 74）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.4.0（build 73）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.4.0（build 73）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.4.0（build 73）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.4.0（build 73）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v1.4.0（build 72）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.4.0（build 72）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.4.0（build 71）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.3.7（build 70）｜KageTrimmer 1.3.7（build 70）：ホットキーの譲り合い・⌘Tab と Dock の表示条件（ソース変更記録：`d5bbd04a`）
- 2026-10-17｜v1.3.4（build 67）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-15｜v1.3.0（build 63）｜各アプリの更新と一覧の整理（2026-10-14〜15）（ソース変更記録：`920a63be`）

既存の詳細：[README](KageTrimmer/README.md)。

## KakkoReplace

- 2026-10-27｜v0.4.0（build 71）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v0.4.0（build 70）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v0.4.0（build 70）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v0.4.0（build 69）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v0.4.0（build 69）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v0.4.0（build 69）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v0.4.0（build 69）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v0.4.0（build 68）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v0.4.0（build 68）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-21｜v0.4.0（build 67）｜配布一覧と共通移行ルール・各アプリのアイコンを更新（ソース変更記録：`96e94012`）
- 2026-10-20｜v0.4.0（build 67）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v0.3.46（build 66）｜KakkoReplace 0.3.46（build 66）：囲んだ後は常に閉じ括弧の後ろへ（ソース変更記録：`4d6772ae`）
- 2026-10-19｜v0.3.38（build 58）｜各アプリ：メインウインドウの［ヘルプ］ボタンを削除（ソース変更記録：`84f443ff`）
- 2026-10-17｜v0.3.38（build 58）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）

既存の詳細：[README](KakkoReplace/README.md)。

## KeynoteMaestro

- 2026-10-27｜v1.2.2（build 30）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.2.2（build 29）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.2.2（build 29）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.2.2（build 28）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.2.2（build 28）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.2.2（build 17）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.2.2（build 17）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v1.2.2（build 17）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.2.2（build 17）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）

既存の詳細：[README](KeynoteMaestro/README.md)。

## KeynoteSweeper

- 2026-10-27｜v1.2.0（build 15）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.2.0（build 14）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.2.0（build 14）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.2.0（build 13）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.2.0（build 13）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.2.0（build 13）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v1.2.0（build 12）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-21｜v1.2.0（build 11）｜KeynoteSweeper 1.2.0（build 11）：マジックムーブ以外のトランジションを削除（ソース変更記録：`cfbf3fb5`）
- 2026-10-20｜v1.1.0（build 10）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.0.8（build 9）｜KeynoteSweeper 1.0.8（build 9）：メインウインドウにバージョンを表示（ソース変更記録：`ea33071e`）
- 2026-10-17｜v1.0.7（build 8）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-10｜v1.0.5（build 6）｜共通: アイコン適用・App Store 手動ビルド・配置テスト・Updater 設定を追加、作業記録を除外（ソース変更記録：`e05ba3bb`）
- 2026-10-10｜v1.0.5（build 6）｜11アプリ: 「情報」タブの解説記事をアプリ専用の note 記事に（ソース変更記録：`ff0cebcd`）
- 2026-10-10｜v1.0.4（build 5）｜全アプリ: ⌘1、情報タブ・目印・証明書署名、UX点検の反映、基準書 B23〜B28（ソース変更記録：`d1606b50`）

既存の詳細：[README](KeynoteSweeper/README.md)。

## LinkMaker

- 2026-10-27｜v1.3.5（build 40）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.3.5（build 39）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.3.5（build 39）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.3.5（build 38）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.3.5（build 38）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.3.5（build 38）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.3.5（build 38）｜GitHub最新版をローカルのLinkMaker・MarkdownKitchen更新と統合（ソース変更記録：`ed67e84e`）
- 2026-10-23｜v1.3.5（build 37）｜LinkMaker: URL操作メニューとホットキー移行を改善（ソース変更記録：`7500fa72`）
- 2026-10-23｜v1.3.0（build 33）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v1.3.0（build 32）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.3.0（build 32）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.3.0（build 31）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.2.27（build 30）｜LinkMaker 1.2.27（build 30）：「ほかのタブを閉じる」と「新規ウインドウで開く」（ソース変更記録：`88b20bb3`）
- 2026-10-19｜v1.2.13（build 16）｜各アプリ：メインウインドウの［ヘルプ］ボタンを削除（ソース変更記録：`84f443ff`）

既存の詳細：[README](LinkMaker/README.md)。

## ListMatch

- 2026-10-27｜v1.6.0（build 14）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.6.0（build 13）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.6.0（build 13）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.6.0（build 12）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.6.0（build 12）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.6.0（build 12）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.6.0（build 12）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.6.0（build 11）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.5.3（build 10）｜ListMatch 1.5.3（build 10）：メインウインドウにバージョンを表示（ソース変更記録：`bfc70c4a`）
- 2026-10-19｜v1.5.2（build 9）｜各アプリ：メインウインドウの［ヘルプ］ボタンを削除（ソース変更記録：`84f443ff`）
- 2026-10-17｜v1.5.2（build 9）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-15｜v1.5.0（build 7）｜ListMatch: アイコンの差し替えとnote見出し画像の追加（ソース変更記録：`052b377e`）
- 2026-10-15｜v1.5.0（build 7）｜ListMatch: 2つのリストを比較する新規アプリ（旧名 ListDiff）（ソース変更記録：`1a8106f0`）

既存の詳細：[README](ListMatch/README.md)。

## MarkdownKitchen

- 2026-10-27｜v1.47.3（build 125）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.47.3（build 125）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-26｜v1.47.3（build 125）｜Route MarkdownKitchen settings to a resizable AppKit window (125)（ソース変更記録：`597326db`）
- 2026-10-26｜v1.47.3（build 124）｜Fix MarkdownKitchen document lifetimes and settings window in 1.47.3 (124)（ソース変更記録：`42b1886b`）
- 2026-10-25｜v1.47.0（build 118）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.47.0（build 117）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.47.0（build 117）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.47.0（build 117）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.47.0（build 117）｜GitHub最新版をローカルのLinkMaker・MarkdownKitchen更新と統合（ソース変更記録：`ed67e84e`）
- 2026-10-23｜v1.47.0（build 115）｜MarkdownKitchen: テキスト変換とツールのホットキー設定を追加（ソース変更記録：`647cbda5`）
- 2026-10-23｜v1.46.3（build 116）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.46.3（build 116）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-21｜v1.46.2（build 114）｜MarkdownKitchen 1.46.2（build 114）：終了時の原稿の扱いをシステム設定に合わせる（ソース変更記録：`0dc3520b`）
- 2026-10-21｜v1.46.1（build 113）｜MarkdownKitchen 1.46.1（build 113）：メインウインドウも閉じると原稿を消す（ソース変更記録：`b6578ab5`）

既存の詳細：[README](MarkdownKitchen/README.md)。

## MenuShot

- 2026-10-29｜v1.4.5（build 19・ソースのみ／再ビルド未実施）｜通常版：「をクリック」付加の未設定時既定値をOFFへ変更し、保存済みの値は保持。

- 2026-10-29｜v1.4.5（build 19）｜通常版テスト用：全角スラッシュの7形式目、設定見本を選択／共通／アピアランスに統一。入力監視を起動・常駐へ移動、アプリ呼出用ホットキーを登録・UIから削除。公証・配布未実施。

- 2026-10-29｜v1.4.4（build 18）｜通常版テスト用：末尾除去機能を削除。6形式と「をクリック」を設定の出力へ移動し、ショートカット後は撮影／テキストのみの2択へ整理。公証・配布未実施。

- 2026-10-29｜v1.4.3（build 17）｜通常版テスト用：ショートカット後の出力選択画面で、実際の取得経路を使った6形式と「をクリック」の有無を選択・保存。公証・配布未実施。

- 2026-10-29｜v1.4.2（build 16）｜通常版テスト用：撮影ショートカット後にスクショのみ／経路テキストのみ／両方を選択。公証・配布未実施。

- 2026-10-29｜v1.4.1（build 15）｜通常版テスト用：メニュー経路の空白除去・NFC正規化・単一項目表記、任意の末尾除去と「をクリック」付加を追加。公証・配布未実施。

- 2026-10-29｜v1.4.0（build 14）｜通常版テスト用：撮影直前の選択メニュー経路をAXで読み取り、結果表示とテキストコピーを追加。実機確認・公証・配布未実施。

- 2026-10-28｜v1.3.7（build 13）｜通常版テスト用：メニューバーと親メニュー間の隙間補完を削除し、システムの取得画像をそのまま使用。ユーザーが実機撮影を確認し採用。公証・配布未実施。

- 2026-10-28｜v1.3.6（build 12）｜通常版比較テスト用：build 11で影が出ないため、macOS 26のスクリーンショット専用APIに切替え、影・クリッピング設定を明示。実機の影は未確認、公証・配布未実施。

- 2026-10-28｜v1.3.5（build 11）｜通常版テスト用：システムの影付きでメニューバー・メニューを同じ座標系で一括取得する方式を試験。1ptの透明な隙間を補完。実機検証・公証・配布未実施。

- 2026-10-28｜v1.3.4（build 10）｜通常版：親メニュー・サブメニューの角丸外周に1pxのグレー枠、メニューバー下端に1pxのグレー線を追加。テスト用、公証・配布未実施。

- 2026-10-27｜v1.3.3（build 9）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.3.3（build 9）｜設定「情報」の解説記事（note）リンクを公開済み個別記事へ更新。

- 2026-10-26｜v1.3.2（build 8）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-26｜v1.3.2（build 8）｜MenuShot：入力監視でのホットキー・点滅・Path Finder・Quick Look の実機確認を記録（ソース変更記録：`b81cca74`）
- 2026-10-26｜v1.3.2（build 8）｜MenuShot 1.3.2（build 8）：秒数の変更・入力監視でのホットキー・点滅・Quick Look・影と角丸の改善（ソース変更記録：`842335d6`）
- 2026-10-26｜v1.0.2（build 3）｜MenuShot 1.0.2（build 3）：サブメニューを開くとメニューが二重に写る不具合を修正（ソース変更記録：`150c9189`）
- 2026-10-26｜v1.0.1（build 2）｜MenuShot 1.0.1（build 2）を新規追加：メニューバーと開いたメニューだけを背景透明で撮る（ソース変更記録：`a29f428a`）

既存の詳細：[README](MenuShot/README.md)。

## MightyEdit

- 2026-10-29｜v0.3.4（build 117）｜通常版・検証用：設定のホットキーを機能名・キー表記で検索可能に。カンマ付与⌃⌥⌘,・カンマ除去⌃⌥⌘.・合計⌃⌥⌘=を初期値にし、共通の欄クリック記録UIを使用。公証・配布は未実施。

- 2026-10-27｜v0.3.3（build 116）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v0.3.3（build 116）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v0.3.3（build 116）｜Add clipboard text removal and align MightyEdit hotkey settings（ソース変更記録：`728b6e0b`）
- 2026-10-25｜v0.3.0（build 112）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v0.3.0（build 111）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v0.3.0（build 111）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v0.3.0（build 111）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v0.3.0（build 111）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v0.3.0（build 110）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v0.3.0（build 110）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v0.3.0（build 109）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v0.2.34（build 108）｜MightyEdit 0.2.34（build 108）：「区切り文字で改行」（ソース変更記録：`f225bfef`）
- 2026-10-19｜v0.2.31（build 105）｜各アプリ：メインウインドウの［ヘルプ］ボタンを削除（ソース変更記録：`84f443ff`）
- 2026-10-17｜v0.2.31（build 105）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）

既存の詳細：[README](MightyEdit/README.md)。

## NotMyType

- 2026-10-30｜v1.64.0（build 107）｜通常版：カードの5段階評価・評価別絞り込み・数字1〜5での評価、お気に入りのハート表示を配布対象として採番。公証・配布は未実施。

- 2026-10-29｜版・build未割当（未ビルド）｜通常版：カードの5段階評価、評価別フィルター、数字キー1〜5での評価を追加。

- 2026-10-29｜版・build未割当（未ビルド）｜通常版：一覧・サイドバーのお気に入りアイコンを星からハートへ変更。

- 2026-10-27｜v1.62.1（build 102）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-27｜v1.62.0（build 101）｜検証結果の訂正：ライブラリの二重矢印は利用者確認で未解決。左側の動作を右端へ移して1つにする再修正を受付。

- 2026-10-27｜v1.62.0（build 101）｜検証用：ライブラリ矢印の二重表示を修正、アクティブ操作をトグル化、字形の文字／輪郭コピー、Path Finder優先オープン。OH MY FONT不可視表示は条件付き自動化、手動案内あり。ビルド・配置・起動確認、Adobe貼り付けと一部実機操作は未確認。

- 2026-10-26｜v1.61.2（build 100）｜通常配布版：キャッシュ消去画面の高さ不足を修正。一覧だけスクロールし、見出し・下部ボタンを固定。99／23の追加変更を統合。ビルド・公証・公開の結果はリリース記録を参照。

- 2026-10-26｜v1.61.1（build 99）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-26｜v1.61.1（build 99）｜Record NotMyType local builds 99 and 23; hide debug links behind Option（ソース変更記録：`c786aa74`）
- 2026-10-26｜v1.61.0（build 96）｜NotMyType: add font-folder debug menu and keep All Fonts visible（ソース変更記録：`532b4e3e`）
- 2026-10-26｜v1.61.0（build 96）｜Add font membership drag and project menu; dim active selection action（ソース変更記録：`2a8f2cd8`）
- 2026-10-25｜v1.60.1（build 95）｜Clear search filters with Option-click in both NotMyType editions（ソース変更記録：`7cff96de`）
- 2026-10-25｜v1.60.0（build 94）｜Add project exclusions and vendor search in NotMyType 1.60.0（ソース変更記録：`937bd759`）
- 2026-10-25｜v1.59.0（build 93）｜Support Adobe Fonts activation in NotMyType 1.59.0（ソース変更記録：`9d400eeb`）
- 2026-10-25｜v1.58.3（build 92）｜Record performance release runtime and settings verification（ソース変更記録：`3fb274f5`）
- 2026-10-25｜v1.58.3（build 92）｜Reduce redundant sidebar updates and reuse font list nodes in both editions（ソース変更記録：`7bbb76ed`）
- 2026-10-25｜v1.58.2（build 91）｜Fix sidebar clicks and clear search on category changes with Option override（ソース変更記録：`29c31014`）
- 2026-10-25｜v1.58.1（build 90）｜NotMyType 1.58.1: toggle memberships and improve project row selection（ソース変更記録：`4ba0bdfc`）
- 2026-10-25｜v1.58.0（build 89）｜Record NotMyType release verification and remaining runtime checks（ソース変更記録：`3256de96`）
- 2026-10-25｜v1.58.0（build 89）｜NotMyType 1.58.0: update links preview controls and window reopening（ソース変更記録：`ddb6242d`）

既存の詳細：[README](NotMyType/README.md)。

最新の変更内容・未確認項目：[NotMyType両版の履歴](NotMyType/CHANGELOG.md)。

## NotMyType Lite

- 2026-10-27｜v1.9.0（build 25）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.8.2（build 24）｜通常配布版：キャッシュ消去画面の高さ不足を修正。一覧だけスクロールし、見出し・下部ボタンを固定。99／23の追加変更を統合。ビルド・公証・公開の結果はリリース記録を参照。

- 2026-10-26｜v1.8.1（build 23）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-26｜v1.8.1（build 23）｜Record NotMyType local builds 99 and 23; hide debug links behind Option（ソース変更記録：`c786aa74`）
- 2026-10-26｜v1.8.0（build 21）｜NotMyType: add font-folder debug menu and keep All Fonts visible（ソース変更記録：`532b4e3e`）
- 2026-10-26｜v1.8.0（build 21）｜Add font membership drag and project menu; dim active selection action（ソース変更記録：`2a8f2cd8`）
- 2026-10-25｜v1.7.4（build 20）｜Clear search filters with Option-click in both NotMyType editions（ソース変更記録：`7cff96de`）
- 2026-10-25｜v1.7.3（build 19）｜Record performance release runtime and settings verification（ソース変更記録：`3fb274f5`）
- 2026-10-25｜v1.7.3（build 19）｜Reduce redundant sidebar updates and reuse font list nodes in both editions（ソース変更記録：`7bbb76ed`）
- 2026-10-25｜v1.7.2（build 18）｜Fix sidebar clicks and clear search on category changes with Option override（ソース変更記録：`29c31014`）
- 2026-10-25｜v1.7.1（build 17）｜Record NotMyType release verification and remaining runtime checks（ソース変更記録：`3256de96`）
- 2026-10-25｜v1.7.1（build 17）｜NotMyType Lite: compact preview options and restore window on activation（ソース変更記録：`27aecd5b`）
- 2026-10-25｜v1.7.1（build 14）｜NotMyType Lite 1.7.1: リンク追加とプレビュー配置・オプションを調整（ソース変更記録：`922022b5`）
- 2026-10-25｜v1.7.0（build 11）｜NotMyType Lite 1.7.0: リンク集とカスタムリンク設定、見出しを更新（ソース変更記録：`854e52bd`）
- 2026-10-25｜v1.6.1（build 10）｜NotMyType両版のアイコン更新と不可視フォント対応、Liteのフォント管理復活（ソース変更記録：`9bee2a9a`）

既存の詳細：[README](NotMyType%20Lite/README.md)。

最新の変更内容・未確認項目：[NotMyType両版の履歴](NotMyType/CHANGELOG.md)。

## PDF2Keynote

- 2026-10-27｜v1.2.0（build 25）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.2.0（build 24）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.2.0（build 24）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.2.0（build 23）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.2.0（build 23）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.2.0（build 23）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.2.0（build 22）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.1.7（build 21）｜開発先の移行：配布先を distribution_paths.py に一元化（ソース変更記録：`e6304d5e`）
- 2026-10-20｜v1.1.7（build 21）｜PDF2Keynote 1.1.7（build 21）：メインウインドウにバージョンを表示（ソース変更記録：`e775647c`）
- 2026-10-17｜v1.1.6（build 20）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-10｜v1.1.4（build 18）｜11アプリ: 「情報」タブの解説記事をアプリ専用の note 記事に（ソース変更記録：`ff0cebcd`）
- 2026-10-10｜v1.1.3（build 17）｜全アプリ: ⌘1、情報タブ・目印・証明書署名、UX点検の反映、基準書 B23〜B28（ソース変更記録：`d1606b50`）
- 2026-10-10｜v1.1.1（build 15）｜全アプリ: 設定ウインドウをリサイズ可能に、タブのフォーカス枠とアクセシビリティ欄の修正（ソース変更記録：`f498f8fc`）
- 2026-10-08｜v1.1.0（build 14）｜PDF2Keynote 1.1.0: 各ページの背景を取り除き、テーマとマスターを指定（ソース変更記録：`5993da29`）

既存の詳細：[README](PDF2Keynote/README.md)。

## PasteInARow

- 2026-10-27｜v1.5.0（build 24）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.5.0（build 23）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.5.0（build 23）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.5.0（build 22）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.5.0（build 22）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.5.0（build 22）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.5.0（build 22）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v1.5.0（build 21）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.5.0（build 21）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.5.0（build 20）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.4.9（build 19）｜PasteInARow 1.4.9（build 19）：メインウインドウにバージョンを表示（ソース変更記録：`edcfad9d`）
- 2026-10-19｜v1.4.8（build 18）｜各アプリ：メインウインドウの［ヘルプ］ボタンを削除（ソース変更記録：`84f443ff`）
- 2026-10-17｜v1.4.8（build 18）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-15｜v1.4.4（build 14）｜各アプリの更新と一覧の整理（2026-10-14〜15）（ソース変更記録：`920a63be`）

既存の詳細：[README](PasteInARow/README.md)。

## PasteMatchStyle

- 2026-10-27｜v1.1.0（build 13）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.1.0（build 12）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.1.0（build 12）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.1.0（build 11）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.1.0（build 11）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.1.0（build 11）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.1.0（build 11）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v1.1.0（build 10）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.1.0（build 10）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-21｜v1.1.0（build 9）｜配布一覧と共通移行ルール・各アプリのアイコンを更新（ソース変更記録：`96e94012`）
- 2026-10-20｜v1.1.0（build 9）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.0.7（build 8）｜PasteMatchStyle 1.0.7（build 8）：メインウインドウにバージョンを表示（ソース変更記録：`e3db0f2d`）
- 2026-10-19｜v1.0.6（build 7）｜各アプリ：メインウインドウの［ヘルプ］ボタンを削除（ソース変更記録：`84f443ff`）
- 2026-10-17｜v1.0.6（build 7）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）

既存の詳細：[README](PasteMatchStyle/README.md)。

## PrefsPreset

- 2026-10-27｜v1.2.1（build 27）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.2.1（build 23）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.2.1（build 23）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.2.1（build 22）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.2.1（build 22）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.2.0（build 21）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.2.0（build 21）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.2.0（build 21）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.2.0（build 20）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.1.16（build 19）｜PrefsPreset 1.1.16（build 19）：バージョン表示・ウィザードの項目の見直し（ソース変更記録：`e2243cdb`）
- 2026-10-17｜v1.1.14（build 17）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-15｜v1.1.9（build 12）｜各アプリの更新と一覧の整理（2026-10-14〜15）（ソース変更記録：`920a63be`）
- 2026-10-14｜v1.1.9（build 12）｜PrefsPreset 1.1.9: エッセンシャル設定、壁紙、Mighty Mouse、24時間表示ほか（ソース変更記録：`3ec1b1eb`）
- 2026-10-14｜v1.1.8（build 11）｜PrefsPreset 1.1.7〜1.1.8: 週の始まり、アプリのショートカット（別名で保存・しまう）（ソース変更記録：`a3474f26`）

既存の詳細：[README](PrefsPreset/README.md)。

## ProjectFolder

- 2026-10-27｜v1.12.0（build 28）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.12.0（build 27）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.12.0（build 27）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.12.0（build 26）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.12.0（build 26）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.12.0（build 26）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.12.0（build 26）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v1.12.0（build 25）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.12.0（build 25）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.12.0（build 23）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.11.6（build 22）｜ProjectFolder 1.11.6（build 22）：メインウインドウにバージョンを表示（ソース変更記録：`ffa006d9`）
- 2026-10-17｜v1.11.5（build 21）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-15｜v1.11.0（build 16）｜ProjectFolder 1.11.0：シンボリックリンクは1件ずつのときだけ（ソース変更記録：`db535698`）
- 2026-10-14｜v1.9.0（build 13）｜FolderMaker を ProjectFolder 1.9.0 に改名・機能追加（ソース変更記録：`8ac56d0e`）

既存の詳細：[README](ProjectFolder/README.md)。

## ScreenTake

- 2026-10-27｜v1.0.1（build 2）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.0.1（build 2）｜アイコンをカチンコ（画面とポインタ入り）に変更：旧アイコンが日の丸に見えたため
- 2026-10-26｜v1.0.0（build 1）｜ScreenTake 1.0.0（build 1）を新規追加：画面・ウインドウ・音声・カメラの収録と簡易編集、ポインタは別レイヤー（ソース変更記録：`2251e28d`）

既存の詳細：[README](ScreenTake/README.md)。

## SettingsCourier

- 2026-10-27｜v1.3.2（build 9）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 ソースが配布済み版より古いため配置保留。

- 2026-10-26｜ソースのURLのみ｜設定「情報」の解説記事（note）リンクを公開済み個別記事へ更新。配布版1.4.2（13）のソース確認待ち、ビルド・配置は保留。

- 2026-10-26｜v1.4.2（build 13）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.3.2（build 9）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.3.2（build 9）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.3.2（build 9）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-24｜v1.3.2（build 9）｜SettingsCourier: record successful notary authentication and saved Safari draft（ソース変更記録：`2272d8a4`）
- 2026-10-24｜v1.3.2（build 9）｜SettingsCourier 1.3.2 build 9: prepare release and document verification blockers（ソース変更記録：`3973ab4b`）
- 2026-10-24｜v1.3.1（build 8）｜SettingsCourier 1.3.1（build 8）：「受け渡しフォルダー」の呼び名を「同期フォルダー」にそろえる（ソース変更記録：`62434b9c`）
- 2026-10-24｜v1.3.0（build 7）｜SettingsCourier 1.3.0（build 7）：まとめて書き出す・取り込む（ソース変更記録：`833c9ab5`）
- 2026-10-24｜v1.2.0（build 6）｜SettingsCourier 1.2.0（build 6）：一緒に運ぶファイルと Default Folder X のお気に入り（ソース変更記録：`d89cdb14`）
- 2026-10-24｜v1.1.0（build 5）｜SettingsCourier 1.1.0（build 5）：受け渡しフォルダーを「設定の共有」の同期フォルダーに統合（ソース変更記録：`cbf71fd1`）
- 2026-10-24｜v1.0.1（build 4）｜SettingsCourier 1.0.1（build 4）：取り込んだ直後に「新しい設定」と出続けるのを修正（ソース変更記録：`24a585ce`）
- 2026-10-24｜v1.0.0（build 3）｜SettingsCourier 1.0.0（build 3）を追加（ソース変更記録：`eb1b522f`）

既存の詳細：[README](SettingsCourier/README.md)。

## SettingsHop

- 2026-10-30｜v1.8.1（build 25）｜通常版：直前のシステム設定画面を保持する前面化処理とAirDrop直下の高速ズーム項目（キーなし）を含むソースの版・buildを更新。ビルド・公証・配布は未実施。

- 2026-10-29｜v1.8.0（build 24）｜呼び出しホットキーは1回でメイン表示、ダブルクリック間隔内の2回で閉じてシステム設定を開く。押しっぱなしのリピートを除外。公開・実キー動作は未確認。

- 2026-10-29｜v1.7.2（build 23）｜通常版検証用：ダブルタップで起動済みのシステム設定を直接前面化し、直前の画面を保持するよう修正。再ビルド・実機確認未実施。

- 2026-10-29｜v1.7.2（build 23）｜通常版の検証用変更：呼び出しキーの2回押しでメインを閉じシステム設定を開く。AirDropの下に高速ズームの範囲設定の入口を追加（キーなし、詳細到達は未確認）。公証・配布未実施。

- 2026-10-27｜v1.7.2（build 23）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.7.2（build 23）｜設定「情報」の解説記事（note）リンクを公開済み個別記事へ更新。

- 2026-10-26｜v1.7.1（build 22）｜通常版：メインウインドウ右下の「直前のアプリ」表示を削除（Option＋クリックの動作は変更なし）。配置済み
- 2026-10-26｜v1.7.0（build 21）｜通常版：設定に［項目］タブを追加し、各項目の表示・非表示とキー（⌘1〜⌘9／なし）を編集できるように（設定の共有の対象）。配置済み
- 2026-10-26｜v1.6.0（build 20）｜通常版：プライバシーとセキュリティの「カメラ」「マイク」を追加（⌘キーなし、Option＋クリックで直前のアプリの行を選択）。配置済み
- 2026-10-26｜v1.5.2（build 19）｜通常版：「プライバシーとセキュリティ」を常に一番上から表示（アクセシビリティ許可時、`?Privacy` で開いてAXで一覧を先頭へスクロール）。配置済み
- 2026-10-26｜v1.5.1（build 18）｜通常版：メインウインドウのリサイズをなくし、中身の大きさに固定（NSHostingController の preferredContentSize）。配置済み
- 2026-10-26｜v1.5.0（build 17）｜SettingsHop 1.5.0（build 17）：プライバシーとセキュリティの「セキュリティ」欄へのリンクを追加（ソース変更記録：`0a96f820`）
- 2026-10-26｜v1.4.1（build 16）｜SettingsHop 1.4.1（build 16）：⌃⌥Q の2回押しを取りやめ、アイコンと余白を調整（ソース変更記録：`ec065133`）
- 2026-10-26｜v1.4.0（build 15）｜SettingsHop 1.4.0（build 15）：設定のホットキー説明を生成元（make-resources.py）で更新（ソース変更記録：`ce757e4a`）
- 2026-10-26｜v1.4.0（build 15）｜SettingsHop 1.4.0（build 15）：⌃⌥Q 1回でシステム設定、2回でウインドウ（ソース変更記録：`fd5366a9`）
- 2026-10-26｜v1.3.1（build 14）｜SettingsHop 1.3.1（build 14）：デフォルトのWebブラウザでポップアップのメニューを開く（ソース変更記録：`866099dd`）
- 2026-10-26｜v1.3.0（build 13）｜SettingsHop 1.3.0（build 13）：システム設定のよく使う画面を直接開く新規アプリ（ソース変更記録：`06465f17`）

既存の詳細：[README](SettingsHop/README.md)。

## ShotSorter

- 2026-10-27｜v1.1.0（build 3）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-27｜v1.1.0（build 3）｜通常版：複数ウォッチフォルダー、PNGドロップで命名、Visionの文字をコメントとクリップボードへ出力。QRCode専用命名を削除。整形設定を設定画面へ移し改行を保持、範囲OCRの初期ホットキーを⌘⇧1へ変更。開発用ビルド、公証・配布は未実施。

- 2026-10-26｜v1.0.1（build 2）｜設定「情報」の解説記事（note）リンクを公開済み個別記事へ更新。

- 2026-10-26｜v1.0.0（build 1）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-26｜v1.0.0（build 1）｜ClipTidy・ShotSorter・FileSorter：リリース工程2の実機確認を記録（ソース変更記録：`e8abf214`）
- 2026-10-26｜v1.0.0（build 1）｜ShotSorter 1.0.0（build 1）：スクリーンショットの改名と範囲の文字認識の新規アプリ（ソース変更記録：`07848bbf`）

既存の詳細：[README](ShotSorter/README.md)。

## SiteMirror

- 2026-10-27｜v1.5.3（build 16）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.5.3（build 16）｜設定「情報」の解説記事（note）リンクを公開済み個別記事へ更新。

- 2026-10-26｜v1.5.2（build 14）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.5.2（build 14）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.5.2（build 13）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.5.2（build 13）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.5.2（build 13）｜SiteMirror 1.5.2: add download comparisons and refine main window（ソース変更記録：`d2d9eac7`）
- 2026-10-24｜v1.4.2（build 9）｜Prepare SiteMirror 1.4.1 and VectorMate 2.19.2 with validation records（ソース変更記録：`2a403aff`）
- 2026-10-24｜v1.3.0（build 5）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-24｜v1.3.0（build 5）｜SiteMirror 1.3.0（build 5）：wget・HTTrack 相当の機能を追加（1.2.0 を含む）（ソース変更記録：`80893da2`）
- 2026-10-24｜v1.1.0（build 3）｜SiteMirror 1.1.0（build 3）：失敗の確認・上書き・記録ファイル（ソース変更記録：`44c9f32e`）
- 2026-10-24｜v1.0.0（build 1）｜SiteMirror 1.0.0（build 1）：Webサイトを相対リンクで保存する新しいアプリ（ソース変更記録：`b34995ef`）

既存の詳細：[README](SiteMirror/README.md)。

## SpreadsheetHelper

- 2026-10-27｜v1.5.0（build 19）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.5.0（build 18）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.5.0（build 18）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.5.0（build 17）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.5.0（build 17）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.5.0（build 17）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.5.0（build 17）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v1.5.0（build 16）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.5.0（build 16）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.5.0（build 15）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.4.5（build 14）｜SpreadsheetHelper 1.4.5（build 14）：ピボットテーブル・整形スペシャル・バージョン表示（ソース変更記録：`796363d8`）
- 2026-10-19｜v1.4.4（build 13）｜各アプリ：メインウインドウの［ヘルプ］ボタンを削除（ソース変更記録：`84f443ff`）
- 2026-10-17｜v1.4.4（build 13）｜SpreadsheetHelper 1.4.4（build 13）：CellCopyCleaner から改名、表の操作のショートカットを追加（ソース変更記録：`9a2fb1b4`）

既存の詳細：[README](SpreadsheetHelper/README.md)。

## VectorKeys

- 2026-11-01｜v1.16.0（build 27）｜通常版・検証用：ファイル／ExtendScriptコードを共有コンポーネントへ分離し、アクションに複数を順序指定。グループ・パレット・既存設定を保持して移行。最近使ったスクリプト10件を追加。公証・配布未実施。

- 2026-10-31｜v1.15.1（build 26）｜通常版・検証用：パス常時表示、概要の独立した開閉、スクリプト情報のアニメーション短縮を反映。公証・配布未実施。

- 2026-10-31｜v1.15.0（build 25）｜通常版・検証用：右ペインをコンパクト化、ホットキー説明を削除、パレットの検索・ファイル名追加表示と検索欄の入力対応を追加。公証・配布未実施。

- 2026-10-31｜v1.14.1（build 24）｜通常版・検証用：情報更新の選択項目・選択グループ・全体の3範囲、既存ファイル名へのSCRIPT_DESCRIPTION_JA適用と手動名保護を追加。公証・配布未実施。

- 2026-10-31｜v1.14.0（build 23）｜通常版・検証用：任意ディバイダー、統計のスクリプト名・パス・列表示切替・ソート、SCRIPT_DESCRIPTION_JA命名（ユーザー名保持）、関連付けアプリでのソース表示を追加。公証・配布未実施。

- 2026-10-31｜v1.13.0（build 22）｜通常版・検証用：監視サブディレクトリの自動カテゴリ化オプション、除外フォルダー名の編集・保存を追加。初期除外single-function／backup。公証・配布未実施。

- 2026-10-31｜v1.12.0（build 21）｜通常版・検証用：手動タグと絞り込み、複数ウォッチフォルダーの再帰読み込み・フォルダー名タグの取り込みを追加。公証・配布未実施。

- 2026-10-29｜v1.11.0（build 20）｜通常版・検証用：⌘Delete、パレット名インライン編集、情報再読み込み、解説ページ・コードURL、Finder準拠の7色によるアイテム全体の背景色、Illustrator前面時のみのパレット表示を追加。単体・4言語検証PASS。実機操作・公証・配布は未確認。

- 2026-10-29｜v1.10.0（build 19）｜通常版：アイテム表示オプション・区切り線・選択ソート、カテゴリ右パネルへのパレット設定移動と3動作を実装。単体・4言語検証・署名付き検証ビルド成功。実機UI・公証・配布未実施。

- 2026-10-28｜v1.9.1（build 18）｜検証用：Quick Look・Finder表示・ソースコードを開くボタン、ホットキー欄の一行化（押し方ラベル非表示）、SCRIPT_NAME/VERSION/AUTHOR/RELEASED/UPDATED/README_JA/README_EN/ARTICLE_URLからのメタデータ補完を追加。SCRIPTMETA優先。初回公開と更新日を分離。テスト・署名検証、実機でQuick Look・一行表示・メタ情報表示を確認。公証・配置・公開未実施。

- 2026-10-28｜v1.8.1（build 14）｜検証用：詳細下部へ概要・メモ・版・URL・README・作者などの情報を追加。概要は開閉式、メモは項目ごとに保存。SCRIPTMETA読取と近傍README探索に対応。テスト・ビルド・署名検証、実機の情報表示確認済み。公証・配置・公開未実施。

- 2026-10-28｜v1.8.0（build 13）｜検証用：3カラムの幅調整と保存、カテゴリ別パレット表示ホットキー、アプリ版のアイコン下表示、SCRIPTMETAからのスクリプト版表示を追加。テスト・ビルド・署名検証合格。幅ドラッグ・版表示・設定画面を実機確認。公証・配置・公開未実施。

- 2026-10-28｜v1.7.0（build 12）｜検証用：カテゴリ別パレット、複数カテゴリ表示、実行ボタン、結果表示、位置・サイズ保存を追加。テスト・ビルド・署名検証合格。実機で表示と直書き実行の完了表示を確認。公証・配布・公開未実施。
- 2026-10-28｜v1.6.0（build 11）｜検証用：コード欄を拡幅し、名前と実行ボタンを上段へ配置。追加操作を集約し、説明と履歴を開閉式に整理。実機表示とユーザーの外観確認済み。公証・配布・公開未実施。
- 2026-10-28｜v1.6.0（build 10）｜検証用：コード欄上部の重複見出しを削除。ビルド・署名検証合格。公証・配布・公開未実施。
- 2026-10-28｜v1.6.0（build 9）｜検証用：JavaScript直書き・保存・編集・実行を追加。Illustrator 2026で提示コードによるカーニングのメトリクス変更を実機確認。公証・配布・公開未実施。

- 2026-10-27｜v1.5.1（build 8）｜設定の共有タブに書き出し・読み込み・同期を追加。ホットキー全体の有効状態・使用回数表示・並び順を共有。一覧・実ファイル・Mac固有値は除外。公証・配布未実施。

- 2026-10-27｜v1.5.0（build 7）｜通常配布版：ユーザーの明示指示により、このMacで版・buildを確定。スクリプト専用化のビルド・自動テスト・Apple公証通過。旧版バックアップ後に両配置先の署名・全内容一致と/Applications起動を確認。設定差分なし。実キー・Illustrator実行は未確認。

- 2026-10-27｜次版未確定（現行v1.4.0／build 6で検証）｜スクリプト専用化：メニューコマンドの追加・選択・実行、専用権限設定、同梱コマンド表を削除。旧メニュー手順はデータを保持して項目全体の実行とキー登録を止める。混在KMマクロも全体をスキップ。公証・配置は未実施。

- 2026-10-26｜v1.4.0（build 6）｜アイテムを手順の並びに（スクリプトの実行・メニューコマンドの実行を挿入・並べ替え・削除）。メニューコマンドはIDで実行し、IDで動かないものはメニュー項目名でアクセシビリティ経由で押す。KM取り込みで複数手順・executeMenuCommand・メニュー選択に対応。/ApplicationsとLatest Buildsへ配置。

- 2026-10-27｜v1.3.1（build 5）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 ソースが配布済み版より古いため配置保留。

- 2026-10-26｜v1.3.1（build 5）｜主画面の見出しを「Illustratorでスクリプトを高速実行」に（4言語）。［ツール］＞［アイテム名の検索と置換…］に⌘F。/ApplicationsとLatest Buildsへ配置。
- 2026-10-26｜v1.3.0（build 4）｜3カラム（カテゴリ・一覧・詳細）とカテゴリの作成・名前変更・削除・振り分け（KMのグループ名をカテゴリに）。ホットキーの押し方（1回／2回、KMの2回タップを引き継ぎ）。一覧の並べ替え（手動・名前順・ショートカット順）。詳細欄の見出しを左列に。「使用回数を表示」。ホットキー欄はクリックで記録し［変更…］ボタンを廃止（共通部品）。複数選択（まとめてドラッグ・カテゴリ変更・削除）、ドロップ先のカテゴリを反転表示、［ツール］＞［統計…］（使用順・カテゴリ付き）［アイテム名の検索と置換…］［KMマクロのナンバリングを削除］［KMマクロをオフ／オンに］。⌘Zで削除・名前変更・カテゴリ変更・取り込みを取り消し、削除時はImportedの.jsxをゴミ箱へ。重なるUIを整理（上の追加ボタン・詳細の有効チェック・設定のホットキータブを廃止、使用回数の表示は［表示］メニューへ）。/ApplicationsとLatest Buildsへ配置。
- 2026-10-26｜v1.2.0（build 3）｜Keyboard Maestroの書き出し（.kmmacros）をドラッグ／⌘Iで取り込み。スクリプトを1つ実行するだけのマクロの名前・ホットキー・オン／オフを引き継ぎ、マクロ内のコードはImportedに.jsxで保存（MaestroPackのスクリプトは読まない）。/ApplicationsとLatest Buildsへ配置。
- 2026-10-26｜v1.1.0（build 2）｜使った回数と最終実行日時を一覧・詳細欄に表示（エラーなく終わった実行を数える）。ホットキー欄のクリックで記録開始。/ApplicationsとLatest Buildsへ配置。
- 2026-10-26｜v1.0.0（build 1）｜新規。登録した.jsxをIllustrator前面時だけ効くショートカットで実行。/ApplicationsとLatest Buildsへ配置（公証・公開は未実施）。

## VectorMaestro

- 2026-10-26｜v1.1.0（build 2）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-26｜v1.1.0（build 2）｜VectorMaestro 1.1.0（build 2）：アプリ内でマクロを編集できるように（ソース変更記録：`d03ea4fb`）
- 2026-10-26｜v1.0.0（build 1）｜VectorMaestro 1.0.0（build 1）：KMのIllustratorマクロを取り込んで実行する新規アプリ（ソース変更記録：`ef5630e0`）

既存の詳細：[README](VectorMaestro/README.md)。

## VectorMate

- 2026-10-27｜v2.19.2（build 81）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v2.19.2（build 80）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v2.19.2（build 80）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v2.19.2（build 79）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v2.19.2（build 79）｜Prepare SiteMirror 1.4.1 and VectorMate 2.19.2 with validation records（ソース変更記録：`2a403aff`）
- 2026-10-24｜v2.19.1（build 78）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v2.19.1（build 78）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v2.19.1（build 77）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-21｜v2.19.1（build 76）｜VectorMate 2.19.1（build 76）：関連付けタブに実際に開く方を表示（ソース変更記録：`88cce993`）
- 2026-10-20｜v2.19.0（build 75）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v2.18.5（build 74）｜VectorMate 2.18.5（build 74）：クイック変形・環境設定セット・同期タブの拡充（ソース変更記録：`46b8ed97`）
- 2026-10-19｜v2.7.1（build 50）｜各アプリ：メインウインドウの［ヘルプ］ボタンを削除（ソース変更記録：`84f443ff`）
- 2026-10-19｜v2.7.1（build 50）｜VectorMate 2.7.1（build 50）：「ツール」タブに選択ツールのダブルタップとツールに合わせたパネル表示（ソース変更記録：`b8a2218a`）
- 2026-10-18｜v2.6.1（build 48）｜VectorMate 2.6.1（build 48）：単位の高速切り替え・アプリ起動のホットキー・「その他」タブ（ソース変更記録：`83748f84`）

既存の詳細：[README](VectorMate/README.md)。

## YohakuTrimmer

- 2026-10-27｜v1.2.0（build 13）｜通常配布版：共通ホットキー欄をクリックして記録開始する方式へ反映し、［変更…］ボタンを廃止。既存のローカル変更も統合。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.2.0（build 12）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.2.0（build 12）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.2.0（build 11）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.2.0（build 11）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.2.0（build 11）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.2.0（build 11）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v1.2.0（build 10）｜Publish individual app repository index and route About links（ソース変更記録：`b21db6b8`）
- 2026-10-23｜v1.2.0（build 10）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.2.0（build 9）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.1.6（build 8）｜YohakuTrimmer 1.1.6（build 8）：バージョン表示と ⌘Tab・Dock の表示条件（ソース変更記録：`a0684e5e`）
- 2026-10-17｜v1.1.4（build 6）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-14｜v1.0.0（build 1）｜ワークスペース整理（2026-10-14）：資料をDocsへ、README追加、一覧を25本に（ソース変更記録：`183ed4c7`）
- 2026-10-14｜v1.0.0（build 1）｜新規アプリ FolderMaker・IncrementPaste・PasteMatchStyle・YohakuTrimmer を追加（ソース変更記録：`dcc7741a`）

既存の詳細：[README](YohakuTrimmer/README.md)。

## note2markdown

- 2026-10-27｜v1.3.0（build 14）｜通常配布版：既存のローカル変更と共通部品を統合して再ビルド。 Apple公証通過、旧版バックアップ後に両配置先の署名・全内容一致と/Applicationsからの起動を確認。全機能実機検証は未確認。

- 2026-10-26｜v1.3.0（build 13）｜ソースの現在版を記録。これは配布・公開の完了記録ではありません。
- 2026-10-25｜v1.3.0（build 13）｜Record Dock menu release build numbers and verified distribution history（ソース変更記録：`ccff0cc6`）
- 2026-10-25｜v1.3.0（build 12）｜Keep application menus available while Dock-hidden apps have regular windows（ソース変更記録：`41725ff4`）
- 2026-10-24｜v1.3.0（build 12）｜Build all apps with Developer ID signing and record verification（ソース変更記録：`aa6e829d`）
- 2026-10-24｜v1.3.0（build 12）｜Unify manual and login startup window behavior（ソース変更記録：`f8d68894`）
- 2026-10-23｜v1.3.0（build 12）｜Standardize accessibility settings assistance and prepare approved releases（ソース変更記録：`f042d344`）
- 2026-10-23｜v1.3.0（build 11）｜Publish current app sources and GitHub links in About（ソース変更記録：`857ef286`）
- 2026-10-20｜v1.3.0（build 10）｜全アプリ：設定［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（ソース変更記録：`454ed18d`）
- 2026-10-20｜v1.2.0（build 9）｜note2markdown 1.2.0（build 9）：ログインして有料部分を読み込み・サイトをエクスポート（ソース変更記録：`4a0b9af0`）
- 2026-10-19｜v1.1.4（build 6）｜各アプリ：メインウインドウの［ヘルプ］ボタンを削除（ソース変更記録：`84f443ff`）
- 2026-10-17｜v1.1.4（build 6）｜各アプリの更新：設定の共有・ホットキー記録欄・対象外アプリなどを共通部品に（2026-10-16〜17）（ソース変更記録：`d490fb01`）
- 2026-10-15｜v1.1.2（build 4）｜各アプリの更新と一覧の整理（2026-10-14〜15）（ソース変更記録：`920a63be`）
- 2026-10-15｜v1.1.2（build 4）｜note2markdown 1.1.2（build 4）：ブラウザーからの読み込み・ドラッグ＆ドロップ・⌘Return（ソース変更記録：`a0be4aad`）

既存の詳細：[README](note2markdown/README.md)。

### NotMyType / NotMyType Lite 検証用更新

- 2026-10-27｜v1.62.1（build 102）｜NotMyType：アクティブ切替の進捗表示、ライブラリ矢印修正、字形16分類とコピー形式を更新。検証用。
- 2026-10-27｜v1.9.0（build 25）｜NotMyType Lite：アクティブ／非アクティブ操作をトグル化し、進捗を表示。検証用。

## InsertSnippets

- 2026-10-27｜v1.11.2（build 28）｜通常配布版：共通部品を反映して再ビルド。Apple公証通過、両配置先の署名・全内容一致と/Applications起動を確認。全機能実機検証は未確認。

## PodiumAssist

- 2026-10-29｜v3.3.19（build 91）｜通常配布版準備：画面サイズからズーム倍率を設定する自動設定、キーボードバックライト輝度の操作を追加。ポインターサイズを「基本」タブへ移動。版・buildは開発側確定値を維持。公証・配置・公開は検証記録へ記載。

- 2026-10-27｜v3.3.19（build 85）｜通常配布版：共通部品を反映して再ビルド。Apple公証通過、両配置先の署名・全内容一致と/Applications起動を確認。全機能実機検証は未確認。

## QuickIconExporter

- 2026-10-27｜v1.2.0（build 42）｜通常配布版：共通部品を反映して再ビルド。Apple公証通過、両配置先の署名・全内容一致と/Applications起動を確認。全機能実機検証は未確認。

## SVGExporter

- 2026-10-27｜v1.2.4（build 10）｜通常配布版：共通部品を反映して再ビルド。Apple公証通過、両配置先の署名・全内容一致と/Applications起動を確認。全機能実機検証は未確認。

- 2026-10-27｜バージョン・build未割当（未ビルド）｜NotMyType／Lite：重複解決でユーザーのFontsフォルダー、共通Fontsフォルダーを優先し、手動指定を保持。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType／Lite：サイドバーのドロップ先を最低32ptの高さに広げ、背景と枠で強調。

- 2026-10-28｜v1.63.0（build 103）｜NotMyType通常版：共通サンプルテキストによるカード比較を追加。Fontsフォルダーの重複優先とドロップハイライト拡大を含む検証用ビルド。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType通常版：文字サイズとカードサイズの調整を両方表示し、独立して保存。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType通常版：カード表示にPostScript名の表示設定が反映されない不具合を修正。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType通常版：カードのダブルクリックでそのフォントだけのカード画面を開く機能を追加。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType通常版：単独画面に日本語／英語／カスタムの長文プレビュー、文字サイズ・行間・カラム数の調整を追加。

- 2026-10-28｜v1.63.1（build 104）｜NotMyType通常版：カードから回転して単独プレビューへ切替。ほかのUIを隠し、戻る／Escで一覧へ復帰。文字・カードサイズ、PostScript名、長文・段組みの調整を含む検証版。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType通常版：単独プレビューのオプションを初期表示に変更。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType通常版：カードフォーカス表示の表示切替を削除し、行間1.0を文字サイズと同じ行送りに修正。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType通常版：カードフォーカス表示に白地に黒／黒地に白／カスタム配色を追加。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType通常版：カードフォーカス表示の「テキスト」ラベルを非表示。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType通常版：カードフォーカス表示のフォント名の下にウエイト・PostScript名を表示。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType通常版：カードフォーカス表示にpaltのON／OFFを追加。

- 2026-10-28｜v1.63.2（build 105）｜NotMyType通常版：カードフォーカス表示の配色・palt・フォント情報を追加し、行送りとオプションの初期表示を修正。検証用。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType通常版：行間初期値を1.0に変更し、段落前／後のアキを独立追加。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType通常版：カード表示から⌘Returnでカードフォーカス表示へ切替。

- 2026-10-28｜v1.63.3（build 106）｜NotMyType通常版：段落前後のアキを独立追加、行間初期値1.0、⌘Returnによるカードフォーカス表示。検証用。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType通常版：段落前後のアキを「段落間のアキ」1つに統合。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType通常版：カードフォーカス表示のプレビューオプションを右側へ移動。

- 2026-10-28｜バージョン・build未割当（未ビルド）｜NotMyType／Lite：サイドバーの項目間隔を元に戻し、ドロップ判定とハイライトだけを上下へ拡張。

- 2026-10-28｜バージョン・build未確定（未ビルド）｜NotMyType通常版・Lite版：サイドバーカテゴリ名のクリックで開閉、Option＋クリックで全カテゴリを同じ状態に開閉。

- 2026-10-28｜版・build未確定（未ビルド）｜NotMyType通常版・Lite版：すべてのカテゴリ見出しをライブラリと同じボタン行に統一。

## 2026-10-29 PodiumAssist / MightyEdit 公開検証済み

PodiumAssist 3.3.19（91）・MightyEdit 0.3.4（117）の配布版実機確認はユーザー回答で正常。署名/公証/配置/GitHub/note公開DL検証成功。個別リポジトリ単体再ビルドと開発Mac現物版は未確認。詳細: Shared/BuildTools/ReleaseRecords/20261029-PodiumAssist-MightyEdit.md。
