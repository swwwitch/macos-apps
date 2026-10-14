# note2markdown

macOS 13以降 / Intel・Apple Silicon対応（Universal）のネイティブアプリ。note記事のURLを入力すると、その記事をMarkdownファイルに書き出します。記事のタイトルは見出し1（`# `）になります。

- 取得元：noteの公開API `https://note.com/api/v3/notes/<記事キー>`（`name`＝タイトル、`body`＝本文HTML）。ブラウザーやPandocは使わない。URLは `https://note.com/<ユーザー名>/n/<記事キー>`、独自ドメインの `…/n/<記事キー>`、記事キーだけのいずれでもよい。
- 変換：Keyboard Maestroのマクロ「Markdown整形（Google Chrome）」（`参考/`）の整形内容をSwiftで実装。本文HTMLを木構造に読み込んで変換する（`Source/NoteMarkdown.swift`）。
  - 見出し・段落・太字・斜体・取り消し線・リンク（リンク内の太字は外す）・箇条書き／番号付きリスト（入れ子可）・引用・コードブロック・区切り線。段落内の `<br>` は行末スペース2つの改行。目次（`<table-of-contents>`）と空段落は書き出さない。
  - 画像：`![画像](URL)`。キャプションがあれば代替テキストに。`assets.st-note.com` のURLからサイズ指定（`?width=…`）を外す。
  - 埋め込み：note記事 `- [記事タイトル](URL)`（タイトルはAPIで取得、設定でオフにすると「note記事へのリンク」）、X `- [Twitter（現「X」）リンク](URL)`、外部記事 `- [ページタイトル](URL)`、添付ファイル `- [ファイル名](URL)`、YouTubeはURLだけの行、そのほか（gist・GitHub等）は `- <URL>`。
  - 本文中の `*`・`_`・`<` など書式記号になる文字はエスケープ。著者が本文に書いた `` `コード` `` の組はそのままコードとして残す。
- 有料記事は無料部分だけ（APIが返す範囲）。非公開・下書き・メンバー限定は読み込めない（エラー表示）。
- 書き出し：保存パネルでファイル名＝タイトル（`/` `:` などは `_`）＋`.md`、UTF-8。前回の保存先フォルダーを記憶。同名ファイルの置き換えは保存パネルが確認する。クリップボードへのコピーも可。
- ウインドウを閉じても終了しない（設定で変更可、初期値オン）。ログイン時に起動（初期値オフ）・起動時にメインウインドウを表示しない（初期値オフ）・メニューバー表示（初期値オフ）。⌘,で設定、⌘?でヘルプ。
- 4言語（日本語・英語・簡体字中国語・韓国語）。通信先はnote.comだけ（ログイン情報・クッキーは送らない）。

## 開発

```sh
./build.sh   # build/note2markdown.app（SKIP_DEPLOY=1 で配置を省略）
./test.sh    # URL解析・ファイル名・APIの応答・HTML→Markdown変換の単体テスト（オフライン）
```

文字列・ヘルプ・Info.plistは `make-resources.py`、アイコンは `Assets/make-icon.sh`（`GenerateIcon.swift`）から再生成します。共有の `AppHeader.swift`・`AppSurface.swift`・`StartupWindow.swift`・`HelpDocument.swift`・`SettingsSection.swift`・`AboutSection.swift`・`LoginAtLaunch.swift` をビルド時に参照します。`MenuBarPresence.swift`・`UpdateSupport.swift` は共通部品のコピーです（`Shared/MenuBarPresence/sync.py`・`Shared/Updater/prepare.py` に登録済み）。

## 制限

noteの公開APIは非公式で、仕様が変わると読み込めなくなることがあります。画像は書き出さず、URLで参照します。

このビルドはローカル利用向けに証明書（PL9S9PXX96）で署名しています。Developer ID署名・公証・更新配信先は未設定です。紹介記事（SWNoteArticleURL）は未設定のため、「note記事を開く」はアプリのまとめページを開きます。

## 更新履歴

### 1.0.0（build 1、2026-10-15）

- 初版。
