# note見出し画像の共通テンプレート

KageTrimmerの記事（n9b43fbba5d54）を基準にする。1280×670px、白系背景、左に現行マスタードアイコン、右上に「小さなMacアプリ工房」と黄色い下線、右中央に濃い茶色の太いアプリ名、下に短い機能説明。アプリ名の改行は読みやすい意味単位。アイコン単体拡大・灰色背景・小さすぎる見出しは使わない。render.swiftと ../KageTrimmer.png を基準として、新規と既存の記事に適用する。

## 使い方

生成した画像はこのフォルダではなく `Shared/NoteHeaders/<アプリ名>.png` に置く。

```sh
cd Shared/NoteHeaders/Template
xcrun swift render.swift ../<アプリ名>.png <アイコンPNG> "<アプリ名（|で改行）>" "<短い機能説明>"
```

2026-10-07：画像をテンプレートのフォルダ（旧 KageTrimmer-template）から Shared/NoteHeaders/ 直下へ移動。移動前後のSHA-1一致を確認。
