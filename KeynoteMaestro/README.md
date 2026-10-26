# KeynoteMaestro

Keynoteが前面のときだけ使える標準ショートカットのカスタム設定と、図形・不透明度・トランジションなどのスペシャル操作をまとめるmacOSアプリ。開発版は1.2.2（build 26）、公開配布版はbuild 16、macOS 13以降／Appleシリコン。Bundle IDは旧版互換の `jp.dtp-transit.keynotehelper` を維持します。

## メイン画面と設定

- 標準セット：デフォルト／カスタム／カスタム 2。デフォルトはKeynote本来のキー、2つのカスタムは個別保存。
- スペシャル：標準とは別タブ・独立スイッチ。旧一括スイッチは廃止。
- 標準資料は原典341項目・14カテゴリ。完全重複2組をまとめ339行を表示。従来の32操作に加え、キー単独で実行できる255項目を方向・数字別の305割り当て欄へ展開。マウス操作など52項目には対象外の理由を表示。
- 新しい標準キー欄は未設定から始まります。変更したキーで元のキーを送信するため、元と同じ選択・表示モードが必要です。登録を一時解除して送信し、再帰を防止。Keynoteが前面か送信直前にも再確認します。
- 設定は初期820×620ポイント、最小720×560ポイントでサイズ変更可能。標準タブは操作名の下に標準キーを表示し、変更欄との2列に整理。1列目は利用可能幅から伸縮し、操作名を折り返して行高を追従。ヘッダーと行は同じ配分を使い、狭い幅では変更欄を下段へ移動し、一覧は縦スクロール。既存の大きすぎる保存サイズは初回だけ縮小し、その後のサイズ選択は保持。
- 検索・カテゴリ・リセットはタブごと。旧設定はカスタムへ移行し、スペシャルのキーと個別オンオフは保持。

## パレット

メイン画面・ファイルメニュー・メニューバーメニューの「パレットを開く」から表示。幅230ポイントの非アクティブNSPanelで、表示数に応じて高さを調整します。画面に収まらない場合は縦スクロール。位置を保存し、画面内へ復帰します。

- トランジション：ディゾルブ／なし／マジックムーブ／マジックムーブ（自動）
- 中央：スライドの幅いっぱい／スライドの高さいっぱい／スライドの幅の80%
- オブジェクトの揃え：同じ高さに（最大）／同じ幅に（最大）／同じ幅に（最小）
- アニメーションをコピー／アニメーションをペースト
- スライドと同じ大きさの図形を作成／選択オブジェクトに背景の図形を追加（グループ化）

設定の「パレット」で14項目を個別に表示/非表示にします。初回はすべて表示し、変更は即時反映・保存。空のグループは見出しと不要な区切りを隠し、全OFFでも「パレットの設定…」から再表示できます。ファイル/メニューバーメニューからもパレット設定へ直接移動できます。表示選択はホットキーの個別オンオフ・キー割り当てとは独立し、新規グローバルキーはありません。

前面の実Keynote・対象外アプリ・権限・処理中を実行直前に確認し、書類IDとスライド番号を捕捉します。対象が変われば中止。図形作成は捕捉したスライドと同じ幅・高さの図形を1個だけ作ります。設定の既存コマンド名は変更していません。

## 主なスペシャル操作

- ⌥D：同じ座標にオブジェクトの複製。複製後⇧←・⇧↑で左上へ10ポイント補正。標準の複製とは別行。
- ⌃0：スライドと同じ大きさの図形。
- ⌃⌥⌘0：選択1件と同じ位置・大きさの白い長方形を作り最背面へ。グループ化なし。
- 背景の図形を追加（グループ化）：選択したトップレベル1個と同じフレームの背景を1個作り、背面へ送ってその2個だけをグループ化。背景の既定スタイルは保持。
- 不透明度10〜100%、隠す・再表示、幅・高さ・拡大縮小、まとめて整列、PNG書き出しなど。
- **自動マジックムーブ**：書類全体の連続する表示スライドに共通オブジェクトがある場合、手前だけを0.7秒へ。⌃⌥⇧⌘M、初期値オフ。画像・ムービー・オーディオは種類＋ファイル名、図形・テキストは種類＋テキスト、文字のない図形は種類＋丸めた幅×高さで照合。不一致・スキップ・最後の表示スライドの効果は保持。処理は非同期、設定枚数と途中失敗を表示。
- KeynoteSweeperの6サービスを呼び出す項目あり。スペシャル設定の項目名だけ末尾（KeynoteSweeper）を省略し、見出し・検索・サービス名は保持。⌃⌥0以外の削除項目は初期値オフ。

