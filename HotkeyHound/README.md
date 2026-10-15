# HotkeyHound

キーの組み合わせを押すと、そのキーをどのアプリで設定しているかを一覧にするユーティリティです。ホットキーが効かないときに、どこで横取りされているかを探すのに使います。

- 記録中はHIDレベルのイベントタップでキーを先に受け取り、ほかのアプリには渡さない（アクセシビリティ未許可時はアプリ内のキーだけ）
- 照合元：macOSのホットキー（symbolichotkeys）・サービス（pbs）・アプリのショートカット（NSUserKeyEquivalents）・起動中のアプリのメニュー（AX）・Keyboard Maestro・BetterTouchTool・Karabiner-Elements・Alfred・Default Folder X・Keystroke Pro・ATOK（キーカスタマイズ）・Adobe Illustrator（キーボードショートカット）・自作アプリ（共通ファイル）・KeyboardShortcuts形式のアプリ
- 定義元の設定での無効、定義元アプリの停止、対象アプリの限定を表示
- 照合する範囲を「すべてのアプリ」と「アプリを指定」（選んだアプリのメニューと、そのアプリで効くもの。初期値は直前に使っていたアプリ）で切り替え
- 設定の「照合元」で並び順の変更（結果の並びにも反映）と、手入力の独自の照合元の追加・編集・削除
- 見つからないときの手がかりとして、システムの専有登録と、キー入力を受け取るイベントタップを持つアプリを表示

各アプリの設定ファイルは読むだけで、書き換えません。通信もしません。

## ビルド

```sh
./build.sh            # ビルド → 検証 → /Applications と Latest Builds へ配置
NO_DEPLOY=1 ./build.sh  # 配置せず build/ にだけ作る
```

- SwiftPM（`Package.swift`）。ソースは [Sources/HotkeyHound](Sources/HotkeyHound/)、文字列・ヘルプは [Localizations](Localizations/)（ja / en / zh-Hans / ko）。
- 共通部品（AppSurface・StartupWindow・SettingsSection・HelpDocument・AboutSection・MenuBarPresence・LoginAtLaunch・AccessibilityPermission・UpdateSupport）は各 `sync` スクリプトがビルド時に上書きするので、直接編集しない。
- アイコンは [Assets/make-icon.sh](Assets/make-icon.sh)（GenerateIcon.swift から .icns を生成）。

## 実装メモ（実測）

