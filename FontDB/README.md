# FontDB

FontSwitcher 向けのフォントのデータベースと、それを探せる公開ページ。モリサワ・フォントワークス・Adobe・フロップデザインを収録する。

取得したページ（`cache/`）・公式資料（`sources/`）・組み立てたデータ（`data/`、`site/fonts.json`）はリポジトリに入れていない。手元で次の手順で作る。

## 作り方

| 手順 | コマンド |
|---|---|
| モリサワの書体見本を取得 | `python3 -I tools/crawl_morisawa.py cache/morisawa 1 4000` |
| ほかのサイトのページを取得 | `python3 -I tools/crawl_pages.py <サイト> <パス一覧> <保存先>` |
| フォントファイルから名前を読む | `swift tools/read_fonts.swift <フォルダー> > sources/<名前>.jsonl` |
| モリサワ | `python3 -I tools/build_morisawa.py cache/morisawa data --tsv sources/morisawa_release_designer.tsv --fontlist "sources/Morisawa Fonts_Fontlist_202610.xlsx"` |
| フォントワークス | `python3 -I tools/build_fontworks.py cache/fontworks/pages data sources/fontworks_releasenote.html` |
| Adobe | `python3 -I tools/build_adobe.py cache/adobe/pages data` |
| フロップデザイン | `python3 -I tools/build_flopdesign.py cache/flopdesign/pages data sources/flopdesign_files.jsonl` |
| まとめ | `python3 -I tools/build_all.py data site/fonts.json <更新日>` |

`build_all.py` が `data/fonts.sqlite`（`fonts`：1書体1行、`files`：PostScript名ごとに1行）と公開ページ用の `site/fonts.json` を書き出す。公開ページの `site/fonts.json` には説明文と見本画像を入れず、各社の公式ページへリンクする。

## 出典

- モリサワ：書体見本（morisawa.co.jp/fonts/specimen）、Morisawa Fonts のフォントリスト（Excel）、発売日・作者はプレスリリースなどの公開情報
- フォントワークス：書体ページ（fontworks.co.jp/fontsearch）、製品リリースノート
- Adobe：Adobe Fonts の Adobe Originals（fonts.adobe.com/foundries/adobe）。発売日は Adobe Fonts での公開日
- フロップデザイン：書体ページ・販売ページ（flopdesign.com）、製品版のフォントファイル
