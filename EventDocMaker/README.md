# EventDocMaker

イベントの表（Excelの「項目⇥値」）から、EventDocフォルダーのテンプレートに値を差し込んで、案内文・メール・告知などの文書をまとめて書き出すAppKit/SwiftUIアプリ。Apple Silicon / macOS 13以降。

- 入力：Excelでコピーした2列の表（［クリップボードから読み込む］⇧⌘V かペースト）。セル内改行の引用符（"…"）、「項目：値」の形にも対応。
- 出力：`<親フォルダー>/<種別小文字・空白なし>-<仮の日付>-<タイトル（abc）>/docs/` に Templates の各ファイル（`%Variable%Event…%` を置換）。`99-stores.txt` のコピー `CeeBeeDee-<仮の日付>-<タイトル（abc）>.txt`、QRコード（配信URL 800px・Doorkeeper・STORES（経費）・アンケート 各500px、余白40px、CoreImageで生成）、最近のイベントのリンク置き場（AT-Recent）へのシンボリックリンク、`42-問い合わせ.txt` と QRコードにパープルのタグ。
- 変数の組み立ては元の手順（日付と曜日、CSS Nite／DTP Transit による差出人・色・フッター・ComingInfo、配信方法による案内文、アーカイブ、ヨガ、売上の合計と3桁区切りなど）をそのまま移した（`Source/Variables.swift`）。
- ⌃⌥E でメインウインドウを呼び出す。

Keyboard Maestroの「____ドキュメント生成」グループ（「キーボードショートカットで実行」→「〓ドキュメント作成のみ4」）を元にした。

## 元の手順から変えたところ

- 表の読み取りを、項目ごとの正規表現ではなくタブ区切り（Excelの引用符つき）として解釈する。プロフィール・セッション概要のような複数行の値も、その項目だけを読む。
- 配信URLからチャットURLを作る置換を順につなげた（元は2つ目の置換が1つ目の結果を上書きし、youtu.be の形は変換されなかった）。
- QRコードは外部のAPI（api.qrserver.com）ではなくMac上で作る。
- 最近のイベントのリンクは `ln -s -f` ではなく、同名の古いリンクだけを置き換えて作る。
- Excelでの列の選択と、Path Finderのサイドバー登録・並び替えは行わない（フォルダーを開くアプリは設定で Path Finder／Finder）。

## ビルド・テスト

```
./test.sh            # 表の解析・変数・トークン・QR・一時フォルダーへの書き出しの単体テスト＋4言語の翻訳検証
./build.sh           # build/EventDocMaker.app
./build.sh --deploy  # /Applications と Latest Builds へ配置
Assets/make-icon.sh  # アイコンを作り直す
```

## 更新履歴

### 1.0.0（build 1、2026-10-26）

- 最初の版。