## 開発と検証

開発元は `/Users/takano/Git/macos-apps/KeynoteMaestro`。Dropbox旧ソースは保全元。

- ビルド：`NO_DEPLOY=1 ./build.sh`。配置は共通 `Shared/BuildTools/deploy_both.py` を使用。既存版をバックアップして `/Applications` とDropbox `Latest Builds` に同じ成果物を配置。
- テスト：`./test.sh`。104互換ID・103操作、原典全文、標準32／スペシャル71分類、305キー定義、旧保存形式、セット独立性、移行、4言語256キーを検証。
- 任意の実機統合テスト：`./test.sh --integration`。既存の書類には触れず、新規未保存16枚の書類で5枚への適用と、スキップ・不一致・最後の表示スライド・遅延・自動切り替えの保持を検証し、作成した書類だけを閉じます。
- 翻訳再生成：`python3 Localization/own.py && python3 Localization/make_strings.py`。
- 原典再生成：`python3 Localization/import_native_shortcuts.py && python3 Localization/make_native_actions.py`。

## 構成

| パス | 内容 |
|---|---|
| Sources/main.swift | メイン画面・設定タブ・ホットキー登録・送信 |
| Sources/KeynoteCommands.swift / CommandRunner.swift | 既存操作・AppleScript・メニュー処理 |
| Sources/AutoMagicMove.swift | 自動マジックムーブのスクリプト生成・共通判定・結果プロトコル |
| Sources/ShortcutCatalog.swift | 原典の分類・検索・比較行 |
| Sources/ShortcutProfiles.swift | セット保存・移行・標準／スペシャルの分離 |
| Sources/NativeKeyboardActions.swift | 標準キー列・配列に応じた記号解決 |
| Reference/KeynoteShortcuts-ja.txt | 提供された原典 |
| Resources/NativeShortcuts.json / NativeActions.json | 再生成できる原典・キー列 |
| Tests/ | 既存動作とセット・標準キーの検証 |
| Documentation/History/ | 改名・過去の変更記録 |

## 公開記事と配布

[GitHub Releases](https://github.com/swwwitch/KeynoteMaestro/releases)に公証済みbuild 16を公開し、[個人noteの記事](https://note.com/swwwitch/n/n7b7e549f7379)から案内しています。過去版の添付は保持。今回の自動マジックムーブ（build 17）はGitHub・noteへ公開しません。

build 17のソース・自動テスト・実機テスト記録は `Documentation/RELEASE-CHECKS.md` と `Shared/ReleasePreparation/20261023-KeynoteMaestro-build17/` を参照。公開済みbuild 16の配置先と履歴を保持します。


Palette settings include an independent **Show Palette** hotkey (initially unassigned). It is active only while Keynote is frontmost and reveals the existing palette without toggling it. Use the shared Change/Clear controls; existing feature/native assignments are checked for duplicates.


The palette is visible only while a supported Keynote is frontmost. Switching away temporarily hides it; returning restores it only if it was open. Closing the palette cancels automatic restoration.

## 2026-10-25 Dock非表示時のメニュー修正（1.2.2 build 29）

メイン・設定ウインドウがある間はアプリメニューを使用でき、最小化中もDock・⌘Tabに残ります。最後の対象ウインドウを閉じると再び隠し、非アクティブパレットと保存済みの設定値を保持します。

Developer ID署名・アプリ/DMG公証Accepted。両配置先の内容・署名・公証チケットと、/Applications版の起動を確認。 各アプリの画面操作と実ログインの確認範囲は別途配布記録に記載。

## 2026-10-25 アプリケーションスイッチャーからの再表示（1.2.2 build 30）

⌘Tabで選択するとメインウインドウを表示し、最小化中なら復元します。ログイン起動は静かなままとし、設定・ヘルプを明示的に開く操作、モーダル操作と常駐パレットを保護します。アプリ・DMGのDeveloper ID署名とApple公証、両配置先の内容一致と起動を確認。画面操作の確認範囲は配布記録を参照。
