# ShotSorter

新しいスクリーンショットの名前を変え、選んだ範囲の文字を読み取るAppKit/SwiftUIアプリ。Apple Silicon / macOS 13以降。

- スクリーンショット：指定フォルダー（初期値はmacOSのスクリーンショットの保存先）に加わったPNGのうち、名前に「ss-」を含まないものを `ss-{width}-{height}-{dpi}-{date}.png`（形式は変更可）に改名。画像の文字（日本語・英語）をVisionで読み取ってFinderのコメントに入れる。読み取った文字が「QRCode #sw-（8桁）」で始まる画像は `CommentScreen-QRCode-（8桁）.png`。
- 文字認識：⌃⌥O（設定で変更）で範囲を選ぶと、Visionで読み取りクリップボードへコピーし、画面右上に表示。日本語の間の空白・改行を詰める、半角の( )を全角にする（どちらも選べる）。
- ⌃⌥S でメインウインドウを呼び出す。

Keyboard Maestroの「Hazelからの移行」グループの「スクショをリネーム」と、「OCR」グループ（Live Text のショートカット）を元にした。ダウンロードの振り分けは FileSorter に分けた。

## しくみ

- フォルダーの監視は `DispatchSource.makeFileSystemObjectSource`（kqueue）。変化があったときだけ一覧を比べ、新しいファイルは大きさが0.8秒変わらなくなってから処理する。起動前からあったファイルは処理しない。自分が付けた名前は再処理しない。
- 文字の読み取りは `VNRecognizeTextRequest`（accurate、ja-JP・en-US）。範囲の撮影は `/usr/sbin/screencapture -i -x`（画面収録の許可が必要。`CGPreflightScreenCaptureAccess` で確かめ、要求は利用者の操作時だけ）。
- Finderのコメントは Finder への Apple Event（初回にオートメーションの確認）。使えないときは `com.apple.metadata:kMDItemFinderComment` にだけ書く（Spotlight用）。
- 外部通信なし（更新確認を除く。配信先は未設定）。

## ビルド・テスト

```
./test.sh            # 名前・QRCode・文字の後処理の単体テスト＋4言語の翻訳検証
./build.sh           # build/ShotSorter.app
./build.sh --deploy  # /Applications と Latest Builds へ配置
Assets/make-icon.sh  # アイコンを作り直す
```

## 更新履歴

### 1.0.0（build 1、2026-10-26）

- 最初の版。


## 2026-10-26：解説記事リンク（1.0.1／build 2）

- 設定「情報」の解説記事リンクを https://note.com/swwwitch/n/n986d53b12004 に設定。
