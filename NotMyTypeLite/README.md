# NotMyTypeLite

現行版：**1.2.0（build 3）** — 2026-10-25

NotMyType の簡易版。フォントファイルをライブラリに登録し、必要なときだけアクティブにします。ユニバーサル版（Apple Silicon・Intel）。Bundle ID は `jp.dtp-transit.notmytypelite`。ライブラリ・設定・共有ファイルは NotMyType と別です。

- 追加：フォントファイル・フォルダーのドロップか「追加…」。ファイルはコピー・移動せず場所だけを覚える。セットを選んでいるときのドロップはそのセットにも入れる
- アクティブ／解除：ファミリー・書体ごとのチェックボックス、選んだものをまとめて。`CTFontManagerRegisterFontsForURL` の `.session`。起動時に前回アクティブだったものを戻す（設定）
- サイドバー：ライブラリ（すべて・重複・見つからない・Adobe Fonts）・システム（ユーザー名・All Users・System。常に読み込む、設定なし）・スマートセット（お気に入り・アクティブ・最近…・日本語をサポート・自作の条件）・セット
- プレビュー：1行・複数行・ウォーターフォール、配色・不透明度・カーニング・トラッキング、表示する情報の切り替え、字形の一覧
- 検索オプション：文字セット・形式・種類・UD・AP版・新ゴ・ファミリーの書体数・収録文字数（N・UD などはフォント名から判定）
- 重複：ウォッチフォルダーの順、重複フォントを解決（カード・フォルダーの規則・この組だけ）、ファイルの中身で決める条件（形式・バージョン・字形数・中身が同じ）、優先外の一括処理、選んだフォントを優先
- 衝突：衝突しているフォントの登録を外す、アクティブにできなかったときの「強制的にアクティブにする」
- ウォッチフォルダー（子フォルダーは親のすぐ上・字下げ）、ライブラリの再構築、フォントキャッシュの消去（システム・アプリ）、進み具合のパネル
- ライブラリの共有（Dropbox などの `NotMyTypeLite-Library.json`）と設定の同期（`NotMyTypeLite-Settings.sync`）
- メニューのホットキー、アプリを呼び出すホットキー、フォントファイルを開くアプリ

NotMyType から外したもの：プロジェクト、コレクション、ベンダー、サイドバーの種類と表示・並び順の設定、公式の情報（FontDB。同梱しない＝検索オプションの分類・発売年代も無し）、フォントを点検、フォントを統一（Illustrator・InDesign）、FontExplorer X Pro の読み込み、フォント管理のリンク、Adobe アプリの自動アクティベート。

## ビルド

```sh
./build.sh            # ビルド（arm64＋x86_64）→ 検証 → /Applications と Latest Builds へ配置
NO_DEPLOY=1 ./build.sh  # 配置せず build/ にだけ作る
```

- ソースは [Sources/NotMyTypeLite](Sources/NotMyTypeLite/)、文字列・ヘルプは [Localizations](Localizations/)（ja / en）。NotMyType 1.52.0（build 81）の写しから機能を外して作った。
- 共通部品は `Tools/sync-shared.py` がビルド時に Shared から写す。
- 画面の文字列を足したら、[Tools/translations.tsv](Tools/translations.tsv) に訳を加えて `python3 Tools/make-strings.py` で Localizable.strings を作り直す。
- アイコンは [Assets/make-icon.sh](Assets/make-icon.sh)（GenerateIcon.swift から NotMyTypeLite.png・.icns を生成）。NotMyType と同じ「あa」のカードの下に小さく「Lite」。

## 更新履歴

- 1.2.0（build 3）：アイコンに小さく「Lite」を入れた（カードの下、Georgia Bold Italic）
- 1.1.0（build 2）：サイドバーの「システム」（ユーザー名・All Users・System）を復活。フォントフォルダーは設定なしで常に一覧に入れる（ユーザー指定）
- 1.0.0（build 1）：NotMyType 1.52.0 を元に作成。
