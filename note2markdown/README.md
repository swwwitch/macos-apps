# note2markdown

macOS 13以降 / Intel・Apple Silicon対応（Universal）のネイティブアプリ。note記事のURLを入力すると、その記事をMarkdownファイルに書き出します。記事のタイトルは見出し1（`# `）になります。

- 取得元：noteの公開API `https://note.com/api/v3/notes/<記事キー>`（`name`＝タイトル、`body`＝本文HTML）。ブラウザーやPandocは使わない。URLは `https://note.com/<ユーザー名>/n/<記事キー>`、独自ドメインの `…/n/<記事キー>`、記事キーだけのいずれでもよい。
- 変換：Keyboard Maestroのマクロ「Markdown整形（Google Chrome）」（`Reference/`）の整形内容をSwiftで実装。本文HTMLを木構造に読み込んで変換する（`Source/NoteMarkdown.swift`）。
  - 見出し・段落・太字・斜体・取り消し線・リンク（リンク内の太字は外す）・箇条書き／番号付きリスト（入れ子可）・引用・コードブロック・区切り線。段落内の `<br>` は行末スペース2つの改行。目次（`<table-of-contents>`）と空段落は書き出さない。
  - 画像：`![画像](URL)`。キャプションがあれば代替テキストに。`assets.st-note.com` のURLからサイズ指定（`?width=…`）を外す。
  - 埋め込み：note記事 `- [記事タイトル](URL)`（タイトルはAPIで取得、設定でオフにすると「note記事へのリンク」）、X `- [Twitter（現「X」）リンク](URL)`、外部記事 `- [ページタイトル](URL)`、添付ファイル `- [ファイル名](URL)`、YouTubeはURLだけの行、そのほか（gist・GitHub等）は `- <URL>`。
  - キーワード：APIの `hashtag_notes` を末尾の区切り線（`---`）と `## キーワード` の下に `` `#Mac #macOS` `` のように半角スペース区切りの1行で書き出す。
  - 本文中の `*`・`_`・`<` など書式記号になる文字はエスケープ。著者が本文に書いた `` `コード` `` の組はそのままコードとして残す。
- 入力のほか2通り：「ブラウザーから」（⌘L）で最前面のブラウザー（Safari・Chrome・Firefox・Edge・Brave・Arc・Vivaldi・Opera・ChatGPT Atlas）の表示中のURLを読み込む（アクセシビリティAPIでウインドウのAXWebAreaのAXURLを読む。アクセシビリティの許可が必要、AppleScriptは使わない）。アドレスバーのファビコンやリンクをウインドウへドラッグ＆ドロップしても読み込む（許可不要）。エディターのURL（editor.note.com/notes/<記事キー>/edit）も記事キーを取り出す。
- 有料記事は無料部分だけ（APIが返す範囲）。オプション「ログインして有料部分も読み込む」（設定の「アカウント」タブ、初期値オフ、Macごと）をオンにしてアプリ内でnoteにログインすると、自分の記事・購入済みの記事は有料部分まで読み込む（`Source/NoteLogin.swift`：WKWebViewで https://note.com/login を開き、WebKitの既定の保存領域に残ったnote.comのクッキーをAPIの要求に付ける。ブラウザーのログインは使わない。「ログアウト」でnote.comのWebサイトデータを消去）。非公開・下書き・メンバー限定は読み込めない（エラー表示）。
- サイトをエクスポート（`Source/SiteExport.swift`、ログイン中だけ設定の「アカウント」タブに表示）：`/api/v2/current_user` でログインしたアカウントのurlnameを取り、`/api/v2/creators/<urlname>/contents?kind=note&page=N` で公開中のテキスト記事を列挙、1件ずつAPI（クッキー付き）で読んで書き出しフォルダーに `<記事キー>.md`（同名は置き換え）。画像は「note内の画像を参照」（URLのまま）／「ローカルにダウンロードして再リンク」（`images/<記事キー>/` に保存し相対リンク、失敗した画像はURLのまま）。要求の間に0.2秒あける。設定はMacごと（siteExportFolder・siteExportDownloadImages）。
- 書き出し：「書き出す…」ボタンのメニューで「保存のみ」「◯◯で開く」（設定「出力」タブの「Markdownエディター」：デフォルト＝.mdの既定のアプリ／指定したアプリ。`editorPath`、Macごと）「MarkdownKitchenに送る」（`jp.dtp-transit.markdownkitchen` で保存したファイルを開く。インストールされていて、エディターに指定していないときだけ表示）を選ぶ。ファイルメニューは⌘S（保存のみ）・⌥⌘S（◯◯で開く）・「MarkdownKitchenに送る…」。保存パネルでファイル名＝タイトル（`/` `:` などは `_`）または記事キー（設定「出力」タブの「ファイル名」、`fileNameByKey`、設定の共有の対象）＋`.md`、UTF-8。前回の保存先フォルダーを記憶。同名ファイルの置き換えは保存パネルが確認する。クリップボードへのコピーも可。
- ウインドウを閉じても常駐（設定で変更可、初期値オン）。ログイン時に起動（初期値オフ）・起動時にメインウインドウを表示しない（初期値オフ）・メニューバー表示（初期値オフ）。⌘Returnで読み込み、⌘,で設定、⌘?でヘルプ。
- 設定の「設定の共有」タブ（共通部品 Shared/SettingsSync）：「出力」タブの設定（fetchEmbedTitles・fileNameByKey）を `note2markdown-Settings.plist` に書き出し・読み込み、iCloud Drive・Dropbox などのフォルダーで同期。最後の保存先・ログイン起動・常駐・メニューバーはMacごと。
- 4言語（日本語・英語・簡体字中国語・韓国語）。アクセシビリティの許可状態は設定の「起動・常駐」タブに表示。通信先はnote.comだけ。ログイン情報・クッキーは、オプションがオフ（初期値）なら送らず、オンならアプリ内でログインしたnoteのクッキーだけをnote.comへ送る。パスワードはアプリで扱わない。

