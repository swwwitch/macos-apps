# LayoutMate

macOS 13以降 / Intel・Apple Silicon対応（Universal）の常駐アプリ（Dock・アプリケーションスイッチャー・メニューバーに表示）。InDesignの作業を補助します。Illustrator向けの VectorMate の InDesign 版で、IdBackgroundOff 1.2.0 の写しから始めた別アプリです（Bundle ID `jp.dtp-transit.layoutmate`。IdBackgroundOff はそのまま残す）。

## 機能

メインウインドウは VectorMate と同じ構成（見出し・上部のタブ・下のボタン）。

### バックグラウンド書き出し

IdBackgroundOff と同じ。InDesignのアプリ内 `Contents/MacOS` に空ファイル `DisableAsyncExports.txt` を配置・削除し、PDFなどの「バックグラウンド書き出し／保存」をオフ／元に戻す。書き込み不可の場所は管理者認証（`do shell script … with administrator privileges`）。参考：[InDesignのバックグラウンド処理をOFFにする（note）](https://note.com/dtp_tranist/n/nf94bf905c478)

### UI

- UIの明るさ：`app.generalPreferences.uiBrightnessPreference`（0／0.5／0.51／1、いちばん近い段階）をラジオボタンで選ぶ。InDesignが前面のときだけ ⇧F2 で明るく、⇧F1 で暗く（Carbonのホットキーを前面アプリに合わせて登録・解除。設定の「ホットキー」で変更・解除）。隠しキー ⌥⇧F2 で「明」、⌥⇧F1 で「やや暗め」（設定・メニューに出さない。VectorMate と同じ）。
- 表示：アプリケーションフレーム（`generalPreferences.useApplicationFrame`）、コンテキストタスクバー（メニューアクション。ID 148997、見つからなければ名前「コンテキストタスクバー」「Contextual Task Bar」で探して `invoke()`）、ツールバー（2列）（`generalPreferences.toolsPanel` を `DOUBLE_COLUMN`／`SINGLE_COLUMN`）。
- アプリケーションバー：IdBackgroundOff と同じ。ワークスペースのXMLの `<app-container-control-bar … is-closed>` を書き換える（InDesignの起動中は不可）。
- 読み書きは `do script … language javascript`（イベント `K2  `/`dosc`、言語 `JSLg`）を前面のInDesign（なければ起動中のもの）のpidへ送る（`Source/InDesignScript.swift`）。メニューアクションの `checked` は同じスクリプト内では古い値なので、変更と読み直しは別の呼び出し。

### ツール

いずれも初期値オフ、InDesignが前面のときだけ、アクセシビリティの許可が必要。

- 選択ツール：修飾キー（control・option・command・shift、初期値 control。設定 `doubleTapKey`）だけを0.3秒以内に押して離し、0.35秒以内にもう一度で `app.toolBoxTools.currentTool = UITools.SELECTION_TOOL`（VectorMate の ToolWatcher から移植、`Source/DoubleTap.swift`）。
- ドラッグでパン：右ボタン／中ボタン（ラジオボタン）のドラッグをスペース＋左ドラッグ（手のひらツール）に置き換える。共通部品 `Shared/DragPan`（VectorMate 2.24.0 の実装を一般化）。文字ツールの判定は `app.toolBoxTools.currentTool` に `TYPE` を含むか（0.3秒で答えが無ければ文字ツール扱い）。

### 関連付け

複数の版のInDesignがあるとき、`.indd`・`.idml` を開く版をまとめて切り替える（VectorMate の「関連付け」から移植、`Source/VersionPinning.swift`）。Launch Services の記録に `LSHandlerPreferredVersions` を書いて lsd を再起動し、反映を確かめる。変更前の記録は `~/Library/Application Support/LayoutMate/LaunchServicesBackups` に10件まで。

### 設定（⌘,）

- 起動・常駐：ログイン時に起動（初期値オフ）・Dockとアプリケーションスイッチャーに表示しない・ウインドウを閉じても常駐（初期値オン）・アプリ起動のホットキー（初期値は未設定）・メニューバーのアイコン・アクセシビリティ（ツールをオンにしたときだけ必要）。
- ホットキー：UIの明るさの有効・変更・解除。
- 情報。

## 権限

- アクセシビリティ：ツール（キーのグローバル監視、CGEventTap）。
- オートメーション（InDesign）：UI・ツールの読み書き。初回は `AEDeterminePermissionToAutomateTarget` で同意を求める。`NSAppleEventsUsageDescription`（4言語）あり、公証時の署名で apple-events の権限が付く。

## 開発

```sh
./build.sh   # build/LayoutMate.app（SKIP_DEPLOY=1 で配布処理を止める）
./test.sh    # 疑似InDesignでの検出・配置・削除、ワークスペースの書き換え、パンの状態の移り変わり
```

文字列・Info.plist は `make-resources.py`、ヘルプは `help_text.py`、アイコンは `Assets/make-icon.sh`（`GenerateIcon.swift`、見開きのページ）から生成。共通部品は `../Shared` から直接コンパイルする。

このビルドはローカル利用向けに証明書（PL9S9PXX96）で署名しています。Developer ID署名・公証・更新配信先は未設定です。

## 更新履歴

### 0.1.1（build 2、2026-11-13）

- UIタブ内をスクロールできるようにし、タブ列と下部のボタンに項目が重なる問題を修正。
- 初回のオートメーション許可後にそのまま読み込み、許可がない場合は設定場所を表示。⌘Rでも明るさと表示を再取得。

### 0.1.0（build 1、2026-11-12）

- 新規。IdBackgroundOff 1.2.0 の「バックグラウンド書き出し」「アプリケーションバー」「ドラッグでパン」に、VectorMate の UIの明るさ（ホットキー・隠しキー）、表示、選択ツールのダブルタップ、関連付けを移植。設定ウインドウ（起動・常駐・ホットキー・情報）、常駐、ログイン起動、アプリ起動のホットキー、メニューバー、ヘルプ（4言語）を搭載。