- 共有登録（RegisterEventHotKey の options 0）のホットキーは、ほかのアプリから一覧できない。同じキーを `kEventHotKeyExclusive` で登録すると、専有登録（⌘Space の Spotlight など）のときだけ `eventHotKeyExistsErr`（-9878）になる。Keyboard Maestro・CommandDee のキーは 0 が返る。
- BetterTouchTool は `~/Library/Application Support/BetterTouchTool/btt_data_store.version_<版>_build_<日付>`（Core Data の SQLite）。キーボードのトリガーは `ZGESTURETYPE = 0`、修飾は NSEvent のフラグ、メモは `ZNOTES`、フォルダは `ZPARENT`（630）、アプリは `Z_2APPS_GESTURES`、プリセットは `ZBELONGSTOPRESET2`（`ZACTIVATED`）。キー送信は `ZSHORTCUT` に修飾キーのキーコード列＋本体。
- Keyboard Maestro の修飾は Carbon（⌘256・⇧512・⌥2048・⌃4096）、キー未設定は KeyCode 32767。
- Default Folder X の `keyBindings` の context は 1＝ファイルダイアログ、2＝Finder、4＝全体、16＝クイックサーチ。Setapp 版は `com.stclairsoft.DefaultFolderX5-setapp`。
- Alfred は `~/Library/Application Support/Alfred/prefs.json` の `current`（同期フォルダ）にある Alfred.alfredpreferences を読む。呼び出しキーは Mac ごとの `preferences/local/<localhash>/hotkey/prefs.plist`、機能は `preferences/features/*/prefs.plist`、ワークフローは `workflows/*/info.plist` の `alfred.workflow.trigger.hotkey`（`hotkey`・`hotmod` は NSEvent のフラグ）。未設定は key -1 か修飾なしで表記が空、ダブルタップは key -1。`relatedAppsMode` 1＝指定アプリのみ・2＝指定アプリ以外（実機の設定から推定）。
- 自作アプリは Carbon の共有登録で外から一覧できないため、各アプリが共通部品 `Shared/HotkeyManifest` で `~/Library/Application Support/swwwitch/Hotkeys/<Bundle ID>.json` に書き出し、それを読む。アプリを削除して残ったファイルは無視する。
- サンドボックスのアプリ（Keystroke Pro、コンテナにある KeyboardShortcuts 形式の設定）は、ドメインにコンテナ内の plist のパス（拡張子なし）を渡して CFPreferences（cfprefsd 経由）で読む。
- KeyboardShortcuts（sindresorhus）の形式は `KeyboardShortcuts_<名前>` = `{"carbonKeyCode":…,"carbonModifiers":…}` の JSON 文字列。
- ATOK は `~/Library/Preferences/ATOK<版>/ATOK<版>Customizer.plist` の「スタイル名」が使用中のスタイル。ファイルは同じフォルダの `Styles`（ユーザー）か `/Library/Application Support/JustSystems/ATOK<版>/Data/Styles`（既定）。plist の「キー」（8064バイト）は、先頭の UInt16 BE が状態ごとの [開始, 終了) のレコード番号（0〜11語目が文字未入力・入力中・変換中・次候補表示中・全候補表示中・文節区切り直し中、28〜29語目が半角入力）、64バイト目から10バイトずつ「キー4つ（未設定 0xFFFF）＋機能番号」。キーは上位バイトが 0x01 特殊キー・0x04 shift・0x10 control・0x20 option、下位バイトが文字（control 付きは制御文字）か特殊キー番号（0x08 delete・0x09 tab・0x0D return・0x1B esc・0x21〜0x2C F1〜F12・0x47 clear・0x50 かな・0x52 英数・0x61 pg dn・0x62 pg up・0x64 delete⌦・0x65〜0x68 ↑←→↓・0x69 home・0x6A end・0x6F enter）。ATOK Customizer の「キー設定のテキストファイル出力」と全件突き合わせて確認した。機能番号と機能名の対応は ATOK Customizer の `__DATA_CONST,__const` にある {番号, 名前の変数} の表から取り出した。
- Illustrator は最新の正式版の `~/Library/Preferences/Adobe Illustrator <版> Settings/<言語>/Adobe Illustrator 環境設定` の `/KBSCShortcutFile` が使用中のセット（`/FileName` はファイル名の16進、`/IsPreset 1` は既定のセットで .kys なし）。既定のセットは同梱の `Resources/デフォルト.kys` を読む。.kys は `/<ID> { /Context /Modifiers /Represent /Key }`。Modifiers は ⌘64・⇧32・⌥128（Illustrator のショートカットに ⌃ は使えない）、Key は文字コード、F1〜F12 は 14〜25、Context 1 は文字の編集中。ツールの切り替えキーは .kys に入らないため、既定の一覧（`Resources/Illustratorのデフォルト.txt` の「ツール」→ `IllustratorTools.tsv`）で補う。ID と名前の対応は AT-doc の ExtendScript.txt から作った `Resources/IllustratorCommands.tsv`。
- Google Drive の `SearchHotKey`（未設定で 0）と ATOK ディクショナリーの `HotKey`（"Shift"）は、設定時の形式が分からない・キーの組み合わせではないため対象外。
- TIS（キーボード配列）はメインスレッド専用なので、照合用の文字表は `KeyNames.prepare()` で先に作る。
- メニューの AXMenuItemCmdChar は英字を常に大文字で返す（シフトの意味はない）。記号はシフトで入力する文字ならシフト込みとして扱う（⌘? ＝ ⇧⌘/）。

## 更新履歴

- 0.3.1（build 10）2026-10-14：設定のショートカットの表示が狭く、⌃⌥⇧⌘ を含むキーが切れていたのを修正（文字の幅に合わせて広がる。全アプリで統一）。
- 0.3.0（build 9）2026-10-13：照合元に ATOK（使用中のスタイルのキーカスタマイズ。効く状態も表示）と Adobe Illustrator（Illustratorで選んでいるキーボードショートカットのセット。デフォルトのセットとツールのキーは同梱の既定値）を追加。
- 0.2.3（build 8）2026-10-13：ヘルプメニューの「note記事を開く」と「情報」タブの記事リンクを、HotkeyHoundの紹介記事（https://note.com/swwwitch/n/n7a9d82bd7346）に変更。
- 0.2.2（build 7）2026-10-13：照合結果の件数の右に「無効なホットキーを非表示」を追加（設定でオフ・定義元のアプリが停止中のものを隠す。選択は記憶）。
- 0.2.1（build 6）2026-10-13：「最前面のアプリ」を「アプリを指定」に変更。起動中のアプリをポップアップで選ぶ（初期値は直前に使っていたアプリ）。起動していないアプリは「その他…」から選べる。
- 0.2.0（build 5）2026-10-13：「一覧」を廃止し、照合する範囲を「すべてのアプリ」「アプリを指定」で切り替えるようにした。設定の「照合元」をドラッグで並び替えられるようにし、独自の照合元（ホットキーを手入力）を追加・編集・削除できるようにした。
- 0.1.2（build 4）2026-10-12：照合元にKeystroke Pro・自作アプリ（CommandDee・MightyEdit・FolderHopper・KageTrimmer・KakkoReplace・BrowserSwitcher が共通ファイルに書き出したもの）・KeyboardShortcuts形式のアプリ（DemoProなど）を追加。
- 0.1.1（build 3）2026-10-12：照合元にAlfredを追加（呼び出しキー・クリップボード履歴などの機能・ワークフローのホットキー）。
- 0.1.0（build 2）2026-10-11：初版。
