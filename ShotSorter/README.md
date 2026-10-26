# ShotSorter

新しいスクリーンショットの名前を変え、選んだ範囲の文字を読み取るAppKit/SwiftUIアプリ。Apple Silicon / macOS 13以降。

- スクリーンショット：複数のウォッチフォルダーに加わったPNGを、設定の命名ルールで改名。メインウインドウへのPNGのドロップでも実行できます。同名ファイルは上書きしません。
- Visionで読み取った文字をFinderのコメントとクリップボードへ出力（個別にON/OFF）。文字がないときはクリップボードを保持します。複数処理では最後に完了した画像の文字をコピーします。
- 文字認識：⌘⇧1（設定で変更）で範囲を選んで読み取ります。設定の「Vision後の整形ルール」で日本語の空白除去・括弧の全角化を個別に選択。改行は保持し、コメントとクリップボードに同じ整形を適用します。
- ⌃⌥S でメインウインドウを呼び出す。

Keyboard Maestroの「Hazelからの移行」グループの「スクショをリネーム」と、「OCR」グループ（Live Text のショートカット）を元にした。ダウンロードの振り分けは FileSorter に分けた。

## しくみ

- フォルダーの監視は `DispatchSource.makeFileSystemObjectSource`（kqueue）。変化があったときだけ一覧を比べ、新しいファイルは大きさが0.8秒変わらなくなってから処理する。起動前からあったファイルは処理しない。自分が付けた名前は再処理しない。
- 文字の読み取りは `VNRecognizeTextRequest`（accurate、ja-JP・en-US）。範囲の撮影は `/usr/sbin/screencapture -i -x`（画面収録の許可が必要。`CGPreflightScreenCaptureAccess` で確かめ、要求は利用者の操作時だけ）。
- Finderのコメントは Finder への Apple Event（初回にオートメーションの確認）。使えないときは `com.apple.metadata:kMDItemFinderComment` にだけ書く（Spotlight用）。
- 外部通信なし（更新確認を除く。配信先は未設定）。

## ビルド・テスト

```
./test.sh            # 名前・フォルダー移行・改行保持・文字の後処理の単体テスト＋4言語の翻訳検証
./test-engine.sh     # 一時フォルダーで複数監視・ドロップ・Vision・コピーを検証
./build.sh           # build/ShotSorter.app
./build.sh --deploy  # /Applications と Latest Builds へ配置
Assets/make-icon.sh  # アイコンを作り直す
```

## 更新履歴

### 1.1.0（build 3、2026-10-27、通常版）

- 複数フォルダー監視、PNGドロップ命名、OCR文字のクリップボード出力を追加。
- QRCode専用命名を削除。整形設定を設定画面へ移し、改行を保持。範囲OCRの初期ホットキーを⌘⇧1へ変更。
- 公証・配布は別工程。

### 1.0.0（build 1、2026-10-26）

- 最初の版。


## 2026-10-26：解説記事リンク（1.0.1／build 2）

- 設定「情報」の解説記事リンクを https://note.com/swwwitch/n/n986d53b12004 に設定。
