# VectorKeys

登録したIllustratorのスクリプト（.jsx・.js・.jsxbin）を、Illustratorが前面のときにキーボードショートカットで実行するAppKit/SwiftUIアプリ。Apple Silicon / macOS 13以降。

- 登録：［スクリプトを追加…］（⌘O）でファイルを選ぶか、ウインドウへドラッグ。同じパスは二重に登録しない。名前は変えられる（初期値はファイル名）。並べ替えはドラッグ。
- ショートカット：スクリプトごとに割り当て。Illustratorが前面のときだけ登録する（Carbon `RegisterEventHotKey`）。同じキーは一覧で上のものだけ。押した瞬間にもIllustratorが前面か確かめる。
- 実行：`do javascript (POSIX file … as alias)` を osascript 経由で。前面のIllustratorをパスで指定する（複数バージョン起動時の取り違えを避ける）。ダイアログボックスを出すスクリプトのため timeout は3600秒。直列で、待ちは3件まで。
- ファイルを移動したら「ファイルなし」と表示。［ファイルを選び直す…］でショートカットを保ったまま指定し直せる。
- アプリ呼び出しのショートカットは既定なし（⌃⌥＋英字はKeyboard Maestroで全部使用済み、2026-10-26）。設定で割り当てる。
- KMのマクロを取り込んで手順ごと再現したいときは VectorMaestro を使う。

## しくみ

- `Source/Scripts.swift`：登録内容（Foundationのみ、テスト対象）・AppleScriptの組み立て・osascript
- `Source/Runner.swift`：Illustratorの判定と直列実行
- `Source/AppModel.swift`：ショートカットの登録、追加・削除・指定し直し、実行結果
- `Source/Views.swift`：主画面・設定
- `Source/main.swift`：メニュー・起動
- 一覧は `~/Library/Application Support/VectorKeys/Scripts.json`。スクリプトのファイルは読むだけ。
- 外部通信なし（更新確認を除く。配信先は未設定）。権限：オートメーション（Illustrator）。アクセシビリティは使わない。

## ビルド・テスト

```
./test.sh            # 単体テスト＋4言語の翻訳キー・プレースホルダー検証
./build.sh           # build/VectorKeys.app
./build.sh --deploy  # 検証後、/Applications と Latest Builds へ配置
Assets/make-icon.sh  # アイコンを作り直す
```

## 更新履歴

- 1.1.0 (2)　2026-10-26：使った回数を表示（一覧と詳細欄、最終実行日時も）。エラーなく終わった実行を数える。
- 1.0.0 (1)　2026-10-26：新規。スクリプトの登録・ショートカットの割り当て・Illustrator前面時だけの実行。
