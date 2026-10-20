# SpreadsheetHelper

![macOS](https://img.shields.io/badge/macOS-13%2B-lightgrey) ![version](https://img.shields.io/badge/version-1.4.4-blue) ![license](https://img.shields.io/badge/license-private-lightgrey)

Microsoft Excel・Googleスプレッドシートでセルを選んで ⌥⌘C を押すと、セル内改行で付く「"」などを取り除いてクリップボードに入れ直すメニューバー常駐アプリ。Keyboard Maestro のマクロ「コピー時、セル内改行使用時に付加される「"」を削除」の移植。表の操作のショートカット26個（行・列の挿入・削除・非表示とピボットテーブルは両方、Excelは書式・置換・形式を選択してペーストなど13個、Googleスプレッドシートはシート移動・SUM・見出し行・垂直方向中央と折り返し・整形スペシャルなど9個。設定で変更可）も持つ。旧名 CellCopyCleaner（Bundle ID jp.dtp-transit.cellcopycleaner）。

- ビルド：`./build.sh`（署名後に /Applications と Latest Builds へ配置。App Store用は `APP_STORE_BUILD=1`）
- テスト：`./test.sh`（整形の規則、起動、ホットキー、4言語の文字列、KMマクロとの一致。マクロは sw_app 直下に置いたときだけ照合）
- 文字列：`Resources/*.lproj/Localizable.strings`（ヘルプ本文は `helpText`）
- アイコン：`Assets/draw-icon.swift`

## 構成

| ファイル | 内容 |
| --- | --- |
| Sources/CleanRules.swift | Excel・Googleスプレッドシートそれぞれの整形の規則（マクロから書き起こし、テスト対象） |
| Sources/ClipboardCleaner.swift | 対象アプリへの ⌘C、クリップボードの読み書き、元の内容への復元 |
| Sources/HotKey.swift・ShortcutCombo.swift | ⌥⌘C の保存形式（JSON）と KeyCombo への変換。記録欄と登録は共通部品 Shared/HotkeyRecorder（HotkeyField・HotkeySet）。登録は対象アプリが前面のときだけ |
| Sources/SheetCommands.swift | 表の操作のショートカット（KMグループ「Excel 2016」「Google スプレッドシート」のマクロから移植） |
| Sources/main.swift | 画面・設定・メニュー |
| そのほか | 共通部品のコピー（AboutSection・AccessibilityPermission・AppHeader・AppSurface・HelpDocument・HotkeyManifest・LaunchPolicy・MenuBarPresence・SettingsSection・StartupWindow・UpdateSupport・WindowActivationPolicy）。原本は Shared |

## 移植の差分

- 対象アプリ（Excel・Chrome・Safari・Firefox）以外が前面のときは ⌥⌘C を登録せず、そのアプリ本来の操作に渡す。ブラウザーはGoogleスプレッドシートのウインドウのときだけ処理する。
- 整える前の内容（文字・HTML・RTF）を控え、「元のコピー内容に戻す」で戻せる。
- アポストロフィ→「"」の置き換えを設定でオン・オフできる。

## 設定の共有

設定の「設定の共有」タブ（「情報」の直前、共通部品 Shared/SettingsSync）で、「書き出し・読み込み」（SpreadsheetHelper-Settings.plist）と「設定の同期」（iCloud Drive・Dropbox などのフォルダー）を使える。共有するのは整えるホットキー（有効・キー）、表の操作（オン・オフ・キー）、対象アプリ、アポストロフィの置き換え、完了の表示。ログイン時の起動・起動時非表示・常駐・メニューバーはMacごとに残る。

## 更新履歴

- 1.5.0（build 15, 2026-10-20）：設定の［起動・常駐］に「Dockとアプリケーションスイッチャーに表示しない」を追加（初期値オフ。オンでDockと⌘Tabに出さず、メニューバーのアイコンかFinderで開き直して表示）。ヘルプ（4言語）にも追記。
- 1.4.5（build 14, 2026-10-17）：⌥⌘P（ピボットテーブル）をExcelでも使えるように（「データ ▸ ピボットテーブルで集計」を実行）。⌃⇧6 で垂直方向中央・折り返す、⌃⌥⌘F で整形スペシャル（全体を上下中央・折り返し、1行目を固定・太字・中央揃え、交互の背景色）を追加（Googleスプレッドシート）。Googleスプレッドシートの ⌥⌘P がメニューを開いたまま止まることがあったのを修正（挿入メニューで P を押したあと Return で実行）。メインウインドウのアイコンの下にバージョンとbuild番号を表示。
- 1.4.4（build 13, 2026-10-17）：設定のホットキー欄を全アプリ共通の部品に（［変更…］［初期値に戻す］、記録中の案内・重複や登録失敗の表示をそろえ、記録中はホットキーを一時的に外す）。有効化のスイッチは「ホットキーを有効にする」に。保存形式はそのまま。表の操作の各行も同じ欄にし、アプリ内のほかのキーと同じキーは断る（初期値が ⌥ だけ・⌥⇧ だけの行は ⌥ のキーも記録できる）。
- 1.4.3（build 12, 2026-10-17）：「起動・常駐」の「アクセシビリティ」を共通の部品に、未許可で実行できなかったときの表示を共通の文言に。常駐・初期値に戻すなどの文言をそろえた。表の操作の「置換…」「形式を選択してペースト…」の省略記号を「…」に。
- 1.4.2（build 11, 2026-10-16）：設定に「設定の共有」タブを追加（書き出し・読み込み、iCloud Drive・Dropboxなどでの同期）。「情報」タブとヘルプの「note記事を開く」を専用の記事に変更。メインウインドウの見出しを「表計算をキーボードで手早く」に変え、説明文に表の操作を追加。状態欄の「ホットキー」を「コピーして整える」に。設定の［対象アプリ］でアイコンがチェックボックスとずれていたのを修正（アプリ名の行に配置）。
- 1.4.1（build 10, 2026-10-16）：設定の［ホットキー］の［表の操作］をカテゴリ（行・列／配置／書式／編集／移動・ウインドウ／データ）の見出しで分類。
- 1.4.0（build 9, 2026-10-16）：表の操作に18個を追加。両方：⌘3 行・列を隠す。Excel：⇧⌘L 左寄せ・⇧⌘R 右揃え・⌘G／⇧⌘G 選択範囲内で中央とその解除・⌃⌥Home A1にジャンプ・⌃U セルを先頭から編集・⌘F 置換・⌥V 形式を選択してペースト・⌥⌘K ハイパーリンクをクリア・⌥⌘W 罫線・⌃⌥⌘I Power Query・⌃⌘N 新しいウインドウ。Googleスプレッドシート：⌥← ⌥→ シート移動・⌥⇧= SUM関数・⌃⇧1 表示形式（#,##0）・⌃⌥⌘= 見出し行。書式とA1へのジャンプはAppleScriptでExcelを操作（初回にオートメーションの許可）。記録したキーがHome・矢印・Fキーなどのとき名前で表示。
- 1.3.0（build 8, 2026-10-16）：CellCopyCleaner から SpreadsheetHelper に改名し、Bundle ID を jp.dtp-transit.spreadsheethelper に変更（初回起動時に旧版の設定を引き継ぐ。アクセシビリティの許可とログイン項目は取り直し）。表の操作のショートカットを変更できるように（ほかのキーとの重複は記録しない）。設定の［表の操作］を1項目1行の表にし、Excel・Googleスプレッドシートの対応を列の✓で表示。キーの表示に字間を追加。画面・ヘルプからKeyboard Maestroマクロに関する説明を削除。
- 1.2.1（build 7, 2026-10-16）：⌃F（交互の背景色）がFirefoxでセルに「÷交互の背景色」と入力されていたのを修正（メニュー検索を ⌥/ ではなくヘルプメニュー ⌃⌥H の検索欄から開く）。
- 1.2.0（build 6, 2026-10-16）：表の操作の固定キーを追加。⌃I・⌃K で選択に応じて行か列を挿入・削除（Excel・Googleスプレッドシート）、⇧⌘E でセルを中央揃え（Excel）、⌥⌘P でピボットテーブル・⌃F で交互の背景色・⌃⇧F でフィルターを作成（Googleスプレッドシート）。設定の「ホットキー」で個別にオン・オフ。
- 1.1.2（build 5, 2026-10-14）：設定のショートカットの表示が狭く、⌃⌥⇧⌘ を含むキーが切れていたのを修正（文字の幅に合わせて広がる。全アプリで統一）。
- 1.1.1（build 4, 2026-10-13）：現行版。一時停止を設定から外し、メニューバーのメニューだけに。これより前の履歴は記録なし。
