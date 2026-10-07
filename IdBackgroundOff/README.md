# IdBackgroundOff

macOS 13以降 / Apple Silicon向けのネイティブアプリ。InDesignのアプリ内 `Contents/MacOS` に空ファイル `DisableAsyncExports.txt` を配置・削除し、PDFなどの「バックグラウンド書き出し／保存」をオフ／元に戻します。

参考：[InDesignのバックグラウンド処理をOFFにする（note）](https://note.com/dtp_tranist/n/nf94bf905c478)

- `/Applications`・`~/Applications`（`Adobe InDesign 20xx/Adobe InDesign 20xx.app`）とLaunch Servicesから検出。Bundle ID `com.adobe.InDesign` だけを対象にし、InDesign Serverは除外。ほかの場所は「InDesignを追加…」（⌘O）。
- バージョンごとに状態（オフ／オン（標準）／確認不可）、起動中の表示。行ごとの「オフにする」「元に戻す」と「すべてオフにする」。
- 書き込み不可の場所（通常のインストール）はmacOSの管理者認証（`do shell script … with administrator privileges`）で1回にまとめて実行。書き込める場所はパスワードなしで変更。
- 実行直前に状態を再確認。同名のフォルダ・シンボリックリンクがある場合は「確認不可」とし、変更しない。パスはシングルクォートで固定し、`…/.app/Contents/MacOS/DisableAsyncExports.txt` 以外は拒否。
- アプリに戻るたびに再読み込み（⌘R）。InDesignのアップデートでファイルが消えた場合も表示に反映。
- 常駐しません。ウインドウを閉じると終了（メニューバーアイコンを表示している間は終了しない）。設定画面はありません。
- 4言語（日本語・英語・簡体字中国語・韓国語）の表示とオフラインヘルプ（⌘?）。外部通信なし。

## 開発

```sh
./build.sh   # build/IdBackgroundOff.app
./test.sh    # 一時フォルダの疑似InDesignで検出・配置・削除・パスの引用を検証
```

文字列・ヘルプ・Info.plistは `make-resources.py`、アイコンは `Assets/make-icon.sh`（`GenerateIcon.swift`）から再生成します。共有の `AppHeader.swift`・`AppSurface.swift` をビルド時に参照します。

## 制限・復元

反映はInDesignの次回起動から。毎年のメジャーバージョンは別フォルダに入るので、新しいバージョンは改めてオフにします。

アプリを使わずに戻すには、InDesignの「パッケージの内容を表示」→ Contents → MacOS の `DisableAsyncExports.txt` を削除します。

このビルドはローカル利用向けのad-hoc署名です。Developer ID署名・公証・更新配信先は未設定です。

## 更新履歴

### 1.0.9（build 10）

- ウインドウメニューの「しまう」からホットキー⌘Mを外した。

### 1.0.8（build 9）

- メニューバーアイコンのメニューから「設定…」を削除（設定画面が無いため）。
- 中国語・韓国語のメニュー表記をmacOSの標準訳語にそろえた（关于／拷贝、에 관하여／오려두기／복사하기）。

### 1.0.7（build 8）

- 編集メニューに「やり直す」（⇧⌘Z）を追加。
- 「ウインドウ」メニューを追加（「しまう」⌘M・「拡大／縮小」・「すべてを手前に移動」とウインドウの一覧）。
- 共通の更新機能（Shared/Updater、Sparkle）を組み込み、アプリメニューに「アップデートを確認…」「アップデートを自動確認」を配置。更新先と署名鍵が未設定の間は「準備中」と表示し、通信しない。従来の仮の「アップデートを確認…」は削除。
- 共通のメニューバーアイコン（MenuBarPresence）を追加。アプリメニューの「メニューバー設定…」で表示を選べる（初期値オフ）。アイコンを表示している間は、ウインドウを閉じても終了しない（非表示なら従来どおり終了）。

### 1.0.6（build 7）

- メニューを共通構成にそろえた（アプリメニューに「サービス」「IdBackgroundOffを隠す」「ほかを隠す」「すべてを表示」を追加。ファイルメニューの「閉じる」を「ウインドウを閉じる」に改名。ヘルプメニューに「note記事を開く」を追加し、サポートマガジンを開く）。

### 1.0.5（build 6）

- ファイルメニューに「メインウインドウを開く」（⌘0）を追加。最小化したり隠したりしたメインウインドウを前面に再表示できる。

### 1.0.4（build 5）

見出しと状態表示の文言を「バックグラウンド書き出し／保存」に変更（日本語。例：「InDesignの「バックグラウンド書き出し／保存」をオフ」）。

### 1.0.3（build 4）

- アプリ名を IdAsyncOff から IdBackgroundOff に変更。Bundle ID（`local.takano.IdAsyncOff`）は保持し、手動追加したInDesignの一覧を引き継ぎます。

### 1.0.2（build 3）

- アイコンの書類に「Id」を入れました。

### 1.0.1（build 2）

- 見出しの補足説明が選択状態になり、背景が青く表示される問題を修正。

### 1.0.0（build 1）

- 初版。
