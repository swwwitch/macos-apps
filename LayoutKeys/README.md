# LayoutKeys

登録したInDesignのスクリプト（.jsx・.js・.jsxbin）を、InDesignが前面のときにキーボードショートカットで実行するAppKit/SwiftUIアプリ。Apple Silicon / macOS 13以降。VectorKeys 1.1.0（Illustrator版）の仕組みをそのまま写した軽量版で、コンポーネント・アクション・KM取り込みなど VectorKeys 1.2.0 以降の機能は入れない。

- 登録：［スクリプトを追加…］（⌘O）でファイルを選ぶか、ウインドウへドラッグ。同じパスは二重に登録しない。名前は変えられる（初期値はファイル名）。並べ替えはドラッグ。
- ショートカット：スクリプトごとに割り当て。InDesignが前面のときだけ登録する（Carbon `RegisterEventHotKey`）。同じキーは一覧で上のものだけ。押した瞬間にもInDesignが前面か確かめる。
- 実行：`do script (POSIX file … as alias) language javascript undo mode entire script undo name "<名前>"` を osascript 経由で。1回の実行を［取り消し］1回で戻せる。前面のInDesignをパスで指定する（2025・2026など複数バージョン起動時の取り違えを避ける）。ダイアログボックスを出すスクリプトのため timeout は3600秒。直列で、待ちは3件まで。
- エラー表示：InDesignは「Adobe InDesign 2026でエラーが起きました: Uncaught JavaScript exception: <メッセージ> (54)」を返す（2026-11-03 実測、21.6）。<メッセージ>だけを出す。
- スクリプトの変数（SW_）：`var SW_名前 = 初期値;` を見つけて詳細欄に並べ、値を入れた変数だけ実行のたびに写しの初期値を差し替えて `do script "<本文>"` で実行する（VectorKeys 1.20.0 の VariableOverrides を移植、行末コメントを説明として表示）。`#targetengine` は本文で渡しても効く（2026-11-03 実測）。ファイルは書き換えない。
- 変数ごとのホットキー（VariableKey）：詳細欄の「ホットキー」の表で、行ごとに変数の値とキーを持つ。そのキーでは「スクリプトの変数」の値の上に行の値を重ねて実行する。行末コメントの `[a|b|c]` を候補として読み、メニューで選べ、候補ごとに行をまとめて作れる。スクリプト自体のキーが先、行のキーが後の順で重複を判定する。
- ファイルを移動したら「ファイルなし」と表示。［ファイルを選び直す…］でショートカットを保ったまま指定し直せる。
- アプリ呼び出しのショートカットは既定なし（⌃⌥＋英字はKeyboard Maestroで全部使用済み、2026-10-26）。設定で割り当てる。

## しくみ

- `Source/Scripts.swift`：登録内容（Foundationのみ、テスト対象）・AppleScriptの組み立て・osascript
- `Source/Variables.swift`：SW_ 変数の検出と差し替え（テスト対象）
- `Source/Runner.swift`：InDesignの判定（Bundle IDが `com.adobe.InDesign` で始まるもの）と直列実行
- `Source/AppModel.swift`：ショートカットの登録、追加・削除・指定し直し、実行結果
- `Source/Views.swift`：主画面・設定
- `Source/main.swift`：メニュー・起動
- 一覧は `~/Library/Application Support/LayoutKeys/Scripts.json`。スクリプトのファイルは読むだけ。
- 外部通信なし（更新確認を除く。配信先は未設定）。権限：オートメーション（InDesign）。アクセシビリティは使わない。

## ビルド・テスト

```
./test.sh            # 単体テスト＋4言語の翻訳キー・プレースホルダー検証
./build.sh           # build/LayoutKeys.app（開発Macはここまで）
Assets/make-icon.sh  # アイコンを作り直す（レイアウトしたページとキーキャップ）
```

`./build.sh --deploy`（/Applications と Latest Builds への配置）は公証Macの担当。

## 更新履歴

- 1.0.0 (3)　2026-11-03：ほかのアプリの基本仕様に合わせる。設定に「設定の共有」タブ（同期はホットキーを使うかどうかだけ、書き出し・読み込みはスクリプトの一覧も移す）、長い補足説明を「説明」で開閉。
- 1.0.0 (2)　2026-11-03：変数ごとのホットキー表に［すべての組み合わせを追加］（候補のある変数の値の組み合わせごとに行を作る。すでにある組み合わせは足さない）。
- 1.0.0 (1)　2026-11-03：新規。VectorKeys 1.1.0 を元にInDesign向けに。スクリプトの登録・ショートカットの割り当て・InDesign前面時だけの実行・1回の取り消しで戻せる実行・使った回数の表示・スクリプトの変数（SW_）の差し替え・変数ごとのホットキー。