## 開発

```sh
./build.sh   # build/note2markdown.app（SKIP_DEPLOY=1 で配置を省略）
./test.sh    # URL解析・ファイル名・APIの応答・HTML→Markdown変換の単体テスト（オフライン）
```

文字列・ヘルプ・Info.plistは `make-resources.py`、アイコンは `Assets/make-icon.sh`（`GenerateIcon.swift`）から再生成します。共有の `AppHeader.swift`・`AppSurface.swift`・`StartupWindow.swift`・`HelpDocument.swift`・`SettingsSection.swift`・`AboutSection.swift`・`LoginAtLaunch.swift`・`SettingsSync.swift` をビルド時に参照します。`MenuBarPresence.swift`・`UpdateSupport.swift` は共通部品のコピーです（`Shared/MenuBarPresence/sync.py`・`Shared/Updater/prepare.py` に登録済み）。

## 制限

noteの公開APIは非公式で、仕様が変わると読み込めなくなることがあります。画像は書き出さず、URLで参照します。

このビルドはローカル利用向けに証明書（PL9S9PXX96）で署名しています。Developer ID署名・公証・更新配信先は未設定です。ヘルプメニューの「note記事を開く」と設定の「情報」タブは紹介記事（SWNoteArticleURL、https://note.com/swwwitch/n/n003d1941c652）を開きます。

## 更新履歴

### 1.2.0（build 9、2026-10-19）

- 「サイトをエクスポート」を追加（ログイン中、設定の「アカウント」タブ）。ログインしたアカウントの公開中の記事をすべて記事キー.mdで書き出す。画像はnoteを参照／ダウンロードして再リンク。
- 設定の「出力」タブに「ファイル名」（タイトル／記事キー）を追加。
- 「書き出す…」をメニューにし、「保存のみ」「◯◯で開く」「MarkdownKitchenに送る」を選べるようにした。開くアプリは設定の「出力」タブの「Markdownエディター」で指定（デフォルトは.mdの既定のアプリ）。
- オプション「ログインして有料部分も読み込む」を追加（設定の「アカウント」タブ、初期値オフ）。アプリ内でnoteにログインすると、自分の記事・購入済みの記事は有料部分まで書き出す。
- キーワードの行をコード（`` `#Mac #macOS` ``）で書き出すようにした。

### 1.1.6（build 8、2026-10-19）

- 記事のキーワード（ハッシュタグ）を末尾の「## キーワード」の下に1行で書き出すようにした。

### 1.1.5（build 7、2026-10-17）

- メインウインドウのアイコンの下にバージョンとbuild番号を表示。

### 1.1.4（build 6、2026-10-17）

- 「起動時にメインウインドウを表示しない」が二重に表示されていたのを1つにした。アクセシビリティを共通部品（AccessibilitySection）にし、未許可のときの文言を共通の文言にそろえた。常駐の表記を「ウインドウを閉じても常駐」にそろえ、共通部品（設定の共有）の更新を取り込んだ。

### 1.1.3（build 5、2026-10-16）

- 設定に「設定の共有」タブを追加（書き出し・読み込みと、iCloud Drive・Dropboxなどでの同期。「出力」タブの設定が対象）。
- 紹介記事（SWNoteArticleURL）を設定し、「note記事を開く」と「情報」タブから開けるようにした。

### 1.1.2（build 4、2026-10-15）

- 「読み込む」ボタンをなくし、⌘Return（ファイルメニュー「記事を読み込む」）で読み込むようにした。入力欄のReturnでも読み込む。読み込み中だけ「キャンセル」ボタンを表示。

### 1.1.1（build 3、2026-10-15）

- URLの入力欄に消去ボタン（×）を追加。

### 1.1.0（build 2、2026-10-15）

- 「ブラウザーから」（⌘L）：最前面のブラウザーで表示中のnote記事を読み込む（アクセシビリティの許可が必要）。
- ブラウザーのアドレスバーのファビコンやリンクのドラッグ＆ドロップで読み込む。
- noteエディターのURLから記事キーを取り出す。

### 1.0.0（build 1、2026-10-15）

- 初版。
