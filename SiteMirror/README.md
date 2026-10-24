# SiteMirror

URLを指定したWebサイトのページをたどり、HTML・CSS・JavaScript・画像・フォントを保存して、リンクを相対パスに書き換えるユーティリティです（SiteSucker や `wget --mirror --convert-links` と同じ用途）。

- 開始URLと同じホスト（www. の有無・http/https は同じとみなす）のページをたどる
- ページの表示に必要なファイルは、ほかのドメイン（CDN など）にあっても保存する（設定でオフにできる）
- 保存先の中に `<ホスト名>` フォルダーを作り、元のパス構成で置く。ほかのドメインのファイルは `_hosts/<ホスト名>/`。同名フォルダーがあれば番号を付けて上書きしない
- 取得が終わってから、保存した HTML・CSS のリンクを相対パスに書き換える。保存しなかったファイルへの相対リンクは元の絶対URLにする。中止しても保存済みの分は書き換える
- 設定：ほかのドメインの素材、サブドメイン、開始URLのフォルダーより上をたどらない、robots.txt、たどる深さ、ファイル数の上限、同時接続数

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
- 非サンドボックスのアプリでも ATS が効くため、Info.plist の `NSAllowsArbitraryLoads` で http のサイトを許可している。

## 更新履歴

- 1.0.0（build 1）2026-10-24：初版。ページのたどり・素材の保存（ほかのドメインを含む）・相対リンクへの書き換え、robots.txt、たどる深さ・ファイル数・同時接続数の設定、中止と終了時の確認。sw_app の共通仕様（メニュー構成・設定・設定の共有・ヘルプ・常駐・4言語・更新機能の準備中表示・マスタードのアイコン）を適用。
