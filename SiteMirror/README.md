# SiteMirror

URLを指定したWebサイトのページをたどり、HTML・CSS・JavaScript・画像・フォントを保存して、リンクを相対パスに書き換えるユーティリティです（SiteSucker や `wget --mirror --convert-links` と同じ用途）。

- 開始URLと同じホスト（www. の有無・http/https は同じとみなす）のページをたどる
- ページの表示に必要なファイルは、ほかのドメイン（CDN など）にあっても保存する（設定でオフにできる）
- 保存先の中に `<ホスト名>` フォルダーを作り、元のパス構成で置く。ほかのドメインのファイルは `_hosts/<ホスト名>/`。同じサイトのフォルダーがあれば「上書き／別のフォルダーに保存」を確かめる（上書きでも今回取らなかったファイルは消さない）
- 取り込みフォルダーに `SiteMirror-log.txt`（日時・件数、失敗・除外したURL・理由・参照元をタブ区切り）を残す
- 取得が終わってから、保存した HTML・CSS のリンクを相対パスに書き換える。保存しなかったファイルへの相対リンクは元の絶対URLにする。中止しても保存済みの分は書き換える
- 設定：ほかのドメインの素材、サブドメイン、開始URLのフォルダーより上をたどらない、robots.txt、取り込まないURL（* 可）、たどる深さ、ファイル数の上限、同時接続数、取得の間隔、再試行、変わっていないファイルを取り直さない
- 「ログイン…」でアプリ内のブラウザー（WKWebView）を開いてログインし、その Cookie と Basic 認証で取り込む。ログイン中はログアウトのリンクをたどらない
- 「リンクを調べる」で、保存せずリンク切れだけを調べ、保存先に報告（`<ホスト名>-linkcheck-<日時>.txt`）を書く
- 設定：取り込むURL（ページだけに適用）、sitemap.xml のページ、JavaScript の中の URL（推測）、取らない種類（拡張子・Content-Type）、1ファイル・合計の大きさの上限、サイトから消えたファイルをゴミ箱に入れる
- 中止した取り込みは、同じフォルダーに取り込むときに「続きから取り込む」を選べる

通信は指定したサイトとその素材の置き場所だけです（アップデート確認を除く）。アクセシビリティの許可は不要です。

## ビルド

```sh
./build.sh            # ビルド → 検証 → /Applications と Latest Builds へ配置
NO_DEPLOY=1 ./build.sh  # 配置せず build/ にだけ作る
```

- SwiftPM（`Package.swift`）。ソースは [Sources/SiteMirror](Sources/SiteMirror/)、文字列・ヘルプは [Localizations](Localizations/)（ja / en / zh-Hans / ko）。
- 共通部品（AboutSection・AppSurface・StartupWindow・SettingsSection・HelpDocument・MenuBarPresence・LoginAtLaunch・SettingsSync・UpdateSupport）は各 `sync` スクリプトがビルド時に上書きするので、直接編集しない。
- 画面の文字列を足したら、[Tools/translations.tsv](Tools/translations.tsv) に訳を加えて `python3 Tools/make-strings.py` で Localizable.strings を作り直す（訳の無いキー・使わないキーがあると止まる）。
- アイコンは [Assets/make-icon.sh](Assets/make-icon.sh)（GenerateIcon.swift から .icns を生成）。

## 実装メモ

