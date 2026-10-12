# LinkMaker

![macOS](https://img.shields.io/badge/macOS-13%2B-lightgrey) ![version](https://img.shields.io/badge/version-1.2.3-blue) ![license](https://img.shields.io/badge/license-private-lightgrey)

ブラウザーで表示中のページのタイトルとURLを、ホットキーでコピー・ファイル書き出し・開き直しするメニューバー常駐アプリ。Keyboard Maestro のマクログループ「Make Link」「Make Link (misc)」（[Reference](Reference/)）の移植。

- ビルド：`./build.sh`（署名後に /Applications と Latest Builds へ配置）。配置しない確認用は `LINKMAKER_SKIP_PUBLISH=1 ./build.sh`
- テスト：`./test.sh`（URL・タイトルの整形、既定キーとKMマクロのトリガーの一致、4言語の文字列）
- 文字列：`Resources/*.lproj/Localizable.strings`（ヘルプ本文は `helpText`）
- アイコン：`Assets/draw-icon.swift`

## 構成

| ファイル | 内容 |
| --- | --- |
| Sources/LinkRules.swift | タイトル・URLの整形、書式、Amazon、編集モードのURL変換（マクロ「Make Link（エンジン）」） |
| Sources/LinkAction.swift | 機能一覧と既定のホットキー（KMのトリガーと同じ） |
| Sources/Browser.swift | 対象ブラウザー、AXでのURL・タイトル取得、キー送信、タブ一覧（AppleScript） |
| Sources/ActionRunner.swift | 各機能の実行 |
| Sources/LinkFiles.swift | webloc・QRコード（CoreImageでローカル生成） |
| Sources/Model.swift | 設定、ホットキー登録（対象ブラウザーが前面のときだけ） |
| Sources/Palette.swift | パレット（KakkoReplace の BracketPalette と同じ作り。フォーカスを奪わない浮動パネル） |
| Sources/main.swift | 画面・メニュー、パレットの表示制御 |

## 移植の差分

- QRコードは外部API（api.qrserver.com）ではなくMac内で生成。
- 確認ダイアログボックス（1秒で閉じる）は画面上部の短い表示に置き換え（設定でオフ可）。
- 「新規ウインドウで開く」は元のタブを閉じない。Finderタグ（パープル）・Finderコメントの付与、Path Finder対応は省略。
- misc の機能は「選択した文字列から」グループ。どのアプリでも動き、設定の「対象外アプリ」（初期値はKMグループと同じ Illustrator・InDesign・Photoshop・Word）を除く。選択は ⌘C で読み取り、元のクリップボードは戻す。
- 未移植：タブ切り替え・タブを閉じる系、Notion・Biscuit・Notefile専用、カンマ削除ペースト、セル内改行の「"」削除（CellCopyCleaner）、デフォルトブラウザーの変更（BrowserSwitcher）、クリップボードで起動するマクロ（KMで無効）。

## 更新履歴

- 1.2.3（build 6, 2026-10-13）：weblocとQRコードの書き出しをそれぞれ1つにまとめ、押すとマウス位置で書き出し先（デスクトップ／前面のFinderウインドウ／場所を指定）を選ぶ（⌥W・⌥Q）。書き出し先を決めた6機能はホットキー専用（⌥K・⌃⌥⌘W は維持、前面Finder向けの ⌥W・⌥Q は外し、保存済みの同じキーも1回だけ解除）。アソシエイトIDの初期値を cssnite に。

- 1.2.3（build 6, 2026-10-13）：コピーに成功したときの結果で、「〜をコピーしました。」とコピーした内容の間に空行を入れた。
- 1.2.2（build 5, 2026-10-13）：ホットキーの2回押しに対応（DocklessLauncherと同じ方式。1つのキーに1回押しと2回押しの機能を1つずつ）。KMと同じく ⌥A の1回押しで「Amazonリンク」、2回押しで「Amazonリンク（アフィリエイト）」。

- 1.2.1（build 4, 2026-10-13）：「Amazonリンク」（⌥A、常に短縮リンク）と「Amazonリンク（アフィリエイト）」（初期キーなし、アソシエイトIDを使用。未設定なら理由を表示）を別の機能に分けた。

- 1.2.0（build 3, 2026-10-13）：「Make Link (misc)」を移植（選択した文字列のURLを開く・ブラウザー選択・3ブラウザー同時、Google・物書堂で検索、Jina形式、URLのテキストファイル、webloc、ダウンロード元からwebloc）。設定に「対象外アプリ」。パレットは対象外アプリでだけ隠れる。

- 1.1.0（build 2, 2026-10-13）：パレットを追加（⌃⇧⌘K、メニューバー・メインウインドウから表示。設定の「パレット」でキー変更と起動時のパレット表示）。表示名（CFBundleDisplayName）に残っていた旧名「Make Link」を修正。

- 1.0.0（build 1, 2026-10-13）：初版。公開前に「Make Link」から改名（Bundle ID も jp.dtp-transit.makelink → jp.dtp-transit.linkmaker）。
