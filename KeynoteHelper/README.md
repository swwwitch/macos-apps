# KeynoteHelper

![macOS](https://img.shields.io/badge/macOS-13%2B-lightgrey) ![version](https://img.shields.io/badge/version-1.2.2-blue) ![license](https://img.shields.io/badge/license-private-lightgrey)

Keynoteが前面のときだけ、102の操作をホットキーで実行するメニューバー常駐アプリ。Keyboard Maestro のマクログループ「Keynote」（`Keynote Macros.kmmacros`）の移植。メニュー項目への割り当てに加え、Keynoteでは設定できない操作（不透明度10〜100%、隠す・再表示、拡大縮小・幅±1pt・幅／高さいっぱい・同じ幅／高さ、トランジションの設定、スライド大の図形・中央の十字線・背景の図形、その場に複製、まとめて中央へ、表示中のスライドのPNG書き出し、アニメーションのプレビュー）を持つ。KeynoteSweeperの掃除6項目も、Keynoteの［サービス］の項目をAXで押してホットキーから呼べる（処理はKeynoteSweeper側、確認なしで削除するため⌃⌥0以外は初期値オフ）。キーと操作ごとのオン・オフは設定で変更できる。

- ビルド：`./build.sh`（署名後に /Applications と Latest Builds へ配置。配置しないときは `NO_DEPLOY=1`）
- テスト：`./test.sh`（起動判定、102操作のキー・手順・AppleScriptのコンパイル・PNGの命名、4言語の文字列、KMマクロのトリガーとの照合）
- 文字列：`Localization/` の `own.py`（画面・ヘルプ）と `commands.tsv`（操作名）を編集し、`python3 Localization/own.py && python3 Localization/make_strings.py` で `Resources/*.lproj` を作り直す（共通の文言は SpreadsheetHelper から取る）
- アイコン：`Assets/draw-icon.swift`

## 構成

| ファイル | 内容 |
| --- | --- |
| Sources/KeynoteCommands.swift | 操作の一覧（初期キー＝KMマクロのトリガー、カテゴリ、手順）とAppleScriptの本文 |
| Sources/CommandRunner.swift | 手順の実行（メニュー項目をAXで押す、キー送信、AppleScript、ボタン、PNG書き出し）、入力中の判定、キーの素通し |
| Sources/HotKey.swift・ShortcutCombo.swift | キーの保存形式（JSON）と KeyCombo への変換。記録欄と登録は共通部品 Shared/HotkeyRecorder（HotkeyField・HotkeySet） |
| Sources/main.swift | 画面・設定・メニュー |
| そのほか | 共通部品のコピー（AboutSection・AccessibilityPermission・AppHeader・AppSurface・HelpDocument・HotkeyManifest・HotkeyRecorder・LaunchPolicy・MenuBarPresence・SettingsSection・SettingsSync・StartupWindow・UpdateSupport・WindowActivationPolicy）。原本は Shared |

## 移植の差分

- ホットキーはKeynote（`com.apple.Keynote`・`com.apple.iWork.Keynote`）が前面のときだけ登録し、ほかのアプリではキーを奪わない。
- メニュー項目が使えないとき（選択がないときなど）は、押したキーをそのままKeynoteへ渡す。⌘・⌃を含まないキー（⌥L、⇧1など）は、テキスト入力中は文字として渡す（テキストの操作を除く）。
- 1つのマクロに複数あったトリガーは、1操作1キーにした（最初のトリガーを初期値に）。値ごとにトリガーを分けていたマクロ（±1pt、90/110/50/200%、幅・高さいっぱい、不透明度）は値ごとの操作に分けた。ただし不透明度100%は ⇧0 と ⇧` の両方を残し、⇧` を「不透明度100%（もう1つのキー）」として別の行にした（1.2.0で一時的に0%にしたのを1.2.1で戻した）。素の Home／End は登録しない。
- 操作名がメニューと食い違っていたマクロ「26)【重ね順】背面へ」（実体は最背面へ）は、名前どおり［背面へ］にした。
- 「中央に十字線を引く」の線は白・2ptを指定できない（Keynoteの線に色・太さのプロパティが無い。元のマクロの指定も効いていなかった）ためテーマの線スタイルになる。
- 「配置したPDFに白バックを追加」は、すべてを選択してグループ化する代わりに、選択したオブジェクトと追加した図形の2つだけをグループ化する。
- 「プレビュー（アニメーション）」は画像検索のクリックをやめ、アニメーションインスペクタの［プレビュー］をAXで押す。
- PNG書き出しは書き出しダイアログボックスのキー操作をやめ、AppleScriptで一時フォルダーに全スライドを書き出して表示中のスライドだけを書類の隣へ移す。同名ファイルは上書きしない。
- 「スライドショーを再生」は［フルスクリーン表示］を選んでから、「ウインドウで再生」は［ウインドウ表示］を選んでから再生する（Keynote 15のメニュー構成）。
- 「37)【トランジション】なし（すべてのスライド）」（⌃⌥⌘0）は KeynoteSweeper の「すべてのトランジションを削除」と重なるため移植しない（1.0.1で削除）。「37)【トランジション】なし（Magic Move以外のすべてのスライド）」（⌃⌥0）は1.1.0でKeynoteSweeperの「マジックムーブ以外のトランジションを削除」に移し、Helperからはそのサービスを呼ぶ。
- 確認用のKeyboard Maestroのウインドウは画面上部の短い表示に置き換えた。

## 配布

1.2.2（build 7）のDeveloper ID署名・Apple公証済みDMGを[個人noteの記事](https://note.com/swwwitch/n/n7b7e549f7379)で公開しています。