- [SiteLinks.swift](Sources/SiteMirror/SiteLinks.swift)：HTML・CSS の中の URL を、文書の文字列（UTF-16）の範囲付きで拾う。依存ライブラリは使わず正規表現で読む。コメントと `<script>` の中は飛ばし、`<style>` と style 属性は CSS として読む。srcset は候補ごとに範囲を出す。AppKit に依存しないので、ハーネスに組み込んで単体で試せる。
- [Crawler.swift](Sources/SiteMirror/Crawler.swift)：取得は TaskGroup で同時接続数まで並べ、結果の処理（保存先の決定・リンクの追加）は1つのタスクの中で順に行う。保存先は Content-Type を見てから決める（`/about` が HTML なら `about.html`）ので、リンクの書き換えは全部取り終えてから行う。転送元と転送先の両方の URL を同じファイルに結び付ける。
- 文字コードは HTTP ヘッダー → `<meta charset>`／`@charset` → UTF-8 の順で読み、どれでも読めなければ ISO Latin 1 で読む（バイトをそのまま保てるので、書き換えた ASCII 以外は元のまま書き戻せる）。
- 書き換えた CSS は SRI のハッシュと合わなくなるので `integrity` を、file:// で CORS の読み込みに失敗しないよう `crossorigin` を取り除く。
- ログインの Cookie は `WKWebsiteDataStore.default()` から読み、サイトのドメイン（親・子を含む）のものだけを取り込みのセッション（ephemeral）に入れる。Basic 認証は WKWebView の認証の問い合わせで名前とパスワードを尋ね、起動中だけ覚えて `AuthDelegate` で答える。
- 取得は `URLSession.bytes(for:)` で行う。`data(for:)` ではタスク別・セッションのデリゲートどちらの `didReceive response` も呼ばれず（2026-10-24 実測）、ヘッダーの時点で打ち切れないため。50MB を 0.8 秒で読めた。
- 続きから取り込むときは、中止の時点で書き換え済みの HTML も読み直す。書き換え済みの相対リンクがフォルダーの中のファイルを指していれば、そのまま残す（`existsLocally`）。
- 取得の間隔は、取得の結果と同じ TaskGroup に「眠るだけのタスク」（結果は nil）を入れて待つ。待つあいだも結果の処理は止まらない。
- 非サンドボックスのアプリでも ATS が効くため、Info.plist の `NSAllowsArbitraryLoads` で http のサイトを許可している。

## 更新履歴

- 1.3.0（build 5）2026-10-24：HTTrack の機能のうち、上書き時にサイトから消えたファイル（どこからもリンクされない・404・410）をゴミ箱に入れる、取らない種類と1ファイル・合計の大きさの上限、取り込むURL（ページだけ）、中止した取り込みの続き（`.sitemirror-resume.json`。取得中だったものも続きに回す）、sitemap.xml、JavaScript の中の URL（推測）を追加。取得は `bytes(for:)` にして、応答のヘッダーで大きさ・種類を見て中身を読まずに打ち切る。
- 1.2.0（build 4）2026-10-24：wget の機能のうち、失敗時の再試行（タイムアウト・接続の失敗・429・5xx、1→2→4秒待つ）、取得の間隔（0.5〜1.5倍に揺らす）、取り込まないURL、変わっていないファイルを取り直さない（上書き時、`.sitemirror.json` の ETag・Last-Modified で条件付きリクエスト。HTMLとCSSは書き換え済みなので毎回取り直す。前回と同じURLは同じファイル名に保存）を追加。保存せずリンク切れだけを調べる「リンクを調べる」（ほかのサイトへのリンクも HEAD で確かめ、断られたら GET）と、ログインが必要なサイトのための「ログイン…」（アプリ内ブラウザーの Cookie と Basic 認証を使う）を追加。
- 1.1.0（build 3）2026-10-24：同じサイトのフォルダーがあるとき（保存先にそのフォルダー自体を選んだときも）、「上書き」「別のフォルダーに保存」を選べるようにした（これまでは常に番号付きの別フォルダー）。上書きでは今回取り込まなかったファイルを消さない。取り込みフォルダーに `SiteMirror-log.txt` を書き、失敗・除外したURLと理由・参照元を残す。「記録を開く」ボタンとメニューを追加。
- 1.0.1（build 2）2026-10-24：一覧の上に「すべて／失敗／除外」の切り替え（件数付き）を追加し、保存できなかったURLと理由だけを表示できるようにした。行の複数選択と⌘C・右クリックの「URLをコピー」「URLと理由をコピー」、保存した行の「Finderで表示」を追加。
- 1.0.0（build 1）2026-10-24：初版。ページのたどり・素材の保存（ほかのドメインを含む）・相対リンクへの書き換え、robots.txt、たどる深さ・ファイル数・同時接続数の設定、中止と終了時の確認。sw_app の共通仕様（メニュー構成・設定・設定の共有・ヘルプ・常駐・4言語・更新機能の準備中表示・マスタードのアイコン）を適用。
