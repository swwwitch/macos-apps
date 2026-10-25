# MenuShot

メニューバーと開いたメニューだけを、背景（デスクトップ・ほかのウインドウ）なしで1枚のPNGに撮るAppKit/SwiftUIアプリ。Apple Silicon / macOS 14以降。

- ［N秒後に撮影］（初期値3秒、0〜10秒）を押し、数えている間にメニューを開く。メニューバーのアイコンのメニューからも始められる。
- メニューを開いたまま撮影のホットキー（初期値 ⌃⌥⇧⌘4、設定で変更・無効化）を押すとすぐに撮影。メニューが無いときは秒数を数えてから撮影。
- 写す範囲：メニューバーの左端からメニューの右まで（初期値）／メニューの幅だけ／メニューバー全体。右クリックやポップアップボタンのメニューなど、メニューバーから離れたメニューはメニューだけ。
- メニューの影はアプリが描く（設定でオフ）。メニューの外側は透明。
- 保存先の初期値はmacOSのスクリーンショットと同じ（`com.apple.screencapture location`、無ければデスクトップ）。ファイル名は「メニュー 2026-10-26 2.10.33.png」、同名は番号を付けて上書きしない。クリップボードにもコピー（初期値オン）、撮影の音（初期値オン）。
- 撮った画像はメインウインドウに表示し、ドラッグでほかのアプリへ渡せる。

## しくみ

- 開いているメニューは `kCGPopUpMenuWindowLevel`（101）のウインドウ、メニューバーは 24、右側のステータス項目は 25（macOS 26で実測）。1×1などの小さい101のウインドウ（他アプリの補助）は除く。自分のウインドウ（メニューバーのアイコンのメニュー）も除く。
- ScreenCaptureKit の `SCContentFilter(desktopIndependentWindow:)` でウインドウを1枚ずつ撮り、`Source/Layout.swift` の計画どおりに重ねる。`ignoreShadowsSingleWindow = true` にするとフレームと同じ大きさで撮れる（falseだと影の分だけ縮んで写る）。影は合成時に Core Graphics で描く。
- 画面のフィルター（`SCContentFilter(display:including:)`）でまとめて撮ると、ポップアップボタンのメニューに親ウインドウが一緒に写る（実測）ので使わない。
- メニューの上端がメニューバーの下端から12pt以内なら「メニューバーから開いたメニュー」とみなし、メニューバーを含める。ポインタのあるディスプレイを優先する。
- PNGの解像度は 72×倍率 dpi（Retinaで144）。保存は隠しファイルに書いてから名前を変えるので、途中で失敗しても壊れたファイルは残らない。
- 撮影のたびに、対象にしたウインドウ（階層・PID・Bundle ID・枠、`*`が使ったもの）を `~/Library/Logs/MenuShot/LastCapture.txt` に上書きする（タイトル・画像は含めない）。
- 撮影のホットキーはメニューが開いているかを `CGWindowListCopyWindowInfo`（権限不要）で判定してから撮る。MenuShotを前面にしない（メニューが閉じるため）。
- 権限は「画面収録とシステムオーディオ録音」だけ。確認は `CGPreflightScreenCaptureAccess`、要求（`CGRequestScreenCaptureAccess`）は撮影の操作をしたときだけ。外部通信なし（更新確認を除く。配信先は未設定）。

## ビルド・テスト

```
./test.sh            # 範囲計算の単体テスト＋4言語の翻訳キー・プレースホルダー検証
./build.sh           # build/MenuShot.app
./build.sh --deploy  # 検証後、/Applications と Latest Builds へ配置（Shared/BuildTools/publish_latest.py）
```

## ファイル

- `Source/Layout.swift`：写すウインドウと範囲の計算（画面に依存しない）
- `Source/Capture.swift`：ScreenCaptureKit での撮影・合成・保存・クリップボード
- `Source/main.swift`：主画面・設定・メニュー・ホットキー
- `make-resources.py` / `help_text.py`：4言語の文字列とヘルプを生成
- `Assets/GenerateIcon.swift`：アイコン（マスタード基調、メニューバーから下がるメニューとファインダーの角）

## 更新履歴

### 1.0.1（build 2、2026-10-26）

- 開いたメニューが二重に写ることがあった。メニューと同じ階層（101）にあるほかのアプリのウインドウまで重ねていたため、前面のアプリのメニューだけを使う（前面のアプリにメニューが無いときは、いちばん大きいメニューのアプリ）。
- 撮影ごとに、対象にしたウインドウの一覧（階層・Bundle ID・枠だけ）を `~/Library/Logs/MenuShot/LastCapture.txt` に上書きで残す。
- 撮影のホットキーの初期値を ⌃⌥⇧⌘4 に変更。

### 1.0.0（build 1、2026-10-26）

- 最初の版。
