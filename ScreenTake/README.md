# ScreenTake

画面（または1つのウインドウ）・システム音声・マイク・カメラを収録し、カット・ズーム・クリック表示・カメラのワイプを付けて MP4／MOV／GIF に書き出す AppKit/SwiftUI アプリ。ScreenFlow の「収録＋簡易編集」に当たる範囲。Apple Silicon / macOS 15以降。

- 収録：画面全体またはウインドウ。システム音声・マイク（機器を選択）・カメラ（機器を選択）・ポインタの表示をオン／オフ。カウントダウン（0〜10秒、初期値3秒）、30／60fps、一時停止・再開。収録中は画面に何も重ねず、メニューバーに経過時間と停止・一時停止のメニュー（MenuBarPresenceのアイコンとは別の項目で、アイコンを隠していても出る）。
- 開始・停止：［収録を開始］、メニューバーのアイコン、ホットキー ⌃⌥⇧⌘6（Keyboard Maestro・他のsw_appと重ならないことを2026-10-26に確認）。
- 編集：プレビュー（書き出しと同じ描画）、タイムライン（サムネイル・ズーム・音声波形）、範囲の削除・前後のトリミング、ズーム（倍率・ポインタ追従／中心指定、始めと終わりは滑らか）、ポインタ（別レイヤー：表示・大きさ・滑らかさ・区間ごとの非表示）、クリック位置の輪、カメラの表示・位置・形・大きさ、システム音声・マイクの音量。⌘Z／⇧⌘Z。編集は自動保存。
- 書き出し：MP4／MOV（収録のまま・2160p・1440p・1080p・720p、H.264またはHEVC）、GIF（横幅・fps）。進捗表示とキャンセル。

## しくみ

- `Source/Recorder.swift`：ScreenCaptureKit の `SCStream` で画面・システム音声・マイク（`captureMicrophone`、macOS 15）を受け、カメラは `AVCaptureSession`。すべて1つの `AVAssetWriter` に書く（トラック順：画面 HEVC、カメラ H.264、システム音声 AAC、マイク AAC）。時刻はホストクロックに揃え、一時停止中のサンプルは捨てて以降を詰める。画面が変わらない間はコマを書かない（`SCFrameStatus.complete` だけ）。ScreenTake のウインドウは収録から外す（`excludingApplications`）。
- ポインタは映像に写さず（`showsCursor = false`）、位置（60Hz）と形（`NSCursor.currentSystem` の画像とホットスポット、`cursors/<番号>.png`）、クリック（グローバルのマウスイベント、権限不要）を記録し、収録の時刻に直して `project.json` に入れる。合成時に大きさ・ズームに合わせて描く。
- 収録ごとに `~/Movies/ScreenTake/収録 日時/` を作り、`recording.mov`（原本、書き換えない）と `project.json`（収録情報・ポインタ・編集内容）を置く。
- `Source/Project.swift`：編集内容と時間の対応（削除した区間・ズームの範囲は収録の時刻で持ち、タイムラインは編集後の時刻）。画面に依存しないので単体テストする。
- `Source/Compositor.swift`：`AVMutableComposition` に残す区間を並べ、独自の `AVVideoCompositing`（Core Image）でズーム・クリックの輪・カメラを描く。プレビューと書き出しは同じ描画。
- `Source/Exporter.swift`：`AVAssetExportSession`（MP4/MOV）、`AVAssetImageGenerator`＋ImageIO（GIF）。隠しファイルに書いて最後に置き換えるので、失敗・キャンセルで壊れたファイルは残らない。
- 権限：画面収録（必須）、マイク・カメラ（オンにして収録するときだけ要求）、オートメーション（Path Finderでの表示だけ）。外部通信なし（更新確認を除く。配信先は未設定）。
- 配布（Hardened Runtime）では `ScreenTake.entitlements`（audio-input・camera）を付けて署名する。

## ビルド・テスト

```
./test.sh            # 時間計算の単体テスト＋生成した動画での書き出し（MP4・MOV・GIF）＋4言語の翻訳キー検証
./build.sh           # build/ScreenTake.app
./build.sh --deploy  # 検証後、/Applications と Latest Builds へ配置
```

## 更新履歴

### 1.0.0（build 1、2026-10-26）

- 最初の版。
