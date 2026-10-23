# KeynoteMaestro

Keynoteが前面のときだけ使える標準ショートカットのカスタム設定と、図形・不透明度・トランジションなどのスペシャル操作をまとめるmacOSアプリ。現行版は1.2.2（build 15）、macOS 13以降／Appleシリコン。Bundle IDは旧版互換の `jp.dtp-transit.keynotehelper` を維持します。

## メイン画面と設定

- 標準セット：デフォルト／カスタム／カスタム 2。デフォルトはKeynote本来のキー、2つのカスタムは個別保存。
- スペシャル：標準とは別タブ・独立スイッチ。旧一括スイッチは廃止。
- 標準資料は原典341項目・14カテゴリ。完全重複2組をまとめ339行を表示。従来の32操作に加え、キー単独で実行できる255項目を方向・数字別の305割り当て欄へ展開。マウス操作など52項目には対象外の理由を表示。
- 新しい標準キー欄は未設定から始まります。変更したキーで元のキーを送信するため、元と同じ選択・表示モードが必要です。登録を一時解除して送信し、再帰を防止。Keynoteが前面か送信直前にも再確認します。
- 検索・カテゴリ・リセットはタブごと。旧設定はカスタムへ移行し、スペシャルのキーと個別オンオフは保持。

## 主なスペシャル操作

- ⌥D：同じ座標にオブジェクトの複製。複製後⇧←・⇧↑で左上へ10ポイント補正。標準の複製とは別行。
- ⌃0：スライドと同じ大きさの図形。
- ⌃⌥⌘0：選択1件と同じ位置・大きさの白い長方形を作り最背面へ。グループ化なし。
- 不透明度10〜100%、隠す・再表示、幅・高さ・拡大縮小、まとめて整列、PNG書き出しなど。
- KeynoteSweeperの6サービスを呼び出す項目あり。⌃⌥0以外の削除項目は初期値オフ。

## 開発と検証

開発元は `/Users/takano/Git/macos-apps/KeynoteMaestro`。Dropbox旧ソースは保全元。

- ビルド：`NO_DEPLOY=1 ./build.sh`。配置は共通 `Shared/BuildTools/deploy_both.py` を使用。既存版をバックアップして `/Applications` とDropbox `Latest Builds` に同じ成果物を配置。
- テスト：`./test.sh`。103互換ID・102既存操作、原典全文、標準32／スペシャル70分類、305キー定義、旧保存形式、セット独立性、移行、4言語251キーを検証。
- 翻訳再生成：`python3 Localization/own.py && python3 Localization/make_strings.py`。
- 原典再生成：`python3 Localization/import_native_shortcuts.py && python3 Localization/make_native_actions.py`。

## 構成

| パス | 内容 |
|---|---|
| Sources/main.swift | メイン画面・設定タブ・ホットキー登録・送信 |
| Sources/KeynoteCommands.swift / CommandRunner.swift | 既存操作・AppleScript・メニュー処理 |
| Sources/ShortcutCatalog.swift | 原典の分類・検索・比較行 |
| Sources/ShortcutProfiles.swift | セット保存・移行・標準／スペシャルの分離 |
| Sources/NativeKeyboardActions.swift | 標準キー列・配列に応じた記号解決 |
| Reference/KeynoteShortcuts-ja.txt | 提供された原典 |
| Resources/NativeShortcuts.json / NativeActions.json | 再生成できる原典・キー列 |
| Tests/ | 既存動作とセット・標準キーの検証 |
| Documentation/History/ | 改名・過去の変更記録 |

## 公開記事と配布

[個人noteの記事](https://note.com/swwwitch/n/n7b7e549f7379)を現行名称・設定・図形操作へ更新済み。旧名KeynoteHelper build 7の公証済みDMGは旧配布版として保持し、build 15はDeveloper ID署名済みDMGまで準備。Apple公証への送信と配布ファイルの追加は承認待ちです。

build 15は自動テスト・両配置先の内容／署名一致・起動・旧設定保持を確認。Keynote上で全標準操作を実際に実行する検証は未確認。今回の成果物を公証済みとは扱いません。
