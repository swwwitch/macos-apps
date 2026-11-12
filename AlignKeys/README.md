# AlignKeys

InDesignのスクリプト「近くの線に揃える」（indesign-scripts の `jsx/frame/IdAlignToNearestEdgePalette.jsx`）のボタンを、InDesignが前面のときにキーボードショートカットで実行するAppKit/SwiftUIアプリ。Apple Silicon / macOS 13以降。LayoutKeys（汎用版）とは別アプリ。

- スクリプトは `Script/IdAlignToNearestEdgePalette.jsx` に写しを置き、アプリに同梱する。元の更新は `./update-script.sh` で写してビルドし直す。
- 実行：同梱スクリプトの `SW_ACTION`・`SW_FROM_CENTER`・`SW_MOVE_AS_UNIT`・`SW_CENTER_BASIS` の初期値を差し替えた本文を `do script "<本文>" language javascript undo mode entire script undo name "近くの線に揃える（…）"` で実行（VariableOverrides は VectorKeys 1.20.0 から）。`#targetengine` は本文でも効く（2026-11-03 実測）。［パレットを開く］は差し替えなしの本文。
- ホットキー：11個のボタンと、辺を揃える8個の「中央から」の欄（19欄）。各欄のキーに ⌥ を加えた形＝選択をまとめて移動、⇧ を加えた形＝中央揃えの基準をマージン、⌥⇧＝両方を同時に登録する（ユーザー指定）。キー自体に ⌥・⇧ が入っていればその形は作らない。表の順で先のものが勝ち、重なり・登録失敗は欄の下に表示。
- 矢印キー（ユーザー指定）：上・下・左・右は ⌃⌘＋←↑→↓ でも実行（⌥・⇧ の形も）。UserDefaults `arrowKeys`（初期値オン）、表のキーのあとに登録するので重なれば表が勝つ。
- 初期値：⌃⌘ に U I O／J K L／M , .（3×3 の並び、ユーザー指定）。水平方向中央・垂直方向中央・「中央から」は未設定。保存は UserDefaults `actionHotkeys`（JSON）。何も保存していなければ初期値、解除したキーは解除のまま。
- InDesign優先（ユーザー指定「⌃⌥⌘の組み合わせ、InDesign上ではInDesignのキーボードショートカットが優先」を全修飾キーに広げた）：InDesignのショートカットのセット（~/Library/Preferences/Adobe InDesign/Version <major>.*/<locale>/InDesign Shortcut Sets/ の最新の .indk、無ければアプリの Presets のデフォルト）を読み、DefaultContext・TextContext・TableContext のキーと同じものは登録しない。InDesignが前面に来るたびに更新日を見て読み直す。UserDefaults `preferInDesign`（初期値オン）。使っているセットは .indk の更新日で推定（InDesignの設定から読む方法は未確認）。
- InDesignが前面のときだけ登録（Carbon `RegisterEventHotKey`）、押した瞬間にも前面を確かめる。直列実行・待ちは3件まで。
- 設定の共有：同期は `actionHotkeys`・`arrowKeys`・`preferInDesign`・`hotkeysEnabled`。
- アプリ呼び出しのショートカットは既定なし。

## しくみ

- `Source/Scripts.swift`：ボタン・欄・⌥⇧の形・キー表・初期値・スクリプト本文の組み立て・AppleScript・osascript（Foundationのみ、テスト対象）
- `Source/Variables.swift`：SW_ 変数の差し替え（VectorKeys 1.20.0 から）
- `Source/Runner.swift`：InDesignの判定と直列実行
- `Source/AppModel.swift`：ホットキーの登録と実行結果
- `Source/Views.swift`：主画面（ボタンとホットキーの表）・設定
- `Source/main.swift`：メニュー・起動・設定の共有
- 外部通信なし（更新確認を除く。配信先は未設定）。権限：オートメーション（InDesign）。アクセシビリティは使わない。

## ビルド・テスト

```
./update-script.sh   # indesign-scripts から最新のスクリプトを写す
./test.sh            # 単体テスト（同梱スクリプトの変数も確認）＋4言語の翻訳キー・プレースホルダー検証
./build.sh           # build/AlignKeys.app（開発Macはここまで）
Assets/make-icon.sh  # アイコンを作り直す（ガイドに寄せたブロックとキーキャップ）
```

`./build.sh --deploy`（/Applications と Latest Builds への配置）は公証Macの担当。

## 更新履歴

- 1.0.0 (1)　2026-11-03：新規。同梱の IdAlignToNearestEdgePalette.jsx（v1.2.0）のボタンを、InDesign前面時のショートカットで実行。⌥＝まとめて移動、⇧＝マージン基準。初期値は ⌃⌘＋U I O／J K L／M , .、上下左右は ⌃⌘＋矢印キーでも、InDesignのショートカットと重なるキーはInDesignを優先。
